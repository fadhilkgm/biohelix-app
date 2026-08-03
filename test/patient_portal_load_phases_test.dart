import 'dart:async';

import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/home_feed_models.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test(
    'startup can return after critical data while deferred data continues',
    () async {
      final repository = _CountingRepository(pauseDocuments: true);
      final portal = await _authenticatedPortal(repository);

      await portal.loadPortal(waitForDeferred: false);

      expect(portal.dashboard, isNotNull);
      expect(portal.isLoading, isFalse);
      expect(portal.isLoadingDeferred, isTrue);
      expect(repository.calls['documents'], 1);

      repository.releaseDocuments();
      await _waitUntil(() => !portal.isLoadingDeferred);

      expect(portal.isLoadingDeferred, isFalse);
    },
  );

  test('cancelling a booking refreshes only dashboard and bookings', () async {
    final repository = _CountingRepository();
    final portal = await _authenticatedPortal(repository);
    await portal.loadPortal();
    repository.calls.clear();

    await portal.cancelBooking(42);

    expect(repository.calls['cancelBooking'], 1);
    expect(repository.calls['dashboard'], 1);
    expect(repository.calls['bookings'], 1);
    expect(
      repository.calls.keys,
      containsAll(<String>['cancelBooking', 'dashboard', 'bookings']),
    );
    expect(repository.calls.length, 3);
  });
}

Future<PatientPortalProvider> _authenticatedPortal(
  _CountingRepository repository,
) async {
  final session = SessionProvider(
    authStorage: AuthStorage(),
    apiClient: repository.apiClient,
    patientRepository: repository,
  );
  await session.sendOtp(phone: '9998887777');
  await session.verifyOtp(otp: '123456');
  expect(session.isAuthenticated, isTrue);
  return PatientPortalProvider(
    repository: repository,
    sessionProvider: session,
  );
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 20 && !predicate(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(predicate(), isTrue);
}

class _CountingRepository extends PatientRepository {
  _CountingRepository({this.pauseDocuments = false})
    : apiClient = ApiClient(config: _config),
      super(apiClient: ApiClient(config: _config));

  static final _config = AppConfig(
    appName: 'BioHelix Test',
    apiBaseUrl: 'https://example.test/api',
    healthEndpoint: '/health',
    showDevOtp: true,
  );
  static const _patient = PatientIdentity(
    id: 108,
    name: 'Amina Patient',
    phone: '9998887777',
    registrationNumber: 'BHRC-108',
    uuid: 'patient-108',
  );

  final ApiClient apiClient;
  final bool pauseDocuments;
  final Map<String, int> calls = <String, int>{};
  final Completer<void> _documentsGate = Completer<void>();

  void _called(String name) {
    calls.update(name, (count) => count + 1, ifAbsent: () => 1);
  }

  void releaseDocuments() {
    if (!_documentsGate.isCompleted) _documentsGate.complete();
  }

  @override
  Future<OtpSendResult> sendOtp({required String phone, String? mrn}) async {
    return const OtpSendResult(devOtp: '123456', message: 'OTP sent');
  }

  @override
  Future<OtpSession> verifyOtp({
    required String phone,
    required String otp,
  }) async => const OtpSession(token: 'token', patient: _patient);

  @override
  Future<PatientDashboard> getDashboard() async {
    _called('dashboard');
    return PatientDashboard(
      patient: _patient,
      metrics: const PortalMetrics(
        totalRecords: 0,
        availableRecords: 0,
        processingRecords: 0,
        showingRecords: 0,
        upcomingBookings: 0,
      ),
      recentBookings: const [],
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
        points: 0,
        currencyValue: 0,
        tier: 'Classic',
        transactions: [],
      ),
      emergencyContacts: const [],
    );
  }

  @override
  Future<List<HomeBannerItem>> getHomeBanners() async {
    _called('homeBanners');
    return const [];
  }

  @override
  Future<List<BookingItem>> getBookings({int? patientId}) async {
    _called('bookings');
    return const [];
  }

  @override
  Future<List<DoctorListing>> getDoctors() async {
    _called('doctors');
    return const [];
  }

  @override
  Future<List<LabTestItem>> getLabTests() async {
    _called('labTests');
    return const [];
  }

  @override
  Future<List<LabPackageItem>> getLabPackages() async {
    _called('labPackages');
    return const [];
  }

  @override
  Future<List<TickerMessageItem>> getTickerMessages() async {
    _called('tickerMessages');
    return const [];
  }

  @override
  Future<List<HomeOfferItem>> getHomeOffers() async {
    _called('homeOffers');
    return const [];
  }

  @override
  Future<List<DepartmentItem>> getDepartments() async {
    _called('departments');
    return const [];
  }

  @override
  Future<MyClubSummary> getMyClub() async {
    _called('myClub');
    return const MyClubSummary(
      patientId: 108,
      points: 0,
      currencyValue: 0,
      tier: 'Classic',
      transactions: [],
    );
  }

  @override
  Future<HealthSnapshot?> getHealthSnapshot() async {
    _called('healthSnapshot');
    return null;
  }

  @override
  Future<List<AiSuggestionItem>> getAiSuggestions() async {
    _called('aiSuggestions');
    return const [];
  }

  @override
  Future<List<PrescriptionRecord>> getPrescriptions() async {
    _called('prescriptions');
    return const [];
  }

  @override
  Future<List<MedicalRecordItem>> getMedicalRecords() async {
    _called('medicalRecords');
    return const [];
  }

  @override
  Future<List<DocumentRecord>> getDocuments() async {
    _called('documents');
    if (pauseDocuments) await _documentsGate.future;
    return const [];
  }

  @override
  Future<List<SummaryRecord>> getSummaries() async {
    _called('summaries');
    return const [];
  }

  @override
  Future<List<VitalRecord>> getVitalTrend() async {
    _called('vitalTrend');
    return const [];
  }

  @override
  Future<List<LabOrderItem>> getLabOrders() async {
    _called('labOrders');
    return const [];
  }

  @override
  Future<List<LabPackageOrderItem>> getLabPackageOrders() async {
    _called('labPackageOrders');
    return const [];
  }

  @override
  Future<List<BodyPointItem>> getBodyPoints() async {
    _called('bodyPoints');
    return const [];
  }

  @override
  Future<List<FamilyMember>> getFamilyMembers() async {
    _called('familyMembers');
    return const [];
  }

  @override
  Future<List<HomeCareServiceItem>> getHomeCareServices() async {
    _called('homeCareServices');
    return const [];
  }

  @override
  Future<List<HomeCareBookingItem>> getHomeCareBookings({
    int? patientId,
  }) async {
    _called('homeCareBookings');
    return const [];
  }

  @override
  Future<void> cancelBooking(int bookingId) async {
    _called('cancelBooking');
  }
}
