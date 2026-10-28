import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/patient_script.dart';
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

/// A message replayed into a fresh realtime session so the assistant keeps
/// its context: the text chat before the call, or this call's own turns after
/// a reconnect.
@immutable
class LiveVoiceHistoryItem {
  const LiveVoiceHistoryItem({required this.fromPatient, required this.text});

  final bool fromPatient;
  final String text;
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
  static const Duration _connectBudget = Duration(seconds: 15);

  /// Longest the client waits for a server-reflexive/relay candidate before
  /// posting the offer anyway.
  static const Duration _iceGatheringBudget = Duration(milliseconds: 1000);

  /// Per-turn context lookup budget before falling back to the session prompt.
  static const Duration _turnContextBudget = Duration(milliseconds: 1500);

  /// A `response.create` that never produces `response.created` must not
  /// leave the orb on "Thinking…" forever.
  static const Duration _responseStartBudget = Duration(seconds: 10);

  /// `session.updated` is the readiness signal after a data-channel
  /// `session.update`, but some edges never echo it.
  static const Duration _sessionReadyFallback = Duration(milliseconds: 1500);

  /// A call nobody has spoken on for this long is ended: an open line keeps
  /// the provider session billing, the screen awake and reward time ticking.
  static const Duration _idleTimeout = Duration(minutes: 3);

  static const Duration _audioLevelInterval = Duration(milliseconds: 110);
  static const Duration _reconnectDebounce = Duration(milliseconds: 2500);
  static const Duration _reconnectWindow = Duration(seconds: 60);
  static const int _maxReconnectAttempts = 3;
  static const int _maxTranscriptEntries = 24;
  static const int _maxReplayItems = 12;

  /// Speaking rate used only when the provider never reports the output audio
  /// buffer, to estimate when playback of a finished reply ends.
  static const double _fallbackCharactersPerSecond = 14;

  /// Provider events that need no handling; logging them would drown the
  /// latency trace.
  static const Set<String> _quietEventTypes = {
    'conversation.item.added',
    'conversation.item.created',
    'conversation.item.done',
    'conversation.item.retrieved',
    'conversation.item.deleted',
    'conversation.item.truncated',
    'input_audio_buffer.committed',
    'input_audio_buffer.cleared',
    'input_audio_buffer.turn_suggestion',
    'input_audio_buffer.turn_suggestion_revoked',
    'response.output_item.added',
    'response.output_item.done',
    'response.content_part.added',
    'response.content_part.done',
    'response.output_audio_transcript.done',
    'response.output_text.done',
    'response.output_audio.delta',
    'response.output_audio.done',
    'response.function_call_arguments.delta',
    'response.backchannel.audio.delta',
    'response.backchannel.audio.done',
    'response.backchannel.skipped',
    'rate_limits.updated',
  };

  final InworldSignalingApi _signalingApi;
  final RealtimeTurnCompleted _onTurnCompleted;
  final RealtimeTurnContext _onTurnContext;

  /// High-frequency microphone/speaker level (0..1, perceptually scaled),
  /// kept off [state] so 10Hz sampling never rebuilds the screen.
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
  Timer? _responseStartTimer;
  Timer? _speakingFallbackTimer;
  Timer? _idleTimer;
  String? _lastStopReason;
  bool _disposed = false;
  bool _stopping = false;
  bool _statsInFlight = false;
  bool _usageStartInFlight = false;
  int _startGeneration = 0;
  int _reconnectAttempts = 0;
  DateTime? _reconnectWindowStart;
  bool _reconnectInFlight = false;
  bool _sessionReady = false;
  bool _sessionPreconfigured = false;
  bool _sessionPatchPending = false;
  bool _audioSessionReapplied = false;
  bool _muted = false;
  bool _wakelockHeld = false;
  String _conversationId = '';
  String _locale = 'en-IN';
  String? _usageSessionId;
  int _usageHeartbeatSeconds = 30;

  // Turn tracking.
  String _currentInputItemId = '';
  String _respondingToItemId = '';
  String _currentResponseId = '';
  String _speakingEntryId = '';
  bool _responseRequested = false;
  bool _responseActive = false;

  /// Set when the patient starts talking while a requested reply has not been
  /// created yet. Bounded in time so a request the provider silently dropped
  /// can never swallow the next, legitimate reply.
  DateTime? _suppressResponsesUntil;
  bool _audioBufferActive = false;
  bool _audioBufferEventsSeen = false;
  DateTime? _speakingSince;
  final Set<String> _cancelledResponseIds = {};

  String _initialResponseInstructions = '';
  bool _initialResponseRequested = false;
  bool _skipInitialResponse = false;
  bool _enableUsageTracking = true;
  String _sessionInstructions = '';

  /// The effective session prompt (Laravel persona, safety rules, patient
  /// background, plus any caller extras). Every `response.create` carries its
  /// own instructions, which *replace* the session prompt for that reply, so
  /// per-turn directives are layered on top of this.
  String _baseInstructions = '';
  List<Map<String, dynamic>> _sessionTools = const [];
  RealtimeFunctionCallHandler? _onFunctionCall;
  final Set<String> _handledFunctionCallIds = {};
  bool _awaitingFunctionResponse = false;
  List<LiveVoiceHistoryItem> _seedHistory = const [];
  final List<LiveVoiceHistoryItem> _sessionHistory = [];
  final Map<String, StringBuffer> _inputTranscripts = {};
  final Map<String, StringBuffer> _responseText = {};
  final Map<String, StringBuffer> _responseAudioTranscripts = {};
  final List<Completer<void>> _speechIdleWaiters = [];
  Stopwatch? _turnLatency;
  int? _responseCreateSentAtMs;
  bool _firstResponseAudioReceived = false;

  LiveVoiceState get state => _state;

  bool get isMuted => _muted;

