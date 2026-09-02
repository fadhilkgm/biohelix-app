import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/network/api_exception.dart';
import 'inworld_signaling_api.dart';
import 'live_voice_conversation.dart';
import 'live_voice_state.dart';

typedef RealtimeTurnCompleted =
    FutureOr<void> Function(String transcript, String response);
typedef RealtimeTurnContext = Future<String> Function(String transcript);
typedef RealtimeFunctionCallHandler =
    Future<RealtimeFunctionResult> Function(
      String name,
      Map<String, dynamic> arguments,
    );

class RealtimeFunctionResult {
  const RealtimeFunctionResult({
    required this.output,
    this.responseInstructions = '',
  });

  final Map<String, dynamic> output;
  final String responseInstructions;
}

class LiveVoiceController extends ChangeNotifier with WidgetsBindingObserver {
  LiveVoiceController({
    required InworldSignalingApi signalingApi,
    required RealtimeTurnCompleted onTurnCompleted,
    required RealtimeTurnContext onTurnContext,
  }) : _signalingApi = signalingApi,
       _onTurnCompleted = onTurnCompleted,
       _onTurnContext = onTurnContext {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Whole-handshake budget: bootstrap, microphone, SDP exchange and the first
  /// session event must all land inside this window.
  static const Duration _connectBudget = Duration(seconds: 12);

  /// Longest the client waits for a server-reflexive/relay candidate before
  /// posting the offer anyway.
  static const Duration _iceGatheringBudget = Duration(milliseconds: 1500);

  /// Per-turn context lookup budget before falling back to session-only
  /// instructions.
  static const Duration _turnContextBudget = Duration(milliseconds: 1200);

  static const Duration _reconnectDebounce = Duration(milliseconds: 2500);
  static const Duration _reconnectWindow = Duration(seconds: 60);
  static const int _maxReconnectAttempts = 2;

  final InworldSignalingApi _signalingApi;
  final RealtimeTurnCompleted _onTurnCompleted;
  final RealtimeTurnContext _onTurnContext;

  /// High-frequency microphone/speaker level, kept off [state] so the 5-8Hz
  /// sampling never rebuilds the assistant tab.
  final ValueNotifier<double> soundLevel = ValueNotifier<double>(0);

  LiveVoiceState _state = const LiveVoiceState();
  RTCPeerConnection? _peer;
  RTCDataChannel? _events;
  MediaStream? _microphone;
  Completer<void>? _iceGathering;
  Timer? _connectBudgetTimer;
  Timer? _audioLevelTimer;
  Timer? _usageHeartbeatTimer;
  Timer? _reconnectDebounceTimer;
  Timer? _sessionReadyFallbackTimer;
  bool _disposed = false;
  bool _stopping = false;
  bool _statsInFlight = false;
  bool _usageStartInFlight = false;
  int _startGeneration = 0;
  int _reconnectAttempts = 0;
  DateTime? _reconnectWindowStart;
  bool _reconnectInFlight = false;
  bool _sessionReady = false;
  bool _audioSessionReapplied = false;
  bool _muted = false;
  String _conversationId = '';
  String _locale = 'en-IN';
  String? _usageSessionId;
  int _usageHeartbeatSeconds = 30;
  String _currentInputItemId = '';
  String _currentResponseId = '';
  String _initialResponseInstructions = '';
  bool _initialResponseRequested = false;
  bool _skipInitialResponse = false;
  bool _enableUsageTracking = true;
  String _sessionInstructions = '';
  List<Map<String, dynamic>> _sessionTools = const [];
  RealtimeFunctionCallHandler? _onFunctionCall;
  final Set<String> _handledFunctionCallIds = {};
  bool _awaitingFunctionResponse = false;
  final Map<String, StringBuffer> _inputTranscripts = {};
  final Map<String, StringBuffer> _responseText = {};
  final Map<String, StringBuffer> _responseAudioTranscripts = {};
  Stopwatch? _turnLatency;
  int? _responseCreateSentAtMs;
  bool _firstResponseAudioReceived = false;

  LiveVoiceState get state => _state;

  bool get isMuted => _muted;

  /// Fetches short-lived ICE/session configuration ahead of the voice tap.
  /// This does not open the microphone or create an Inworld call.
  Future<void> prewarm({required String locale}) async {
    if (_disposed || _state.isActive) return;
    _locale = locale;
    try {
      await _signalingApi.bootstrap(locale: locale);
      _debugLog('voice bootstrap prewarmed');
    } catch (error) {
      // A warm-up failure must not prevent the normal start path from retrying.
      _debugLog('voice bootstrap prewarm failed: ${_safeError(error)}');
    }
  }

  Future<void> start({
    required String locale,
    required String conversationId,
    String initialResponseInstructions = '',
    bool enableUsageTracking = true,
    String sessionInstructions = '',
    List<Map<String, dynamic>> tools = const [],
    RealtimeFunctionCallHandler? onFunctionCall,
  }) async {
    if (_state.isActive) {
      _debugLog('start ignored: session is already active');
      return;
    }
    final generation = ++_startGeneration;
    _locale = locale;
    _initialResponseInstructions = initialResponseInstructions.trim();
    _initialResponseRequested = false;
    _skipInitialResponse = false;
    _enableUsageTracking = enableUsageTracking;
    _sessionInstructions = sessionInstructions.trim();
    _sessionTools = tools;
    _onFunctionCall = onFunctionCall;
    _handledFunctionCallIds.clear();
    _awaitingFunctionResponse = false;
    _conversationId = conversationId;
    _muted = false;
    _reconnectAttempts = 0;
    _reconnectWindowStart = null;
    _debugLog('start requested locale=$locale');
    _armConnectBudget();
    await _runConnectSequence(generation: generation, reconnect: false);
  }

  Future<void> stop({String reason = 'user_stopped'}) async {
    if (_stopping) {
      _debugLog('stop ignored: already stopping');
      return;
    }
    _debugLog('stop requested: reason=$reason');
    _stopping = true;
    // Any connect sequence still in flight must abandon its resources.
    _startGeneration++;
    _cancelConnectTimers();
    if (!_disposed) {
      _setState(_state.copyWith(phase: LiveVoicePhase.closing));
    }
    await _releaseResources();
    _clearTurnBuffers();
    if (!_disposed) {
      _setState(const LiveVoiceState(phase: LiveVoicePhase.closed));
    }
    _stopping = false;
  }

  Future<void> interrupt() async {
    if (_currentResponseId.isEmpty && !_state.isSpeaking) {
      _debugLog('interrupt ignored: no response is in progress');
      return;
    }
    if (_events?.state != RTCDataChannelState.RTCDataChannelOpen) {
      _debugLog('interrupt ignored: data channel is not open');
      return;
    }
    _debugLog('interrupting current response');
    await _sendEvent({'type': 'response.cancel'});
    await _sendEvent({'type': 'output_audio_buffer.clear'});
    _responseText.clear();
    _responseAudioTranscripts.clear();
    _currentResponseId = '';
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.listening,
        responseText: '',
        clearError: true,
      ),
    );
  }

  Future<void> toggleMute() async {
    final microphone = _microphone;
    if (microphone == null) return;
    final next = !_muted;
    for (final track in microphone.getAudioTracks()) {
      try {
        await Helper.setMicrophoneMute(next, track);
      } catch (error) {
        _debugLog('native mic mute unavailable: ${_safeError(error)}');
      }
      track.enabled = !next;
    }
    _muted = next;
    _debugLog('microphone muted=$_muted');
    if (!_disposed) notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Connect sequence
  // ---------------------------------------------------------------------------

  bool _isStale(int generation) =>
      generation != _startGeneration || _stopping || _disposed;

  void _armConnectBudget() {
    _connectBudgetTimer?.cancel();
    _connectBudgetTimer = Timer(_connectBudget, () {
      if (_disposed || _stopping || _sessionReady) return;
      _debugLog('connect budget elapsed before the session became ready');
      _signalingApi.invalidateBootstrap();
      _setError(
        'Could not reach the voice service. Check your connection and try again.',
      );
    });
  }

  Future<void> _runConnectSequence({
    required int generation,
    required bool reconnect,
  }) async {
    final startup = Stopwatch()..start();
    _sessionReady = false;
    _audioSessionReapplied = false;
    _setState(
      _state.copyWith(
        phase: reconnect
            ? LiveVoicePhase.reconnecting
            : LiveVoicePhase.connecting,
        clearError: true,
      ),
    );

    MediaStream? microphone;
    RTCPeerConnection? peer;
    RTCDataChannel? channel;
    Object? microphoneError;
    // The three slow start-up steps are independent: running the microphone
    // permission prompt alongside the network calls removes a full round trip
    // from the patient's perceived latency.
    final bootstrapFuture = _signalingApi.bootstrap(locale: _locale);
    final audioSessionFuture = _configureAudioSession();
    final microphoneFuture = navigator.mediaDevices
        .getUserMedia({
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': false,
        })
        .then<MediaStream?>((stream) {
          microphone = stream;
          return stream;
        })
        .catchError((Object error) {
          microphoneError = error;
          return null;
        });

    // A superseded attempt must only dispose what it created: touching the
    // shared fields would tear down the attempt that replaced it.
    Future<void> abandon() async {
      _debugLog('connect attempt superseded; abandoning its resources');
      if (identical(_events, channel)) _events = null;
      if (identical(_microphone, microphone)) _microphone = null;
      if (identical(_peer, peer)) _peer = null;
      try {
        await channel?.close();
      } catch (_) {
        // Already gone with the transport.
      }
      await microphoneFuture.then(_disposeStream);
      await _disposePeer(peer);
    }

    try {
      final bootstrap = await bootstrapFuture;
      if (_isStale(generation)) return abandon();
      _debugLog(
        'bootstrap received: iceServers=${bootstrap.iceServers.length}, '
        'sessionEvent=${bootstrap.sessionUpdate['type']}, '
        'elapsed=${startup.elapsedMilliseconds}ms',
      );
      if (bootstrap.iceServers.isEmpty) {
        throw StateError('No realtime ICE servers are available.');
      }

      peer = await createPeerConnection({
        'iceServers': bootstrap.iceServers
            .map((server) => server.toWebRtcJson())
            .toList(),
        'sdpSemantics': 'unified-plan',
        // Begin gathering candidates as early as the native WebRTC stack allows.
        'iceCandidatePoolSize': 2,
      });
      if (_isStale(generation)) return abandon();
      _debugLog('peer connection created');
      _peer = peer;
      _wirePeerCallbacks(peer);

      await audioSessionFuture;
      await microphoneFuture;
      if (_isStale(generation)) return abandon();
      if (microphoneError != null) throw microphoneError!;
      final stream = microphone;
      if (stream == null) {
        throw StateError('The microphone could not be opened.');
      }
      _microphone = stream;
      _muted = false;
      _debugLog(
        'microphone acquired: audioTracks=${stream.getAudioTracks().length}',
      );
      for (final track in stream.getAudioTracks()) {
        await peer.addTrack(track, stream);
      }
      if (_isStale(generation)) return abandon();
      _startAudioLevelMonitor();

      channel = await peer.createDataChannel(
        'oai-events',
        RTCDataChannelInit()..ordered = true,
      );
      if (_isStale(generation)) return abandon();
      _debugLog('data channel created: label=oai-events');
      _events = channel;
      _wireDataChannel(
        channel,
        _configuredSessionUpdate(bootstrap.sessionUpdate),
      );

      final offer = await peer.createOffer({'offerToReceiveAudio': true});
      if (_isStale(generation)) return abandon();
      await peer.setLocalDescription(offer);
      if (_isStale(generation)) return abandon();
      _debugLog('local SDP offer set; waiting for ICE gathering');
      await _waitForIceGathering(peer);
      if (_isStale(generation)) return abandon();
      final local = await peer.getLocalDescription();
      final offerSdp = local?.sdp ?? '';
      if (!offerSdp.trimLeft().startsWith('v=0')) {
        throw StateError('WebRTC did not create a valid SDP offer.');
      }

      _debugLog(
        'sending SDP offer to Laravel: bytes=${offerSdp.length}, '
        'elapsed=${startup.elapsedMilliseconds}ms',
      );
      final answer = await _signalingApi.createCall(offerSdp);
      if (_isStale(generation)) return abandon();
      _debugLog(
        'SDP answer received: bytes=${answer.length}, '
        'elapsed=${startup.elapsedMilliseconds}ms',
      );
      await peer.setRemoteDescription(RTCSessionDescription(answer, 'answer'));
      if (_isStale(generation)) return abandon();
      _debugLog('remote SDP answer set; awaiting the first session event');
    } catch (error) {
      _debugLog('connect sequence failed: ${_safeError(error)}');
      _signalingApi.invalidateBootstrap();
      if (_isStale(generation)) {
        await abandon();
        return;
      }
      // _setError supersedes this attempt and releases the shared transport.
      _setError(_friendlyError(error));
      await microphoneFuture.then(_disposeStream);
    }
  }

  Future<void> _waitForIceGathering(RTCPeerConnection peer) async {
    if (await peer.getIceGatheringState() ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final gathering = Completer<void>();
    _iceGathering = gathering;
    // A single server-reflexive or relay candidate is enough for the Inworld
    // edge to reach us; waiting for full gathering only adds dead air.
    await gathering.future.timeout(
      _iceGatheringBudget,
      onTimeout: () {
        _debugLog('ICE gathering budget elapsed; continuing with current SDP');
      },
    );
    _iceGathering = null;
  }

  void _completeIceGathering(String reason) {
    final gathering = _iceGathering;
    if (gathering == null || gathering.isCompleted) return;
    _debugLog('ICE gathering satisfied: $reason');
    gathering.complete();
  }

  void _wirePeerCallbacks(RTCPeerConnection peer) {
    peer.onIceCandidate = (candidate) {
      final value = candidate.candidate ?? '';
      if (value.isEmpty) {
        _completeIceGathering('end-of-candidates');
        return;
      }
      if (value.contains('typ srflx') || value.contains('typ relay')) {
        _completeIceGathering('reachable candidate found');
      }
    };
    peer.onIceGatheringState = (iceState) {
      _debugLog('ICE gathering state=$iceState');
      if (iceState == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        _completeIceGathering('gathering complete');
      }
    };
    peer.onIceConnectionState = (iceState) {
      _debugLog('ICE connection state=$iceState');
    };
    peer.onSignalingState = (signalingState) {
      _debugLog('signaling state=$signalingState');
    };
    peer.onConnectionState = (connectionState) {
      if (!identical(_peer, peer)) return;
      _debugLog('peer connection state=$connectionState');
      switch (connectionState) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _reconnectDebounceTimer?.cancel();
          _reconnectDebounceTimer = null;
          // Android resets the audio mode once the remote track starts, so the
          // communication routing has to be re-applied exactly once per call.
          if (!_audioSessionReapplied) {
            _audioSessionReapplied = true;
            unawaited(_configureAudioSession());
          }
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _handleConnectionLoss(immediate: false);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _handleConnectionLoss(immediate: true);
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          if (!_stopping && !_reconnectInFlight && _state.isActive) {
            _setState(_state.copyWith(phase: LiveVoicePhase.closed));
          }
        default:
          break;
      }
    };
    peer.onTrack = (event) {
      _debugLog(
        'remote track received: kind=${event.track.kind}, '
        'id=${event.track.id}, streams=${event.streams.length}',
      );
      if (event.track.kind == 'audio') {
        event.track.enabled = true;
      }
    };
  }

  Future<void> _configureAudioSession() async {
    try {
      await Helper.setAndroidAudioConfiguration(
        AndroidAudioConfiguration.communication,
      );
      await Helper.setAppleAudioConfiguration(
        AppleNativeAudioManagement.getAppleAudioConfigurationForMode(
          AppleAudioIOMode.localAndRemote,
          preferSpeakerOutput: true,
        ),
      );
      await Helper.setSpeakerphoneOnButPreferBluetooth();
      _debugLog('audio session configured for speaker/Bluetooth');
    } catch (error) {
      // Routing is a best-effort optimisation: a failure must not abort a call.
      _debugLog('audio session configuration failed: ${_safeError(error)}');
    }
  }

  // ---------------------------------------------------------------------------
  // Reconnect
  // ---------------------------------------------------------------------------

  void _handleConnectionLoss({required bool immediate}) {
    if (_disposed || _stopping || _reconnectInFlight || !_state.isActive) {
      return;
    }
    _setState(_state.copyWith(phase: LiveVoicePhase.reconnecting));
    // Heartbeats must not accrue reward time while the call is down.
    _usageHeartbeatTimer?.cancel();
    _usageHeartbeatTimer = null;
    if (immediate) {
      _reconnectDebounceTimer?.cancel();
      _reconnectDebounceTimer = null;
      unawaited(_reconnect());
      return;
    }
    _reconnectDebounceTimer?.cancel();
    _reconnectDebounceTimer = Timer(_reconnectDebounce, () {
      final peer = _peer;
      final connected =
          peer?.connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      if (connected) {
        _debugLog('reconnect skipped: the peer recovered on its own');
        return;
      }
      unawaited(_reconnect());
    });
  }

  Future<void> _reconnect() async {
    if (_disposed || _stopping || _reconnectInFlight) return;
    final now = DateTime.now();
    final windowStart = _reconnectWindowStart;
    if (windowStart == null || now.difference(windowStart) > _reconnectWindow) {
      _reconnectWindowStart = now;
      _reconnectAttempts = 0;
    }
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _debugLog('reconnect budget exhausted');
      _setError('Voice connection lost. Please try again.');
      return;
    }
    _reconnectAttempts++;
    _reconnectInFlight = true;
    _debugLog('reconnect attempt $_reconnectAttempts');
    try {
      // Inworld exposes no ICE-restart on this path, so a reconnect is a fresh
      // call. Usage tracking survives it, and the greeting is not repeated.
      await _teardownForReconnect();
      if (_disposed || _stopping) return;
      _skipInitialResponse = true;
      _initialResponseRequested = true;
      final generation = ++_startGeneration;
      _armConnectBudget();
      await _runConnectSequence(generation: generation, reconnect: true);
    } finally {
      _reconnectInFlight = false;
    }
  }

  /// Drops the media/peer/data-channel internals without emitting `closed`,
  /// raising an error, or finishing the reward-usage session.
  Future<void> _teardownForReconnect() async {
    _debugLog('tearing down transport for reconnect');
    _cancelConnectTimers();
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
    _usageHeartbeatTimer?.cancel();
    _usageHeartbeatTimer = null;
    _iceGathering = null;
    final events = _events;
    _events = null;
    try {
      await events?.close();
    } catch (_) {
      // The channel may already be gone with the transport.
    }
    final microphone = _microphone;
    _microphone = null;
    await _disposeStream(microphone);
    final peer = _peer;
    _peer = null;
    await _disposePeer(peer);
    _publishSoundLevel(0);
  }

  // ---------------------------------------------------------------------------
  // Audio level
  // ---------------------------------------------------------------------------

  void _startAudioLevelMonitor() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => unawaited(_readAudioLevel()),
    );
  }

  Future<void> _readAudioLevel() async {
    final peer = _peer;
    if (peer == null || _disposed || _statsInFlight) return;
    if (!_state.isListening && !_state.isSpeaking) return;
    _statsInFlight = true;
    try {
      final reports = await peer.getStats();
      var level = 0.0;
      for (final report in reports) {
        final type = report.type;
        if (type != 'media-source' &&
            type != 'inbound-rtp' &&
            type != 'outbound-rtp' &&
            type != 'track') {
          continue;
        }
        final values = report.values;
        final kind = values['kind'] ?? values['mediaType'];
        if (kind != null && kind != 'audio') continue;
        final raw = values['audioLevel'];
        if (raw is num && raw.toDouble() > level) {
          level = raw.toDouble();
        }
      }
      _publishSoundLevel(level.clamp(0.0, 1.0).toDouble());
    } catch (_) {
      // Audio-level stats are optional and differ across native WebRTC builds.
    } finally {
      _statsInFlight = false;
    }
  }

  void _publishSoundLevel(double level) {
    if (_disposed) return;
    if ((level - soundLevel.value).abs() < 0.005) return;
    // Deliberately bypasses notifyListeners: only the orb listens to levels.
    _state = _state.copyWith(soundLevel: level);
    soundLevel.value = level;
  }

  // ---------------------------------------------------------------------------
  // Data channel + events
  // ---------------------------------------------------------------------------

  void _wireDataChannel(
    RTCDataChannel channel,
    Map<String, dynamic> sessionUpdate,
  ) {
    channel.onDataChannelState = (channelState) {
      if (!identical(_events, channel)) return;
      _debugLog('data channel state=$channelState');
      if (channelState == RTCDataChannelState.RTCDataChannelOpen) {
        _debugLog('data channel open; sending session.update');
        unawaited(_sendEvent(sessionUpdate));
      } else if (channelState == RTCDataChannelState.RTCDataChannelClosed &&
          !_stopping &&
          !_reconnectInFlight &&
          _state.isActive) {
        _setError('Realtime event channel closed.');
      }
    };
    channel.onMessage = (message) {
      if (message.isBinary) {
        _debugLog('binary data-channel message received: ignored');
        return;
      }
      try {
        final decoded = jsonDecode(message.text);
        if (decoded is Map) {
          _handleEvent(Map<String, dynamic>.from(decoded));
        } else {
          _debugLog('non-object data-channel message received: ignored');
        }
      } catch (error) {
        _debugLog('invalid data-channel event: ${_safeError(error)}');
        _setError('Realtime server sent an invalid event.');
      }
    };
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    if (_disposed || _stopping || !_state.isActive) {
      _debugLog(
        'event ignored after voice session ended: ${type.isEmpty ? '<missing>' : type}',
      );
      return;
    }
    final deltaLength = event['delta']?.toString().length;
    _debugLog(
      deltaLength == null
          ? 'event received: type=${type.isEmpty ? '<missing>' : type}'
          : 'event received: type=$type deltaChars=$deltaLength',
    );
    switch (type) {
      case 'session.updated':
        _sessionReadyFallbackTimer?.cancel();
        _sessionReadyFallbackTimer = null;
        _markSessionReady(_sessionOf(event));
      case 'session.created':
        _connectBudgetTimer?.cancel();
        _connectBudgetTimer = null;
        final session = _sessionOf(event);
        // `session.updated` is the authoritative readiness signal, but some
        // edges never echo it. Fall back shortly after `session.created`.
        _sessionReadyFallbackTimer?.cancel();
        _sessionReadyFallbackTimer = Timer(
          const Duration(milliseconds: 1500),
          () {
            if (_disposed || _stopping || _sessionReady) return;
            _debugLog('session.updated never arrived; using session.created');
            _markSessionReady(session);
          },
        );
      case 'input_audio_buffer.speech_started':
        _resetTurnLatency();
        if (_state.isSpeaking) {
          unawaited(interrupt());
        }
        _setState(
          _state.copyWith(
            phase: LiveVoicePhase.listening,
            partialTranscript: '',
            responseText: '',
            clearError: true,
          ),
        );
      case 'input_audio_buffer.speech_stopped':
        _turnLatency = Stopwatch()..start();
        _debugLog('turn latency: speech stopped at 0ms');
        _setState(_state.copyWith(phase: LiveVoicePhase.transcribing));
      case 'conversation.item.input_audio_transcription.delta':
        final itemId = event['item_id']?.toString() ?? 'current-input';
        _currentInputItemId = itemId;
        final buffer = _inputTranscripts.putIfAbsent(itemId, StringBuffer.new);
        buffer.write(event['delta']?.toString() ?? '');
        _setState(_state.copyWith(partialTranscript: buffer.toString()));
      case 'conversation.item.input_audio_transcription.completed':
        final itemId = event['item_id']?.toString() ?? _currentInputItemId;
        final transcript =
            event['transcript']?.toString().trim() ??
            _inputTranscripts[itemId]?.toString().trim() ??
            '';
        _currentInputItemId = itemId;
        _inputTranscripts[itemId] = StringBuffer(transcript);
        _setState(
          _state.copyWith(
            phase: LiveVoicePhase.thinking,
            partialTranscript: '',
            finalTranscript: transcript,
          ),
        );
        _debugTurnLatency('transcription completed');
        unawaited(_requestContextAndRespond(itemId, transcript));
      case 'response.created':
        final response = _mapOf(event['response']);
        _currentResponseId =
            response['id']?.toString() ??
            event['response_id']?.toString() ??
            'current-response';
        final sentAt = _responseCreateSentAtMs;
        final elapsed = _turnLatency?.elapsedMilliseconds;
        if (sentAt != null && elapsed != null) {
          _debugLog(
            'turn latency: response created at ${elapsed}ms '
            '(provider create=${elapsed - sentAt}ms)',
          );
        } else {
          _debugTurnLatency('response created');
        }
        _setState(_state.copyWith(phase: LiveVoicePhase.thinking));
      case 'output_audio_buffer.started':
        _setState(_state.copyWith(phase: LiveVoicePhase.speaking));
      case 'output_audio_buffer.stopped':
      case 'output_audio_buffer.cleared':
        if (_state.isSpeaking) {
          _setState(_state.copyWith(phase: LiveVoicePhase.listening));
        }
      case 'response.output_audio_transcript.delta':
        _appendResponseDelta(event, audioTranscript: true);
      case 'response.output_text.delta':
        _appendResponseDelta(event, audioTranscript: false);
      case 'response.function_call_arguments.done':
        unawaited(_handleFunctionCall(event));
      case 'response.done':
        _completeResponse(event);
      case 'error':
        final error = _mapOf(event['error']);
        _debugLog(
          'provider error: code=${error['code'] ?? '<missing>'}, '
          'message=${error['message'] ?? '<missing>'}',
        );
        final fatal = !_isIgnorableProviderError(error);
        _setError(
          error['message']?.toString() ?? 'Realtime voice request failed.',
          fatal: fatal,
        );
      default:
        _debugLog('unhandled event type: ${type.isEmpty ? '<missing>' : type}');
    }
  }

  Map<String, dynamic> _sessionOf(Map<String, dynamic> event) =>
      _mapOf(event['session']);

  Map<String, dynamic> _mapOf(Object? value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  void _markSessionReady(Map<String, dynamic> session) {
    if (_disposed || _stopping || _sessionReady) return;
    _sessionReady = true;
    _connectBudgetTimer?.cancel();
    _connectBudgetTimer = null;
    _sessionReadyFallbackTimer?.cancel();
    _sessionReadyFallbackTimer = null;
    _reconnectAttempts = 0;
    _reconnectWindowStart = null;
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.listening,
        sessionId: session['id']?.toString(),
        clearError: true,
      ),
    );
    if (_usageSessionId != null) {
      _resumeUsageHeartbeat();
    } else {
      unawaited(_beginUsageTracking());
    }
    _requestInitialResponse();
  }

  /// Errors the provider raises for a cancel that arrived after the response
  /// already finished are normal in a barge-in flow and must not end the call.
  bool _isIgnorableProviderError(Map<String, dynamic> error) {
    final blob =
        '${error['code'] ?? ''} ${error['type'] ?? ''} ${error['message'] ?? ''}'
            .toLowerCase();
    return blob.contains('cancel') || blob.contains('no active response');
  }

  Future<void> _handleFunctionCall(Map<String, dynamic> event) async {
    final handler = _onFunctionCall;
    final item = _mapOf(event['item']);
    final callId =
        event['call_id']?.toString() ?? item['call_id']?.toString() ?? '';
    final name = event['name']?.toString() ?? item['name']?.toString() ?? '';
    if (handler == null || callId.isEmpty || name.isEmpty) {
      _debugLog('function call ignored: handler, call_id, or name missing');
      return;
    }
    if (!_handledFunctionCallIds.add(callId)) {
      _debugLog('duplicate function call ignored: $callId');
      return;
    }

    Map<String, dynamic> arguments = const {};
    final rawArguments =
        event['arguments']?.toString() ?? item['arguments']?.toString() ?? '{}';
    try {
      final decoded = jsonDecode(rawArguments);
      if (decoded is Map) {
        arguments = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      _debugLog('function call arguments were not valid JSON');
    }

    _awaitingFunctionResponse = true;
    _setState(_state.copyWith(phase: LiveVoicePhase.thinking));
    try {
      final result = await handler(name, arguments);
      if (_disposed || _stopping || !_state.isActive) return;
      await _sendEvent({
        'type': 'conversation.item.create',
        'item': {
          'type': 'function_call_output',
          'call_id': callId,
          'output': jsonEncode(result.output),
        },
      });
      await _sendEvent({
        'type': 'response.create',
        'response': {
          'output_modalities': ['audio', 'text'],
          if (result.responseInstructions.trim().isNotEmpty)
            'instructions': result.responseInstructions.trim(),
        },
      });
    } catch (error) {
      _awaitingFunctionResponse = false;
      _debugLog('function call failed: ${_safeError(error)}');
      // A tool failure is recoverable: apologise in-call rather than hanging up.
      await _recoverTurn(
        'Tell the patient that the requested check could not be completed '
        'right now, and offer to continue the conversation. Keep it to one '
        'short spoken sentence.',
      );
    }
  }

  Future<void> _requestContextAndRespond(
    String itemId,
    String transcript,
  ) async {
    if (transcript.isEmpty) {
      // Nothing usable was heard. Keep the microphone open instead of ending
      // the call, which is what patients expect after a cough or a pause.
      _debugLog('empty transcript: returning to listening');
      _setState(
        _state.copyWith(
          phase: LiveVoicePhase.listening,
          partialTranscript: '',
          finalTranscript: '',
        ),
      );
      return;
    }

    _debugLog(
      'requesting Laravel voice context for transcript chars=${transcript.length}',
    );
    final contextLookup = Stopwatch()..start();
    var useFallback = false;
    String instructions = '';
    try {
      // Late results are dropped by the timeout wrapper, so a slow context
      // lookup can never talk over the fallback response we already sent.
      instructions = await Future<String>.sync(
        () => _onTurnContext(transcript),
      ).timeout(_turnContextBudget);
      contextLookup.stop();
      _debugLog(
        'turn latency: Laravel context completed at '
        '${_turnLatency?.elapsedMilliseconds ?? -1}ms '
        '(round trip=${contextLookup.elapsedMilliseconds}ms)',
      );
      if (instructions.trim().isEmpty) useFallback = true;
    } on TimeoutException {
      contextLookup.stop();
      useFallback = true;
      _debugLog(
        'turn latency: Laravel context exceeded '
        '${_turnContextBudget.inMilliseconds}ms; using fallback instructions',
      );
    } catch (error) {
      contextLookup.stop();
      useFallback = true;
      _debugLog('Laravel voice context request failed: ${_safeError(error)}');
    }

    if (_disposed ||
        _stopping ||
        !_state.isActive ||
        _currentInputItemId != itemId) {
      return;
    }
    _responseCreateSentAtMs = _turnLatency?.elapsedMilliseconds;
    await _sendEvent({
      'type': 'response.create',
      'response': {
        'output_modalities': ['audio', 'text'],
        'instructions': useFallback
            ? kLiveVoiceFallbackTurnInstructions
            : instructions,
      },
    });
    _debugTurnLatency(
      useFallback ? 'fallback response.create sent' : 'response.create sent',
    );
  }

  void _requestInitialResponse() {
    if (_skipInitialResponse ||
        _initialResponseRequested ||
        _initialResponseInstructions.isEmpty) {
      return;
    }
    _initialResponseRequested = true;
    _debugLog('requesting initial assistant response');
    unawaited(
      _sendEvent({
        'type': 'response.create',
        'response': {
          'output_modalities': ['audio', 'text'],
          'instructions': _initialResponseInstructions,
        },
      }),
    );
  }

  Future<void> _recoverTurn(String spokenInstructions) async {
    if (_disposed || _stopping || !_state.isActive) return;
    _responseText.clear();
    _responseAudioTranscripts.clear();
    _currentResponseId = '';
    _setState(
      _state.copyWith(phase: LiveVoicePhase.thinking, responseText: ''),
    );
    await _sendEvent({
      'type': 'response.create',
      'response': {
        'output_modalities': ['audio', 'text'],
        'instructions': spokenInstructions,
      },
    });
  }

  void _appendResponseDelta(
    Map<String, dynamic> event, {
    required bool audioTranscript,
  }) {
    if (audioTranscript && !_firstResponseAudioReceived) {
      _firstResponseAudioReceived = true;
      _debugTurnLatency('first response audio transcript');
    }
    final responseId =
        event['response_id']?.toString() ??
        (_currentResponseId.isEmpty ? 'current-response' : _currentResponseId);
    _currentResponseId = responseId;
    final target = audioTranscript ? _responseAudioTranscripts : _responseText;
    final buffer = target.putIfAbsent(responseId, StringBuffer.new);
    buffer.write(event['delta']?.toString() ?? '');
    final display = _firstNonEmpty([
      _responseAudioTranscripts[responseId]?.toString(),
      _responseText[responseId]?.toString(),
    ]);
    _setState(
      _state.copyWith(phase: LiveVoicePhase.speaking, responseText: display),
    );
  }

  void _completeResponse(Map<String, dynamic> event) {
    _debugTurnLatency('response done');
    final response = _mapOf(event['response']);
    final responseId =
        response['id']?.toString() ??
        event['response_id']?.toString() ??
        _currentResponseId;
    final transcript =
        _inputTranscripts[_currentInputItemId]?.toString().trim() ??
        _state.finalTranscript.trim();
    final answer = _firstNonEmpty([
      _responseAudioTranscripts[responseId]?.toString().trim(),
      _responseText[responseId]?.toString().trim(),
      _state.responseText.trim(),
    ]);
    if (_awaitingFunctionResponse && answer.isEmpty) {
      _responseText.remove(responseId);
      _responseAudioTranscripts.remove(responseId);
      _currentResponseId = '';
      _setState(_state.copyWith(phase: LiveVoicePhase.thinking));
      return;
    }
    if (transcript.isNotEmpty && answer.isNotEmpty) {
      unawaited(Future.sync(() => _onTurnCompleted(transcript, answer)));
    }
    _awaitingFunctionResponse = false;
    _inputTranscripts.remove(_currentInputItemId);
    _responseText.remove(responseId);
    _responseAudioTranscripts.remove(responseId);
    _currentInputItemId = '';
    _currentResponseId = '';
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.listening,
        partialTranscript: '',
        finalTranscript: '',
        responseText: '',
        clearTurn: true,
      ),
    );
    _resetTurnLatency();
  }

  Future<void> _sendEvent(Map<String, dynamic> event) async {
    final channel = _events;
    if (channel == null ||
        channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      _debugLog(
        'event not sent: type=${event['type'] ?? '<missing>'}, '
        'channelState=${channel?.state}',
      );
      return;
    }
    _debugLog('event sending: type=${event['type'] ?? '<missing>'}');
    await channel.send(RTCDataChannelMessage(jsonEncode(event)));
    _debugLog('event sent: type=${event['type'] ?? '<missing>'}');
  }

  void _clearTurnBuffers() {
    _inputTranscripts.clear();
    _responseText.clear();
    _responseAudioTranscripts.clear();
    _currentInputItemId = '';
    _currentResponseId = '';
    _initialResponseInstructions = '';
    _initialResponseRequested = false;
    _skipInitialResponse = false;
    _enableUsageTracking = true;
    _conversationId = '';
    _sessionInstructions = '';
    _sessionTools = const [];
    _onFunctionCall = null;
    _handledFunctionCallIds.clear();
    _awaitingFunctionResponse = false;
    _reconnectAttempts = 0;
    _reconnectWindowStart = null;
    _muted = false;
    _resetTurnLatency();
  }

  Map<String, dynamic> _configuredSessionUpdate(Map<String, dynamic> source) {
    final update = Map<String, dynamic>.from(source);
    final session = source['session'] is Map
        ? Map<String, dynamic>.from(source['session'] as Map)
        : <String, dynamic>{};
    if (_sessionInstructions.isNotEmpty) {
      final existing = session['instructions']?.toString().trim() ?? '';
      session['instructions'] = existing.isEmpty
          ? _sessionInstructions
          : '$existing\n\n$_sessionInstructions';
    }
    if (_sessionTools.isNotEmpty) {
      session['tools'] = _sessionTools;
      session['tool_choice'] = 'auto';
    }
    update['session'] = session;

    return update;
  }

  void _debugTurnLatency(String stage) {
    final elapsed = _turnLatency?.elapsedMilliseconds;
    if (elapsed != null) {
      _debugLog('turn latency: $stage at ${elapsed}ms');
    }
  }

  void _resetTurnLatency() {
    _turnLatency?.stop();
    _turnLatency = null;
    _responseCreateSentAtMs = null;
    _firstResponseAudioReceived = false;
  }

  String _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      if ((value ?? '').isNotEmpty) return value!;
    }
    return '';
  }

  void _cancelConnectTimers() {
    _connectBudgetTimer?.cancel();
    _connectBudgetTimer = null;
    _sessionReadyFallbackTimer?.cancel();
    _sessionReadyFallbackTimer = null;
    _reconnectDebounceTimer?.cancel();
    _reconnectDebounceTimer = null;
  }

  Future<void> _disposeStream(MediaStream? stream) async {
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      try {
        await track.stop();
      } catch (_) {
        // The track may already be gone with the peer connection.
      }
    }
    try {
      await stream.dispose();
    } catch (_) {
      // Disposal is best effort during teardown races.
    }
  }

  Future<void> _disposePeer(RTCPeerConnection? peer) async {
    if (peer == null) return;
    try {
      await peer.close();
    } catch (_) {
      // Already closed.
    }
    try {
      await peer.dispose();
    } catch (_) {
      // Already disposed.
    }
  }

  Future<void> _releaseResources() async {
    _debugLog('releasing realtime resources');
    _cancelConnectTimers();
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
    _sessionReady = false;
    _audioSessionReapplied = false;
    await _finishUsageTracking();
    _iceGathering = null;
    final events = _events;
    _events = null;
    try {
      await events?.close();
    } catch (_) {
      // The channel may already be gone with the transport.
    }
    final microphone = _microphone;
    _microphone = null;
    await _disposeStream(microphone);
    final peer = _peer;
    _peer = null;
    await _disposePeer(peer);
    _publishSoundLevel(0);
    _debugLog('realtime resources released');
  }

  // ---------------------------------------------------------------------------
  // Reward usage tracking
  // ---------------------------------------------------------------------------

  Future<void> _beginUsageTracking() async {
    if (!_enableUsageTracking ||
        _usageSessionId != null ||
        _usageStartInFlight ||
        _conversationId.isEmpty ||
        _disposed ||
        _stopping) {
      return;
    }
    _usageStartInFlight = true;
    try {
      final update = await _signalingApi.startUsage(
        conversationId: _conversationId,
      );
      if (_disposed || _stopping || !_state.isActive) {
        await _signalingApi.finishUsage(update.sessionId);
        return;
      }
      _usageSessionId = update.sessionId;
      _usageHeartbeatSeconds = update.heartbeatIntervalSeconds.clamp(15, 60);
      _resumeUsageHeartbeat();
      _debugLog('voice reward tracking started: session=${update.sessionId}');
    } catch (error) {
      // Reward tracking must never interrupt a clinical voice conversation.
      _debugLog('voice reward tracking unavailable: ${_safeError(error)}');
    } finally {
      _usageStartInFlight = false;
    }
  }

  void _resumeUsageHeartbeat() {
    if (_usageSessionId == null || _disposed || _stopping) return;
    _usageHeartbeatTimer?.cancel();
    _usageHeartbeatTimer = Timer.periodic(
      Duration(seconds: _usageHeartbeatSeconds),
      (_) => unawaited(_heartbeatUsage()),
    );
  }

  Future<void> _heartbeatUsage() async {
    final sessionId = _usageSessionId;
    if (sessionId == null || _disposed || _stopping) return;
    try {
      final update = await _signalingApi.heartbeatUsage(sessionId);
      if (update.awardedPoints > 0) {
        _debugLog(
          'voice activity reward earned: ${update.awardedPoints} points',
        );
      }
    } catch (error) {
      _debugLog('voice reward heartbeat failed: ${_safeError(error)}');
    }
  }

  Future<void> _finishUsageTracking() async {
    _usageHeartbeatTimer?.cancel();
    _usageHeartbeatTimer = null;
    final sessionId = _usageSessionId;
    _usageSessionId = null;
    if (sessionId == null) return;
    try {
      await _signalingApi.finishUsage(sessionId);
      _debugLog('voice reward tracking finished: session=$sessionId');
    } catch (error) {
      _debugLog('voice reward finish failed: ${_safeError(error)}');
    }
  }

  // ---------------------------------------------------------------------------
  // Errors and state
  // ---------------------------------------------------------------------------

  String _friendlyError(Object error) {
    if (error is ApiException && error.statusCode == 503) {
      return error.message;
    }
    final text = error.toString().toLowerCase();
    if (text.contains('permission') ||
        text.contains('notallowed') ||
        text.contains('denied') ||
        text.contains('record_audio') ||
        text.contains('not granted')) {
      return 'Microphone access is needed for live voice. '
          'Please allow it in Settings and try again.';
    }
    if (text.contains('timeout') ||
        text.contains('timed out') ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('connection')) {
      return 'Could not reach the voice service. '
          'Check your connection and try again.';
    }
    return 'Live voice could not start right now. Please try again.';
  }

  /// Terminal errors always release the transport: leaving the microphone and
  /// the peer connection open after a failure drains battery and keeps the
  /// reward session ticking on a call the patient can no longer hear.
  void _setError(String message, {bool fatal = true}) {
    if (_disposed) return;
    if (!fatal) {
      _debugLog('non-fatal voice error ignored: $message');
      return;
    }
    _debugLog('state error: $message');
    // Supersede any connect attempt still in flight so it abandons its own
    // microphone and peer instead of attaching them to a dead session.
    _startGeneration++;
    _reconnectInFlight = false;
    _setState(
      _state.copyWith(phase: LiveVoicePhase.error, errorMessage: message),
    );
    unawaited(_releaseResources().then((_) => _clearTurnBuffers()));
  }

  void _setState(LiveVoiceState next) {
    if (_disposed) return;
    if (next == _state) return;
    if (next.phase != _state.phase) {
      _debugLog('phase ${_state.phase.name} -> ${next.phase.name}');
    }
    _state = next;
    notifyListeners();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[LiveVoice] $message');
    }
  }

  String _safeError(Object error) {
    final text = error.toString();
    return text.length <= 500 ? text : '${text.substring(0, 500)}…';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // There is no foreground service, so a backgrounded call must end.
        if (_state.isActive) {
          unawaited(stop(reason: 'app_backgrounded'));
        }
      case AppLifecycleState.resumed:
        if (!_state.isActive) {
          unawaited(prewarm(locale: _locale));
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Transient: a call survives a notification shade or a phone rotation.
        break;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _cancelConnectTimers();
    unawaited(_releaseResources());
    soundLevel.dispose();
    super.dispose();
  }
}
