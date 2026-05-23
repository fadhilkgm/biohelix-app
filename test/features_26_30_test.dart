import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/core/providers/theme_provider.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/home_feed_models.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';
import 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('26. doctor directory section is visible on home', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    expect(find.text('Find Doctors'), findsOneWidget);
  });

  testWidgets('27. doctor cards include booking CTA', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    expect(find.text('Book Now'), findsWidgets);
  });

  testWidgets('28. doctor cards show profile information', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    expect(find.text('Dr Sana Rahman'), findsWidgets);
    expect(find.text('Cardiology'), findsWidgets);
  });

  testWidgets('29. doctor discovery shows department chips', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Cardiology'), findsWidgets);
  });

  testWidgets('30. bookings tab shows appointment list entries', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('My Bookings'), findsOneWidget);
    expect(find.text('Dr Sana Rahman'), findsWidgets);
  });
}

Future<Widget> _buildHarness() async {
  final repository = _FakePortalRepository();
  final session = SessionProvider(
    authStorage: AuthStorage(),
    apiClient: repository.apiClient,
    patientRepository: repository,
  );
  await session.sendOtp(phone: '9998887777');
  await session.verifyOtp(otp: '123456');

  final portal = PatientPortalProvider(
    repository: repository,
    sessionProvider: session,
  );
  await portal.loadPortal();

  return MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: _testConfig()),
      ChangeNotifierProvider<SessionProvider>.value(value: session),
      ChangeNotifierProvider<PatientPortalProvider>.value(value: portal),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
    ],
    child: const MaterialApp(home: PatientAppShell()),
  );
}

AppConfig _testConfig() => AppConfig(
  appName: 'BioHelix Test',
  apiBaseUrl: 'https://example.test/api',
  healthEndpoint: '/health',
  showDevOtp: true,
);

class _FakePortalRepository extends PatientRepository {
  _FakePortalRepository()
    : apiClient = superApiClient,
      super(apiClient: superApiClient);

  static final superApiClient = ApiClient(config: _testConfig());
  final ApiClient apiClient;

  static const _patient = PatientIdentity(
    id: 108,
    name: 'Amina Patient',
    phone: '9998887777',
    registrationNumber: 'BHRC-108',
    uuid: 'patient-108',
  );

  static String _getFutureDateString(int daysAhead) {
    final futureDate = DateTime.now().add(Duration(days: daysAhead));
    final yyyy = futureDate.year.toString();
    final mm = futureDate.month.toString().padLeft(2, '0');
    final dd = futureDate.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  static List<BookingItem> get _bookings => [
    BookingItem(
      id: 1,
      bookingDate: _getFutureDateString(2),
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

  @override
  Future<List<String>> getDoctorAvailableSlots({
    required int doctorId,
    required String date,
  }) async => const ['09:00 AM - 09:30 AM', '10:00 AM - 10:30 AM'];

  @override
  Future<String?> sendOtp({required String phone, String? mrn}) async => '123456';

  @override
  Future<OtpSession> verifyOtp({required String phone, required String otp}) async =>
      const OtpSession(token: 'portal-token', patient: _patient);

  @override
  Future<PatientIdentity> getCurrentPatient() async => _patient;

  @override
  Future<PatientDashboard> getDashboard() async => PatientDashboard(
    patient: _patient,
    metrics: const PortalMetrics(
      totalRecords: 3,
      availableRecords: 3,
      processingRecords: 0,
      showingRecords: 3,
      upcomingBookings: 1,
    ),
    recentBookings: _bookings,
    recentPrescriptions: const [],
    recentDocuments: const [],
    recentSummaries: const [],
    idCard: const IdCardInfo(
      registrationNumber: 'BHRC-108',
      patientName: 'Amina Patient',
      membershipTier: 'Classic',
      qrValue: 'patient-108',
    ),
    myClub: const MyClubSummary(
      patientId: 108,
      points: 240,
      currencyValue: 24,
      tier: 'Classic',
      transactions: [],
    ),
    emergencyContacts: const [],
  );

  @override
  Future<List<BookingItem>> getBookings() async => _bookings;
  @override
  Future<List<DoctorListing>> getDoctors() async => _doctors;
  @override
  Future<List<DepartmentItem>> getDepartments() async =>
      const [DepartmentItem(id: 1, name: 'Cardiology')];
  @override
  Future<List<HomeBannerItem>> getHomeBanners() async =>
      const [HomeBannerItem(id: 1, title: 'Monsoon Wellness', imageUrl: '')];
  @override
  Future<List<TickerMessageItem>> getTickerMessages() async =>
      const [TickerMessageItem(id: 1, message: 'Free camp on Friday')];
  @override
  Future<List<HomeOfferItem>> getHomeOffers() async => const [];
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
  Future<ChatThreadSummary> createGlobalChatThread({String? title}) async =>
      const ChatThreadSummary(id: 'thread-1', title: 'New chat', messageCount: 0);
  @override
  Future<List<ChatMessage>> getGlobalChatHistory(String threadId) async => const [];
}
