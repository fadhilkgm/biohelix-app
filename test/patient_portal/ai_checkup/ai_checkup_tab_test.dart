import 'dart:convert';

import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/ai_checkup/screens/ai_checkup_tab.dart';
import 'package:biohelix_app/patient_portal/ai_checkup/services/ai_checkup_service.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _FakeAiCheckupService service;

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    GoogleFonts.config.allowRuntimeFetching = false;
    service = _FakeAiCheckupService();
  });

  testWidgets('completes a new AI Health Checkup smoothly', (tester) async {
    await tester.pumpWidget(_buildSubject(service));
    await tester.pumpAndSettle();

    expect(find.text('Health Checkup History'), findsOneWidget);
    expect(find.text('No previous assessments found'), findsOneWidget);

    await tester.tap(find.text('Start New Assessment'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Assessment'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Amina Patient');
    await tester.enterText(find.byType(TextField).at(1), '34');
    await tester.enterText(find.byType(TextField).at(2), '62');
    await tester.enterText(find.byType(TextField).at(3), '5ft 5in');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Question 1'), findsOneWidget);
    expect(find.text('How often do you feel tired?'), findsOneWidget);

    await tester.tap(find.text('Often'));
    await tester.pumpAndSettle();

    expect(find.text('Question 2'), findsOneWidget);
    expect(find.text('Do you sleep well?'), findsOneWidget);

    await tester.ensureVisible(find.text('Skip & Analyze Now'));
    await tester.tap(find.text('Skip & Analyze Now'));
    await tester.pumpAndSettle();

    expect(find.text('Your Health Score'), findsOneWidget);
    expect(find.text('82%'), findsOneWidget);
    expect(find.text('Suggested Issues'), findsOneWidget);
    expect(find.text('Fatigue risk'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Recommended Packages'),
      200,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Recommended Packages'), findsOneWidget);
    expect(find.text('Wellness Package'), findsOneWidget);
    expect(service.analyzeCallCount, 1);
    expect(service.lastAnalyzeLanguage, 'en');
    expect(service.lastAnswers['name'], 'Amina Patient');
    expect(service.lastAnswers['age'], 34);
    expect(service.lastAnswers['weight'], '62');
    expect(service.lastAnswers['height'], '5ft 5in');
    expect(service.lastAnswers['q1']['answer'], 'Often');
  });

  testWidgets('opens a previous assessment from history without re-analyzing', (
    tester,
  ) async {
    service.history = [
      {
        'createdAt': '2026-05-08 10:15:00',
        'healthScore': 64,
        'assessmentJson': jsonEncode({
          'healthScore': 64,
          'peerComparison': 'Similar to your peer group.',
          'risks': [
            {'name': 'Sleep imbalance', 'reason': 'Late sleep schedule.'},
          ],
          'matchedPackages': const [],
          'unmatchedPackages': const [],
          'testRecommendations': const [],
        }),
      },
    ];

    await tester.pumpWidget(_buildSubject(service));
    await tester.pumpAndSettle();

    expect(find.text('Health Score: 64%'), findsOneWidget);

    await tester.tap(find.text('Health Score: 64%'));
    await tester.pumpAndSettle();

    expect(find.text('Your Health Score'), findsOneWidget);
    expect(find.text('64%'), findsOneWidget);
    expect(find.text('Sleep imbalance'), findsOneWidget);
    expect(service.analyzeCallCount, 0);
  });
}

Widget _buildSubject(_FakeAiCheckupService service) {
  final config = AppConfig(
    appName: 'BioHelix Test',
    apiBaseUrl: 'https://example.test/api',
    healthEndpoint: '/health',
    showDevOtp: false,
  );
  final apiClient = ApiClient(config: config);
  final repository = PatientRepository(apiClient: apiClient);
  final sessionProvider = SessionProvider(
    authStorage: AuthStorage(),
    apiClient: apiClient,
    patientRepository: repository,
  );

  return MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: config),
      ChangeNotifierProvider<SessionProvider>.value(value: sessionProvider),
      ChangeNotifierProvider<PatientPortalProvider>(
        create: (_) => PatientPortalProvider(
          repository: repository,
          sessionProvider: sessionProvider,
        ),
      ),
    ],
    child: MaterialApp(home: AiCheckupTab(serviceFactory: (_) => service)),
  );
}

class _FakeAiCheckupService extends AiCheckupService {
  _FakeAiCheckupService() : super(apiBaseUrl: '', authToken: '');

  List<Map<String, dynamic>> history = const [];
  int _questionIndex = 0;
  int analyzeCallCount = 0;
  String? lastAnalyzeLanguage;
  Map<String, dynamic> lastAnswers = {};

  @override
  Future<List<Map<String, dynamic>>> getHistory() async {
    return history;
  }

  @override
  Future<Map<String, dynamic>> getNextQuestion({
    required List<Map<String, dynamic>> messages,
    String? step,
    Map<String, dynamic>? patientInfo,
    String? language,
  }) async {
    final questions = [
      {
        'question': 'How often do you feel tired?',
        'options': ['Rarely', 'Sometimes', 'Often'],
      },
      {
        'question': 'Do you sleep well?',
        'options': ['Yes', 'No'],
      },
    ];
    return {'reply': questions[_questionIndex++]};
  }

  @override
  Future<AiHealthAssessmentResponse> analyzeHealth({
    required Map<String, dynamic> answers,
    String? language,
  }) async {
    analyzeCallCount++;
    lastAnalyzeLanguage = language;
    lastAnswers = Map<String, dynamic>.from(answers);

    return const AiHealthAssessmentResponse(
      healthScore: 82,
      peerComparison: 'Better than similar profiles.',
      risks: [
        {
          'name': 'Fatigue risk',
          'reason': 'You reported frequent tiredness.',
          'precaution': 'Prioritize sleep and hydration.',
        },
      ],
      matchedPackages: [
        {
          'id': 7,
          'name': 'Wellness Package',
          'basePrice': 1200,
          'discountedPrice': 999,
          'reason': 'Good baseline screening.',
        },
      ],
      unmatchedPackages: [],
      testRecommendations: [
        {'name': 'CBC', 'reason': 'Screens for anemia.'},
      ],
    );
  }
}
