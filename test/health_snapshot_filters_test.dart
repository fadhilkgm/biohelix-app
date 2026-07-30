import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/health_profile/models/health_snapshot_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const snapshots = [
    HealthSnapshot(
      snapshotDate: '2026-07-30',
      riskScore: 20,
      bloodSugar: 96,
      latestVitals: VitalRecord(
        id: 1,
        recordedAt: '2026-07-30T08:00:00Z',
        bloodPressureSystolic: 122,
        bloodPressureDiastolic: 78,
      ),
    ),
    HealthSnapshot(snapshotDate: '2026-07-20', riskScore: 45, cholesterol: 210),
    HealthSnapshot(
      snapshotDate: '2026-06-15',
      riskScore: 70,
      bloodSugar: 148,
      otherConditions: 'Diabetes follow-up',
    ),
  ];

  test('filters snapshot history by date and measurement', () {
    final filtered = filterHealthSnapshots(
      snapshots,
      from: DateTime(2026, 7, 1),
      metric: HealthSnapshotMetricFilter.bloodSugar,
    );

    expect(filtered, hasLength(1));
    expect(filtered.single.snapshotDate, '2026-07-30');
  });

  test('filters snapshot history by pressure and risk band', () {
    final pressure = filterHealthSnapshots(
      snapshots,
      metric: HealthSnapshotMetricFilter.bloodPressure,
    );
    final highRisk = filterHealthSnapshots(
      snapshots,
      risk: HealthSnapshotRiskFilter.high,
    );

    expect(pressure.single.snapshotDate, '2026-07-30');
    expect(highRisk.single.snapshotDate, '2026-06-15');
  });

  test('filters snapshots containing reported conditions', () {
    final filtered = filterHealthSnapshots(
      snapshots,
      metric: HealthSnapshotMetricFilter.conditions,
    );

    expect(filtered.single.otherConditions, 'Diabetes follow-up');
  });

  test('parses a manually entered systolic-only pressure value', () {
    final snapshot = HealthSnapshot.fromJson({
      'snapshot': {
        'snapshot_date': '2026-07-30',
        'latest_vitals': {'bp': 128, 'weight': 72},
      },
    });

    expect(snapshot.latestVitals?.bloodPressureSystolic, 128);
    expect(snapshot.latestVitals?.bloodPressureDiastolic, isNull);
  });
}
