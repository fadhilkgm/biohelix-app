import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/ai_checkup/screens/ai_checkup_tab.dart';
import 'package:biohelix_app/patient_portal/ai_checkup/services/ai_checkup_service.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/inworld_signaling_api.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/live_voice_controller.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/live_voice_state.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _FakeAiCheckupService service;
  late _FakeLiveVoiceController voice;

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    service = _FakeAiCheckupService();
  });

  testWidgets('requires explicit consent before starting voice', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSubject(service, (onTurnCompleted, onTurnContext) {
        voice = _FakeLiveVoiceController(
          onTurnCompleted: onTurnCompleted,
          onTurnContext: onTurnContext,
        );
        return voice;
      }, consentInitiallyGranted: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Before your private AI Checkup'), findsOneWidget);
    expect(service.startVoiceCallCount, 0);
    expect(voice.startCallCount, 0);

    await tester.tap(find.text('I agree — start checkup'));
    await tester.pumpAndSettle();

    expect(service.startVoiceCallCount, 1);
    expect(service.lastConsent, isTrue);
    expect(voice.startCallCount, 1);
  });

  testWidgets('starts voice immediately and completes with controlled outcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSubject(service, (onTurnCompleted, onTurnContext) {
        voice = _FakeLiveVoiceController(
          onTurnCompleted: onTurnCompleted,
          onTurnContext: onTurnContext,
        );
        return voice;
      }),
    );
    await tester.pumpAndSettle();

    expect(service.startVoiceCallCount, 1);
    expect(voice.startCallCount, 1);
    expect(find.text('Private AI health checkup'), findsOneWidget);
    expect(find.textContaining('Are you feeling unwell today'), findsOneWidget);

    service.nextDecision = const VoiceAssessmentTurnDecision(
      acceptedTranscript: 'I have been tired for two weeks.',
      spokenResponse: 'How have your sleep and energy been?',
      responseInstructions: 'Ask about sleep and energy.',
      completed: false,
      turnCount: 1,
      maxTurns: 10,
    );
    await voice.simulateTurn(
      'I have been tired for two weeks.',
      'How have your sleep and energy been?',
    );
    await tester.pumpAndSettle();

    expect(find.text('I have been tired for two weeks.'), findsOneWidget);
    expect(find.text('How have your sleep and energy been?'), findsOneWidget);

    service.nextDecision = VoiceAssessmentTurnDecision(
      acceptedTranscript: 'I sleep five hours and still feel tired.',
      spokenResponse:
          'A consultation is the most suitable next step. Your result is saved.',
      responseInstructions: 'Explain the consultation outcome.',
      completed: true,
      turnCount: 2,
      maxTurns: 10,
      result: AssessmentResults.fromJson(const {
        'outcome': 'consultation_only',
        'urgency': 'soon',
        'risk_level': 'moderate',
        'summary': 'Persistent fatigue should be reviewed by a clinician.',
        'insights': ['Arrange a clinical review if fatigue continues.'],
      }),
    );
    await voice.simulateTurn(
      'I sleep five hours and still feel tired.',
      'A consultation is the most suitable next step. Your result is saved.',
    );
    await tester.pumpAndSettle();

    expect(find.text('Hospital support recommended'), findsOneWidget);
    expect(
      find.text('Persistent fatigue should be reviewed by a clinician.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('No test or consultation has been booked'),
      findsOneWidget,
    );
    expect(service.recordedResponses, 2);
    expect(voice.stopCallCount, 1);
  });

  testWidgets('keeps the preparation screen until the first voice starts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSubject(service, (onTurnCompleted, onTurnContext) {
        voice = _FakeLiveVoiceController(
          onTurnCompleted: onTurnCompleted,
          onTurnContext: onTurnContext,
          startPhase: LiveVoicePhase.connecting,
        );
        return voice;
      }),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Your assistant is getting ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Private AI health checkup'), findsNothing);

    voice.simulatePhase(LiveVoicePhase.speaking);
    await tester.pump();

    expect(find.text('Your assistant is getting ready'), findsNothing);
    expect(find.text('Private AI health checkup'), findsOneWidget);
  });

  testWidgets('shows text fallback when realtime voice fails', (tester) async {
    await tester.pumpWidget(
      _buildSubject(service, (onTurnCompleted, onTurnContext) {
        voice = _FakeLiveVoiceController(
          onTurnCompleted: onTurnCompleted,
          onTurnContext: onTurnContext,
          failOnStart: true,
        );
        return voice;
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Text fallback'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    service.nextDecision = const VoiceAssessmentTurnDecision(
      acceptedTranscript: 'I feel tired',
      spokenResponse: 'What is your main concern?',
      responseInstructions: 'Ask the main concern.',
      completed: false,
      turnCount: 1,
      maxTurns: 10,
    );
    await tester.enterText(find.byType(TextField), 'I feel tired');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('I feel tired'), findsOneWidget);
    expect(find.text('What is your main concern?'), findsOneWidget);
  });

  testWidgets(
    'finalizes after the realtime completion phrase and custom package consent',
    (tester) async {
      await tester.pumpWidget(
        _buildSubject(service, (onTurnCompleted, onTurnContext) {
          voice = _FakeLiveVoiceController(
            onTurnCompleted: onTurnCompleted,
            onTurnContext: onTurnContext,
          );
          return voice;
        }),
      );
      await tester.pumpAndSettle();

      service.nextDecision = VoiceAssessmentTurnDecision(
        acceptedTranscript: 'Yes, please create it.',
        spokenResponse:
            'I have enough information to prepare your checkup result now.',
        responseInstructions: 'Speak the custom package completion message.',
        completed: true,
        turnCount: 4,
        maxTurns: 10,
        result: AssessmentResults.fromJson(const {
          'intent': 'custom_package',
          'outcome': 'test_package_only',
          'urgency': 'routine',
          'risk_level': 'low',
          'summary': 'A tailored draft panel is ready for review.',
          'custom_package': {
            'id': 5,
            'draft_token': 'draft-5',
            'name': 'AI Personal Health Panel',
            'price': '600.00',
            'status': 'draft',
            'tests': [
              {'id': 1, 'test_name': 'CBC', 'price': '250.00'},
              {'id': 2, 'test_name': 'TSH', 'price': '350.00'},
            ],
          },
        }),
      );

      await voice.simulateFinalization(
        transcript: 'Yes, please create it.',
        response:
            'I have enough information to prepare your checkup result now.',
      );
      await tester.pumpAndSettle();

      expect(service.finalizeVoiceCallCount, 1);
      expect(service.lastCustomPackageConsent, isFalse);
      expect(find.text('Custom panel ready for review'), findsOneWidget);
      expect(find.text('AI Personal Health Panel'), findsOneWidget);
      expect(voice.stopCallCount, 1);
    },
  );

  testWidgets('end checkup stops voice and cancels the active session', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSubject(service, (onTurnCompleted, onTurnContext) {
        voice = _FakeLiveVoiceController(
          onTurnCompleted: onTurnCompleted,
          onTurnContext: onTurnContext,
        );
        return voice;
      }),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('End checkup'));
    await tester.pumpAndSettle();

    expect(voice.stopCallCount, 1);
    expect(service.cancelVoiceCallCount, 1);
    expect(find.text('The checkup was ended.'), findsOneWidget);
    expect(find.text('Start again'), findsOneWidget);
  });

  testWidgets('shows a direct package action for a package outcome', (
    tester,
  ) async {
    final openedPackages = <String?>[];
    await tester.pumpWidget(
      _buildSubject(service, (onTurnCompleted, onTurnContext) {
        voice = _FakeLiveVoiceController(
          onTurnCompleted: onTurnCompleted,
          onTurnContext: onTurnContext,
        );
        return voice;
      }, onOpenPackage: openedPackages.add),
    );
    await tester.pumpAndSettle();

    service.nextDecision = VoiceAssessmentTurnDecision(
      acceptedTranscript: 'I want a routine general health checkup.',
      spokenResponse:
          'A health package may be the most suitable next step. Your result is saved.',
      responseInstructions: 'Explain the package outcome.',
      completed: true,
      turnCount: 1,
      maxTurns: 10,
      result: AssessmentResults.fromJson(const {
        'outcome': 'test_package_only',
        'urgency': 'routine',
        'risk_level': 'low',
        'summary': 'Consider a package for routine preventive screening.',
        'insights': ['Review the available health packages.'],
        'recommended_packages': [
          {
            'id': 7,
            'package_name': 'General Wellness Package',
            'price': '1499.00',
            'discounted_price': '1199.00',
            'tests_count': 12,
          },
        ],
      }),
    );

    await voice.simulateTurn(
      'I want a routine general health checkup.',
      'A health package may be the most suitable next step. Your result is saved.',
    );
    await tester.pumpAndSettle();

    expect(find.text('Test package may be suitable'), findsOneWidget);
    expect(find.text('General Wellness Package'), findsOneWidget);
    expect(find.text('12 tests included'), findsOneWidget);
    expect(find.text('₹1199'), findsOneWidget);
    expect(find.text('View health packages'), findsOneWidget);

    await tester.tap(find.text('View package →'));
    expect(openedPackages, ['General Wellness Package']);

    await tester.ensureVisible(find.text('View health packages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View health packages'));
    expect(openedPackages, ['General Wellness Package', null]);
  });

  testWidgets('opens a recommended doctor without creating a booking', (
    tester,
  ) async {
    final openedDoctors = <AssessmentRecommendedDoctor>[];
    String? sourceSession;
    await tester.pumpWidget(
      _buildSubject(
        service,
        (onTurnCompleted, onTurnContext) {
          voice = _FakeLiveVoiceController(
            onTurnCompleted: onTurnCompleted,
            onTurnContext: onTurnContext,
          );
          return voice;
        },
        onOpenDoctor: (doctor, source) {
          openedDoctors.add(doctor);
          sourceSession = source;
        },
      ),
    );
    await tester.pumpAndSettle();

    service.nextDecision = VoiceAssessmentTurnDecision(
      acceptedTranscript: 'My headache has lasted two weeks.',
      spokenResponse: 'A doctor review is recommended.',
      responseInstructions: 'Explain the doctor recommendation.',
      completed: true,
      turnCount: 1,
      maxTurns: 10,
      result: AssessmentResults.fromJson(const {
        'intent': 'doctor_booking',
        'outcome': 'consultation_only',
        'urgency': 'soon',
        'risk_level': 'moderate',
        'summary': 'Please arrange a non-emergency clinical review.',
        'insights': [],
        'recommended_doctors': [
          {
            'id': 42,
            'name': 'Dr Active',
            'specialization': 'General Medicine',
            'reason': 'Persistent headache review',
          },
        ],
      }),
    );

    await voice.simulateTurn(
      'My headache has lasted two weeks.',
      'A doctor review is recommended.',
    );
    await tester.pumpAndSettle();

    expect(find.text('Recommended doctors'), findsOneWidget);
    expect(find.text('Dr Active'), findsOneWidget);
    expect(
      find.textContaining('Recommendations require your confirmation'),
      findsOneWidget,
    );

    await tester.tap(find.text('Dr Active'));
    expect(openedDoctors.single.id, 42);
    expect(sourceSession, 'voice-token');
  });

  testWidgets('hands recommended test ids to the editable lab cart', (
    tester,
  ) async {
    final openedTests = <List<AssessmentRecommendedTest>>[];
    await tester.pumpWidget(
      _buildSubject(service, (onTurnCompleted, onTurnContext) {
        voice = _FakeLiveVoiceController(
          onTurnCompleted: onTurnCompleted,
          onTurnContext: onTurnContext,
        );
        return voice;
      }, onOpenTests: (tests, _) => openedTests.add(tests)),
    );
    await tester.pumpAndSettle();

    service.nextDecision = VoiceAssessmentTurnDecision(
      acceptedTranscript: 'I have persistent fatigue.',
      spokenResponse: 'Two lab tests may help.',
      responseInstructions: 'Explain the test recommendations.',
      completed: true,
      turnCount: 1,
      maxTurns: 10,
      result: AssessmentResults.fromJson(const {
        'intent': 'test_booking',
        'outcome': 'test_package_only',
        'urgency': 'routine',
        'risk_level': 'low',
        'summary': 'Review these tests before deciding whether to book.',
        'insights': [],
        'recommended_tests': [
          {'id': 11, 'test_name': 'CBC', 'reason': 'Review blood counts.'},
          {'id': 12, 'test_name': 'TSH', 'reason': 'Review thyroid function.'},
        ],
      }),
    );

    await voice.simulateTurn(
      'I have persistent fatigue.',
      'Two lab tests may help.',
    );
    await tester.pumpAndSettle();

    expect(find.text('Recommended lab tests'), findsOneWidget);
    expect(find.text('Lab tests may be suitable'), findsOneWidget);
    expect(find.text('CBC'), findsOneWidget);
    expect(find.text('TSH'), findsOneWidget);
    expect(find.text('View health packages'), findsNothing);
    await tester.ensureVisible(find.text('Review selected tests'));
    await tester.tap(find.text('Review selected tests'));

    expect(openedTests.single.map((test) => test.id), [11, 12]);
  });

  testWidgets('shows a server-priced custom draft and opens it for editing', (
    tester,
  ) async {
    final openedTests = <List<AssessmentRecommendedTest>>[];
    await tester.pumpWidget(
      _buildSubject(service, (onTurnCompleted, onTurnContext) {
        voice = _FakeLiveVoiceController(
          onTurnCompleted: onTurnCompleted,
          onTurnContext: onTurnContext,
        );
        return voice;
      }, onOpenTests: (tests, _) => openedTests.add(tests)),
    );
    await tester.pumpAndSettle();

    service.nextDecision = VoiceAssessmentTurnDecision(
      acceptedTranscript: 'Build a tailored panel for my fatigue.',
      spokenResponse: 'A draft panel is ready for review.',
      responseInstructions: 'Explain the custom draft.',
      completed: true,
      turnCount: 1,
      maxTurns: 10,
      result: AssessmentResults.fromJson(const {
        'intent': 'custom_package',
        'outcome': 'test_package_only',
        'urgency': 'routine',
        'risk_level': 'low',
        'summary': 'Review the tailored panel before booking.',
        'insights': [],
        'custom_package': {
          'id': 9,
          'draft_token': 'draft-token',
          'name': 'AI Personal Health Panel',
          'price': '600.00',
          'status': 'draft',
          'valid_until': '2026-08-17T12:00:00Z',
          'tests': [
            {'id': 11, 'test_name': 'CBC', 'price': '250.00'},
            {'id': 12, 'test_name': 'TSH', 'price': '350.00'},
          ],
        },
      }),
    );

    await voice.simulateTurn(
      'Build a tailored panel for my fatigue.',
      'A draft panel is ready for review.',
    );
    await tester.pumpAndSettle();

    expect(find.text('Draft custom panel'), findsOneWidget);
    expect(find.text('Custom panel ready for review'), findsOneWidget);
    expect(find.text('AI Personal Health Panel'), findsOneWidget);
    expect(find.text('View health packages'), findsNothing);
    expect(find.textContaining('₹600'), findsOneWidget);
    await tester.ensureVisible(find.text('Review and edit panel'));
    await tester.tap(find.text('Review and edit panel'));

    expect(openedTests.single.map((test) => test.id), [11, 12]);
  });

  testWidgets('emergency result suppresses booking actions and opens support', (
    tester,
  ) async {
    var emergencyOpened = false;
    await tester.pumpWidget(
      _buildSubject(service, (onTurnCompleted, onTurnContext) {
        voice = _FakeLiveVoiceController(
          onTurnCompleted: onTurnCompleted,
          onTurnContext: onTurnContext,
        );
        return voice;
      }, onOpenEmergency: () => emergencyOpened = true),
    );
    await tester.pumpAndSettle();

    service.nextDecision = VoiceAssessmentTurnDecision(
      acceptedTranscript: 'I have severe chest pain.',
      spokenResponse: 'Seek emergency care now.',
      responseInstructions: 'Speak the emergency message.',
      completed: true,
      turnCount: 1,
      maxTurns: 10,
      result: AssessmentResults.fromJson(const {
        'intent': 'advice',
        'outcome': 'emergency_escalation',
        'urgency': 'emergency',
        'risk_level': 'critical',
        'summary': 'Seek emergency care now.',
        'insights': ['Do not wait for routine booking.'],
        'recommended_packages': [
          {'id': 7, 'package_name': 'Must not appear'},
        ],
        'recommended_tests': [
          {'id': 11, 'test_name': 'Must not appear'},
        ],
      }),
    );

    await voice.simulateTurn(
      'I have severe chest pain.',
      'Seek emergency care now.',
    );
    await tester.pumpAndSettle();

    expect(find.text('Emergency care recommended'), findsOneWidget);
    expect(find.text('Open emergency contacts'), findsOneWidget);
    expect(find.text('Must not appear'), findsNothing);
    expect(find.text('View health packages'), findsNothing);

    await tester.ensureVisible(find.text('Open emergency contacts'));
    await tester.tap(find.text('Open emergency contacts'));
    expect(emergencyOpened, isTrue);
  });

  testWidgets('offers human support when no active recommendation matches', (
    tester,
  ) async {
    var supportOpened = false;
    await tester.pumpWidget(
      _buildSubject(service, (onTurnCompleted, onTurnContext) {
        voice = _FakeLiveVoiceController(
          onTurnCompleted: onTurnCompleted,
          onTurnContext: onTurnContext,
        );
        return voice;
      }, onOpenSupport: () => supportOpened = true),
    );
    await tester.pumpAndSettle();

    service.nextDecision = VoiceAssessmentTurnDecision(
      acceptedTranscript: 'I would like to see a specialist.',
      spokenResponse: 'Please contact the hospital for assistance.',
      responseInstructions: 'Offer a safe human handoff.',
      completed: true,
      turnCount: 1,
      maxTurns: 10,
      result: AssessmentResults.fromJson(const {
        'intent': 'doctor_booking',
        'outcome': 'consultation_only',
        'urgency': 'soon',
        'risk_level': 'moderate',
        'summary': 'A clinician review is appropriate.',
        'insights': [],
        'recommended_doctors': [],
      }),
    );

    await voice.simulateTurn(
      'I would like to see a specialist.',
      'Please contact the hospital for assistance.',
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No matching active option is available'),
      findsOneWidget,
    );
    expect(find.text('Hospital support recommended'), findsOneWidget);
    expect(find.text('Contact hospital support'), findsOneWidget);

    await tester.ensureVisible(find.text('Contact hospital support'));
    await tester.tap(find.text('Contact hospital support'));
    expect(supportOpened, isTrue);
  });

  testWidgets('waits half a second after final voice words before result', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSubject(service, (onTurnCompleted, onTurnContext) {
        voice = _FakeLiveVoiceController(
          onTurnCompleted: onTurnCompleted,
          onTurnContext: onTurnContext,
        );
        return voice;
      }, resultRevealDelay: const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();

    service.nextDecision = VoiceAssessmentTurnDecision(
      acceptedTranscript: 'That is all.',
      spokenResponse: 'Your checkup is complete. Take care.',
      responseInstructions: 'Conclude the checkup.',
      completed: true,
      turnCount: 3,
      maxTurns: 10,
      result: AssessmentResults.fromJson(const {
        'outcome': 'test_package_only',
        'urgency': 'routine',
        'risk_level': 'low',
        'summary': 'Routine screening is suitable.',
        'insights': [],
      }),
    );

    final completion = voice.simulateTurn(
      'That is all.',
      'Your checkup is complete. Take care.',
    );
    await tester.pump();
    expect(find.text('Private AI health checkup'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 499));
    expect(find.text('Private AI health checkup'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await completion;
    await tester.pumpAndSettle();
    expect(find.text('Hospital support recommended'), findsOneWidget);
  });
}

Widget _buildSubject(
  _FakeAiCheckupService service,
  _FakeLiveVoiceController Function(
    RealtimeTurnCompleted onTurnCompleted,
    RealtimeTurnContext onTurnContext,
  )
  createVoice, {
  AiCheckupPackageOpener? onOpenPackage,
  AiCheckupDoctorOpener? onOpenDoctor,
  AiCheckupTestsOpener? onOpenTests,
  AiCheckupEmergencyOpener? onOpenEmergency,
  AiCheckupSupportOpener? onOpenSupport,
  bool consentInitiallyGranted = true,
  Duration resultRevealDelay = Duration.zero,
}) {
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
      Provider<ApiClient>.value(value: apiClient),
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(apiClient: apiClient),
      ),
      ChangeNotifierProvider<SessionProvider>.value(value: sessionProvider),
    ],
    child: MaterialApp(
      home: AiCheckupTab(
        onOpenPackage: onOpenPackage,
        onOpenDoctor: onOpenDoctor,
        onOpenTests: onOpenTests,
        onOpenEmergency: onOpenEmergency,
        onOpenSupport: onOpenSupport,
        consentInitiallyGranted: consentInitiallyGranted,
        resultRevealDelay: resultRevealDelay,
        serviceFactory: (_) => service,
        voiceControllerFactory:
            ({
              required signalingApi,
              required onTurnCompleted,
              required onTurnContext,
            }) => createVoice(onTurnCompleted, onTurnContext),
      ),
    ),
  );
}

