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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    GoogleFonts.config.allowRuntimeFetching = false;
    _mockVoiceChannels();
  });

  testWidgets('31. bookings tab opens appointment list', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('My Bookings'), findsOneWidget);
    expect(find.text('Dr Sana Rahman'), findsWidgets);
  });

  testWidgets('32. bookings supports Consultations filter', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consultations'));
    await tester.pumpAndSettle();
    expect(find.text('Dr Sana Rahman'), findsWidgets);
  });

  testWidgets('33. bookings supports Lab Tests filter', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab Tests'));
    await tester.pumpAndSettle();
    expect(find.text('CBC Lab Order'), findsWidgets);
  });

  testWidgets('34. bookings supports Packages filter', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Packages'));
    await tester.pumpAndSettle();
    expect(find.text('Executive Health Package'), findsWidgets);
  });

  testWidgets('35. booking card shows management actions', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr Sana Rahman').first);
    await tester.pumpAndSettle();
    expect(find.text('Reschedule'), findsWidgets);
    expect(find.text('Cancel'), findsWidgets);
  });

  testWidgets('36. cancelling appointment triggers repository call', (tester) async {
    final repo = _FakePortalRepository();
    await tester.pumpWidget(await _buildHarness(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr Sana Rahman').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, Cancel').first);
    await tester.pumpAndSettle();
    expect(repo.cancelBookingCalls, 1);
  });

  testWidgets('37. reschedule action opens appointment sheet', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr Sana Rahman').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reschedule').first);
    await tester.pumpAndSettle();
    expect(find.text('Reschedule'), findsWidgets);
    expect(find.text('Confirm Reschedule'), findsOneWidget);
  });

  testWidgets('38. bookings shows lab order actions', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab Tests'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CBC Lab Order').first);
    await tester.pumpAndSettle();
    expect(find.text('Reschedule'), findsWidgets);
    expect(find.text('Cancel'), findsWidgets);
  });

  testWidgets('39. bookings shows package order actions', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Packages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Executive Health Package').first);
    await tester.pumpAndSettle();
    expect(find.text('Reschedule'), findsWidgets);
    expect(find.text('Cancel'), findsWidgets);
  });

  testWidgets('40. bookings timeline can switch to History', (tester) async {
    await tester.pumpWidget(await _buildHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('My Bookings'), findsOneWidget);
  });
}

void _mockVoiceChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async => null);
  messenger.setMockMethodCallHandler(
    const MethodChannel('speech_to_text_windows'),
    (call) async {
      if (call.method == 'initialize' || call.method == 'hasPermission') return true;
      return null;
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugin.csdcorp.com/speech_to_text'),
    (call) async {
      if (call.method == 'initialize' || call.method == 'hasPermission') return true;
      return null;
    },
  );
  messenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.audio_session'), (call) async => null);
}

