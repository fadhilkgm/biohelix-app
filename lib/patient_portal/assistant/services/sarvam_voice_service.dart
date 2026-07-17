import 'dart:io';

import 'package:dio/dio.dart';

class SarvamVoiceTranscript {
  const SarvamVoiceTranscript({required this.text, required this.languageCode});

  final String text;
  final String languageCode;
}

class SarvamVoiceService {
  SarvamVoiceService({
    required String apiKey,
    String baseUrl = 'https://api.sarvam.ai',
    String sttModel = 'saaras:v2.5',
    Dio? dio,
  }) : _apiKey = apiKey.trim(),
       _sttModel = sttModel.trim().isEmpty ? 'saaras:v2.5' : sttModel.trim(),
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

  factory SarvamVoiceService.fromEnvironment() {
    const apiKey = String.fromEnvironment('SARVAM_API_KEY');
    const baseUrl = String.fromEnvironment(
      'SARVAM_BASE_URL',
      defaultValue: 'https://api.sarvam.ai',
    );
    const sttModel = String.fromEnvironment(
      'SARVAM_STT_MODEL',
      defaultValue: 'saaras:v2.5',
    );
    return SarvamVoiceService(
      apiKey: apiKey,
      baseUrl: baseUrl,
      sttModel: sttModel,
    );
  }

  final Dio _dio;
  String _apiKey;
  String _sttModel;

  bool get isConfigured => _apiKey.isNotEmpty;

  void configure({required String apiKey, String? baseUrl, String? sttModel}) {
    final nextKey = apiKey.trim();
    if (nextKey.isNotEmpty) {
      _apiKey = nextKey;
    }
    final nextBaseUrl = (baseUrl ?? '').trim();
    if (nextBaseUrl.isNotEmpty) {
      _dio.options.baseUrl = nextBaseUrl;
    }
    final nextSttModel = (sttModel ?? '').trim();
    if (nextSttModel.isNotEmpty) {
      _sttModel = nextSttModel;
    }
  }

  Future<SarvamVoiceTranscript?> transcribeRecording({
    required String audioFilePath,
    required String language,
  }) async {
    if (!isConfigured) return null;

    final file = File(audioFilePath);
    if (!await file.exists()) return null;

    final languageCode = language == 'ml' ? 'ml-IN' : 'en-IN';
    final response = await _dio.post<Map<String, dynamic>>(
      '/speech-to-text',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.uri.pathSegments.last,
        ),
        'model': _sttModel,
        'language_code': languageCode,
        'with_timestamps': false,
      }),
      options: Options(headers: {'api-subscription-key': _apiKey}),
    );

    final body = response.data ?? const <String, dynamic>{};
    final transcript = _firstString(body, const [
      'transcript',
      'text',
      'transcription',
    ]);
    if (transcript.trim().isEmpty) return null;

    final detected = _firstString(body, const [
      'language_code',
      'detected_language_code',
      'language',
    ]);

    return SarvamVoiceTranscript(
      text: transcript.trim(),
      languageCode: _normalizeLanguage(detected, fallback: language),
    );
  }

  static String _firstString(Map<String, dynamic> body, List<String> keys) {
    for (final key in keys) {
      final value = body[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static String _normalizeLanguage(String value, {required String fallback}) {
    final lowered = value.toLowerCase();
    if (lowered.startsWith('ml')) return 'ml';
    if (lowered.startsWith('en')) return 'en';
    return fallback == 'ml' ? 'ml' : 'en';
  }
}