class _FakeAiCheckupService extends AiCheckupService {
  _FakeAiCheckupService() : super(apiBaseUrl: '', authToken: '');

  int startVoiceCallCount = 0;
  int recordedResponses = 0;
  int cancelVoiceCallCount = 0;
  int finalizeVoiceCallCount = 0;
  bool? lastConsent;
  bool? lastCustomPackageConsent;
  VoiceAssessmentTurnDecision nextDecision = const VoiceAssessmentTurnDecision(
    acceptedTranscript: 'I feel unwell.',
    spokenResponse: 'Tell me more.',
    responseInstructions: 'Ask the patient to tell you more.',
    completed: false,
    turnCount: 1,
    maxTurns: 10,
  );

  @override
  Future<VoiceAssessmentSession> startVoiceAssessment({
    String language = 'en',
    bool consent = false,
  }) async {
    startVoiceCallCount++;
    lastConsent = consent;
    return const VoiceAssessmentSession(
      sessionToken: 'voice-token',
      initialInstructions:
          'Hello. Are you feeling unwell today, or would you like a general health check?',
      maxTurns: 10,
      maxSeconds: 300,
    );
  }

  @override
  Future<VoiceAssessmentTurnDecision> submitVoiceTurn({
    required String sessionToken,
    required String transcript,
  }) async {
    return nextDecision;
  }

