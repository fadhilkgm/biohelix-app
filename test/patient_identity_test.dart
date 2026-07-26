import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('patient identity accepts list health fields from the OTP response', () {
    final patient = PatientIdentity.fromJson({
      'id': 16,
      'name': 'Test Patient',
      'phone': '+910000000001',
      'registrationNumber': 'BHRC-P-TEST',
      'uuid': 'BHRC-CARD-TEST',
      'allergies': ['Sulfonamide antibiotics'],
      'chronicConditions': ['Type 2 diabetes mellitus', 'Mild hypertension'],
    });

    expect(patient.allergies, 'Sulfonamide antibiotics');
    expect(
      patient.chronicConditions,
      'Type 2 diabetes mellitus, Mild hypertension',
    );
  });

  test('patient identity still accepts legacy string health fields', () {
    final patient = PatientIdentity.fromJson({
      'id': 1,
      'name': 'Legacy Patient',
      'phone': '+910000000000',
      'registrationNumber': 'BHRC-P-1',
      'uuid': 'BHRC-CARD-1',
      'allergies': 'Penicillin',
      'chronic_conditions': 'Diabetes',
    });

    expect(patient.allergies, 'Penicillin');
    expect(patient.chronicConditions, 'Diabetes');
  });
}
