import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

class GeminiVoiceTranscript {
  const GeminiVoiceTranscript({required this.text, required this.languageCode});

  final String text;
  final String languageCode;
}

class GeminiSttService {
  GeminiSttService({
    required String apiKey,
    String model = 'google/gemini-3-flash',
    String baseUrl = 'https://api.replicate.com/v1',
    Dio? dio,
  }) : _apiKey = apiKey.trim(),
       _model = model.trim().isEmpty ? 'google/gemini-3-flash' : model.trim(),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 20),
               sendTimeout: const Duration(seconds: 45),
               receiveTimeout: const Duration(seconds: 90),
               headers: const {'Accept': 'application/json'},
             ),
           );

  final Dio _dio;
  String _apiKey;
  String _model;

  bool get isConfigured => _apiKey.isNotEmpty;

  void configure({required String apiKey, String? model}) {
    final nextKey = apiKey.trim();
    if (nextKey.isNotEmpty) _apiKey = nextKey;

    final nextModel = (model ?? '').trim();
    if (nextModel.isNotEmpty) _model = nextModel;
  }

  Future<GeminiVoiceTranscript?> transcribeRecording({
    required String audioFilePath,
    required String language,
  }) async {
    final file = File(audioFilePath);
    if (!isConfigured || !await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final mimeType = _mimeTypeForPath(audioFilePath);
    final languageName = language == 'ml' ? 'Malayalam' : 'English';
    final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';

    final response = await _dio.post<Map<String, dynamic>>(
      '/models/$_model/predictions',
      data: {
        'input': {
          'audio': dataUri,
          'mime_type': mimeType,
          'prompt':
              'Transcribe this audio exactly. Language hint: $languageName. '
              'If the hint is wrong, use the language actually spoken. '
              'If there is no clear human speech, or the audio is only static, '
              'background noise, music, breathing, tapping, or silence, return an empty string. '
              'Return only the spoken words, with no explanation, labels, '
              'translation, markdown, or punctuation-only filler.',
          'system_instruction':
              'You are a speech-to-text engine. Never guess missing speech.',
          'max_output_tokens': 256,
          'thinking_level': 'low',
        },
      },
      options: Options(
        headers: {'Authorization': 'Bearer $_apiKey', 'Prefer': 'wait'},
      ),
    );

    final text = _extractText(response.data?['output']).trim();
    if (text.isEmpty) return null;

    return GeminiVoiceTranscript(
      text: text,
      languageCode: _containsMalayalam(text) ? 'ml' : language,
    );
  }

  static String _extractText(dynamic output) {
    if (output is String) return output;
    if (output is List) return output.map((item) => item.toString()).join();
    if (output is Map) {
      return (output['transcription'] ?? output['text'] ?? '').toString();
    }
    return '';
  }

  static bool _containsMalayalam(String text) {
    return RegExp(r'[\u0D00-\u0D7F]').hasMatch(text);
  }

  static String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.webm')) return 'audio/webm';
    return 'audio/mp4';
  }
}