  @override
  Future<VoiceAssessmentTurnDecision> recordRealtimeTurn({
    required String sessionToken,
    required String transcript,
  }) async {
    return nextDecision;
  }

  @override
  Future<VoiceAssessmentTurnDecision> finalizeVoiceAssessment({
    required String sessionToken,
    bool customPackageConsent = false,
    Map<String, dynamic> realtimeAnalysis = const {},
  }) async {
    finalizeVoiceCallCount++;
    lastCustomPackageConsent = customPackageConsent;
    return nextDecision;
  }

  @override
  Future<void> recordVoiceResponse({
    required String sessionToken,
    required String transcript,
    required String response,
  }) async {
    recordedResponses++;
  }

  @override
  Future<void> cancelVoiceAssessment(String sessionToken) async {
    cancelVoiceCallCount++;
  }
}

class _FakeLiveVoiceController extends LiveVoiceController {
  _FakeLiveVoiceController({
    required super.onTurnCompleted,
    required super.onTurnContext,
    this.failOnStart = false,
    this.startPhase = LiveVoicePhase.speaking,
  }) : _completed = onTurnCompleted,
       _context = onTurnContext,
       super(
         signalingApi: InworldSignalingApi(
           ApiClient(
             config: AppConfig(
               appName: 'Fake',
               apiBaseUrl: 'https://example.test/api',
               healthEndpoint: '/health',
               showDevOtp: false,
             ),
           ),
         ),
       );

