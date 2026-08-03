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

  test('patient identity exposes persisted legal consent status', () {
    final pending = PatientIdentity.fromJson({
      'id': 1,
      'name': 'Pending Patient',
    });
    final accepted = PatientIdentity.fromJson({
      'id': 2,
      'name': 'Accepted Patient',
      'legal_consent_accepted_at': '2026-07-31T21:30:00+05:30',
    });

    expect(pending.hasAcceptedLegalConsent, isFalse);
    expect(accepted.hasAcceptedLegalConsent, isTrue);
    expect(
      PatientIdentity.fromJson(accepted.toJson()).hasAcceptedLegalConsent,
      isTrue,
    );
  });

  test('patient identity exposes the one-time health assessment status', () {
    final pending = PatientIdentity.fromJson({
      'id': 1,
      'name': 'New Patient',
      'hasCompletedInitialHealthAssessment': false,
    });
    final completed = PatientIdentity.fromJson({
      'id': 2,
      'name': 'Assessed Patient',
      'initialHealthAssessmentCompletedAt': '2026-08-02T18:00:00+05:30',
    });

    expect(pending.hasCompletedInitialHealthAssessment, isFalse);
    expect(completed.hasCompletedInitialHealthAssessment, isTrue);
  });
}
