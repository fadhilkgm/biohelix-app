import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const labRecord = MedicalRecordItem(
    id: 'lab-1',
    sourceType: 'document',
    category: 'lab',
    recordType: 'Lab Report',
    title: 'Blood report',
    subtitle: 'AI-generated private summary',
    status: 'available',
    date: '2026-08-05',
    kindLabel: 'Blood Report',
    summary: 'AI-generated private summary',
  );
  const summaryRecord = MedicalRecordItem(
    id: 'summary-1',
    sourceType: 'summary',
    category: 'summary',
    recordType: 'AI Summary',
    title: 'Health Summary',
    subtitle: 'Generated overview',
    status: 'available',
    date: '2026-08-05',
    kindLabel: 'AI Summary',
    summary: 'Generated overview',
  );

  test('Medical Records excludes summary records', () {
    final visible = medicalRecordsForDisplay([labRecord, summaryRecord]);

    expect(visible, [labRecord]);
  });

  test('Medical Records does not use summary text as a card subtitle', () {
    expect(medicalRecordSubtitleForDisplay(labRecord), 'Blood Report');
    expect(
      medicalRecordSubtitleForDisplay(
        const MedicalRecordItem(
          id: 'prescription-1',
          sourceType: 'prescription',
          category: 'prescription',
          recordType: 'Prescription',
          title: 'Prescription',
          subtitle: 'Hidden summary',
          status: 'available',
          date: '2026-08-05',
          kindLabel: 'Prescription',
          doctorName: 'Dr Amina',
          summary: 'Hidden summary',
        ),
      ),
      'Dr Amina',
    );
  });
}