  final RealtimeTurnCompleted _completed;
  final RealtimeTurnContext _context;
  final bool failOnStart;
  final LiveVoicePhase startPhase;
  LiveVoiceState _fakeState = const LiveVoiceState();
  int startCallCount = 0;
  int stopCallCount = 0;

  @override
  LiveVoiceState get state => _fakeState;

  @override
  Future<void> start({
    required String locale,
    required String conversationId,
    String initialResponseInstructions = '',
    bool enableUsageTracking = true,
    String sessionInstructions = '',
    List<Map<String, dynamic>> tools = const [],
    RealtimeFunctionCallHandler? onFunctionCall,
  }) async {
    startCallCount++;
    _fakeState = failOnStart
        ? const LiveVoiceState(
            phase: LiveVoicePhase.error,
            errorMessage: 'Realtime voice is unavailable.',
          )
        : LiveVoiceState(phase: startPhase);
    notifyListeners();
  }

  @override
  Future<void> stop({String reason = 'user_stopped'}) async {
    stopCallCount++;
    _fakeState = const LiveVoiceState(phase: LiveVoicePhase.closed);
    notifyListeners();
  }

  void simulatePhase(LiveVoicePhase phase) {
    _fakeState = LiveVoiceState(phase: phase);
    notifyListeners();
  }

  Future<void> simulateTurn(String transcript, String response) async {
    _fakeState = const LiveVoiceState(phase: LiveVoicePhase.thinking);
    notifyListeners();
    await _context(transcript);
    _fakeState = LiveVoiceState(
      phase: LiveVoicePhase.speaking,
      responseText: response,
    );
    notifyListeners();
    await _completed(transcript, response);
  }

  Future<void> simulateFinalization({
    required String transcript,
    required String response,
  }) async {
    await _context(transcript);
    await _completed(transcript, response);
  }
}
