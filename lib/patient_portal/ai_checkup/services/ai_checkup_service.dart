import 'package:dio/dio.dart';

/// A single selectable answer for an assessment question.
class AssessmentOption {
  const AssessmentOption({required this.key, required this.text});

  final String key;
  final String text;

  factory AssessmentOption.fromJson(Map<String, dynamic> json) {
    return AssessmentOption(
      key: json['key']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}

/// A single multiple-choice assessment question.
class AssessmentQuestion {
  const AssessmentQuestion({
    required this.id,
    required this.question,
    required this.category,
    required this.options,
  });

  final int id;
  final String question;
  final String category;
  final List<AssessmentOption> options;

  factory AssessmentQuestion.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'] as List<dynamic>? ?? const [];
    return AssessmentQuestion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: json['question']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      options: optionsRaw
          .map((item) => AssessmentOption.fromJson(_map(item)))
          .toList(),
    );
  }
}

/// A health-assessment session returned by `start`/`show`.
class AssessmentSession {
  const AssessmentSession({
    required this.sessionToken,
    required this.status,
    required this.isPersonalised,
    required this.questions,
    this.expiresAt,
  });

  final String sessionToken;

  /// `questions_pending`, `questions_ready`, `answers_submitted`, `evaluated`.
  final String status;
  final bool isPersonalised;
  final String? expiresAt;
  final List<AssessmentQuestion> questions;

  factory AssessmentSession.fromJson(Map<String, dynamic> json) {
    final questionsRaw = json['questions'] as List<dynamic>? ?? const [];
    return AssessmentSession(
      sessionToken: json['session_token']?.toString() ?? '',
      status: json['status']?.toString() ?? 'questions_pending',
      isPersonalised: json['is_personalised'] as bool? ?? false,
      expiresAt: json['expires_at']?.toString(),
      questions: questionsRaw
          .map((item) => AssessmentQuestion.fromJson(_map(item)))
          .toList(),
    );
  }
}

/// A recommended individual lab test inside an assessment result.
class AssessmentRecommendedTest {
  const AssessmentRecommendedTest({
    required this.id,
    required this.testName,
    this.category,
    this.price,
  });

  final int id;
  final String testName;
  final String? category;
  final String? price;

  factory AssessmentRecommendedTest.fromJson(Map<String, dynamic> json) {
    return AssessmentRecommendedTest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      testName: json['test_name']?.toString() ?? '',
      category: json['category']?.toString(),
      price: json['price']?.toString(),
    );
  }
}

/// An existing lab package recommended by the assessment.
class AssessmentRecommendedPackage {
  const AssessmentRecommendedPackage({
    required this.id,
    required this.packageName,
    this.price,
    this.tests = const [],
  });

  final int id;
  final String packageName;
  final String? price;
  final List<AssessmentRecommendedTest> tests;

  factory AssessmentRecommendedPackage.fromJson(Map<String, dynamic> json) {
    final testsRaw = json['tests'] as List<dynamic>? ?? const [];
    return AssessmentRecommendedPackage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      packageName: json['package_name']?.toString() ?? 'Package',
      price: json['price']?.toString(),
      tests: testsRaw
          .map((item) => AssessmentRecommendedTest.fromJson(_map(item)))
          .toList(),
    );
  }
}

/// A tailored panel built from tests not covered by an existing package.
class AssessmentCustomPackage {
  const AssessmentCustomPackage({
    required this.name,
    this.reason,
    this.price,
    this.tests = const [],
  });

  final String name;
  final String? reason;
  final String? price;
  final List<AssessmentRecommendedTest> tests;

  factory AssessmentCustomPackage.fromJson(Map<String, dynamic> json) {
    final testsRaw = json['tests'] as List<dynamic>? ?? const [];
    return AssessmentCustomPackage(
      name: json['name']?.toString() ?? 'Custom Package',
      reason: json['reason']?.toString(),
      price: json['price']?.toString(),
      tests: testsRaw
          .map((item) => AssessmentRecommendedTest.fromJson(_map(item)))
          .toList(),
    );
  }
}

/// The evaluated assessment outcome.
class AssessmentResults {
  const AssessmentResults({
    required this.riskLevel,
    required this.summary,
    required this.insights,
    required this.recommendedPackages,
    required this.recommendedTests,
    this.customPackage,
  });

