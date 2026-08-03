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
    expect(find.text('Checkup for Fadhil P'), findsOneWidget);
    expect(find.textContaining('Are you feeling unwell today'), findsOneWidget);

    service.nextDecision = const VoiceAssessmentTurnDecision(
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
}

Widget _buildSubject(
  _FakeAiCheckupService service,
  _FakeLiveVoiceController Function(
    RealtimeTurnCompleted onTurnCompleted,
    RealtimeTurnContext onTurnContext,
  )
  createVoice,
) {
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
      patientName: 'Fadhil P',
      initialInstructions:
          'Hi Fadhil. Are you feeling unwell today, or would you like a general health check?',
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
    required RealtimeTurnCompleted onTurnCompleted,
    required RealtimeTurnContext onTurnContext,
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
         onTurnCompleted: onTurnCompleted,
         onTurnContext: onTurnContext,
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
