import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/l10n/app_strings.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/core/providers/theme_provider.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/home_feed_models.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';
import 'package:biohelix_app/patient_portal/fitness/providers/fitness_provider.dart';
import 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    _mockVoiceChannels();
  });

  testWidgets('11. pull-to-refresh reloads portal data', (tester) async {
    final harness = await _buildHarness();
    await tester.pumpWidget(harness.widget);
    await tester.pump(const Duration(milliseconds: 600));

    final initialDashboardCalls = harness.repository.dashboardCalls;

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator).first,
    );
    await refreshIndicator.onRefresh();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      harness.repository.dashboardCalls,
      greaterThan(initialDashboardCalls),
    );
  });

  testWidgets('12. back button returns to home before exit dialog', (
    tester,
  ) async {
    final harness = await _buildHarness();
    await tester.pumpWidget(harness.widget);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byTooltip('Health AI'), findsOneWidget);

    final controller =
        tester.state(find.byType(PatientAppShell)) as PatientAppShellController;
    controller.openRecords();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byTooltip('Health AI'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byTooltip('Health AI'), findsOneWidget);
    expect(find.text('Exit BHRC?'), findsNothing);
  });

  testWidgets('13. back button on home shows exit confirmation dialog', (
    tester,
  ) async {
    final harness = await _buildHarness();
    await tester.pumpWidget(harness.widget);
    await tester.pump(const Duration(milliseconds: 600));

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Exit BHRC?'), findsOneWidget);
    expect(find.text('Stay'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);
  });

  testWidgets(
    '14. home floating assistant shortcut opens the assistant screen',
    (tester) async {
      final harness = await _buildHarness();
      await tester.pumpWidget(harness.widget);
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byTooltip('Health AI'), findsOneWidget);

      final controller =
          tester.state(find.byType(PatientAppShell))
              as PatientAppShellController;
      controller.openAssistant();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Health AI'), findsOneWidget);
    },
  );

  testWidgets('15. home shows patient greeting and hero content', (
    tester,
  ) async {
    final harness = await _buildHarness();
    await tester.pumpWidget(harness.widget);
    await tester.pump(const Duration(milliseconds: 600));

    final strings = AppStrings.of(AppLanguage.en);

    final greetingCount =
        find.text(strings.goodDay).evaluate().length +
        find.text(strings.goodNight).evaluate().length;

    expect(greetingCount, greaterThan(0));
    expect(find.text('Amina Patient'), findsOneWidget);
  });

  testWidgets('16. home shows banners and announcement ticker', (tester) async {
    final harness = await _buildHarness();
    await tester.pumpWidget(harness.widget);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Monsoon Wellness'), findsOneWidget);
    expect(find.text('Free camp on Friday'), findsOneWidget);
  });

  testWidgets('17. home shows health tips from banner content', (tester) async {
    final harness = await _buildHarness();
    await tester.pumpWidget(harness.widget);
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Stay hydrated and monitor your blood pressure.'),
      findsWidgets,
    );
  });

  testWidgets('18. home shows packages without a special-offers heading', (
    tester,
  ) async {
    final harness = await _buildHarness();
    await tester.pumpWidget(harness.widget);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Special Offers'), findsNothing);
    expect(find.text('Executive Health Package'), findsWidgets);
  });

  testWidgets('19. home shows upcoming appointments preview', (tester) async {
    final harness = await _buildHarness();
    await tester.pumpWidget(harness.widget);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Upcoming Appointments'), findsOneWidget);
    expect(find.text('Dr Sana Rahman'), findsWidgets);
  });

  testWidgets('20. home shows doctor discovery section', (tester) async {
    final harness = await _buildHarness();
    await tester.pumpWidget(harness.widget);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Find Doctors'), findsOneWidget);
    expect(find.text('Dr Sana Rahman'), findsWidgets);
    expect(find.text('Cardiology'), findsWidgets);
    expect(find.text('Book Now'), findsOneWidget);
  });
}

