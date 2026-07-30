import 'dart:convert';

import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/lab_booking/state/lab_booking_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test('lab booking defaults to the globally active patient details', () {
    final controller = LabBookingController(
      patientName: 'Switched Patient',
      patientPhone: '9876543210',
      patientAge: 47,
      patientGender: 'female',
      tests: const [],
      bodyPoints: const [],
    );

    expect(controller.selectedPatient.name, 'Switched Patient');
    expect(controller.selectedPatient.phone, '9876543210');
    expect(controller.selectedPatient.age, 47);
    expect(controller.selectedPatient.gender, 'female');
    expect(controller.selectedPatientId, 'self');
  });

  test('missing demographics are not replaced with fabricated defaults', () {
    final controller = LabBookingController(
      patientName: 'Switched Patient',
      tests: const [],
      bodyPoints: const [],
    );

    expect(controller.selectedPatient.age, 0);
    expect(controller.selectedPatient.gender, isEmpty);
  });

  test('switching profiles replaces the active token and patient', () async {
    const first = _firstPatient;
    const second = _secondPatient;
    final profiles = _savedProfiles(first, second);
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token-a',
      'family_profiles': profiles
          .map((profile) => jsonEncode(profile.toJson()))
          .toList(),
    });
    final apiClient = _apiClient();
    final repository = _SwitchRepository(
      apiClient: apiClient,
      responses: [first, second],
    );
    final session = SessionProvider(
      authStorage: AuthStorage(),
      apiClient: apiClient,
      patientRepository: repository,
    );

    await session.initialize();
    await session.switchFamilyProfile('token-b');

    expect(session.authToken, 'token-b');
    expect(session.patient?.id, second.id);
    expect(session.state, SessionState.signedIn);
  });

  test('failed switch restores the exact previous session', () async {
    const first = _firstPatient;
    const second = _secondPatient;
    final profiles = _savedProfiles(first, second);
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token-a',
      'family_profiles': profiles
          .map((profile) => jsonEncode(profile.toJson()))
          .toList(),
    });
    final apiClient = _apiClient();
    final repository = _SwitchRepository(
      apiClient: apiClient,
      responses: [first],
      failAfterResponses: true,
    );
    final session = SessionProvider(
      authStorage: AuthStorage(),
      apiClient: apiClient,
      patientRepository: repository,
    );

    await session.initialize();

    await expectLater(
      session.switchFamilyProfile('token-b'),
      throwsA(isA<StateError>()),
    );
    expect(session.authToken, 'token-a');
    expect(session.patient?.id, first.id);
    expect(session.state, SessionState.signedIn);
    expect(session.familyProfiles, hasLength(2));
  });
}

const _firstPatient = PatientIdentity(
  id: 1,
  name: 'First Patient',
  phone: '1111111111',
  registrationNumber: 'BHRC-1',
  uuid: 'patient-1',
);

const _secondPatient = PatientIdentity(
  id: 2,
  name: 'Second Patient',
  phone: '2222222222',
  registrationNumber: 'BHRC-2',
  uuid: 'patient-2',
);

List<SavedPatientProfile> _savedProfiles(
  PatientIdentity first,
  PatientIdentity second,
) {
  return [
    SavedPatientProfile(
      token: 'token-a',
      patient: first,
      lastUsedAt: '2026-07-30T10:00:00.000Z',
    ),
    SavedPatientProfile(
      token: 'token-b',
      patient: second,
      lastUsedAt: '2026-07-29T10:00:00.000Z',
    ),
  ];
}

ApiClient _apiClient() {
  return ApiClient(
    config: AppConfig(
      appName: 'Test',
      apiBaseUrl: 'https://example.test/api/v1',
      healthEndpoint: '/health',
      showDevOtp: false,
    ),
  );
}

class _SwitchRepository extends PatientRepository {
  _SwitchRepository({
    required super.apiClient,
    required List<PatientIdentity> responses,
    this.failAfterResponses = false,
  }) : _responses = List.of(responses);

  final List<PatientIdentity> _responses;
  final bool failAfterResponses;

  @override
  Future<PatientIdentity> getCurrentPatient() async {
    if (_responses.isNotEmpty) {
      return _responses.removeAt(0);
    }
    if (failAfterResponses) {
      throw StateError('Selected patient token expired.');
    }
    throw StateError('No patient response configured.');
  }
}
