import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/auth/presentation/patient_auth_flow.dart';
import 'package:biohelix_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/features/splash/presentation/splash_screen.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const patient = PatientIdentity(
    id: 7,
    name: 'Integration Patient',
    phone: '9998887777',
    registrationNumber: 'BHRC-7',
    uuid: 'integration-patient-7',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  testWidgets('first entry/session journey works end to end', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();

    expect(find.text('BioHelix'), findsOneWidget);
    expect(find.text('Health and Research Center'), findsOneWidget);

    var onboardingCompleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onCompleted: () async {
            onboardingCompleted = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your Smart Health Partner'), findsOneWidget);
    await tester.drag(find.byIcon(Icons.chevron_right_rounded), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(onboardingCompleted, isTrue);

    final apiClient = ApiClient(config: _integrationConfig());
    final repository = _IntegrationPatientRepository(
      patient: patient,
      apiClient: apiClient,
    );
    final session = SessionProvider(
      authStorage: AuthStorage(),
      apiClient: apiClient,
      patientRepository: repository,
    );

    await tester.pumpWidget(_authFlowSubject(session));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter your mobile number'),
      patient.phone,
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(repository.otpRequestPhone, patient.phone);
    expect(session.pendingPhone, patient.phone);
    expect(find.text('Verify OTP'), findsWidgets);
    expect(find.text('ENTER OTP'), findsOneWidget);

    await session.verifyOtp(otp: '123456');
    await tester.pumpAndSettle();

    expect(session.isAuthenticated, isTrue);
    expect(session.authToken, 'integration-token');
    expect(session.patient?.name, patient.name);
    expect(await AuthStorage().readToken(), 'integration-token');
  });
}

Widget _authFlowSubject(SessionProvider session) {
  return MultiProvider(
    providers: [
      Provider<AppConfig>.value(
        value: _integrationConfig(),
      ),
      ChangeNotifierProvider<SessionProvider>.value(value: session),
    ],
    child: const MaterialApp(home: PatientAuthFlow()),
  );
}

AppConfig _integrationConfig() {
  return AppConfig(
    appName: 'BioHelix Integration Test',
    apiBaseUrl: 'https://example.test/api',
    healthEndpoint: '/health',
    showDevOtp: true,
  );
}

class _IntegrationPatientRepository extends PatientRepository {
  _IntegrationPatientRepository({
    required this.patient,
    required ApiClient apiClient,
  }) : super(apiClient: apiClient);

  final PatientIdentity patient;
  String? otpRequestPhone;

  @override
  Future<String?> sendOtp({required String phone, String? mrn}) async {
    otpRequestPhone = phone;
    return '123456';
  }

  @override
  Future<OtpSession> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    return OtpSession(token: 'integration-token', patient: patient);
  }
}
