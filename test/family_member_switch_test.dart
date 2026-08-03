import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test('linked family member switches without requesting an otp', () async {
    final repository = _FamilySwitchRepository();
    final session = SessionProvider(
      authStorage: AuthStorage(),
      apiClient: repository.apiClient,
      patientRepository: repository,
    );

    await session.switchLinkedFamilyMember(42);

    expect(repository.switchedLinkId, 42);
    expect(repository.otpRequestCount, 0);
    expect(session.state, SessionState.signedIn);
    expect(session.authToken, 'mother-family-token');
    expect(session.patient?.id, 2);
    expect(session.patient?.name, 'Mother Patient');
    expect(session.familyProfiles.single.patient.id, 2);
    expect(
      await SharedPreferences.getInstance().then(
        (preferences) => preferences.getString('auth_token'),
      ),
      'mother-family-token',
    );
  });
}

class _FamilySwitchRepository extends PatientRepository {
  factory _FamilySwitchRepository() {
    final apiClient = ApiClient(
      config: AppConfig(
        appName: 'BioHelix Test',
        apiBaseUrl: 'https://example.test/api',
        healthEndpoint: '/health',
        showDevOtp: false,
      ),
    );
    return _FamilySwitchRepository._(apiClient);
  }

  _FamilySwitchRepository._(this.apiClient) : super(apiClient: apiClient);

  final ApiClient apiClient;
  int? switchedLinkId;
  int otpRequestCount = 0;

  @override
  Future<PatientAuthSession> switchToFamilyMember(int linkId) async {
    switchedLinkId = linkId;
    return const PatientAuthSession(
      token: 'mother-family-token',
      patient: PatientIdentity(
        id: 2,
        name: 'Mother Patient',
        phone: '+919999999999',
        registrationNumber: 'PAT-MOTHER',
        uuid: 'BHRC-MOTHER',
      ),
    );
  }

  @override
  Future<OtpSendResult> sendOtp({required String phone, String? mrn}) async {
    otpRequestCount += 1;
    return const OtpSendResult(devOtp: '123456');
  }
}