  /// `low`, `moderate`, or `high`.
  final String riskLevel;
  final String summary;
  final List<String> insights;
  final List<AssessmentRecommendedPackage> recommendedPackages;
  final List<AssessmentRecommendedTest> recommendedTests;
  final AssessmentCustomPackage? customPackage;

  bool get isEmpty =>
      summary.trim().isEmpty &&
      insights.isEmpty &&
      recommendedPackages.isEmpty &&
      recommendedTests.isEmpty &&
      customPackage == null;

  factory AssessmentResults.fromJson(Map<String, dynamic> json) {
    final insightsRaw = json['insights'] as List<dynamic>? ?? const [];
    final packagesRaw =
        json['recommended_packages'] as List<dynamic>? ?? const [];
    final testsRaw = json['recommended_tests'] as List<dynamic>? ?? const [];
    final custom = json['custom_package'];
    return AssessmentResults(
      riskLevel: json['risk_level']?.toString() ?? 'low',
      summary: json['summary']?.toString() ?? '',
      insights: insightsRaw
          .map((item) => item?.toString() ?? '')
          .where((value) => value.trim().isNotEmpty)
          .toList(),
      recommendedPackages: packagesRaw
          .map((item) => AssessmentRecommendedPackage.fromJson(_map(item)))
          .toList(),
      recommendedTests: testsRaw
          .map((item) => AssessmentRecommendedTest.fromJson(_map(item)))
          .toList(),
      customPackage: custom is Map
          ? AssessmentCustomPackage.fromJson(_map(custom))
          : null,
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

/// Client for the documented 3-step AI health assessment flow:
/// `start` -> `answers` -> `results`.
///
/// Authentication is optional; supplying a Bearer token personalises the
/// generated questions based on the patient's latest health profile.
class AiCheckupService {
  const AiCheckupService({required this.apiBaseUrl, required this.authToken});

  final String apiBaseUrl;
  final String authToken;

  Dio _dio() {
    return Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
        },
      ),
    );
  }

  static String _dioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      return data['error']?.toString() ??
          data['message']?.toString() ??
          error.message ??
          'Request failed';
    }
    return data?.toString() ?? error.message ?? 'Request failed';
  }

  /// Starts a new assessment session and returns its (personalised) questions.
  Future<AssessmentSession> startAssessment() async {
    try {
      final response = await _dio().post<Map<String, dynamic>>(
        '/health-assessment/start',
      );
      return AssessmentSession.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw Exception(_dioMessage(error));
    }
  }

  /// Fetches the current state of an existing session.
  Future<AssessmentSession> showAssessment(String sessionToken) async {
    try {
      final response = await _dio().get<Map<String, dynamic>>(
        '/health-assessment/$sessionToken',
      );
      return AssessmentSession.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw Exception(_dioMessage(error));
    }
  }

  /// Submits answers (`{questionId: optionKey}`) and returns the evaluation.
  Future<AssessmentResults> submitAnswers({
    required String sessionToken,
    required Map<String, String> answers,
  }) async {
    try {
      final response = await _dio().post<Map<String, dynamic>>(
        '/health-assessment/$sessionToken/answers',
        data: {'answers': answers},
      );
      return AssessmentResults.fromJson(_map(response.data?['results']));
    } on DioException catch (error) {
      throw Exception(_dioMessage(error));
    }
  }

  /// Fetches the results for an already-evaluated session.
  Future<AssessmentResults> getResults(String sessionToken) async {
    try {
      final response = await _dio().get<Map<String, dynamic>>(
        '/health-assessment/$sessionToken/results',
      );
      return AssessmentResults.fromJson(_map(response.data?['results']));
    } on DioException catch (error) {
      throw Exception(_dioMessage(error));
    }
  }

  /// Optionally associates contact details with an anonymous session.
  Future<void> saveContact({
    required String sessionToken,
    required String name,
    required String phone,
    String? email,
  }) async {
    try {
      await _dio().post<Map<String, dynamic>>(
        '/health-assessment/$sessionToken/save-contact',
        data: {
          'name': name,
          'phone': phone,
          if ((email ?? '').trim().isNotEmpty) 'email': email!.trim(),
        },
      );
    } on DioException catch (error) {
      throw Exception(_dioMessage(error));
    }
  }
}