  /// Why the last call ended (`idle`, `app_backgrounded`, ...), so the screen
  /// can explain an ending the patient did not ask for.
  String? get lastStopReason => _lastStopReason;

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
    List<LiveVoiceHistoryItem> history = const [],
  }) async {
    if (_state.isActive) {
      _debugLog('start ignored: session is already active');
      return;
    }
    final generation = ++_startGeneration;
    _lastStopReason = null;
    _locale = locale;
    _initialResponseInstructions = initialResponseInstructions.trim();
    _initialResponseRequested = false;
    _skipInitialResponse = false;
    _enableUsageTracking = enableUsageTracking;
    _sessionInstructions = sessionInstructions.trim();
    _baseInstructions = '';
    _sessionTools = tools;
    _onFunctionCall = onFunctionCall;
    _handledFunctionCallIds.clear();
    _awaitingFunctionResponse = false;
    _conversationId = conversationId;
    _seedHistory = _normalizedHistory(history);
    _sessionHistory.clear();
    _muted = false;
    _reconnectAttempts = 0;
    _reconnectWindowStart = null;
    _audioBufferEventsSeen = false;
    _resetResponseTracking();
    _debugLog('start requested locale=$locale history=${_seedHistory.length}');
    // A fresh call never inherits captions or a timer from the last one.
    _setState(const LiveVoiceState(phase: LiveVoicePhase.connecting));
    unawaited(_setWakelock(true));
    _armConnectBudget();
    await _runConnectSequence(generation: generation, reconnect: false);
  }

  /// Supplies the chat thread once it exists, so a voice call can start while
  /// the thread is still being created.
  void attachConversation(String conversationId) {
    if (conversationId.isEmpty || conversationId == _conversationId) return;
    _conversationId = conversationId;
    if (_sessionReady && _usageSessionId == null) {
      unawaited(_beginUsageTracking());
    }
  }

  Future<void> stop({String reason = 'user_stopped'}) async {
    if (_stopping) {
      _debugLog('stop ignored: already stopping');
      return;
    }
    _debugLog('stop requested: reason=$reason');
    _lastStopReason = reason;
    _stopping = true;
    _idleTimer?.cancel();
    _idleTimer = null;
    // Any connect sequence still in flight must abandon its resources.
    _startGeneration++;
    _cancelConnectTimers();
    _completeSpeechWaiters();
    if (!_disposed && _state.phase != LiveVoicePhase.idle) {
      _setState(_state.copyWith(phase: LiveVoicePhase.closing));
    }
    await _releaseResources();
    _clearTurnBuffers();
    if (!_disposed) {
      _setState(
        LiveVoiceState(
          phase: LiveVoicePhase.closed,
          transcript: _state.transcript,
        ),
      );
    }
    _stopping = false;
  }

  /// Ends the call once the assistant has finished speaking, so a farewell is
  /// heard in full instead of being cut off by the hang-up.
  Future<void> stopAfterSpeaking({
    Duration timeout = const Duration(seconds: 8),
    String reason = 'conversation_finished',
  }) async {
    if (!_state.isActive) return;
    if (_state.isSpeaking ||
        _responseActive ||
        _responseRequested ||
        _audioBufferActive) {
      final waiter = Completer<void>();
      _speechIdleWaiters.add(waiter);
      await waiter.future.timeout(timeout, onTimeout: () {});
    }
    await stop(reason: reason);
  }

  /// Stops the assistant mid-reply so the patient can talk (the orb tap).
  Future<void> interrupt() async {
    final speaking = _state.isSpeaking || _responseActive || _audioBufferActive;
    if (!speaking) {
      _debugLog('interrupt ignored: no response is in progress');
      return;
    }
    _debugLog('interrupting current response');
    _touchActivity();
    final transcript = _bargeIn();
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.listening,
        responseText: '',
        transcript: transcript,
        clearError: true,
      ),
    );
  }

  Future<void> toggleMute() => setMuted(!_muted);

  Future<void> setMuted(bool muted) async {
    final microphone = _microphone;
    if (microphone != null) {
      await _applyMute(microphone, muted);
    }
    _muted = muted;
    _debugLog('microphone muted=$_muted');
    _touchActivity();
    if (muted) _publishSoundLevel(0);
    if (!_disposed) _setState(_state.copyWith(isMuted: muted));
  }

  Future<void> _applyMute(MediaStream stream, bool muted) async {
    for (final track in stream.getAudioTracks()) {
      try {
        await Helper.setMicrophoneMute(muted, track);
      } catch (error) {
        _debugLog('native mic mute unavailable: ${_safeError(error)}');
      }
      track.enabled = !muted;
    }
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
    _sessionPreconfigured = false;
    _sessionPatchPending = false;
    _audioSessionReapplied = false;
    _setState(
      _state.copyWith(
        phase: reconnect
            ? LiveVoicePhase.reconnecting
            : LiveVoicePhase.connecting,
        isUserSpeaking: false,
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
      final sessionUpdate = _configuredSessionUpdate(bootstrap.sessionUpdate);
      _baseInstructions =
          _mapOf(sessionUpdate['session'])['instructions']?.toString().trim() ??
          '';

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
      _debugLog(
        'microphone acquired: audioTracks=${stream.getAudioTracks().length}',
      );
      // A reconnect keeps the patient's mute choice.
      if (_muted) await _applyMute(stream, true);
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
      _wireDataChannel(channel, sessionUpdate);

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
      final answer = await _signalingApi.createCall(offerSdp, locale: _locale);
      if (_isStale(generation)) return abandon();
      _sessionPreconfigured = answer.sessionConfigured;
      _debugLog(
        'SDP answer received: bytes=${answer.sdp.length}, '
        'sessionConfigured=${answer.sessionConfigured}, '
        'elapsed=${startup.elapsedMilliseconds}ms',
      );
      await peer.setRemoteDescription(
        RTCSessionDescription(answer.sdp, 'answer'),
      );
      if (_isStale(generation)) return abandon();
      _debugLog('remote SDP answer set; awaiting the data channel');
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
            _handleConnectionLoss(immediate: true);
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
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.reconnecting,
        isUserSpeaking: false,
      ),
    );
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
        if (_sessionReady && _state.phase == LiveVoicePhase.reconnecting) {
          _returnToListening();
          _resumeUsageHeartbeat();
        }
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
      // call. Usage tracking survives it, the greeting is not repeated, and
      // this call's turns are replayed so the assistant keeps its context.
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
    _resetResponseTracking();
    _completeSpeechWaiters();
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
      _audioLevelInterval,
      (_) => unawaited(_readAudioLevel()),
    );
  }

  Future<void> _readAudioLevel() async {
    final peer = _peer;
    if (peer == null || _disposed || _statsInFlight) return;
    final speaking = _state.isSpeaking;
    if (!speaking && !_state.isListening) {
      _publishSoundLevel(0);
      return;
    }
    _statsInFlight = true;
    try {
      final reports = await peer.getStats();
      var microphone = 0.0;
      var assistant = 0.0;
      for (final report in reports) {
        final values = report.values;
        final kind = values['kind'] ?? values['mediaType'];
        if (kind != null && kind != 'audio') continue;
        final raw = values['audioLevel'];
        if (raw is! num) continue;
        final level = raw.toDouble();
        switch (report.type) {
          case 'inbound-rtp':
            assistant = math.max(assistant, level);
          case 'media-source':
          case 'outbound-rtp':
            microphone = math.max(microphone, level);
          case 'track':
            final remote = values['remoteSource'] == true;
            if (remote) {
              assistant = math.max(assistant, level);
            } else {
              microphone = math.max(microphone, level);
            }
          default:
            break;
        }
      }
      final level = speaking ? assistant : (_muted ? 0.0 : microphone);
      _publishSoundLevel(_perceptualLevel(level));
    } catch (_) {
      // Audio-level stats are optional and differ across native WebRTC builds.
    } finally {
      _statsInFlight = false;
    }
  }

  /// WebRTC reports linear amplitude; speech sits around 0.01-0.3, which looks
  /// dead on a linear scale. Map -50..-10 dBov onto 0..1 instead.
  double _perceptualLevel(double linear) {
    if (linear <= 0) return 0;
    final decibels = 20 * math.log(linear) / math.ln10;
    return ((decibels + 50) / 40).clamp(0.0, 1.0).toDouble();
  }

  void _publishSoundLevel(double level) {
    if (_disposed) return;
    if ((level - soundLevel.value).abs() < 0.01) return;
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
        _onEventsChannelOpen(sessionUpdate);
      } else if (channelState == RTCDataChannelState.RTCDataChannelClosed &&
          !_stopping &&
          !_reconnectInFlight &&
          _state.isActive) {
        // The provider closed the session (idle limit, redeploy): start a new
        // one instead of dropping the patient out of the call.
        _debugLog('data channel closed unexpectedly');
        _handleConnectionLoss(immediate: true);
      }
    };
    channel.onMessage = (message) {
      if (message.isBinary) {
        _debugLog('binary data-channel message received: ignored');
        return;
      }
      Object? decoded;
      try {
        decoded = jsonDecode(message.text);
      } catch (error) {
        // One malformed event must not end a working call.
        _debugLog('invalid data-channel event ignored: ${_safeError(error)}');
        return;
      }
      if (decoded is Map) {
        _handleEvent(Map<String, dynamic>.from(decoded));
      } else {
        _debugLog('non-object data-channel message received: ignored');
      }
    };
  }

  void _onEventsChannelOpen(Map<String, dynamic> sessionUpdate) {
    final needsPatch =
        !_sessionPreconfigured ||
        _sessionInstructions.isNotEmpty ||
        _sessionTools.isNotEmpty;
    if (needsPatch) {
      _debugLog('data channel open; sending session.update');
      _sessionPatchPending = true;
      unawaited(sendRealtimeEvent(sessionUpdate));
      return;
    }
    // Laravel configured the session together with the call, so it is live as
    // soon as the channel is: start listening without another round trip.
    _debugLog('data channel open; session was configured with the call');
    _markSessionReady(const {});
  }

  /// Events that show someone is talking on the line.
  static const Set<String> _activityEventTypes = {
    'input_audio_buffer.speech_started',
    'input_audio_buffer.speech_stopped',
    'conversation.item.input_audio_transcription.delta',
    'conversation.item.input_audio_transcription.completed',
    'response.created',
    'response.done',
    'response.output_audio_transcript.delta',
    'response.output_text.delta',
    'output_audio_buffer.started',
    'output_audio_buffer.stopped',
  };

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    if (_disposed || _stopping || !_state.isActive) {
      _debugLog(
        'event ignored after voice session ended: ${type.isEmpty ? '<missing>' : type}',
      );
      return;
    }
    if (_activityEventTypes.contains(type)) _touchActivity();
    if (!_quietEventTypes.contains(type)) {
      final deltaLength = event['delta']?.toString().length;
      _debugLog(
        deltaLength == null
            ? 'event received: type=${type.isEmpty ? '<missing>' : type}'
            : 'event received: type=$type deltaChars=$deltaLength',
      );
    }
    switch (type) {
      case 'session.created':
        _connectBudgetTimer?.cancel();
        _connectBudgetTimer = null;
        final session = _sessionOf(event);
        if (!_sessionPatchPending) {
          _markSessionReady(session);
        } else {
          _armSessionReadyFallback(session);
        }
      case 'session.updated':
        _sessionReadyFallbackTimer?.cancel();
        _sessionReadyFallbackTimer = null;
        _sessionPatchPending = false;
        _markSessionReady(_sessionOf(event));
      case 'input_audio_buffer.speech_started':
        _onSpeechStarted(event);
      case 'input_audio_buffer.speech_stopped':
        _onSpeechStopped();
      case 'conversation.item.input_audio_transcription.delta':
        _onTranscriptionDelta(event);
      case 'conversation.item.input_audio_transcription.completed':
        _onTranscriptionCompleted(event);
      case 'conversation.item.input_audio_transcription.failed':
        _onTranscriptionFailed(event);
      case 'response.created':
        _onResponseCreated(event);
      case 'output_audio_buffer.started':
        _onAudioBufferStarted();
      case 'output_audio_buffer.stopped':
      case 'output_audio_buffer.cleared':
        _onAudioBufferStopped();
      case 'response.output_audio_transcript.delta':
        _appendResponseDelta(event, audioTranscript: true);
      case 'response.output_text.delta':
        _appendResponseDelta(event, audioTranscript: false);
      case 'response.function_call_arguments.done':
        unawaited(_handleFunctionCall(event));
      case 'response.done':
        _completeResponse(event);
      case 'input_audio_buffer.timeout_triggered':
        // Server-VAD idle timeout: nothing to answer, keep listening.
        break;
      case 'error':
        _handleProviderError(_mapOf(event['error']));
      default:
        if (!_quietEventTypes.contains(type)) {
          _debugLog(
            'unhandled event type: ${type.isEmpty ? '<missing>' : type}',
          );
        }
    }
  }

  Map<String, dynamic> _sessionOf(Map<String, dynamic> event) =>
      _mapOf(event['session']);

  Map<String, dynamic> _mapOf(Object? value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};

  void _armSessionReadyFallback(Map<String, dynamic> session) {
    _sessionReadyFallbackTimer?.cancel();
    _sessionReadyFallbackTimer = Timer(_sessionReadyFallback, () {
      if (_disposed || _stopping || _sessionReady) return;
      _debugLog('session.updated never arrived; using session.created');
      _markSessionReady(session);
    });
  }

  void _markSessionReady(Map<String, dynamic> session) {
    final providerSessionId = session['id']?.toString();
    if (_disposed || _stopping) return;
    if (_sessionReady) {
      // Late session events only contribute the provider's session id.
      if ((providerSessionId ?? '').isNotEmpty &&
          _state.sessionId != providerSessionId) {
        _setState(_state.copyWith(sessionId: providerSessionId));
      }
      return;
    }
    _sessionReady = true;
    _sessionPatchPending = false;
    _connectBudgetTimer?.cancel();
    _connectBudgetTimer = null;
    _sessionReadyFallbackTimer?.cancel();
    _sessionReadyFallbackTimer = null;
    _reconnectAttempts = 0;
    _reconnectWindowStart = null;
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.listening,
        sessionId: providerSessionId,
        isMuted: _muted,
        isUserSpeaking: false,
        connectedAt: _state.connectedAt ?? DateTime.now(),
        clearError: true,
      ),
    );
    _replayHistory();
    _touchActivity();
    if (_usageSessionId != null) {
      _resumeUsageHeartbeat();
    } else {
      unawaited(_beginUsageTracking());
    }
    _requestInitialResponse();
  }

  /// Restarts the idle countdown; the call ends after [_idleTimeout] without
  /// any speech from either side.
  void _touchActivity() {
    if (!_sessionReady || _disposed || _stopping) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      _idleTimer = null;
      if (_disposed || _stopping || !_state.isActive) return;
      if (_state.isSpeaking || _responseActive || _responseRequested) {
        _touchActivity();
        return;
      }
      _debugLog('no speech for ${_idleTimeout.inSeconds}s; ending the call');
      unawaited(stop(reason: 'idle'));
    });
  }

  /// Replays prior messages as conversation items. A new Inworld session has
  /// no memory, so without this a reconnect (or a call started from an
  /// existing chat) would lose the thread of the conversation.
  void _replayHistory() {
    final items = [..._seedHistory, ..._sessionHistory];
    if (items.isEmpty) return;
    final replay = items.length > _maxReplayItems
        ? items.sublist(items.length - _maxReplayItems)
        : items;
    _debugLog('replaying ${replay.length} history items');
    for (final item in replay) {
      unawaited(
        sendRealtimeEvent({
          'type': 'conversation.item.create',
          'item': {
            'type': 'message',
            'role': item.fromPatient ? 'user' : 'assistant',
            'content': [
              {
                'type': item.fromPatient ? 'input_text' : 'output_text',
                'text': item.text,
              },
            ],
          },
        }),
      );
    }
  }

  List<LiveVoiceHistoryItem> _normalizedHistory(
    List<LiveVoiceHistoryItem> history,
  ) {
    final items = <LiveVoiceHistoryItem>[];
    for (final item in history) {
      final text = plainLiveVoiceText(item.text);
      if (text.isEmpty) continue;
      items.add(
        LiveVoiceHistoryItem(fromPatient: item.fromPatient, text: text),
      );
    }
    return items.length > _maxReplayItems
        ? items.sublist(items.length - _maxReplayItems)
        : items;
  }

  void _rememberTurn(String transcript, String answer) {
    _sessionHistory
      ..add(LiveVoiceHistoryItem(fromPatient: true, text: transcript))
      ..add(
        LiveVoiceHistoryItem(
          fromPatient: false,
          text: plainLiveVoiceText(answer),
        ),
      );
    if (_sessionHistory.length > _maxReplayItems) {
      _sessionHistory.removeRange(0, _sessionHistory.length - _maxReplayItems);
    }
  }

  // ---------------------------------------------------------------------------
  // Patient speech
  // ---------------------------------------------------------------------------

  void _onSpeechStarted(Map<String, dynamic> event) {
    // A new utterance supersedes any context lookup still in flight for the
    // previous one; its late result must not start a stale reply.
    _currentInputItemId = event['item_id']?.toString() ?? '';
    _resetTurnLatency();
    var transcript = _state.transcript;
    if (_state.isSpeaking || _responseActive || _audioBufferActive) {
      // Barge-in: Inworld cancels the reply itself (interrupt_response), the
      // client mirrors it so playback stops and the captions settle at once.
      transcript = _bargeIn();
    }
    if (_responseRequested) {
      // The reply for the previous utterance has not started yet; the patient
      // is still talking, so it must not start playing over them.
      _suppressResponsesUntil = DateTime.now().add(const Duration(seconds: 3));
      _responseRequested = false;
      _responseStartTimer?.cancel();
      _responseStartTimer = null;
    }
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.listening,
        isUserSpeaking: true,
        partialTranscript: '',
        responseText: '',
        transcript: transcript,
        clearError: true,
      ),
    );
  }

  void _onSpeechStopped() {
    _turnLatency = Stopwatch()..start();
    _debugLog('turn latency: speech stopped at 0ms');
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.transcribing,
        isUserSpeaking: false,
      ),
    );
  }

  void _onTranscriptionDelta(Map<String, dynamic> event) {
    final itemId = event['item_id']?.toString() ?? 'current-input';
    // `speech_started` names the current utterance; a late delta for an
    // earlier one must not steal that role.
    if (_currentInputItemId.isEmpty) _currentInputItemId = itemId;
    final buffer = _inputTranscripts.putIfAbsent(itemId, StringBuffer.new);
    buffer.write(event['delta']?.toString() ?? '');
    final text = toPatientScript(buffer.toString());
    _setState(
      _state.copyWith(
        partialTranscript: text,
        transcript: _withEntry(
          _patientEntryId(itemId),
          LiveVoiceSpeaker.patient,
          text,
        ),
      ),
    );
  }

  void _onTranscriptionCompleted(Map<String, dynamic> event) {
    final itemId = event['item_id']?.toString() ?? _currentInputItemId;
    final transcript = toPatientScript(
      event['transcript']?.toString().trim() ??
          _inputTranscripts[itemId]?.toString().trim() ??
          '',
    );
    final superseded =
        _state.isUserSpeaking &&
        _currentInputItemId.isNotEmpty &&
        itemId != _currentInputItemId;
    if (superseded) {
      // The patient is already saying more: settle this caption, and let the
      // newer utterance (which sees this one in the conversation) get the
      // reply instead of answering a half-finished thought.
      _debugLog('transcript for superseded utterance $itemId: no reply');
      _inputTranscripts.remove(itemId);
      _setState(
        _state.copyWith(
          transcript: transcript.isEmpty
              ? _withoutEntry(_patientEntryId(itemId))
              : _withEntry(
                  _patientEntryId(itemId),
                  LiveVoiceSpeaker.patient,
                  transcript,
                  isFinal: true,
                ),
        ),
      );
      return;
    }
    _currentInputItemId = itemId;
    _inputTranscripts[itemId] = StringBuffer(transcript);
    _debugTurnLatency('transcription completed');
    if (transcript.isEmpty) {
      // Nothing usable was heard (a cough, a pause, background noise). Keep
      // the microphone open instead of answering or ending the call.
      _debugLog('empty transcript: returning to listening');
      _inputTranscripts.remove(itemId);
      _setState(
        _state.copyWith(
          phase: _state.isSpeaking ? null : LiveVoicePhase.listening,
          partialTranscript: '',
          finalTranscript: '',
          transcript: _withoutEntry(_patientEntryId(itemId)),
        ),
      );
      return;
    }
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.thinking,
        partialTranscript: '',
        finalTranscript: transcript,
        transcript: _withEntry(
          _patientEntryId(itemId),
          LiveVoiceSpeaker.patient,
          transcript,
          isFinal: true,
        ),
      ),
    );
    unawaited(_requestContextAndRespond(itemId, transcript));
  }

  void _onTranscriptionFailed(Map<String, dynamic> event) {
    final itemId = event['item_id']?.toString() ?? _currentInputItemId;
    _debugLog('transcription failed for item $itemId');
    _inputTranscripts.remove(itemId);
    if (_state.isSpeaking || _responseActive || _responseRequested) return;
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.listening,
        partialTranscript: '',
        finalTranscript: '',
        transcript: _withoutEntry(_patientEntryId(itemId)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Assistant responses
  // ---------------------------------------------------------------------------

  Future<void> _requestContextAndRespond(
    String itemId,
    String transcript,
  ) async {
    _debugLog(
      'requesting Laravel voice context for transcript chars=${transcript.length}',
    );
    final contextLookup = Stopwatch()..start();
    var useFallback = false;
    var turnInstructions = '';
    try {
      // Late results are dropped by the timeout wrapper, so a slow context
      // lookup can never talk over the fallback response we already sent.
      turnInstructions = await Future<String>.sync(
        () => _onTurnContext(transcript),
      ).timeout(_turnContextBudget);
      contextLookup.stop();
      _debugLog(
        'turn latency: Laravel context completed at '
        '${_turnLatency?.elapsedMilliseconds ?? -1}ms '
        '(round trip=${contextLookup.elapsedMilliseconds}ms)',
      );
      if (turnInstructions.trim().isEmpty) useFallback = true;
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
    _respondingToItemId = itemId;
    await _createResponse(
      _composeInstructions(
        useFallback ? kLiveVoiceFallbackTurnInstructions : turnInstructions,
      ),
    );
    _debugTurnLatency(
      useFallback ? 'fallback response.create sent' : 'response.create sent',
    );
  }

  /// A `response.create` instruction replaces the session prompt for that
  /// reply, so directives are layered on the session prompt; verbatim
  /// "say exactly" instructions go on their own.
  String _composeInstructions(String directive) {
    final turn = directive.trim();
    final base = _baseInstructions.trim();
    if (base.isEmpty) return turn;
    if (turn.isEmpty) return base;
    if (isExactLiveVoiceInstruction(turn)) return turn;
    return '$base\n\n$turn';
  }

  Future<void> _createResponse(String instructions) async {
    _responseCreateSentAtMs = _turnLatency?.elapsedMilliseconds;
    _responseRequested = true;
    _armResponseStartWatchdog();
    await sendRealtimeEvent({
      'type': 'response.create',
      'response': {
        'output_modalities': ['audio', 'text'],
        if (instructions.isNotEmpty) 'instructions': instructions,
      },
    });
  }

  void _armResponseStartWatchdog() {
    _responseStartTimer?.cancel();
    _responseStartTimer = Timer(_responseStartBudget, () {
      _responseStartTimer = null;
      if (_disposed || _stopping || !_responseRequested) return;
      _debugLog('no response.created within budget; returning to listening');
      _responseRequested = false;
      if (!_state.isSpeaking) _returnToListening();
    });
  }

  void _requestInitialResponse() {
    if (_skipInitialResponse ||
        _initialResponseRequested ||
        _initialResponseInstructions.isEmpty) {
      return;
    }
    _initialResponseRequested = true;
    _debugLog('requesting initial assistant response');
    _respondingToItemId = '';
    unawaited(
      _createResponse(_composeInstructions(_initialResponseInstructions)),
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
    await _createResponse(_composeInstructions(spokenInstructions));
  }

  void _onResponseCreated(Map<String, dynamic> event) {
    final response = _mapOf(event['response']);
    final responseId =
        response['id']?.toString() ??
        event['response_id']?.toString() ??
        'current-response';
    final suppressUntil = _suppressResponsesUntil;
    _suppressResponsesUntil = null;
    if (suppressUntil != null && DateTime.now().isBefore(suppressUntil)) {
      // The patient kept talking after this reply was requested. The newer
      // request (if any) keeps its own watchdog and pending flag.
      _cancelledResponseIds.add(responseId);
      _debugLog('cancelling a reply the patient talked over: $responseId');
      unawaited(sendRealtimeEvent({'type': 'response.cancel'}));
      return;
    }
    _responseStartTimer?.cancel();
    _responseStartTimer = null;
    _responseRequested = false;
    _responseActive = true;
    _currentResponseId = responseId;
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
    if (!_state.isSpeaking) {
      _setState(_state.copyWith(phase: LiveVoicePhase.thinking));
    }
  }

  void _appendResponseDelta(
    Map<String, dynamic> event, {
    required bool audioTranscript,
  }) {
    final responseId =
        event['response_id']?.toString() ??
        (_currentResponseId.isEmpty ? 'current-response' : _currentResponseId);
    if (_cancelledResponseIds.contains(responseId)) return;
    if (audioTranscript && !_firstResponseAudioReceived) {
      _firstResponseAudioReceived = true;
      _debugTurnLatency('first response audio transcript');
    }
    _currentResponseId = responseId;
    final target = audioTranscript ? _responseAudioTranscripts : _responseText;
    final buffer = target.putIfAbsent(responseId, StringBuffer.new);
    buffer.write(event['delta']?.toString() ?? '');
    final display = toPatientScript(
      _firstNonEmpty([
        _responseAudioTranscripts[responseId]?.toString(),
        _responseText[responseId]?.toString(),
      ]),
    );
    final entryId = _assistantEntryId(responseId);
    _speakingEntryId = entryId;
    if (!_state.isSpeaking) _speakingSince = DateTime.now();
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.speaking,
        responseText: display,
        isUserSpeaking: false,
        transcript: _withEntry(entryId, LiveVoiceSpeaker.assistant, display),
      ),
    );
  }

  void _onAudioBufferStarted() {
    _audioBufferEventsSeen = true;
    _audioBufferActive = true;
    _speakingFallbackTimer?.cancel();
    _speakingFallbackTimer = null;
    if (!_state.isSpeaking) {
      _speakingSince = DateTime.now();
      _setState(
        _state.copyWith(phase: LiveVoicePhase.speaking, isUserSpeaking: false),
      );
    }
  }

  void _onAudioBufferStopped() {
    _audioBufferEventsSeen = true;
    _audioBufferActive = false;
    // Playback has finished. Only return to listening when no newer reply is
    // on its way; otherwise that reply's own events drive the phase.
    if (_responseActive || _responseRequested) return;
    if (_state.isSpeaking) _returnToListening();
    _completeSpeechWaiters();
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
      await sendRealtimeEvent({
        'type': 'conversation.item.create',
        'item': {
          'type': 'function_call_output',
          'call_id': callId,
          'output': jsonEncode(result.output),
        },
      });
      // Tool sessions opt out of Inworld's automatic continuation, so the
      // follow-up reply (and its instructions) is requested explicitly.
      await _createResponse(
        _composeInstructions(result.responseInstructions.trim()),
      );
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

  void _completeResponse(Map<String, dynamic> event) {
    _debugTurnLatency('response done');
    final response = _mapOf(event['response']);
    final responseId =
        response['id']?.toString() ??
        event['response_id']?.toString() ??
        _currentResponseId;
    final status = response['status']?.toString() ?? 'completed';
    // The start watchdog and `_responseRequested` belong to whichever reply
    // was requested last, which may already be a newer turn: leave them be.
    final isCurrent =
        _currentResponseId.isEmpty || responseId == _currentResponseId;
    if (isCurrent) {
      _responseActive = false;
      _currentResponseId = '';
    }
    final answer = toPatientScript(
      _firstNonEmpty([
        _responseAudioTranscripts.remove(responseId)?.toString().trim(),
        _responseText.remove(responseId)?.toString().trim(),
      ]),
    );
    if (_cancelledResponseIds.remove(responseId) || status == 'cancelled') {
      // Barge-in already moved the UI on.
      _debugLog('response $responseId finished as cancelled');
      return;
    }
    if (_awaitingFunctionResponse && answer.isEmpty) {
      // The model only called a tool; its spoken answer is the next response.
      _setState(_state.copyWith(phase: LiveVoicePhase.thinking));
      return;
    }
    _awaitingFunctionResponse = false;
    if (status == 'failed') {
      _debugLog('response $responseId failed');
    }

    final itemId = _respondingToItemId;
    final transcript = itemId.isEmpty
        ? ''
        : (_inputTranscripts.remove(itemId)?.toString() ?? '').trim();
    if (itemId.isNotEmpty && _currentInputItemId == itemId) {
      _currentInputItemId = '';
    }
    _respondingToItemId = '';

    var captions = _state.transcript;
    if (answer.isNotEmpty) {
      captions = _withEntry(
        _assistantEntryId(responseId),
        LiveVoiceSpeaker.assistant,
        answer,
        isFinal: true,
      );
      if (transcript.isNotEmpty) {
        _rememberTurn(transcript, answer);
        unawaited(_notifyTurnCompleted(transcript, answer));
      }
    }
    _resetTurnLatency();

    if (_audioBufferActive) {
      // Generation is done but the reply is still playing: stay "speaking"
      // until the provider reports the output audio buffer has drained.
      _setState(
        _state.copyWith(
          partialTranscript: '',
          finalTranscript: '',
          transcript: captions,
          clearTurn: true,
        ),
      );
      return;
    }
    if (!_audioBufferEventsSeen && answer.isNotEmpty && _state.isSpeaking) {
      _setState(_state.copyWith(transcript: captions));
      _armSpeakingFallback(answer);
      return;
    }
    _returnToListening(transcript: captions);
  }

  Future<void> _notifyTurnCompleted(String transcript, String answer) async {
    try {
      await Future.sync(() => _onTurnCompleted(transcript, answer));
    } catch (error) {
      _debugLog('turn completion handler failed: ${_safeError(error)}');
    }
  }

  /// Without `output_audio_buffer.*` events, estimate when the finished reply
  /// stops playing from its length.
  void _armSpeakingFallback(String answer) {
    _speakingFallbackTimer?.cancel();
    final spokenMs = (answer.length / _fallbackCharactersPerSecond * 1000)
        .round();
    final since = _speakingSince;
    final elapsed = since == null
        ? 0
        : DateTime.now().difference(since).inMilliseconds;
    final remaining = (spokenMs - elapsed).clamp(400, 30000);
    _speakingFallbackTimer = Timer(Duration(milliseconds: remaining), () {
      _speakingFallbackTimer = null;
      if (_disposed || _stopping || !_state.isSpeaking) return;
      if (_responseActive || _responseRequested) return;
      _returnToListening();
    });
  }

  void _returnToListening({List<LiveVoiceTranscriptEntry>? transcript}) {
    _speakingFallbackTimer?.cancel();
    _speakingFallbackTimer = null;
    _speakingEntryId = '';
    _speakingSince = null;
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.listening,
        partialTranscript: '',
        finalTranscript: '',
        responseText: '',
        transcript: transcript,
        clearTurn: true,
      ),
    );
    _completeSpeechWaiters();
  }

  /// Stops the reply in progress and returns the settled captions. Callers
  /// fold the result into their own state update.
  List<LiveVoiceTranscriptEntry> _bargeIn() {
    final responseId = _currentResponseId;
    final playing = _audioBufferActive || _state.isSpeaking;
    if (_responseActive && responseId.isNotEmpty) {
      _cancelledResponseIds.add(responseId);
      unawaited(sendRealtimeEvent({'type': 'response.cancel'}));
    }
    if (playing) {
      unawaited(sendRealtimeEvent({'type': 'output_audio_buffer.clear'}));
    }
    var captions = _state.transcript;
    if (responseId.isNotEmpty) {
      final spoken = _firstNonEmpty([
        _responseAudioTranscripts.remove(responseId)?.toString().trim(),
        _responseText.remove(responseId)?.toString().trim(),
      ]);
      captions = spoken.isEmpty
          ? _withoutEntry(_assistantEntryId(responseId))
          : _withEntry(
              _assistantEntryId(responseId),
              LiveVoiceSpeaker.assistant,
              spoken,
              isFinal: true,
              interrupted: true,
            );
    } else if (_speakingEntryId.isNotEmpty) {
      captions = _markEntry(_speakingEntryId, interrupted: true);
    }
    // An interrupted turn is not persisted, so its transcript is dropped.
    if (_respondingToItemId.isNotEmpty) {
      _inputTranscripts.remove(_respondingToItemId);
    }
    _responseActive = false;
    _audioBufferActive = false;
    _currentResponseId = '';
    _respondingToItemId = '';
    _speakingEntryId = '';
    _speakingSince = null;
    _speakingFallbackTimer?.cancel();
    _speakingFallbackTimer = null;
    _completeSpeechWaiters();
    return captions;
  }

  void _handleProviderError(Map<String, dynamic> error) {
    final code = error['code']?.toString() ?? '';
    final type = error['type']?.toString() ?? '';
    final message = error['message']?.toString() ?? '';
    _debugLog(
      'provider error: type=${type.isEmpty ? '<missing>' : type}, '
      'code=${code.isEmpty ? '<missing>' : code}, '
      'message=${message.isEmpty ? '<missing>' : message}',
    );
    final blob = '$code $type $message'.toLowerCase();
    if (blob.contains('session_expired') ||
        blob.contains('session expired') ||
        blob.contains('session_not_found')) {
      // The provider ended the session: start a fresh one in place.
      _handleConnectionLoss(immediate: true);
      return;
    }
    // Everything else (a cancel that raced a finished reply, a rejected
    // parameter, a transient server error) leaves the transport healthy, so
    // the call continues. A turn that was waiting on the failed request goes
    // back to listening instead of hanging on "Thinking…".
    if (_responseRequested && !_responseActive) {
      _responseRequested = false;
      _responseStartTimer?.cancel();
      _responseStartTimer = null;
      if (!_state.isSpeaking) _returnToListening();
    }
  }

  // ---------------------------------------------------------------------------
  // Captions
  // ---------------------------------------------------------------------------

  String _patientEntryId(String itemId) => 'patient:$itemId';

  String _assistantEntryId(String responseId) => 'assistant:$responseId';

  List<LiveVoiceTranscriptEntry> _withEntry(
    String id,
    LiveVoiceSpeaker speaker,
    String text, {
    bool? isFinal,
    bool? interrupted,
  }) {
    final entries = List<LiveVoiceTranscriptEntry>.of(_state.transcript);
    final index = entries.indexWhere((entry) => entry.id == id);
    final trimmed = text.trim();
    if (index >= 0) {
      entries[index] = entries[index].copyWith(
        text: trimmed,
        isFinal: isFinal,
        interrupted: interrupted,
      );
    } else {
      if (trimmed.isEmpty) return _state.transcript;
      entries.add(
        LiveVoiceTranscriptEntry(
          id: id,
          speaker: speaker,
          text: trimmed,
          isFinal: isFinal ?? false,
          interrupted: interrupted ?? false,
        ),
      );
      if (entries.length > _maxTranscriptEntries) {
        entries.removeRange(0, entries.length - _maxTranscriptEntries);
      }
    }
    return List.unmodifiable(entries);
  }

  List<LiveVoiceTranscriptEntry> _withoutEntry(String id) {
    if (!_state.transcript.any((entry) => entry.id == id)) {
      return _state.transcript;
    }
    return List.unmodifiable(
      _state.transcript.where((entry) => entry.id != id),
    );
  }

  List<LiveVoiceTranscriptEntry> _markEntry(String id, {bool? interrupted}) {
    final index = _state.transcript.indexWhere((entry) => entry.id == id);
    if (index < 0) return _state.transcript;
    final entries = List<LiveVoiceTranscriptEntry>.of(_state.transcript);
    entries[index] = entries[index].copyWith(
      isFinal: true,
      interrupted: interrupted,
    );
    return List.unmodifiable(entries);
  }

  // ---------------------------------------------------------------------------
  // Transport helpers
  // ---------------------------------------------------------------------------

  /// Sends one client event over the realtime data channel. Overridden in
  /// tests to capture what the controller would send.
  @protected
  @visibleForTesting
  Future<void> sendRealtimeEvent(Map<String, dynamic> event) async {
    final channel = _events;
    if (channel == null ||
        channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      _debugLog(
        'event not sent: type=${event['type'] ?? '<missing>'}, '
        'channelState=${channel?.state}',
      );
      return;
    }
    try {
      await channel.send(RTCDataChannelMessage(jsonEncode(event)));
      _debugLog('event sent: type=${event['type'] ?? '<missing>'}');
    } catch (error) {
      _debugLog('event send failed: ${_safeError(error)}');
    }
  }

  /// Puts the controller into a live session without WebRTC, for tests of the
  /// event handling.
  @visibleForTesting
  void debugStartSimulatedSession({
    String locale = 'en-IN',
    String conversationId = '',
    String baseInstructions = '',
    bool sessionPreconfigured = true,
    List<LiveVoiceHistoryItem> history = const [],
  }) {
    _locale = locale;
    _conversationId = conversationId;
    _baseInstructions = baseInstructions;
    _enableUsageTracking = false;
    _sessionPreconfigured = sessionPreconfigured;
    _seedHistory = _normalizedHistory(history);
    _sessionReady = false;
    _setState(const LiveVoiceState(phase: LiveVoicePhase.connecting));
    _onEventsChannelOpen(const {'type': 'session.update', 'session': {}});
  }

  /// Feeds one provider event through the controller, for tests.
  @visibleForTesting
  void debugHandleEvent(Map<String, dynamic> event) => _handleEvent(event);

  /// Ends the simulated call with a terminal error, for tests.
  @visibleForTesting
  void debugFail(String message) => _setError(message);

  void _resetResponseTracking() {
    _currentInputItemId = '';
    _respondingToItemId = '';
    _currentResponseId = '';
    _speakingEntryId = '';
    _responseRequested = false;
    _responseActive = false;
    _suppressResponsesUntil = null;
    _audioBufferActive = false;
    _speakingSince = null;
    _cancelledResponseIds.clear();
    _inputTranscripts.clear();
    _responseText.clear();
    _responseAudioTranscripts.clear();
    _responseStartTimer?.cancel();
    _responseStartTimer = null;
    _speakingFallbackTimer?.cancel();
    _speakingFallbackTimer = null;
  }

  void _completeSpeechWaiters() {
    if (_speechIdleWaiters.isEmpty) return;
    final waiters = List<Completer<void>>.of(_speechIdleWaiters);
    _speechIdleWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  void _clearTurnBuffers() {
    _resetResponseTracking();
    _initialResponseInstructions = '';
    _initialResponseRequested = false;
    _skipInitialResponse = false;
    _enableUsageTracking = true;
    _conversationId = '';
    _sessionInstructions = '';
    _baseInstructions = '';
    _sessionTools = const [];
    _onFunctionCall = null;
    _handledFunctionCallIds.clear();
    _awaitingFunctionResponse = false;
    _seedHistory = const [];
    _sessionHistory.clear();
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
      // Inworld starts the follow-up reply on its own by default; this client
      // requests it explicitly (with instructions), so opt out to avoid two
      // replies racing each other.
      final providerData = session['providerData'] is Map
          ? Map<String, dynamic>.from(session['providerData'] as Map)
          : <String, dynamic>{};
      providerData['auto_tool_response'] = false;
      session['providerData'] = providerData;
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
    _responseStartTimer?.cancel();
    _responseStartTimer = null;
    _speakingFallbackTimer?.cancel();
    _speakingFallbackTimer = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    _sessionReady = false;
    _sessionPatchPending = false;
    _audioSessionReapplied = false;
    unawaited(_setWakelock(false));
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

  /// Keeps the screen on for the call: a dimmed, locked screen backgrounds
  /// the app, and without a foreground service that ends the conversation.
  Future<void> _setWakelock(bool enabled) async {
    if (_wakelockHeld == enabled) return;
    _wakelockHeld = enabled;
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (error) {
      _debugLog('wakelock unavailable: ${_safeError(error)}');
    }
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
    if (error is ApiException) {
      if (error.statusCode == 503 && error.message.trim().isNotEmpty) {
        return error.message;
      }
      if (error.statusCode == 429) {
        return 'Live voice is busy right now. Please wait a moment and try again.';
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Your session has expired. Please sign in again to use live voice.';
      }
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
  void _setError(String message) {
    if (_disposed) return;
    _debugLog('state error: $message');
    // Supersede any connect attempt still in flight so it abandons its own
    // microphone and peer instead of attaching them to a dead session.
    _startGeneration++;
    _reconnectInFlight = false;
    _completeSpeechWaiters();
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.error,
        errorMessage: message,
        isUserSpeaking: false,
      ),
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
    _completeSpeechWaiters();
    _disposed = true;
    _cancelConnectTimers();
    unawaited(_releaseResources());
    soundLevel.dispose();
    super.dispose();
  }
}
