import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/core/providers/theme_provider.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/auth/presentation/patient_auth_flow.dart';
import 'package:biohelix_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/features/splash/presentation/splash_screen.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/home_feed_models.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';
import 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const patient = PatientIdentity(
    id: 42,
    name: 'Amina Patient',
    phone: '7034598461',
    registrationNumber: 'BHRC-42',
    uuid: 'patient-42',
    age: 34,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('1. splash screen shows BioHelix branding', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();

    expect(find.text('BioHelix'), findsOneWidget);
    expect(find.text('Health and Research Center'), findsOneWidget);
  });

  testWidgets('2. onboarding swipe completes the start flow', (tester) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onCompleted: () async {
            completed = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your Smart Health Partner'), findsOneWidget);
    expect(find.text('Swipe to Start'), findsOneWidget);

    await tester.drag(
      find.byIcon(Icons.chevron_right_rounded),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });

  testWidgets('3. login authenticates with phone and password', (tester) async {
    final repository = _FakePatientRepository(patient: patient);
    final session = _buildSession(repository);

    await tester.pumpWidget(_authSubject(session));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, '+919876543210'),
      '9998887777',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter password'),
      'password123',
    );
    await tester.ensureVisible(find.text('Login').last);
    await tester.tap(find.text('Login').last);
    await tester.pumpAndSettle();

    expect(repository.lastLoginPayload, {
      'phone': '9998887777',
      'password': 'password123',
    });
    expect(session.isAuthenticated, isTrue);
  });

  testWidgets('4. register submits documented patient details', (tester) async {
    final repository = _FakePatientRepository(patient: patient);
    final session = _buildSession(repository);

    await tester.pumpWidget(_authSubject(session));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('New patient? Register'));
    await tester.tap(find.text('New patient? Register'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '+919876543210'),
      '8887776666',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Aisha Rahman'),
      'New Patient',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter password'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Re-enter password'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '1994-04-12'),
      '1990-01-02',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'aisha.rahman@example.com'),
      'new@example.test',
    );
    await tester.enterText(find.widgetWithText(TextField, 'female'), 'female');
    await tester.enterText(find.widgetWithText(TextField, 'O+'), 'A+');
    await tester.ensureVisible(find.text('Register').last);
    await tester.tap(find.text('Register').last);
    await tester.pumpAndSettle();

    expect(repository.lastSignupPayload, {
      'phone': '8887776666',
      'password': 'password123',
      'passwordConfirmation': 'password123',
      'firstName': 'New',
      'lastName': 'Patient',
      'gender': 'female',
      'email': 'new@example.test',
      'dateOfBirth': '1990-01-02',
      'bloodGroup': 'A+',
    });
    expect(session.isAuthenticated, isTrue);
  });

  test('5. auth storage persists and clears the auth token', () async {
    final storage = AuthStorage();

    await storage.writeToken('token-a');
    expect(await storage.readToken(), 'token-a');

    await storage.clearToken();
    expect(await storage.readToken(), isNull);
  });

  test('6. auth storage persists saved family profiles', () async {
    final storage = AuthStorage();
    final profiles = [
      SavedPatientProfile(
        token: 'family-token',
        patient: patient,
        lastUsedAt: DateTime(2026, 5, 8).toIso8601String(),
      ),
    ];

    await storage.writeFamilyProfiles(profiles);
    final stored = await storage.readFamilyProfiles();

    expect(stored, hasLength(1));
    expect(stored.single.token, 'family-token');
    expect(stored.single.patient.name, 'Amina Patient');
  });

  test(
    '7. session initializes from a stored token and loads the patient',
    () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'stored-token'});
      final apiAdapter = _RecordingAdapter();
      final apiClient = _testApiClient(adapter: apiAdapter);
      final repository = _FakePatientRepository(
        patient: patient,
        apiClient: apiClient,
      );
      final session = SessionProvider(
        authStorage: AuthStorage(),
        apiClient: apiClient,
        patientRepository: repository,
      );

      await session.initialize();

      expect(session.isAuthenticated, isTrue);
      expect(session.authToken, 'stored-token');
      expect(session.patient?.id, 42);
      expect(repository.getCurrentPatientCalls, 1);
    },
  );

  test(
    '8. session recovers from saved family profiles when primary token fails',
    () async {
      final profile = SavedPatientProfile(
        token: 'fallback-token',
        patient: patient,
        lastUsedAt: DateTime(2026, 5, 8).toIso8601String(),
      );
      SharedPreferences.setMockInitialValues({
        'auth_token': 'expired-token',
        'family_profiles': [jsonEncode(profile.toJson())],
      });
      final repository = _FakePatientRepository(
        patient: patient,
        failCurrentPatientCalls: 1,
      );
      final session = _buildSession(repository);

      await session.initialize();

      expect(session.isAuthenticated, isTrue);
      expect(session.authToken, 'fallback-token');
      expect(session.patient?.name, 'Amina Patient');
      expect(repository.getCurrentPatientCalls, 2);
    },
  );

  test('9. app config uses production-safe defaults when env is absent', () {
    final config = AppConfig.fromEnvironment();

    expect(config.appName, isNotEmpty);
    expect(config.apiBaseUrl, 'https://www.bhrchospital.com/api/v1');
    expect(config.healthEndpoint, '/health');
  });

  test(
    '10. API client sends bearer auth and preserves signed media URLs',
    () async {
      final adapter = _RecordingAdapter();
      final apiClient = _testApiClient(adapter: adapter);

      apiClient.updateAuthToken('secret-token');
      final response = await apiClient.getJson('/patients/me');

      expect(response['ok'], isTrue);
      expect(adapter.lastPath, '/patients/me');
      expect(adapter.lastAuthorizationHeader, 'Bearer secret-token');
      expect(
        apiClient.authenticatedMediaUrl('https://signed.example/report.pdf'),
        'https://signed.example/report.pdf',
      );

      apiClient.updateAuthToken(null);
      await apiClient.getJson('/health');
      expect(adapter.lastAuthorizationHeader, isNull);
    },
  );

  testWidgets('10b. authenticated patient shell exposes the five bottom tabs', (
    tester,
  ) async {
    final repository = _FakePatientRepository(patient: patient);
    final session = _buildSession(repository);

    await session.login(phone: patient.phone, password: 'password123');

    final portal = PatientPortalProvider(
      repository: repository,
      sessionProvider: session,
    );
    await portal.loadPortal();

    await tester.pumpWidget(_shellSubject(session: session, portal: portal));
    await tester.pump();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Checkup'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}

Widget _authSubject(SessionProvider session) {
  return MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: _testConfig(showDevOtp: true)),
      ChangeNotifierProvider<SessionProvider>.value(value: session),
    ],
    child: const MaterialApp(home: PatientAuthFlow()),
  );
}

