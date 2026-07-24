import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'inworld_signaling_api.dart';
import 'live_voice_state.dart';

typedef RealtimeTurnCompleted =
    FutureOr<void> Function(String transcript, String response);

class LiveVoiceController extends ChangeNotifier with WidgetsBindingObserver {
  LiveVoiceController({
    required InworldSignalingApi signalingApi,
    required RealtimeTurnCompleted onTurnCompleted,
  }) : _signalingApi = signalingApi,
       _onTurnCompleted = onTurnCompleted {
    WidgetsBinding.instance.addObserver(this);
  }

  final InworldSignalingApi _signalingApi;
  final RealtimeTurnCompleted _onTurnCompleted;

  LiveVoiceState _state = const LiveVoiceState();
  RTCPeerConnection? _peer;
  RTCDataChannel? _events;
  MediaStream? _microphone;
  Completer<void>? _iceGathering;
  Timer? _connectTimeout;
  Timer? _audioLevelTimer;
  bool _disposed = false;
  bool _stopping = false;
  String _currentInputItemId = '';
  String _currentResponseId = '';
  final Map<String, StringBuffer> _inputTranscripts = {};
  final Map<String, StringBuffer> _responseText = {};
  final Map<String, StringBuffer> _responseAudioTranscripts = {};

  LiveVoiceState get state => _state;

  Future<void> start({required String locale}) async {
    if (_state.isActive) return;
    _setState(const LiveVoiceState(phase: LiveVoicePhase.connecting));

    try {
      final bootstrap = await _signalingApi.bootstrap();
      if (bootstrap.iceServers.isEmpty) {
        throw StateError('No realtime ICE servers are available.');
      }

      final peer = await createPeerConnection({
        'iceServers': bootstrap.iceServers
            .map((server) => server.toWebRtcJson())
            .toList(),
        'sdpSemantics': 'unified-plan',
      });
      _peer = peer;
      _wirePeerCallbacks(peer);
      await _configureAudioSession();

      final microphone = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      _microphone = microphone;
      for (final track in microphone.getAudioTracks()) {
        await peer.addTrack(track, microphone);
      }
      _startAudioLevelMonitor();

      final channel = await peer.createDataChannel(
        'oai-events',
        RTCDataChannelInit()..ordered = true,
      );
      _events = channel;
      _wireDataChannel(channel, bootstrap.sessionUpdate);

      final offer = await peer.createOffer({'offerToReceiveAudio': true});
      await peer.setLocalDescription(offer);
      await _waitForIceGathering(peer);
      final local = await peer.getLocalDescription();
      final offerSdp = local?.sdp ?? '';
      if (!offerSdp.trimLeft().startsWith('v=0')) {
        throw StateError('WebRTC did not create a valid SDP offer.');
      }

      final answer = await _signalingApi.createCall(offerSdp);
      await peer.setRemoteDescription(RTCSessionDescription(answer, 'answer'));
      _connectTimeout = Timer(const Duration(seconds: 20), () {
        if (_state.phase == LiveVoicePhase.connecting) {
          _setError('Realtime voice connection timed out.');
          unawaited(stop(reason: 'connection_timeout'));
        }
      });
    } catch (error) {
      await _releaseResources();
      _setError(_friendlyError(error));
    }
  }

  Future<void> stop({String reason = 'user_stopped'}) async {
    if (_stopping) return;
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
    if (_events?.state != RTCDataChannelState.RTCDataChannelOpen) return;
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
      if (iceState == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !(_iceGathering?.isCompleted ?? true)) {
        _iceGathering?.complete();
      }
    };
    peer.onConnectionState = (connectionState) {
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
      if (event.track.kind == 'audio') {
        event.track.enabled = true;
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
      if (channelState == RTCDataChannelState.RTCDataChannelOpen) {
        unawaited(_sendEvent(sessionUpdate));
      } else if (channelState == RTCDataChannelState.RTCDataChannelClosed &&
          !_stopping &&
          _state.isActive) {
        _setError('Realtime event channel closed.');
      }
    };
    channel.onMessage = (message) {
      if (message.isBinary) return;
      try {
        final decoded = jsonDecode(message.text);
        if (decoded is Map) {
          _handleEvent(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
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
    await _iceGathering!.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
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
      case 'input_audio_buffer.speech_started':
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
      case 'response.created':
        final response = event['response'] is Map
            ? Map<String, dynamic>.from(event['response'] as Map)
            : const <String, dynamic>{};
        _currentResponseId =
            response['id']?.toString() ??
            event['response_id']?.toString() ??
            'current-response';
        _setState(_state.copyWith(phase: LiveVoicePhase.thinking));
      case 'response.output_audio_transcript.delta':
        _appendResponseDelta(event, audioTranscript: true);
      case 'response.output_text.delta':
        _appendResponseDelta(event, audioTranscript: false);
      case 'response.done':
        _completeResponse(event);
      case 'error':
        final error = event['error'] is Map
            ? Map<String, dynamic>.from(event['error'] as Map)
            : const <String, dynamic>{};
        _setError(
          error['message']?.toString() ?? 'Realtime voice request failed.',
        );
      default:
        break;
    }
  }

  void _appendResponseDelta(
    Map<String, dynamic> event, {
    required bool audioTranscript,
  }) {
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
    if (transcript.isNotEmpty && answer.isNotEmpty) {
      unawaited(Future.sync(() => _onTurnCompleted(transcript, answer)));
    }
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
  }

  Future<void> _sendEvent(Map<String, dynamic> event) async {
    final channel = _events;
    if (channel == null ||
        channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      return;
    }
    await channel.send(RTCDataChannelMessage(jsonEncode(event)));
  }

  void _clearTurnBuffers() {
    _inputTranscripts.clear();
    _responseText.clear();
    _responseAudioTranscripts.clear();
    _currentInputItemId = '';
    _currentResponseId = '';
  }

  String _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      if ((value ?? '').isNotEmpty) return value!;
    }
    return '';
  }

  Future<void> _releaseResources() async {
    _connectTimeout?.cancel();
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
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
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('Permission') || text.contains('NotAllowed')) {
      return 'Microphone permission is required for live voice.';
    }
    return text;
  }

  void _setError(String message) {
    if (_disposed) return;
    _setState(
      _state.copyWith(phase: LiveVoicePhase.error, errorMessage: message),
    );
  }

  void _setState(LiveVoiceState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
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
