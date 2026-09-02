import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/ai_checkup/screens/initial_health_assessment_screen.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pendingPatient = PatientIdentity(
    id: 42,
    name: 'New Patient',
    phone: '+919998887777',
    registrationNumber: 'PAT-42',
    uuid: 'BHRC-PATIENT42',
    hasCompletedInitialHealthAssessment: false,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test(
    'offers the initial assessment after signup but not normal login',
    () async {
      final loginRepository = _AssessmentRepository(pendingPatient);
      final loginSession = _session(loginRepository);

      await loginSession.sendOtp(phone: pendingPatient.phone);
      await loginSession.verifyOtp(otp: '123456');

      expect(loginSession.shouldOfferInitialHealthAssessment, isFalse);

      final signupRepository = _AssessmentRepository(pendingPatient);
      final signupSession = _session(signupRepository);

      await signupSession.signUp(
        phone: pendingPatient.phone,
        name: pendingPatient.name,
        dob: '',
        place: 'Ponnani',
      );
      await signupSession.verifyOtp(otp: '123456');

      expect(signupSession.shouldOfferInitialHealthAssessment, isTrue);

      signupSession.updatePatient(
        pendingPatient.copyWith(hasCompletedInitialHealthAssessment: true),
      );

      expect(signupSession.shouldOfferInitialHealthAssessment, isFalse);
    },
  );

  testWidgets(
    'separates allergy and medication questions and supports one-time skip',
    (tester) async {
      final repository = _AssessmentRepository(pendingPatient);
      final session = _session(repository);

      await session.signUp(
        phone: pendingPatient.phone,
        name: pendingPatient.name,
        dob: '',
        place: 'Ponnani',
      );
      await session.verifyOtp(otp: '123456');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<PatientRepository>.value(value: repository),
            ChangeNotifierProvider<SessionProvider>.value(value: session),
            ChangeNotifierProvider<LanguageProvider>(
              create: (_) => LanguageProvider(apiClient: repository.apiClient),
            ),
          ],
          child: const MaterialApp(home: InitialHealthAssessmentScreen()),
        ),
      );

      expect(find.text('1/7'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('What is your date of birth?'), findsNothing);
      expect(find.text('Add date of birth (optional)'), findsNothing);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Do you have any allergies?'), findsOneWidget);
      expect(find.text('Are you taking any medications?'), findsNothing);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Are you taking any medications?'), findsOneWidget);
      expect(find.text('Do you have any allergies?'), findsNothing);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(repository.initialAssessmentCompletions, 1);
      expect(session.patient?.hasCompletedInitialHealthAssessment, isTrue);
      expect(session.shouldOfferInitialHealthAssessment, isFalse);
    },
  );

  test('submits date of birth without a separate age field', () {
    const input = InitialHealthAssessmentInput(dateOfBirth: '1990-05-12');

    expect(input.toJson()['date_of_birth'], '1990-05-12');
    expect(input.toJson().containsKey('age'), isFalse);
  });
}

SessionProvider _session(_AssessmentRepository repository) {
  return SessionProvider(
    authStorage: AuthStorage(),
    apiClient: repository.apiClient,
    patientRepository: repository,
  );
}

class _AssessmentRepository extends PatientRepository {
  _AssessmentRepository(this.patient)
    : apiClient = ApiClient(
        config: AppConfig(
          appName: 'BioHelix Test',
          apiBaseUrl: 'https://example.test/api',
          healthEndpoint: '/health',
          showDevOtp: false,
        ),
      ),
      super(
        apiClient: ApiClient(
          config: AppConfig(
            appName: 'BioHelix Test',
            apiBaseUrl: 'https://example.test/api',
            healthEndpoint: '/health',
            showDevOtp: false,
          ),
        ),
      );

  final PatientIdentity patient;
  final ApiClient apiClient;
  int initialAssessmentCompletions = 0;

  @override
  Future<OtpSendResult> sendOtp({required String phone, String? mrn}) async {
    return const OtpSendResult(devOtp: '123456');
  }

  @override
  Future<OtpSendResult> signUp({
    required String phone,
    required String name,
    required String dob,
    required String place,
    String? email,
    String? gender,
    String? referralCode,
  }) async {
    return const OtpSendResult(devOtp: '123456');
  }

  @override
  Future<OtpSession> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    return OtpSession(token: 'test-token', patient: patient);
  }

  @override
  Future<PatientIdentity> completeInitialHealthAssessment(
    InitialHealthAssessmentInput input,
  ) async {
    initialAssessmentCompletions++;
    return patient.copyWith(hasCompletedInitialHealthAssessment: true);
  }
}