Widget _shellSubject({
  required SessionProvider session,
  required PatientPortalProvider portal,
}) {
  final languageProvider = LanguageProvider();

  return MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: _testConfig()),
      ChangeNotifierProvider<SessionProvider>.value(value: session),
      ChangeNotifierProvider<PatientPortalProvider>.value(value: portal),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
    ],
    child: const MaterialApp(home: PatientAppShell()),
  );
}

SessionProvider _buildSession(_FakePatientRepository repository) {
  final apiClient = repository.apiClient;
  return SessionProvider(
    authStorage: AuthStorage(),
    apiClient: apiClient,
    patientRepository: repository,
  );
}

AppConfig _testConfig({bool showDevOtp = false}) {
  return AppConfig(
    appName: 'BioHelix Test',
    apiBaseUrl: 'https://example.test/api',
    healthEndpoint: '/health',
    showDevOtp: showDevOtp,
  );
}

ApiClient _testApiClient({_RecordingAdapter? adapter}) {
  return ApiClient(config: _testConfig(), httpClientAdapter: adapter);
}

class _FakePatientRepository extends PatientRepository {
  _FakePatientRepository({
    required this.patient,
    this.failCurrentPatientCalls = 0,
    ApiClient? apiClient,
  }) : apiClient = apiClient ?? _testApiClient(),
       super(apiClient: apiClient ?? _testApiClient());

