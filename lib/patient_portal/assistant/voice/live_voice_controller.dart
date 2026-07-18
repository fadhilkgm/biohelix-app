import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'live_voice_state.dart';
import 'microphone_stream.dart';
import 'streaming_audio_player.dart';
import 'voice_gateway_client.dart';
import 'voice_protocol.dart';

class LiveVoiceController extends ChangeNotifier {
  LiveVoiceController({
    required ApiClient apiClient,
    required String Function() conversationIdProvider,
    void Function(String transcript, String response)? onTurnCompleted,
    MicrophoneStream? microphone,
    StreamingAudioPlayer? audioPlayer,
    VoiceGatewayClient? gateway,
  }) : _apiClient = apiClient,
       _conversationIdProvider = conversationIdProvider,
       _onTurnCompleted = onTurnCompleted,
       _microphone = microphone ?? MicrophoneStream(),
       _audioPlayer = audioPlayer ?? StreamingAudioPlayer(),
       _gateway = gateway ?? VoiceGatewayClient();

  final ApiClient _apiClient;
  final String Function() _conversationIdProvider;
  final void Function(String transcript, String response)? _onTurnCompleted;
  final MicrophoneStream _microphone;
  final StreamingAudioPlayer _audioPlayer;
  final VoiceGatewayClient _gateway;

  LiveVoiceState _state = const LiveVoiceState();
  StreamSubscription<VoiceGatewayEvent>? _gatewaySubscription;
  StreamSubscription<Uint8List>? _microphoneSubscription;
  StreamSubscription<dynamic>? _amplitudeSubscription;
  Timer? _endpointingTimer;
  VoiceSessionTicket? _session;
  String? _activeTurnId;
  int _audioSequence = 0;
  int _generation = 0;
  int _turnSequence = 0;
  DateTime? _lastSpeechAt;
  bool _hasSpeech = false;
  bool _disposed = false;

  LiveVoiceState get state => _state;

