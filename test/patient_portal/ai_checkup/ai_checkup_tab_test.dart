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

    expect(find.text('Consultation may be suitable'), findsOneWidget);
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
    await tester.pumpWidget(
      _buildSubject(service, (onTurnCompleted, onTurnContext) {
        voice = _FakeLiveVoiceController(
          onTurnCompleted: onTurnCompleted,
          onTurnContext: onTurnContext,
        );
        return voice;
      }, onOpenDoctor: openedDoctors.add),
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
    expect(find.text('Test package may be suitable'), findsOneWidget);
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
  }) async {
    startVoiceCallCount++;
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
  Future<void> recordVoiceResponse({
    required String sessionToken,
    required String transcript,
    required String response,
  }) async {
    recordedResponses++;
  }

  @override
  Future<void> cancelVoiceAssessment(String sessionToken) async {}
}

class _FakeLiveVoiceController extends LiveVoiceController {
  _FakeLiveVoiceController({
    required super.onTurnCompleted,
    required super.onTurnContext,
    this.failOnStart = false,
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
  }) async {
    startCallCount++;
    _fakeState = failOnStart
        ? const LiveVoiceState(
            phase: LiveVoicePhase.error,
            errorMessage: 'Realtime voice is unavailable.',
          )
        : const LiveVoiceState(phase: LiveVoicePhase.listening);
    notifyListeners();
  }

  @override
  Future<void> stop({String reason = 'user_stopped'}) async {
    stopCallCount++;
    _fakeState = const LiveVoiceState(phase: LiveVoicePhase.closed);
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
}
