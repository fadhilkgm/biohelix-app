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
import 'package:flutter/services.dart';
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
    _mockVoiceChannels();
  });

  testWidgets('1. splash screen shows BioHelix branding', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();

    expect(find.text('BioHelix'), findsOneWidget);
    expect(find.text('Health and Research Center'), findsOneWidget);
  });

  testWidgets('2. onboarding button completes the start flow', (tester) async {
    var completed = false;
    final languageProvider = LanguageProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: languageProvider,
        child: MaterialApp(
          home: OnboardingScreen(
            onCompleted: () async {
              completed = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your Smart Health Partner'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });

  testWidgets('3. login sends OTP and authenticates', (tester) async {
    final repository = _FakePatientRepository(patient: patient);
    final session = _buildSession(repository);

    await tester.pumpWidget(_authSubject(session));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, '9998887777');
    await tester.tap(find.text('Send WhatsApp OTP'));
    await tester.pumpAndSettle();

    expect(repository.lastOtpPhone, isNotNull);
    expect(session.pendingPhone, isNotEmpty);
    expect(find.text('Verify OTP'), findsWidgets);

    await session.verifyOtp(otp: '123456');
    await tester.pumpAndSettle();

    expect(session.isAuthenticated, isTrue);
  });

  testWidgets('4. register submits patient details and sends OTP', (tester) async {
    final repository = _FakePatientRepository(patient: patient);
    final session = _buildSession(repository);

    await tester.pumpWidget(_authSubject(session));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('New patient? Register'));
    await tester.tap(find.text('New patient? Register'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Aisha Rahman'),
      'New Patient',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '+919876543210'),
      '8887776666',
    );
    final now = DateTime.now();
    final selectedDob = DateTime(now.year - 25, now.month, now.day);
    final selectedDobText =
        '${selectedDob.year}-${selectedDob.month.toString().padLeft(2, '0')}-${selectedDob.day.toString().padLeft(2, '0')}';
    await tester.tap(find.widgetWithText(TextField, 'Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'aisha.rahman@example.com'),
      'new@example.test',
    );
    final dropdowns = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdowns.first);
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Female').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(dropdowns.last);
    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A+').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Ponnani, Kerala'),
      'Ponnani',
    );
    await tester.ensureVisible(find.text('Register & send WhatsApp OTP'));
    await tester.tap(find.text('Register & send WhatsApp OTP'));
    await tester.pumpAndSettle();

    expect(repository.lastSignupPayload, {
      'phone': '+918887776666',
      'name': 'New Patient',
      'dob': selectedDobText,
      'place': 'Ponnani',
      'email': 'new@example.test',
      'gender': 'female',
    });
    expect(session.pendingPhone, isNotEmpty);
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

  test('9. app config uses local dev defaults when env is absent', () {
    final config = AppConfig.fromEnvironment();

    expect(config.appName, isNotEmpty);
    expect(config.apiBaseUrl, 'http://10.0.2.2:8000/api/v1');
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
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Checkup'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}

void _mockVoiceChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  // flutter_tts
  messenger.setMockMethodCallHandler(
    const MethodChannel('flutter_tts'),
    (call) async => null,
  );
  // speech_to_text on Windows
  messenger.setMockMethodCallHandler(
    const MethodChannel('speech_to_text_windows'),
    (call) async {
      if (call.method == 'initialize' || call.method == 'hasPermission') {
        return true;
      }
      return null;
    },
  );
  // speech_to_text cross-platform channel
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugin.csdcorp.com/speech_to_text'),
    (call) async {
      if (call.method == 'initialize' || call.method == 'hasPermission') {
        return true;
      }
      return null;
    },
  );
  // audio_session used by just_audio
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.ryanheise.audio_session'),
    (call) async => null,
  );
}

Widget _authSubject(SessionProvider session) {
  final languageProvider = LanguageProvider();

  return MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: _testConfig(showDevOtp: true)),
      ChangeNotifierProvider<SessionProvider>.value(value: session),
      ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
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
  Future<OtpSendResult> sendOtp({required String phone, String? mrn}) async {
    lastOtpPhone = phone;
    return const OtpSendResult(devOtp: '123456', message: 'OTP sent to your WhatsApp');
  }

  @override
  Future<OtpSendResult> signUp({
    required String phone,
    required String name,
    required String dob,
    required String place,
    String? email,
    String? gender,
  }) async {
    lastSignupPayload = {
      'phone': phone,
      'name': name,
      'dob': dob,
      'place': place,
      'email': email ?? '',
      'gender': gender ?? '',
    };
    return const OtpSendResult(devOtp: '123456', message: 'OTP sent to your WhatsApp');
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
  @override
  Future<List<BodyPointItem>> getBodyPoints() async => const [];
  @override
  Future<MyClubSummary> getMyClub() async => MyClubSummary(
    patientId: patient.id,
    points: 0,
    currencyValue: 0,
    tier: 'Classic',
    transactions: const [],
  );
  @override
  Future<HealthSnapshot?> getHealthSnapshot() async => null;
  @override
  Future<List<AiSuggestionItem>> getAiSuggestions() async => const [];
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
