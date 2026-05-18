import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceManager {
  VoiceManager({
    required this.sarvamApiKey,
  });

  final String sarvamApiKey;
  final FlutterTts _nativeTts = FlutterTts();
  final SpeechToText _nativeStt = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();

  FlutterTts get nativeTts => _nativeTts;
  SpeechToText get nativeStt => _nativeStt;

  // Usage limit — 100 calls per day
  static const int _dailyLimit = 100;
  static const String _usageKey = 'sarvam_usage_count';
  static const String _dateKey = 'sarvam_usage_date';

  bool _isPremiumEnabled() =>
      sarvamApiKey.isNotEmpty &&
      sarvamApiKey != 'your_sarvam_api_key_here';

  Future<bool> _checkLimitAndIncrement() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;
    final storedDate = prefs.getString(_dateKey);

    int usage = prefs.getInt(_usageKey) ?? 0;

    if (storedDate != today) {
      usage = 0;
      await prefs.setString(_dateKey, today);
    }

    if (usage < _dailyLimit) {
      await prefs.setInt(_usageKey, usage + 1);
      return true;
    }
    return false;
  }

  // --- TTS ---

  Future<void> speak(String text, String languageCode) async {
    if (_isPremiumEnabled() && await _checkLimitAndIncrement()) {
      try {
        // ignore: avoid_print
        print('🎙️ [VoiceManager] Using Premium Sarvam Voice! (Language: $languageCode)');
        await _speakPremium(text, languageCode);
        return;
      } catch (e) {
        // ignore: avoid_print
        print('🎙️ [VoiceManager] Premium TTS failed: $e. Falling back to native.');
      }
    } else {
      // ignore: avoid_print
      print('🎙️ [VoiceManager] Using Native Free Voice (Limit reached or Premium Disabled).');
    }

    // Fallback to Native TTS
    await _speakNative(text, languageCode);
  }

  Future<void> _speakPremium(String text, String languageCode) async {
    final safeText = text.length > 2400 ? text.substring(0, 2400) : text;

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ));

    final response = await dio.post(
      'https://api.sarvam.ai/text-to-speech',
      options: Options(
        headers: {
          'api-subscription-key': sarvamApiKey,
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'text': safeText,
        'target_language_code': languageCode,
        'model': 'bulbul:v2',
        'speaker': languageCode.startsWith('ml') ? 'vidya' : 'anushka',
        'pace': 1.3,
      },
    );

    final audios = response.data['audios'] as List<dynamic>?;
    if (audios == null || audios.isEmpty) return;
    final bytes = base64Decode(audios.first as String);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/sarvam_tts.wav');
    await file.writeAsBytes(bytes);

    await _audioPlayer.setFilePath(file.path);
    await _audioPlayer.play();
    await _audioPlayer.playerStateStream.firstWhere(
      (state) =>
          state.processingState == ProcessingState.completed ||
          state.processingState == ProcessingState.idle,
    );
  }

  Future<void> _speakNative(String text, String languageCode) async {
    await _nativeTts.setLanguage(languageCode);
    await _nativeTts.setPitch(1.0);
    await _nativeTts.setSpeechRate(languageCode.startsWith('ml') ? 0.42 : 0.45);
    await _nativeTts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _nativeTts.stop();
    await _audioPlayer.stop();
  }

  void setTtsStartHandler(void Function() handler) {
    _nativeTts.setStartHandler(handler);
    _audioPlayer.playerStateStream.listen((state) {
      if (state.playing &&
          state.processingState == ProcessingState.ready) {
        handler();
      }
    });
  }

  void setTtsCompletionHandler(void Function() handler) {
    _nativeTts.setCompletionHandler(handler);
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        handler();
      }
    });
  }

  void setTtsCancelHandler(void Function() handler) {
    _nativeTts.setCancelHandler(handler);
  }

  Future<void> awaitSpeakCompletion(bool awaitCompletion) async {
    await _nativeTts.awaitSpeakCompletion(awaitCompletion);
  }

  // --- STT ---
  // Native speech_to_text is used here to preserve the live partial-results
  // typing effect. Sarvam WebSocket STT can be integrated later.

  Future<bool> initializeStt({
    required Function(String) onStatus,
    required Function(dynamic) onError,
  }) async {
    return await _nativeStt.initialize(
      onStatus: onStatus,
      onError: onError,
    );
  }

  bool get isListening => _nativeStt.isListening;

  Future<void> stopListening() async {
    await _nativeStt.stop();
  }

  Future<void> listen({
    required String localeId,
    required Duration listenFor,
    required Duration pauseFor,
    required SpeechListenOptions listenOptions,
    required Function(SpeechRecognitionResult) onResult,
  }) async {
    await _nativeStt.listen(
      localeId: localeId,
      listenFor: listenFor,
      pauseFor: pauseFor,
      listenOptions: listenOptions,
      onResult: onResult,
    );
  }
}
