import 'dart:async';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Owns the assistant's microphone and playback resources.
///
/// Provider credentials intentionally never enter this class. Text returned by
/// the authenticated backend is spoken with the device TTS engine, while an
/// optional signed server-audio URL can still be played for compatibility.
class VoiceManager {
  VoiceManager() {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      _handlePlayerState,
    );
  }

  final FlutterTts _nativeTts = FlutterTts();
  final SpeechToText _nativeStt = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  late final StreamSubscription<PlayerState> _playerStateSubscription;

  void Function()? _ttsStartHandler;
  void Function()? _ttsCompletionHandler;
  bool _playerWasPlaying = false;

  FlutterTts get nativeTts => _nativeTts;
  SpeechToText get nativeStt => _nativeStt;
  Stream<Amplitude> get amplitudeStream =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 90));

  void _handlePlayerState(PlayerState state) {
    if (state.playing && !_playerWasPlaying) {
      _ttsStartHandler?.call();
    }
    if (state.processingState == ProcessingState.completed) {
      _ttsCompletionHandler?.call();
    }
    _playerWasPlaying = state.playing;
  }

  Future<void> speak(String text, String languageCode) async {
    await _nativeTts.setLanguage(languageCode);
    await _nativeTts.setPitch(1.0);
    await _nativeTts.setSpeechRate(languageCode.startsWith('ml') ? 0.42 : 0.45);
    await _nativeTts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _nativeTts.stop();
    await _audioPlayer.stop();
  }

  Future<bool> get isRecording => _recorder.isRecording();

  Future<String?> startRecording() async {
    if (!await _recorder.hasPermission()) {
      return null;
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/voice_turn_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    return path;
  }

  Future<String?> stopRecording() async {
    if (!await _recorder.isRecording()) return null;
    return _recorder.stop();
  }

  Future<void> cancelRecording() async {
    if (await _recorder.isRecording()) {
      await _recorder.cancel();
    }
  }

  Future<void> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Temporary-file cleanup must not break the voice session.
    }
  }

  Future<void> playRemoteAudio(String url) async {
    await _audioPlayer.setUrl(url);
    await _audioPlayer.play();
    await _audioPlayer.playerStateStream.firstWhere(
      (state) =>
          state.processingState == ProcessingState.completed ||
          state.processingState == ProcessingState.idle,
    );
  }

  void setTtsStartHandler(void Function() handler) {
    _nativeTts.setStartHandler(handler);
    _ttsStartHandler = handler;
  }

  void setTtsCompletionHandler(void Function() handler) {
    _nativeTts.setCompletionHandler(handler);
    _ttsCompletionHandler = handler;
  }

  void setTtsCancelHandler(void Function() handler) {
    _nativeTts.setCancelHandler(handler);
  }

  Future<void> awaitSpeakCompletion(bool awaitCompletion) async {
    await _nativeTts.awaitSpeakCompletion(awaitCompletion);
  }

  Future<bool> initializeStt({
    required Function(String) onStatus,
    required Function(dynamic) onError,
  }) {
    return _nativeStt.initialize(onStatus: onStatus, onError: onError);
  }

  bool get isListening => _nativeStt.isListening;

  Future<void> stopListening() => _nativeStt.stop();

  Future<void> listen({
    required String localeId,
    required Duration listenFor,
    required Duration pauseFor,
    required SpeechListenOptions listenOptions,
    required Function(SpeechRecognitionResult) onResult,
  }) async {
    await _nativeStt.listen(
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        partialResults: listenOptions.partialResults,
        cancelOnError: listenOptions.cancelOnError,
        onDevice: listenOptions.onDevice,
        autoPunctuation: listenOptions.autoPunctuation,
        enableHapticFeedback: listenOptions.enableHapticFeedback,
      ),
      onResult: onResult,
    );
  }

  Future<void> dispose() async {
    await _playerStateSubscription.cancel();
    await _nativeStt.cancel();
    await _nativeTts.stop();
    await _audioPlayer.dispose();
    await _recorder.dispose();
  }
}
