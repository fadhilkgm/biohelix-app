import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class GeminiTtsService {
  GeminiTtsService({
    required String apiKey,
    String model = 'google/gemini-3.1-flash-tts',
    String voice = 'Kore',
    String languageCode = 'ml-IN',
    String baseUrl = 'https://api.replicate.com/v1',
    Dio? dio,
  }) : _apiKey = apiKey.trim(),
       _model = model.trim().isEmpty
           ? 'google/gemini-3.1-flash-tts'
           : model.trim(),
       _voice = voice.trim().isEmpty ? 'Kore' : voice.trim(),
       _languageCode = languageCode.trim().isEmpty
           ? 'ml-IN'
           : languageCode.trim(),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 20),
               sendTimeout: const Duration(seconds: 30),
               receiveTimeout: const Duration(seconds: 90),
               headers: const {'Accept': 'application/json'},
             ),
           );

  final Dio _dio;
  String _apiKey;
  String _model;
  String _voice;
  String _languageCode;

  bool get isConfigured => _apiKey.isNotEmpty;

  void configure({
    required String apiKey,
    String? model,
    String? voice,
    String? languageCode,
  }) {
    final nextKey = apiKey.trim();
    if (nextKey.isNotEmpty) _apiKey = nextKey;

    final nextModel = (model ?? '').trim();
    if (nextModel.isNotEmpty) _model = nextModel;

    final nextVoice = (voice ?? '').trim();
    if (nextVoice.isNotEmpty) _voice = nextVoice;

    final nextLanguageCode = (languageCode ?? '').trim();
    if (nextLanguageCode.isNotEmpty) _languageCode = nextLanguageCode;
  }

  Future<String?> synthesizeToTempFile(String text) async {
    final trimmed = text.trim();
    if (!isConfigured || trimmed.isEmpty) return null;

    final response = await _dio.post<Map<String, dynamic>>(
      '/models/$_model/predictions',
      data: {
        'input': {
          'prompt': trimmed,
          'text': trimmed,
          'voice_name': _voice,
          'voice': _voice,
          'language_code': _languageCode,
          'thinking_level': 'low',
        },
      },
      options: Options(
        headers: {'Authorization': 'Bearer $_apiKey', 'Prefer': 'wait'},
      ),
    );

    final output = response.data?['output'];
    final audioUrl = _extractAudioUrl(output);
    final bytes = audioUrl == null
        ? _extractInlineAudioBytes(output)
        : await _downloadAudio(audioUrl);
    if (bytes.isEmpty) return null;

    final tempDir = await getTemporaryDirectory();
    final extension = audioUrl == null ? 'wav' : _extensionForUrl(audioUrl);
    final path =
        '${tempDir.path}/gemini_reply_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<List<int>> _downloadAudio(String url) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? const <int>[];
  }

  static String? _extractAudioUrl(dynamic output) {
    if (output is String && output.startsWith('http')) return output;
    if (output is List) {
      for (final item in output) {
        if (item is String && item.startsWith('http')) return item;
        if (item is Map) {
          final value = item['audio'] ?? item['url'] ?? item['output'];
          if (value is String && value.startsWith('http')) return value;
        }
      }
    }
    if (output is Map) {
      final value = output['audio'] ?? output['url'] ?? output['output'];
      if (value is String && value.startsWith('http')) return value;
    }
    return null;
  }

  static List<int> _extractInlineAudioBytes(dynamic output) {
    String? encoded;
    if (output is String && !output.startsWith('http')) {
      encoded = output;
    } else if (output is List) {
      encoded = output.whereType<String>().firstWhere(
        (item) => !item.startsWith('http'),
        orElse: () => '',
      );
    } else if (output is Map) {
      final value = output['audio'] ?? output['data'];
      if (value is String) encoded = value;
    }

    if ((encoded ?? '').isEmpty) return const <int>[];
    final payload = encoded!.contains(',') ? encoded.split(',').last : encoded;
    return base64Decode(payload);
  }

  static String _extensionForUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.mp3')) return 'mp3';
    if (path.endsWith('.ogg')) return 'ogg';
    if (path.endsWith('.webm')) return 'webm';
    if (path.endsWith('.m4a')) return 'm4a';
    return 'wav';
  }
}