  Future<void> start({required String locale}) async {
    if (_state.isActive) return;
    _generation = 0;
    _activeTurnId = null;
    _audioSequence = 0;
    _hasSpeech = false;
    _lastSpeechAt = null;
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.connecting,
        clearError: true,
      ),
    );

    try {
      final session = await _createSession(locale: locale);
      _session = session;
      _gatewaySubscription = _gateway.events.listen(
        _handleGatewayEvent,
        onError: (Object error, StackTrace stack) {
          _setError(error.toString());
        },
      );
      await _gateway.connect(session);
      final permitted = await _microphone.hasPermission();
      if (!permitted) {
        throw StateError('Microphone permission is required for live voice.');
      }
      await _audioPlayer.initialize();
      await _startMicrophone();
      _setState(
        _state.copyWith(
          phase: LiveVoicePhase.listening,
          sessionId: session.sessionId,
          clearError: true,
        ),
      );
    } catch (error) {
      await stop(reason: 'start_failed');
      _setError(error.toString());
    }
  }

  Future<void> stop({String reason = 'user_stopped'}) async {
    if (_state.phase == LiveVoicePhase.idle ||
        _state.phase == LiveVoicePhase.closed) {
      return;
    }
    _setState(_state.copyWith(phase: LiveVoicePhase.closing));
    _generation++;
    try {
      final session = _session;
      if (session != null && _gateway.isConnected) {
        _gateway.sendControl(
          VoiceProtocol.control(
            type: VoiceClientEventType.sessionEnd,
            sessionId: session.sessionId,
            generation: _generation,
            data: {'reason': reason},
          ),
        );
      }
    } catch (_) {
      // The socket may already have closed; local resources still need cleanup.
    }
    await _microphoneSubscription?.cancel();
    await _amplitudeSubscription?.cancel();
    _endpointingTimer?.cancel();
    _endpointingTimer = null;
    await _gatewaySubscription?.cancel();
    _microphoneSubscription = null;
    _amplitudeSubscription = null;
    _gatewaySubscription = null;
    await _microphone.cancel();
    await _audioPlayer.stop();
    await _gateway.disconnect();
    _session = null;
    _activeTurnId = null;
    _setState(
      const LiveVoiceState(
        phase: LiveVoicePhase.closed,
      ),
    );
  }

  Future<void> interrupt() async {
    final session = _session;
    final turnId = _activeTurnId;
    if (session == null || turnId == null) return;
    _generation++;
    await _audioPlayer.stop();
    if (_gateway.isConnected) {
      _gateway.sendControl(
        VoiceProtocol.control(
          type: VoiceClientEventType.responseCancel,
          sessionId: session.sessionId,
          turnId: turnId,
          generation: _generation,
        ),
      );
    }
    _activeTurnId = null;
    _audioSequence = 0;
    _hasSpeech = false;
    _lastSpeechAt = null;
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.listening,
        partialTranscript: '',
        finalTranscript: '',
        responseText: '',
        clearError: true,
        clearTurn: true,
      ),
    );
  }

  Future<void> commitTurn() async {
    final session = _session;
    final turnId = _activeTurnId;
    if (session == null || turnId == null || !_gateway.isConnected) return;
    _hasSpeech = false;
    _gateway.sendControl(
      VoiceProtocol.control(
        type: VoiceClientEventType.audioCommit,
        sessionId: session.sessionId,
        turnId: turnId,
        generation: _generation,
      ),
    );
    _setState(_state.copyWith(phase: LiveVoicePhase.transcribing));
  }

  Future<VoiceSessionTicket> _createSession({required String locale}) async {
    final conversationId = _conversationId;
    if (conversationId.isEmpty) {
      throw StateError('Select a chat conversation before starting voice.');
    }
    final response = await _apiClient.postJson(
      '/patients/chat/global/threads/$conversationId/voice-sessions',
      data: {
        'locale': locale,
        'protocol': VoiceProtocol.version,
        'device_id': 'flutter-${defaultTargetPlatform.name}',
      },
    );
    final raw = response['session'] is Map ? response['session'] : response;
    final session = VoiceSessionTicket.fromJson(_map(raw));
    if (session.sessionId.isEmpty ||
        session.gatewayUrl.isEmpty ||
        session.ticket.isEmpty) {
      throw StateError('The server returned an incomplete voice session.');
    }
    return session;
  }

  Future<void> _startMicrophone() async {
    final stream = await _microphone.start();
    final session = _session!;
    _microphoneSubscription = stream.listen((chunk) {
      if (_state.phase != LiveVoicePhase.listening &&
          _state.phase != LiveVoicePhase.speaking) {
        return;
      }
      if (_state.phase == LiveVoicePhase.speaking) return;
      if (_activeTurnId == null) {
        _activeTurnId = _newTurnId();
        _audioSequence = 0;
        _gateway.sendControl(
          VoiceProtocol.control(
            type: VoiceClientEventType.audioStart,
            sessionId: session.sessionId,
            turnId: _activeTurnId,
            generation: _generation,
          ),
        );
      }
      _gateway.sendAudio(
        sessionId: session.sessionId,
        turnId: _activeTurnId!,
        sequence: _audioSequence++,
        pcm16: chunk,
      );
    });
    _amplitudeSubscription = _microphone.amplitudeStream.listen((amplitude) {
      final level = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
      if (_state.phase == LiveVoicePhase.speaking && level >= 0.22) {
        unawaited(interrupt());
      }
      if (_state.phase != LiveVoicePhase.listening) {
        _setState(_state.copyWith(soundLevel: level));
        return;
      }
      if (level >= 0.14) {
        _lastSpeechAt = DateTime.now();
        _hasSpeech = true;
      }
      _endpointingTimer ??= Timer.periodic(
        const Duration(milliseconds: 120),
        (_) {
          if (_state.phase != LiveVoicePhase.listening ||
              !_hasSpeech ||
              _activeTurnId == null) {
            return;
          }
          final lastSpeech = _lastSpeechAt;
          if (lastSpeech != null &&
              DateTime.now().difference(lastSpeech) >=
                  const Duration(milliseconds: 900)) {
            _hasSpeech = false;
            unawaited(commitTurn());
          }
        },
      );
      _setState(_state.copyWith(soundLevel: level));
    });
  }

  void _handleGatewayEvent(VoiceGatewayEvent event) {
    if (event.sessionId != null && event.sessionId != _session?.sessionId) {
      return;
    }
    if (event.generation != null && event.generation != _generation) return;

    switch (event.type) {
      case 'session.ready':
        _setState(_state.copyWith(phase: LiveVoicePhase.listening));
      case 'turn.accepted':
        _setState(
          _state.copyWith(
            phase: LiveVoicePhase.listening,
            turnId: event.turnId,
            clearError: true,
          ),
        );
      case 'transcript.partial':
        _setState(
          _state.copyWith(
            phase: LiveVoicePhase.listening,
            partialTranscript: event.text,
          ),
        );
      case 'transcript.final':
        _setState(
          _state.copyWith(
            phase: LiveVoicePhase.thinking,
            finalTranscript: event.text,
            partialTranscript: '',
          ),
        );
      case 'response.text.delta':
        _setState(
          _state.copyWith(
            phase: LiveVoicePhase.speaking,
            responseText: '${_state.responseText}${event.text}',
          ),
        );
      case 'response.audio.start':
        unawaited(_audioPlayer.start());
        _setState(_state.copyWith(phase: LiveVoicePhase.speaking));
      case 'response.audio.chunk':
        final audio = event.audio;
        if (audio != null) _audioPlayer.add(audio);
        _setState(_state.copyWith(phase: LiveVoicePhase.speaking));
      case 'response.audio.end':
        unawaited(_audioPlayer.finish());
        _completeTurn();
      case 'response.cancelled':
        unawaited(_audioPlayer.stop());
        _completeTurn();
      case 'safety.escalation':
        _setState(_state.copyWith(phase: LiveVoicePhase.degraded));
      case 'error':
        _setError(event.text.isEmpty ? 'Live voice is unavailable.' : event.text);
      case 'session.ended':
        unawaited(stop(reason: 'server_ended'));
    }
  }

  void _completeTurn() {
    final transcript = _state.finalTranscript;
    final response = _state.responseText;
    _activeTurnId = null;
    _audioSequence = 0;
    _hasSpeech = false;
    _lastSpeechAt = null;
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.listening,
        partialTranscript: '',
        clearError: true,
      ),
    );
    if (transcript.trim().isNotEmpty || response.trim().isNotEmpty) {
      _onTurnCompleted?.call(transcript, response);
    }
  }

  void _setError(String message) {
    _setState(
      _state.copyWith(
        phase: LiveVoicePhase.error,
        errorMessage: message,
      ),
    );
  }

  void _setState(LiveVoiceState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  String get _conversationId {
    return _conversationIdProvider().trim();
  }

  String _newTurnId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_turnSequence++}';

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop(reason: 'controller_disposed'));
    unawaited(_microphone.dispose());
    unawaited(_audioPlayer.dispose());
    unawaited(_gateway.dispose());
    super.dispose();
  }
}