  final PatientIdentity patient;
  final ApiClient apiClient;
  final int failCurrentPatientCalls;
  int getCurrentPatientCalls = 0;
  String? lastOtpPhone;
  Map<String, String>? lastSignupPayload;
  Map<String, String>? lastLoginPayload;

  @override
  Future<String?> sendOtp({required String phone, String? mrn}) async {
    lastOtpPhone = phone;
    return '123456';
  }

  @override
  Future<String?> signUp({
    required String phone,
    required String name,
    required String dob,
    required String place,
  }) async {
    lastSignupPayload = {
      'phone': phone,
      'name': name,
      'dob': dob,
      'place': place,
    };
    return '123456';
  }

  @override
  Future<PatientAuthSession> registerPatient({
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String firstName,
    required String lastName,
    String? gender,
    String? email,
    String? dateOfBirth,
    String? bloodGroup,
  }) async {
    lastSignupPayload = {
      'phone': phone,
      'password': password,
      'passwordConfirmation': passwordConfirmation,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender ?? '',
      'email': email ?? '',
      'dateOfBirth': dateOfBirth ?? '',
      'bloodGroup': bloodGroup ?? '',
    };
    return PatientAuthSession(token: 'registered-token', patient: patient);
  }

  @override
  Future<PatientAuthSession> loginPatient({
    required String phone,
    required String password,
  }) async {
    lastLoginPayload = {'phone': phone, 'password': password};
    return PatientAuthSession(token: 'login-token', patient: patient);
  }

  @override
  Future<OtpSession> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    return OtpSession(token: 'verified-token', patient: patient);
  }

  @override
  Future<PatientIdentity> getCurrentPatient() async {
    getCurrentPatientCalls++;
    if (getCurrentPatientCalls <= failCurrentPatientCalls) {
      throw Exception('Token expired');
    }
    return patient;
  }

  @override
  Future<PatientDashboard> getDashboard() async {
    return PatientDashboard(
      patient: patient,
      metrics: const PortalMetrics(
        totalRecords: 2,
        availableRecords: 2,
        processingRecords: 0,
        showingRecords: 2,
        upcomingBookings: 0,
      ),
      recentBookings: const [],
      recentPrescriptions: const [],
      recentDocuments: const [],
      recentSummaries: const [],
      idCard: IdCardInfo(
        registrationNumber: patient.registrationNumber,
        patientName: patient.name,
        membershipTier: 'Classic',
        qrValue: patient.uuid,
      ),
      myClub: MyClubSummary(
        patientId: patient.id,
        points: 0,
        currencyValue: 0,
        tier: 'Classic',
        transactions: const [],
      ),
      emergencyContacts: const [],
    );
  }

  @override
  Future<List<HomeBannerItem>> getHomeBanners() async => const [];
  @override
  Future<List<TickerMessageItem>> getTickerMessages() async => const [];
  @override
  Future<List<HomeOfferItem>> getHomeOffers() async => const [];
  @override
  Future<List<BookingItem>> getBookings() async => const [];
  @override
  Future<List<PrescriptionRecord>> getPrescriptions() async => const [];
  @override
  Future<List<MedicalRecordItem>> getMedicalRecords() async => const [];
  @override
  Future<List<DocumentRecord>> getDocuments() async => const [];
  @override
  Future<List<SummaryRecord>> getSummaries() async => const [];
  @override
  Future<List<VitalRecord>> getVitalTrend() async => const [];
  @override
  Future<List<DoctorListing>> getDoctors() async => const [];
  @override
  Future<List<DepartmentItem>> getDepartments() async => const [];
  @override
  Future<List<LabTestItem>> getLabTests() async => const [];
  @override
  Future<List<LabOrderItem>> getLabOrders() async => const [];
  @override
  Future<List<LabPackageItem>> getLabPackages() async => const [];
  @override
  Future<List<LabPackageOrderItem>> getLabPackageOrders() async => const [];
  @override
  Future<List<ChatThreadSummary>> getGlobalChatThreads() async => const [];
}

class _RecordingAdapter implements HttpClientAdapter {
  String? lastPath;
  String? lastAuthorizationHeader;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastAuthorizationHeader = options.headers['Authorization']?.toString();
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
