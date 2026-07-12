import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceManager {
  VoiceManager({this.sarvamApiKey = ''}) {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      _handlePlayerState,
    );
  }

  final String sarvamApiKey;
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

  // Usage limit — 100 calls per day
  static const int _dailyLimit = 100;
  static const String _usageKey = 'sarvam_usage_count';
  static const String _dateKey = 'sarvam_usage_date';

  bool _isPremiumEnabled() =>
      sarvamApiKey.isNotEmpty && sarvamApiKey != 'your_sarvam_api_key_here';

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
        print(
          '🎙️ [VoiceManager] Using Premium Sarvam Voice! (Language: $languageCode)',
        );
        await _speakPremium(text, languageCode);
        return;
      } catch (e) {
        // ignore: avoid_print
        print(
          '🎙️ [VoiceManager] Premium TTS failed: $e. Falling back to native.',
        );
      }
    } else {
      // ignore: avoid_print
      print(
        '🎙️ [VoiceManager] Using Native Free Voice (Limit reached or Premium Disabled).',
      );
    }

    // Fallback to Native TTS
    await _speakNative(text, languageCode);
  }

  String _cleanTextForTts(String text) {
    // Remove markdown bold/italic
    var cleaned = text.replaceAll(RegExp(r'\*\*|__|\*|_|`'), '');
    // Remove markdown headers
    cleaned = cleaned.replaceAll(RegExp(r'#+\s+'), '');
    // Remove bullet points/numbered lists at start of lines
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
    // Replace links
    cleaned = cleaned.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'\1');
    return cleaned.trim();
  }

  List<String> _splitTextIntoChunks(String text, {int maxChars = 350}) {
    final List<String> chunks = [];
    final sentences = text.split(RegExp(r'(?<=[.!?|])\s+|\n+'));

    String currentChunk = '';
    for (final sentence in sentences) {
      final cleanSentence = sentence.trim();
      if (cleanSentence.isEmpty) continue;

      if (currentChunk.isEmpty) {
        currentChunk = cleanSentence;
      } else if ((currentChunk.length + cleanSentence.length + 1) <= maxChars) {
        currentChunk += ' $cleanSentence';
      } else {
        chunks.add(currentChunk);
        currentChunk = cleanSentence;
      }
    }
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    final List<String> finalChunks = [];
    for (final chunk in chunks) {
      if (chunk.length <= maxChars) {
        finalChunks.add(chunk);
      } else {
        final words = chunk.split(' ');
        String subChunk = '';
        for (final word in words) {
          if (subChunk.isEmpty) {
            subChunk = word;
          } else if ((subChunk.length + word.length + 1) <= maxChars) {
            subChunk += ' $word';
          } else {
            finalChunks.add(subChunk);
            subChunk = word;
          }
        }
        if (subChunk.isNotEmpty) {
          finalChunks.add(subChunk);
        }
      }
    }
    return finalChunks;
  }

  Future<void> _speakPremium(String text, String languageCode) async {
    final cleanedText = _cleanTextForTts(text);
    final chunks = _splitTextIntoChunks(cleanedText);

    if (chunks.isEmpty) return;

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    final tempDir = await getTemporaryDirectory();

    // Fetch all chunks in parallel for ultra-fast generation
    final futures = chunks.asMap().entries.map((entry) async {
      final index = entry.key;
      final chunkText = entry.value;

      final response = await dio.post(
        'https://api.sarvam.ai/text-to-speech',
        options: Options(
          headers: {
            'api-subscription-key': sarvamApiKey,
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'text': chunkText,
          'target_language_code': languageCode,
          'model': 'bulbul:v2',
          'speaker': languageCode.startsWith('ml') ? 'vidya' : 'anushka',
          'pace': 1.1,
        },
      );

      final audios = response.data['audios'] as List<dynamic>?;
      if (audios != null && audios.isNotEmpty) {
        final bytes = base64Decode(audios.first as String);
        final file = File('${tempDir.path}/sarvam_tts_$index.wav');
        await file.writeAsBytes(bytes);
        return MapEntry(index, file);
      }
      return null;
    });

    final results = await Future.wait(futures);
    final validResults = results.whereType<MapEntry<int, File>>().toList();
    validResults.sort((a, b) => a.key.compareTo(b.key));

    if (validResults.isEmpty) return;

    await _audioPlayer.setAudioSources(
      validResults.map((r) => AudioSource.file(r.value.path)).toList(),
    );
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

  // --- Server-side voice (push-to-talk) ---
  // Records a clip that is uploaded to the backend voice endpoint (which runs
  // STT → LLM → TTS) and plays back the signed audio URL it returns.

  /// Whether the microphone is currently capturing a push-to-talk clip.
  Future<bool> get isRecording => _recorder.isRecording();

  /// Requests mic permission and begins recording an AAC/m4a clip. Returns the
  /// file path being written to, or null if permission was denied.
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

  /// Stops the current recording and returns the finished file path (or null).
  Future<String?> stopRecording() async {
    if (!await _recorder.isRecording()) return null;
    return _recorder.stop();
  }

  /// Cancels and discards the current recording without producing a file.
  Future<void> cancelRecording() async {
    if (await _recorder.isRecording()) {
      await _recorder.cancel();
    }
  }

  /// Deletes a temporary recording file once it has been uploaded.
  Future<void> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Plays a remote (signed) audio URL returned by the voice endpoint and
  /// completes when playback finishes.
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

  // --- STT ---
  // Native speech_to_text is used here to preserve the live partial-results
  // typing effect. Sarvam WebSocket STT can be integrated later.

  Future<bool> initializeStt({
    required Function(String) onStatus,
    required Function(dynamic) onError,
  }) async {
    return await _nativeStt.initialize(onStatus: onStatus, onError: onError);
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
