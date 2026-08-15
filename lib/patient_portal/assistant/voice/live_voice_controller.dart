import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/network/api_exception.dart';
import 'inworld_signaling_api.dart';
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

  final InworldSignalingApi _signalingApi;
  final RealtimeTurnCompleted _onTurnCompleted;
  final RealtimeTurnContext _onTurnContext;

  LiveVoiceState _state = const LiveVoiceState();
  RTCPeerConnection? _peer;
  RTCDataChannel? _events;
  MediaStream? _microphone;
  Completer<void>? _iceGathering;
  Timer? _connectTimeout;
  Timer? _audioLevelTimer;
  Timer? _usageHeartbeatTimer;
  bool _disposed = false;
  bool _stopping = false;
  bool _usageStartInFlight = false;
  String _conversationId = '';
  String? _usageSessionId;
  String _currentInputItemId = '';
  String _currentResponseId = '';
  String _initialResponseInstructions = '';
  bool _initialResponseRequested = false;
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

  /// Fetches short-lived ICE/session configuration ahead of the voice tap.
  /// This does not open the microphone or create an Inworld call.
  Future<void> prewarm({required String locale}) async {
    if (_disposed || _state.isActive) return;
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
    _initialResponseInstructions = initialResponseInstructions.trim();
    _initialResponseRequested = false;
    _enableUsageTracking = enableUsageTracking;
    _sessionInstructions = sessionInstructions.trim();
    _sessionTools = tools;
    _onFunctionCall = onFunctionCall;
    _handledFunctionCallIds.clear();
    _awaitingFunctionResponse = false;
    _conversationId = conversationId;
    _debugLog('start requested locale=$locale');
    final startup = Stopwatch()..start();
    _setState(const LiveVoiceState(phase: LiveVoicePhase.connecting));

    try {
      final bootstrap = await _signalingApi.bootstrap(locale: locale);
      _debugLog(
        'bootstrap received: iceServers=${bootstrap.iceServers.length}, '
        'sessionEvent=${bootstrap.sessionUpdate['type']}, '
        'elapsed=${startup.elapsedMilliseconds}ms',
      );
      if (bootstrap.iceServers.isEmpty) {
        throw StateError('No realtime ICE servers are available.');
      }

      final peer = await createPeerConnection({
        'iceServers': bootstrap.iceServers
            .map((server) => server.toWebRtcJson())
            .toList(),
        'sdpSemantics': 'unified-plan',
        // Begin gathering candidates as early as the native WebRTC stack allows.
        'iceCandidatePoolSize': 2,
      });
      _debugLog('peer connection created');
      _peer = peer;
      _wirePeerCallbacks(peer);
      // Audio routing and microphone allocation are independent native calls;
      // running them together removes avoidable startup latency.
      final audioSessionFuture = _configureAudioSession();
      final microphoneFuture = navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      await audioSessionFuture;
      _debugLog('audio session configured for speaker/Bluetooth');

      final microphone = await microphoneFuture;
      _microphone = microphone;
      _debugLog(
        'microphone acquired: audioTracks=${microphone.getAudioTracks().length}',
      );
      for (final track in microphone.getAudioTracks()) {
        _debugLog(
          'adding microphone track: id=${track.id}, enabled=${track.enabled}',
        );
        await peer.addTrack(track, microphone);
      }
      _startAudioLevelMonitor();

      final channel = await peer.createDataChannel(
        'oai-events',
        RTCDataChannelInit()..ordered = true,
      );
      _debugLog('data channel created: label=oai-events');
      _events = channel;
      _wireDataChannel(
        channel,
        _configuredSessionUpdate(bootstrap.sessionUpdate),
      );

      final offer = await peer.createOffer({'offerToReceiveAudio': true});
      await peer.setLocalDescription(offer);
      _debugLog('local SDP offer set; waiting for ICE gathering');
      await _waitForIceGathering(peer);
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
      _debugLog(
        'SDP answer received: bytes=${answer.length}, '
        'elapsed=${startup.elapsedMilliseconds}ms',
      );
      await peer.setRemoteDescription(RTCSessionDescription(answer, 'answer'));
      _debugLog('remote SDP answer set');
      _connectTimeout = Timer(const Duration(seconds: 20), () {
        if (_state.phase == LiveVoicePhase.connecting) {
          _debugLog('connection timeout fired');
          _setError('Realtime voice connection timed out.');
          unawaited(stop(reason: 'connection_timeout'));
        }
      });
    } catch (error) {
      _debugLog('start failed: ${_safeError(error)}');
      _signalingApi.invalidateBootstrap();
      await _releaseResources();
      _setError(_friendlyError(error));
    }
  }

  Future<void> stop({String reason = 'user_stopped'}) async {
    if (_stopping) {
      _debugLog('stop ignored: already stopping');
      return;
    }
    _debugLog('stop requested: reason=$reason');
    _stopping = true;
    _connectTimeout?.cancel();
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

  void _wirePeerCallbacks(RTCPeerConnection peer) {
    peer.onIceGatheringState = (iceState) {
      _debugLog('ICE gathering state=$iceState');
      if (iceState == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !(_iceGathering?.isCompleted ?? true)) {
        _iceGathering?.complete();
      }
    };
    peer.onIceConnectionState = (iceState) {
      _debugLog('ICE connection state=$iceState');
    };
    peer.onSignalingState = (signalingState) {
      _debugLog('signaling state=$signalingState');
    };
    peer.onConnectionState = (connectionState) {
      _debugLog('peer connection state=$connectionState');
      switch (connectionState) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _connectTimeout?.cancel();
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          if (_state.isActive) {
            _setState(_state.copyWith(phase: LiveVoicePhase.reconnecting));
          }
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _setError('Realtime voice connection failed.');
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          if (!_stopping && _state.isActive) {
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
        _debugLog('remote audio track enabled');
      }
    };
  }

  Future<void> _configureAudioSession() async {
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
  }

  void _startAudioLevelMonitor() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => unawaited(_readAudioLevel()),
    );
  }

  Future<void> _readAudioLevel() async {
    final peer = _peer;
    if (peer == null || !_state.isListening) return;
    try {
      final reports = await peer.getStats();
      var level = 0.0;
      for (final report in reports) {
        final raw = report.values['audioLevel'];
        if (raw is num && raw.toDouble() > level) {
          level = raw.toDouble();
        }
      }
      if (level != _state.soundLevel) {
        _setState(_state.copyWith(soundLevel: level.clamp(0.0, 1.0)));
      }
    } catch (_) {
      // Audio-level stats are optional and differ across native WebRTC builds.
    }
  }

  void _wireDataChannel(
    RTCDataChannel channel,
    Map<String, dynamic> sessionUpdate,
  ) {
    channel.onDataChannelState = (channelState) {
      _debugLog('data channel state=$channelState');
      if (channelState == RTCDataChannelState.RTCDataChannelOpen) {
        _debugLog('data channel open; sending session.update');
        unawaited(_sendEvent(sessionUpdate));
      } else if (channelState == RTCDataChannelState.RTCDataChannelClosed &&
          !_stopping &&
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

  Future<void> _waitForIceGathering(RTCPeerConnection peer) async {
    if (await peer.getIceGatheringState() ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    _iceGathering = Completer<void>();
    // Do not block the patient on full ICE completion. Candidates continue to
    // populate the local SDP immediately, while this short window preserves a
    // reliable first candidate for typical mobile and Wi-Fi networks.
    await _iceGathering!.future.timeout(
      const Duration(milliseconds: 350),
      onTimeout: () {
        _debugLog('ICE fast-start window elapsed; continuing with current SDP');
      },
    );
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
        final session = event['session'] is Map
            ? Map<String, dynamic>.from(event['session'] as Map)
            : const <String, dynamic>{};
        _setState(
          _state.copyWith(
            phase: LiveVoicePhase.listening,
            sessionId: session['id']?.toString(),
            clearError: true,
          ),
        );
        unawaited(_beginUsageTracking());
        _requestInitialResponse();
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
        final response = event['response'] is Map
            ? Map<String, dynamic>.from(event['response'] as Map)
            : const <String, dynamic>{};
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
      case 'response.output_audio_transcript.delta':
        _appendResponseDelta(event, audioTranscript: true);
      case 'response.output_text.delta':
        _appendResponseDelta(event, audioTranscript: false);
      case 'response.function_call_arguments.done':
        unawaited(_handleFunctionCall(event));
      case 'response.done':
        _completeResponse(event);
      case 'error':
        final error = event['error'] is Map
            ? Map<String, dynamic>.from(event['error'] as Map)
            : const <String, dynamic>{};
        _debugLog(
          'provider error: code=${error['code'] ?? '<missing>'}, '
          'message=${error['message'] ?? '<missing>'}',
        );
        _setError(
          error['message']?.toString() ?? 'Realtime voice request failed.',
        );
      default:
        break;
    }
  }

  Future<void> _handleFunctionCall(Map<String, dynamic> event) async {
    final handler = _onFunctionCall;
    final item = event['item'] is Map
        ? Map<String, dynamic>.from(event['item'] as Map)
        : const <String, dynamic>{};
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
      await _failContextTurn(
        'Could not prepare your AI Checkup result. Please try again.',
      );
    }
  }

  Future<void> _requestContextAndRespond(
    String itemId,
    String transcript,
  ) async {
    if (transcript.isEmpty) {
      await _failContextTurn('No speech was detected. Please try again.');
      return;
    }

    try {
      _debugLog(
        'requesting Laravel voice context for transcript chars=${transcript.length}',
      );
      final contextLookup = Stopwatch()..start();
      final instructions = await _onTurnContext(transcript);
      contextLookup.stop();
      _debugLog(
        'turn latency: Laravel context completed at '
        '${_turnLatency?.elapsedMilliseconds ?? -1}ms '
        '(round trip=${contextLookup.elapsedMilliseconds}ms)',
      );
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
          'instructions': instructions,
        },
      });
      _debugTurnLatency('response.create sent');
    } catch (error) {
      _debugLog('Laravel voice context request failed: ${_safeError(error)}');
      if (!_disposed && !_stopping && _currentInputItemId == itemId) {
        await _failContextTurn(
          'Could not prepare your health context. Please try again.',
        );
      }
    }
  }

  void _requestInitialResponse() {
    if (_initialResponseRequested || _initialResponseInstructions.isEmpty) {
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

  Future<void> _failContextTurn(String message) async {
    _setError(message);
    await _releaseResources();
    _clearTurnBuffers();
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
    final response = event['response'] is Map
        ? Map<String, dynamic>.from(event['response'] as Map)
        : const <String, dynamic>{};
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
    _enableUsageTracking = true;
    _conversationId = '';
    _sessionInstructions = '';
    _sessionTools = const [];
    _onFunctionCall = null;
    _handledFunctionCallIds.clear();
    _awaitingFunctionResponse = false;
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

  Future<void> _releaseResources() async {
    _debugLog('releasing realtime resources');
    _connectTimeout?.cancel();
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
    await _finishUsageTracking();
    _iceGathering = null;
    final events = _events;
    _events = null;
    await events?.close();
    final microphone = _microphone;
    _microphone = null;
    for (final track in microphone?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    await microphone?.dispose();
    final peer = _peer;
    _peer = null;
    await peer?.close();
    await peer?.dispose();
    _debugLog('realtime resources released');
  }

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
      final interval = update.heartbeatIntervalSeconds.clamp(15, 60);
      _usageHeartbeatTimer?.cancel();
      _usageHeartbeatTimer = Timer.periodic(
        Duration(seconds: interval),
        (_) => unawaited(_heartbeatUsage()),
      );
      _debugLog('voice reward tracking started: session=${update.sessionId}');
    } catch (error) {
      // Reward tracking must never interrupt a clinical voice conversation.
      _debugLog('voice reward tracking unavailable: ${_safeError(error)}');
    } finally {
      _usageStartInFlight = false;
    }
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

  String _friendlyError(Object error) {
    if (error is ApiException && error.statusCode == 503) {
      return error.message;
    }
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('Permission') || text.contains('NotAllowed')) {
      return 'Microphone permission is required for live voice.';
    }
    return text;
  }

  void _setError(String message) {
    if (_disposed) return;
    _debugLog('state error: $message');
    _setState(
      _state.copyWith(phase: LiveVoicePhase.error, errorMessage: message),
    );
  }

  void _setState(LiveVoiceState next) {
    if (_disposed) return;
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
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) &&
        _state.isActive) {
      unawaited(stop(reason: 'app_backgrounded'));
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    unawaited(_releaseResources());
    super.dispose();
  }
}