Future<Widget> _buildHarness({_FakePortalRepository? repository}) async {
  final repo = repository ?? _FakePortalRepository();
  final session = SessionProvider(
    authStorage: AuthStorage(),
    apiClient: repo.apiClient,
    patientRepository: repo,
  );
  await session.sendOtp(phone: '9998887777');
  await session.verifyOtp(otp: '123456');
  final portal = PatientPortalProvider(repository: repo, sessionProvider: session);
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
  _FakePortalRepository() : apiClient = superApiClient, super(apiClient: superApiClient);
  static final superApiClient = ApiClient(config: _testConfig());
  final ApiClient apiClient;
  int cancelBookingCalls = 0;

  static const _patient = PatientIdentity(
    id: 108, name: 'Amina Patient', phone: '9998887777', registrationNumber: 'BHRC-108', uuid: 'patient-108');

  static String _getFutureDateString(int daysAhead) {
    final futureDate = DateTime.now().add(Duration(days: daysAhead));
    final yyyy = futureDate.year.toString();
    final mm = futureDate.month.toString().padLeft(2, '0');
    final dd = futureDate.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  static List<BookingItem> get _bookings => [
    BookingItem(
      id: 1, bookingDate: _getFutureDateString(2), timeslot: '10:30 AM', status: 'confirmed',
      doctorId: 7, doctorName: 'Dr Sana Rahman', doctorSpecialization: 'Cardiology')
  ];

  @override
  Future<void> cancelBooking(int bookingId) async {
    cancelBookingCalls++;
  }

  @override
  Future<List<String>> getDoctorAvailableSlots({
    required int doctorId,
    required String date,
  }) async => const ['09:00 AM - 09:30 AM', '10:00 AM - 10:30 AM'];

  @override
  Future<OtpSendResult> sendOtp({required String phone, String? mrn}) async {
    return const OtpSendResult(devOtp: '123456', message: 'OTP sent to your WhatsApp');
  }
  @override
  Future<OtpSession> verifyOtp({required String phone, required String otp}) async =>
      const OtpSession(token: 'portal-token', patient: _patient);
  @override
  Future<PatientIdentity> getCurrentPatient() async => _patient;
  @override
  Future<PatientDashboard> getDashboard() async => PatientDashboard(
    patient: _patient,
    metrics: const PortalMetrics(totalRecords: 3, availableRecords: 3, processingRecords: 0, showingRecords: 3, upcomingBookings: 1),
    recentBookings: _bookings, recentPrescriptions: const [], recentDocuments: const [], recentSummaries: const [],
    idCard: const IdCardInfo(registrationNumber: 'BHRC-108', patientName: 'Amina Patient', membershipTier: 'Classic', qrValue: 'patient-108'),
    myClub: const MyClubSummary(patientId: 108, points: 240, currencyValue: 24, tier: 'Classic', transactions: []),
    emergencyContacts: const []);
  @override
  Future<List<BookingItem>> getBookings() async => _bookings;
  @override
  Future<List<LabOrderItem>> getLabOrders() async => [
    LabOrderItem(
      id: 11,
      date: _getFutureDateString(3),
      status: 'confirmed',
      testId: 101,
      testName: 'CBC Lab Order',
      doctorId: 7,
      doctorName: 'Dr Sana Rahman',
      slot: '09:00 - 10:00 AM',
    )
  ];
  @override
  Future<List<LabPackageOrderItem>> getLabPackageOrders() async => [
    LabPackageOrderItem(
      id: 21,
      date: _getFutureDateString(4),
      status: 'confirmed',
      packageId: 201,
      packageName: 'Executive Health Package',
      doctorId: 7,
      doctorName: 'Dr Sana Rahman',
      slot: '10:00 - 11:00 AM',
    )
  ];
  @override
  Future<List<DoctorListing>> getDoctors() async => const [
    DoctorListing(id: 7, name: 'Dr Sana Rahman', specialization: 'Cardiology', departmentName: 'Cardiology', availableTime: '10:00 AM - 2:00 PM', consultationFee: 500, imageUrl: '')
  ];
  @override
  Future<List<DepartmentItem>> getDepartments() async => const [DepartmentItem(id: 1, name: 'Cardiology')];
  @override
  Future<List<HomeBannerItem>> getHomeBanners() async => const [HomeBannerItem(id: 1, title: 'Monsoon', imageUrl: '')];
  @override
  Future<List<TickerMessageItem>> getTickerMessages() async => const [TickerMessageItem(id: 1, message: 'Free camp on Friday')];
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
  Future<List<LabPackageItem>> getLabPackages() async => const [];
  @override
  Future<List<ChatThreadSummary>> getGlobalChatThreads() async => const [];
  @override
  Future<ChatThreadSummary> createGlobalChatThread({String? title}) async =>
      const ChatThreadSummary(id: 'thread-1', title: 'New chat', messageCount: 0);
  @override
  Future<List<ChatMessage>> getGlobalChatHistory(String threadId) async => const [];
}