Future<_ShellHarness> _buildHarness() async {
  final repository = _FakePortalRepository();
  final apiClient = repository.apiClient;
  final session = SessionProvider(
    authStorage: AuthStorage(),
    apiClient: apiClient,
    patientRepository: repository,
  );
  await session.sendOtp(phone: '9998887777');
  await session.verifyOtp(otp: '123456');

  final portal = PatientPortalProvider(
    repository: repository,
    sessionProvider: session,
  );
  await portal.loadPortal();
  final fitness = FitnessProvider(
    repository: repository,
    sessionProvider: session,
  );

  return _ShellHarness(
    repository: repository,
    widget: MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: _testConfig()),
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<SessionProvider>.value(value: session),
        ChangeNotifierProvider<PatientPortalProvider>.value(value: portal),
        ChangeNotifierProvider<FitnessProvider>.value(value: fitness),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(apiClient: apiClient),
        ),
      ],
      child: const MaterialApp(home: PatientAppShell()),
    ),
  );
}

void _mockVoiceChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('flutter_tts'),
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('speech_to_text_windows'),
    (call) async {
      if (call.method == 'initialize' || call.method == 'hasPermission') {
        return true;
      }
      return null;
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugin.csdcorp.com/speech_to_text'),
    (call) async {
      if (call.method == 'initialize' || call.method == 'hasPermission') {
        return true;
      }
      return null;
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.ryanheise.audio_session'),
    (call) async => null,
  );
}

AppConfig _testConfig() {
  return AppConfig(
    appName: 'BioHelix Test',
    apiBaseUrl: 'https://example.test/api',
    healthEndpoint: '/health',
    showDevOtp: true,
  );
}

class _ShellHarness {
  const _ShellHarness({required this.repository, required this.widget});

  final _FakePortalRepository repository;
  final Widget widget;
}

class _FakePortalRepository extends PatientRepository {
  _FakePortalRepository()
    : apiClient = superApiClient,
      super(apiClient: superApiClient);

  static final superApiClient = ApiClient(config: _testConfig());
  final ApiClient apiClient;
  int dashboardCalls = 0;

  static const _patient = PatientIdentity(
    id: 108,
    name: 'Amina Patient',
    phone: '9998887777',
    registrationNumber: 'BHRC-108',
    uuid: 'patient-108',
  );

  static const _bookings = [
    BookingItem(
      id: 1,
      bookingDate: '2099-05-12',
      timeslot: '10:30 AM',
      status: 'confirmed',
      doctorId: 7,
      doctorName: 'Dr Sana Rahman',
      doctorSpecialization: 'Cardiology',
    ),
  ];

  static const _doctors = [
    DoctorListing(
      id: 7,
      name: 'Dr Sana Rahman',
      specialization: 'Cardiology',
      departmentName: 'Cardiology',
      availableTime: '10:00 AM - 2:00 PM',
      consultationFee: 500,
      imageUrl: '',
    ),
  ];

  static const _labTests = [
    LabTestItem(
      id: 12,
      testName: 'Complete Blood Count',
      categoryId: 1,
      categoryName: 'Blood',
      status: true,
      basePrice: 450,
      resultEta: '24 hrs',
    ),
  ];

  static const _labPackages = [
    LabPackageItem(
      id: 21,
      name: 'Executive Health Package',
      slug: 'executive-health-package',
      status: true,
      basePrice: 3200,
      discountedPrice: 2800,
      totalTests: 12,
      description: 'A strong preventive screening package.',
      includedTests: ['CBC', 'Lipid Profile'],
    ),
  ];

  static const _banners = [
    HomeBannerItem(
      id: 1,
      title: 'Monsoon Wellness',
      subtitle: 'Stay hydrated and monitor your blood pressure.',
      imageUrl: 'https://example.test/banner.png',
      ctaLabel: 'Explore',
    ),
  ];

  static const _tickerMessages = [
    TickerMessageItem(id: 1, message: 'Free camp on Friday'),
  ];

