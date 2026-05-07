import 'dart:convert';
import 'package:dio/dio.dart';

class AiHealthAssessmentResponse {
  final int healthScore;
  final String peerComparison;
  final List<Map<String, dynamic>> risks;
  final List<Map<String, dynamic>> matchedPackages;
  final List<Map<String, dynamic>> unmatchedPackages;
  final List<Map<String, dynamic>> testRecommendations;

  const AiHealthAssessmentResponse({
    required this.healthScore,
    required this.peerComparison,
    required this.risks,
    required this.matchedPackages,
    required this.unmatchedPackages,
    required this.testRecommendations,
  });

  factory AiHealthAssessmentResponse.fromJson(Map<String, dynamic> json) {
    return AiHealthAssessmentResponse(
      healthScore: (json['healthScore'] as num?)?.toInt() ?? 50,
      peerComparison: json['peerComparison'] as String? ?? '',
      risks: _toList(json['risks']),
      matchedPackages: _toList(json['matchedPackages']),
      unmatchedPackages: _toList(json['unmatchedPackages']),
      testRecommendations: _toList(json['testRecommendations']),
    );
  }

  static List<Map<String, dynamic>> _toList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      if (e is String) return {'name': e, 'reason': e};
      return <String, dynamic>{};
    }).toList();
  }
}

class AiCheckupService {
  final String apiBaseUrl;
  final String authToken;

  const AiCheckupService({required this.apiBaseUrl, required this.authToken});

  Future<Map<String, dynamic>> getNextQuestion({
    required List<Map<String, dynamic>> messages,
    String? step,
    Map<String, dynamic>? patientInfo,
    String? language,
  }) async {
    final dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    ));

    final response = await dio.post<Map<String, dynamic>>(
      '/patient/ai-checkup',
      data: {
        'messages': messages,
        'step': step ?? 'questions',
        'patientInfo': patientInfo,
        'language': language ?? 'en',
      },
    );

    final reply = response.data!['reply'];
    
    // Client-side cleaning/parsing fallback
    if (reply is String && reply.contains('{') && reply.contains('}')) {
      try {
        final start = reply.indexOf('{');
        final end = reply.lastIndexOf('}');
        final cleaned = reply.substring(start, end + 1).replaceAll('\\{', '{').replaceAll('\\}', '}');
        final parsed = Map<String, dynamic>.from(jsonDecode(cleaned));
        if (parsed.containsKey('question')) {
          response.data!['reply'] = parsed;
        }
      } catch (_) {}
    }

    return response.data!;
  }

  Future<AiHealthAssessmentResponse> analyzeHealth({
    required Map<String, dynamic> answers,
    String? language,
  }) async {
    final dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));

    final response = await dio.post<Map<String, dynamic>>(
      '/patient/ai-health-assessment',
      data: {
        'answers': answers,
        'language': language ?? 'en',
      },
    );

    if (response.statusCode != 200 || response.data == null) {
      throw Exception('AI service error: ${response.statusCode}');
    }

    return AiHealthAssessmentResponse.fromJson(response.data!);
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
    ));

    final response = await dio.get<List>('/patient/ai-history');

    if (response.statusCode != 200 || response.data == null) {
      throw Exception('Failed to fetch AI history: ${response.statusCode}');
    }

    return response.data!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
