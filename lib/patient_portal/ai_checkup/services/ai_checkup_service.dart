import 'package:dio/dio.dart';

abstract final class AiCheckupContract {
  static const intents = {
    'advice',
    'doctor_booking',
    'test_booking',
    'custom_package',
  };
  static const urgencies = {'routine', 'soon', 'urgent', 'emergency'};
  static const states = {
    'collecting',
    'recommendation_ready',
    'awaiting_confirmation',
    'completed',
    'cancelled',
  };

  static String intent(dynamic value, {dynamic legacyOutcome}) {
    final candidate = value?.toString();
    if (intents.contains(candidate)) return candidate!;
    return switch (legacyOutcome?.toString()) {
      'consultation_only' ||
      'test_package_and_consultation' => 'doctor_booking',
      'test_package_only' => 'test_booking',
      _ => 'advice',
    };
  }

  static String urgency(dynamic value) {
    final candidate = value?.toString();
    return urgencies.contains(candidate) ? candidate! : 'routine';
  }

  static String state(dynamic value, {required bool completed}) {
    final candidate = value?.toString();
    if (states.contains(candidate)) return candidate!;
    return completed ? 'recommendation_ready' : 'collecting';
  }
}

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
    this.reason,
  });

  final int id;
  final String testName;
  final String? category;
  final String? price;
  final String? reason;

  factory AssessmentRecommendedTest.fromJson(Map<String, dynamic> json) {
    return AssessmentRecommendedTest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      testName: json['test_name']?.toString() ?? '',
      category: json['category']?.toString(),
      price: json['price']?.toString(),
      reason: json['reason']?.toString(),
    );
  }
}

class AssessmentRecommendedDoctor {
  const AssessmentRecommendedDoctor({
    required this.id,
    required this.name,
    this.specialization,
    this.consultationFee,
    this.reason,
  });

  final int id;
  final String name;
  final String? specialization;
  final String? consultationFee;
  final String? reason;

  factory AssessmentRecommendedDoctor.fromJson(Map<String, dynamic> json) {
    return AssessmentRecommendedDoctor(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Doctor',
      specialization: json['specialization']?.toString(),
      consultationFee: json['consultation_fee']?.toString(),
      reason: json['reason']?.toString(),
    );
  }
}

/// An existing lab package recommended by the assessment.
class AssessmentRecommendedPackage {
  const AssessmentRecommendedPackage({
    required this.id,
    required this.packageName,
    this.price,
    this.discountedPrice,
    this.description,
    this.imageUrl,
    this.reason,
    this.testsCount = 0,
    this.tests = const [],
  });

  final int id;
  final String packageName;
  final String? price;
  final String? discountedPrice;
  final String? description;
  final String? imageUrl;
  final String? reason;
  final int testsCount;
  final List<AssessmentRecommendedTest> tests;

  factory AssessmentRecommendedPackage.fromJson(Map<String, dynamic> json) {
    final testsRaw = json['tests'] as List<dynamic>? ?? const [];
    return AssessmentRecommendedPackage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      packageName: json['package_name']?.toString() ?? 'Package',
      price: json['price']?.toString(),
      discountedPrice: json['discounted_price']?.toString(),
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      reason: json['reason']?.toString(),
      testsCount:
          (json['tests_count'] as num?)?.toInt() ??
          (json['test_count'] as num?)?.toInt() ??
          testsRaw.length,
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
    this.recommendedDoctors = const [],
    this.customPackage,
    this.intent = 'advice',
    this.state = 'recommendation_ready',
    this.outcome = 'advice_only',
    this.urgency = 'routine',
  });

  /// `low`, `moderate`, or `high`.
  final String riskLevel;
  final String summary;
  final List<String> insights;
  final List<AssessmentRecommendedPackage> recommendedPackages;
  final List<AssessmentRecommendedTest> recommendedTests;
  final List<AssessmentRecommendedDoctor> recommendedDoctors;
  final AssessmentCustomPackage? customPackage;
  final String intent;
  final String state;
  final String outcome;
  final String urgency;

  bool get isEmpty =>
      summary.trim().isEmpty &&
      insights.isEmpty &&
      recommendedPackages.isEmpty &&
      recommendedTests.isEmpty &&
      recommendedDoctors.isEmpty &&
      customPackage == null;

  factory AssessmentResults.fromJson(Map<String, dynamic> json) {
    final insightsRaw = json['insights'] as List<dynamic>? ?? const [];
    final packagesRaw =
        json['recommended_packages'] as List<dynamic>? ?? const [];
    final testsRaw = json['recommended_tests'] as List<dynamic>? ?? const [];
    final doctorsRaw =
        json['recommended_doctors'] as List<dynamic>? ?? const [];
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
      recommendedDoctors: doctorsRaw
          .map((item) => AssessmentRecommendedDoctor.fromJson(_map(item)))
          .toList(),
      customPackage: custom is Map
          ? AssessmentCustomPackage.fromJson(_map(custom))
          : null,
      intent: AiCheckupContract.intent(
        json['intent'],
        legacyOutcome: json['outcome'],
      ),
      state: AiCheckupContract.state(json['state'], completed: true),
      outcome: json['outcome']?.toString() ?? 'advice_only',
      urgency: AiCheckupContract.urgency(json['urgency']),
    );
  }
}

