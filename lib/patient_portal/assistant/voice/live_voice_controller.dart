import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    if (_state.isActive) {
      _debugLog('start ignored: session is already active');
      return;
    }
    _debugLog('start requested locale=$locale');
    _setState(const LiveVoiceState(phase: LiveVoicePhase.connecting));

    try {
      final bootstrap = await _signalingApi.bootstrap();
      _debugLog(
        'bootstrap received: iceServers=${bootstrap.iceServers.length}, '
        'sessionEvent=${bootstrap.sessionUpdate['type']}',
      );
      if (bootstrap.iceServers.isEmpty) {
        throw StateError('No realtime ICE servers are available.');
      }

      final peer = await createPeerConnection({
        'iceServers': bootstrap.iceServers
            .map((server) => server.toWebRtcJson())
            .toList(),
        'sdpSemantics': 'unified-plan',
      });
      _debugLog('peer connection created');
      _peer = peer;
      _wirePeerCallbacks(peer);
      await _configureAudioSession();
      _debugLog('audio session configured for speaker/Bluetooth');

      final microphone = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
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
      _wireDataChannel(channel, bootstrap.sessionUpdate);

      final offer = await peer.createOffer({'offerToReceiveAudio': true});
      await peer.setLocalDescription(offer);
      _debugLog('local SDP offer set; waiting for ICE gathering');
      await _waitForIceGathering(peer);
      final local = await peer.getLocalDescription();
      final offerSdp = local?.sdp ?? '';
      if (!offerSdp.trimLeft().startsWith('v=0')) {
        throw StateError('WebRTC did not create a valid SDP offer.');
      }

      _debugLog('sending SDP offer to Laravel: bytes=${offerSdp.length}');
      final answer = await _signalingApi.createCall(offerSdp);
      _debugLog('SDP answer received: bytes=${answer.length}');
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
    await _iceGathering!.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _debugLog('ICE gathering wait timed out; continuing with current SDP');
      },
    );
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
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

  String _friendlyError(Object error) {
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
