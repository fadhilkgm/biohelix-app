import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/network/api_exception.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/auth/presentation/patient_auth_flow.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  testWidgets('registered phone goes to OTP instead of registration form', (
    tester,
  ) async {
    final repository = _PhoneGateRepository(isRegistered: true);
    await tester.pumpWidget(_subject(repository));

    await tester.ensureVisible(find.text('New patient? Register'));
    await tester.tap(find.text('New patient? Register'));
    await tester.pumpAndSettle();

    expect(find.text('Check your mobile number'), findsOneWidget);
    expect(find.byKey(const ValueKey('field_name')), findsNothing);
    expect(find.text('Already registered? Login'), findsNothing);

    await tester.enterText(_phoneField(), '8075595617');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Verify OTP'), findsWidgets);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('unregistered phone continues to the full registration form', (
    tester,
  ) async {
    final repository = _PhoneGateRepository(isRegistered: false);
    await tester.pumpWidget(_subject(repository));

    await tester.ensureVisible(find.text('New patient? Register'));
    await tester.tap(find.text('New patient? Register'));
    await tester.pumpAndSettle();
    await tester.enterText(_phoneField(), '9998887777');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Check your mobile number'), findsOneWidget);
    expect(
      find.text(
        'This mobile number is not registered. You can create a new account.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('field_name')), findsNothing);
    expect(find.text('Already registered? Login'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Register'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Register'));
    expect(
      tester.getTopLeft(find.widgetWithText(FilledButton, 'Register')).dy,
      lessThan(tester.getTopLeft(find.text('Continue')).dy),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.byKey(const ValueKey('field_name')), findsOneWidget);
    expect(find.text('Verify OTP'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Check your mobile number'), findsOneWidget);
    expect(find.byKey(const ValueKey('field_name')), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Register'), findsOneWidget);
  });
}

Finder _phoneField() {
  return find.descendant(
    of: find.byKey(const ValueKey('field_phone')),
    matching: find.byType(TextField),
  );
}

Widget _subject(_PhoneGateRepository repository) {
  final config = AppConfig(
    appName: 'BioHelix Test',
    apiBaseUrl: 'https://example.test/api',
    healthEndpoint: '/health',
    showDevOtp: false,
  );
  final session = SessionProvider(
    authStorage: AuthStorage(),
    apiClient: repository.apiClient,
    patientRepository: repository,
  );

  return MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: config),
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(apiClient: repository.apiClient),
      ),
      ChangeNotifierProvider<SessionProvider>.value(value: session),
    ],
    child: const MaterialApp(home: PatientAuthFlow()),
  );
}

class _PhoneGateRepository extends PatientRepository {
  factory _PhoneGateRepository({required bool isRegistered}) {
    final apiClient = ApiClient(
      config: AppConfig(
        appName: 'BioHelix Test',
        apiBaseUrl: 'https://example.test/api',
        healthEndpoint: '/health',
        showDevOtp: false,
      ),
    );
    return _PhoneGateRepository._(
      isRegistered: isRegistered,
      apiClient: apiClient,
    );
  }

  _PhoneGateRepository._({required this.isRegistered, required this.apiClient})
    : super(apiClient: apiClient);

  final bool isRegistered;
  final ApiClient apiClient;

  @override
  Future<OtpSendResult> sendOtp({required String phone, String? mrn}) async {
    if (!isRegistered) {
      throw ApiException(
        'Patient not found for the provided phone number.',
        statusCode: 422,
      );
    }
    return const OtpSendResult(devOtp: '123456');
  }
}