/// A summary row for a previously completed assessment, shown in History.
class AssessmentHistoryItem {
  const AssessmentHistoryItem({
    required this.sessionToken,
    required this.language,
    required this.riskLevel,
    required this.summary,
    this.intent = 'advice',
    this.state = 'recommendation_ready',
    this.outcome = 'advice_only',
    this.urgency = 'routine',
    this.createdAt,
  });

  final String sessionToken;
  final String language;
  final String riskLevel;
  final String summary;
  final String intent;
  final String state;
  final String outcome;
  final String urgency;
  final DateTime? createdAt;

  factory AssessmentHistoryItem.fromJson(Map<String, dynamic> json) {
    return AssessmentHistoryItem(
      sessionToken: json['session_token']?.toString() ?? '',
      language: json['language']?.toString() ?? 'en',
      riskLevel: json['risk_level']?.toString() ?? 'low',
      summary: json['summary']?.toString() ?? '',
      intent: AiCheckupContract.intent(
        json['intent'],
        legacyOutcome: json['outcome'],
      ),
      state: AiCheckupContract.state(json['state'], completed: true),
      outcome: json['outcome']?.toString() ?? 'advice_only',
      urgency: AiCheckupContract.urgency(json['urgency']),
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

class VoiceAssessmentSession {
  const VoiceAssessmentSession({
    required this.sessionToken,
    required this.initialInstructions,
    required this.maxTurns,
    required this.maxSeconds,
    this.state = 'collecting',
  });

  final String sessionToken;
  final String initialInstructions;
  final int maxTurns;
  final int maxSeconds;
  final String state;

  factory VoiceAssessmentSession.fromJson(Map<String, dynamic> json) {
    return VoiceAssessmentSession(
      sessionToken: json['session_token']?.toString() ?? '',
      initialInstructions: json['initial_instructions']?.toString() ?? '',
      maxTurns: (json['max_turns'] as num?)?.toInt() ?? 10,
      maxSeconds: (json['max_seconds'] as num?)?.toInt() ?? 300,
      state: AiCheckupContract.state(json['state'], completed: false),
    );
  }
}

class VoiceAssessmentTurnDecision {
  const VoiceAssessmentTurnDecision({
    required this.acceptedTranscript,
    required this.spokenResponse,
    required this.responseInstructions,
    required this.completed,
    required this.turnCount,
    required this.maxTurns,
    this.state = 'collecting',
    this.result,
  });

  final String acceptedTranscript;
  final String spokenResponse;
  final String responseInstructions;
  final bool completed;
  final int turnCount;
  final int maxTurns;
  final String state;
  final AssessmentResults? result;

  factory VoiceAssessmentTurnDecision.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    return VoiceAssessmentTurnDecision(
      acceptedTranscript: json['accepted_transcript']?.toString() ?? '',
      spokenResponse: json['spoken_response']?.toString() ?? '',
      responseInstructions: json['response_instructions']?.toString() ?? '',
      completed: json['completed'] as bool? ?? false,
      turnCount: (json['turn_count'] as num?)?.toInt() ?? 0,
      maxTurns: (json['max_turns'] as num?)?.toInt() ?? 10,
      state: AiCheckupContract.state(
        json['state'],
        completed: json['completed'] as bool? ?? false,
      ),
      result: result is Map
          ? AssessmentResults.fromJson(Map<String, dynamic>.from(result))
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

  Future<VoiceAssessmentSession> startVoiceAssessment({
    String language = 'en',
  }) async {
    try {
      final response = await _dio().post<Map<String, dynamic>>(
        '/health-assessment/voice/start',
        data: {'language': language},
      );
      return VoiceAssessmentSession.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw Exception(_dioMessage(error));
    }
  }

  Future<VoiceAssessmentTurnDecision> submitVoiceTurn({
    required String sessionToken,
    required String transcript,
  }) async {
    try {
      final response = await _dio().post<Map<String, dynamic>>(
        '/health-assessment/voice/$sessionToken/turn',
        data: {'transcript': transcript},
      );
      return VoiceAssessmentTurnDecision.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw Exception(_dioMessage(error));
    }
  }

  Future<void> recordVoiceResponse({
    required String sessionToken,
    required String transcript,
    required String response,
  }) async {
    try {
      await _dio().post<Map<String, dynamic>>(
        '/health-assessment/voice/$sessionToken/response',
        data: {'transcript': transcript, 'response': response},
      );
    } on DioException catch (error) {
      throw Exception(_dioMessage(error));
    }
  }

  Future<void> cancelVoiceAssessment(String sessionToken) async {
    try {
      await _dio().post<Map<String, dynamic>>(
        '/health-assessment/voice/$sessionToken/cancel',
      );
    } on DioException catch (error) {
      throw Exception(_dioMessage(error));
    }
  }

  /// Starts a new assessment session and returns its (personalised) questions.
  ///
  /// [language] (`en` or `ml`) controls the language of the generated
  /// questions and the final evaluation.
  Future<AssessmentSession> startAssessment({String language = 'en'}) async {
    try {
      final response = await _dio().post<Map<String, dynamic>>(
        '/health-assessment/start',
        data: {'language': language},
      );
      return AssessmentSession.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw Exception(_dioMessage(error));
    }
  }

  /// Lists the authenticated patient's past evaluated assessments.
  Future<List<AssessmentHistoryItem>> listHistory() async {
    try {
      final response = await _dio().get<Map<String, dynamic>>(
        '/health-assessment/history',
      );
      final raw = response.data?['history'] as List<dynamic>? ?? const [];
      return raw
          .map((item) => AssessmentHistoryItem.fromJson(_map(item)))
          .toList();
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