  static const _offers = [
    HomeOfferItem(
      id: 1,
      title: 'Executive Health Package',
      subtitle: 'Save on your annual preventive checkup',
      gradientFrom: '#0C2C6D',
      gradientTo: '#1A6EAA',
      buttonBorderColor: '#05B3E6',
      ctaLabel: 'View Offer',
    ),
  ];

  static const _departments = [DepartmentItem(id: 1, name: 'Cardiology')];

  @override
  Future<OtpSendResult> sendOtp({required String phone, String? mrn}) async {
    return const OtpSendResult(
      devOtp: '123456',
      message: 'OTP sent to your WhatsApp',
    );
  }

  @override
  Future<OtpSession> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    return const OtpSession(token: 'portal-token', patient: _patient);
  }

  @override
  Future<PatientIdentity> getCurrentPatient() async => _patient;

  @override
  Future<PatientDashboard> getDashboard() async {
    dashboardCalls++;
    return const PatientDashboard(
      patient: _patient,
      metrics: PortalMetrics(
        totalRecords: 3,
        availableRecords: 3,
        processingRecords: 0,
        showingRecords: 3,
        upcomingBookings: 1,
      ),
      recentBookings: _bookings,
      recentPrescriptions: [],
      recentDocuments: [],
      recentSummaries: [],
      idCard: IdCardInfo(
        registrationNumber: 'BHRC-108',
        patientName: 'Amina Patient',
        membershipTier: 'Classic',
        qrValue: 'patient-108',
      ),
      myClub: MyClubSummary(
        patientId: 108,
        points: 240,
        currencyValue: 24,
        tier: 'Classic',
        transactions: [],
      ),
      emergencyContacts: [],
    );
  }

  @override
  Future<List<HomeBannerItem>> getHomeBanners() async => _banners;

  @override
  Future<List<TickerMessageItem>> getTickerMessages() async => _tickerMessages;

  @override
  Future<List<HomeOfferItem>> getHomeOffers() async => _offers;

  @override
  Future<List<BookingItem>> getBookings({int? patientId}) async => _bookings;

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
  Future<List<DoctorListing>> getDoctors() async => _doctors;

  @override
  Future<List<DepartmentItem>> getDepartments() async => _departments;

  @override
  Future<List<LabTestItem>> getLabTests() async => _labTests;

  @override
  Future<List<LabOrderItem>> getLabOrders() async => const [];

  @override
  Future<List<LabPackageItem>> getLabPackages() async => _labPackages;

  @override
  Future<List<LabPackageOrderItem>> getLabPackageOrders() async => const [];

  @override
  Future<List<ChatThreadSummary>> getGlobalChatThreads() async => const [];

  @override
  Future<ChatThreadSummary> createGlobalChatThread({String? title}) async {
    return const ChatThreadSummary(
      id: 'thread-1',
      title: 'New chat',
      messageCount: 0,
    );
  }

  @override
  Future<List<ChatMessage>> getGlobalChatHistory(String threadId) async =>
      const [];

  @override
  Future<MyClubSummary> getMyClub() async => const MyClubSummary(
    patientId: 108,
    points: 240,
    currencyValue: 24,
    tier: 'Classic',
    transactions: [],
  );
  @override
  Future<HealthSnapshot?> getHealthSnapshot() async => null;
  @override
  Future<HealthSnapshotHistoryPage> getHealthSnapshotHistory({
    int page = 1,
  }) async => const HealthSnapshotHistoryPage(
    items: [],
    currentPage: 1,
    lastPage: 1,
    total: 0,
  );
  @override
  Future<List<AiSuggestionItem>> getAiSuggestions() async => const [];
  @override
  Future<List<BodyPointItem>> getBodyPoints() async => const [];
  @override
  Future<List<FamilyMember>> getFamilyMembers() async => const [];
  @override
  Future<List<HomeCareServiceItem>> getHomeCareServices() async => const [];
  @override
  Future<List<HomeCareBookingItem>> getHomeCareBookings({
    int? patientId,
  }) async => const [];
}
