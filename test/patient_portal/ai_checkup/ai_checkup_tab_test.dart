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

  testWidgets('completes the documented health-assessment flow', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject(service));
    await tester.pumpAndSettle();

    // Language selection.
    expect(find.text('Choose Language'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Welcome -> start session (fetches questions).
    expect(find.text('AI Health Checkup'), findsWidgets);
    await tester.tap(find.text('Start Assessment'));
    await tester.pumpAndSettle();

    expect(service.startCallCount, 1);

    // Question 1.
    expect(find.text('Question 1/2'), findsOneWidget);
    expect(find.text('How severe has your fatigue been?'), findsOneWidget);
    await tester.tap(find.text('Frequent fatigue'));
    await tester.pumpAndSettle();

    // Question 2 (last) -> submitting answers triggers evaluation.
    expect(find.text('Question 2/2'), findsOneWidget);
    expect(find.text('Do you sleep well?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    // Results.
    expect(service.submitCallCount, 1);
    expect(service.lastAnswers['1'], 'C');
    expect(service.lastAnswers['2'], 'B');

    expect(find.text('Moderate Risk'), findsOneWidget);
    expect(
      find.textContaining('metabolic health'),
      findsOneWidget,
    );
    expect(find.text('Key Insights'), findsOneWidget);
    expect(find.text('Monitor your blood glucose regularly.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Recommended Packages'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Comprehensive Health Package'), findsOneWidget);
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

  int startCallCount = 0;
  int submitCallCount = 0;
  Map<String, String> lastAnswers = const {};

  @override
  Future<AssessmentSession> startAssessment() async {
    startCallCount++;
    return AssessmentSession.fromJson(const {
      'session_token': 'test-token',
      'status': 'questions_ready',
      'is_personalised': true,
      'questions': [
        {
          'id': 1,
          'question': 'How severe has your fatigue been?',
          'category': 'symptoms',
          'options': [
            {'key': 'A', 'text': 'Mild'},
            {'key': 'B', 'text': 'Occasional'},
            {'key': 'C', 'text': 'Frequent fatigue'},
            {'key': 'D', 'text': 'Severe'},
          ],
        },
        {
          'id': 2,
          'question': 'Do you sleep well?',
          'category': 'lifestyle',
          'options': [
            {'key': 'A', 'text': 'Yes'},
            {'key': 'B', 'text': 'No'},
          ],
        },
      ],
    });
  }

  @override
  Future<AssessmentResults> submitAnswers({
    required String sessionToken,
    required Map<String, String> answers,
  }) async {
    submitCallCount++;
    lastAnswers = Map<String, String>.from(answers);
    return AssessmentResults.fromJson(const {
      'risk_level': 'moderate',
      'summary': 'The main concerns are diabetes/metabolic health.',
      'insights': ['Monitor your blood glucose regularly.'],
      'recommended_packages': [
        {
          'id': 2,
          'package_name': 'Comprehensive Health Package',
          'price': '2000.00',
          'tests': [
            {'id': 5, 'test_name': 'Complete Blood Count', 'price': '250.00'},
          ],
        },
      ],
      'recommended_tests': [
        {'id': 1, 'test_name': 'ALBUMIN', 'category': 'Biochemistry', 'price': '20.00'},
      ],
      'custom_package': null,
    });
  }
}
