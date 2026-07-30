import '../../core/models/patient_models.dart';

enum HealthSnapshotMetricFilter {
  all('All readings'),
  bloodSugar('Blood sugar'),
  bloodPressure('Blood pressure'),
  cholesterol('Cholesterol'),
  bmi('BMI'),
  conditions('Conditions');

  const HealthSnapshotMetricFilter(this.label);

  final String label;
}

enum HealthSnapshotRiskFilter {
  all('All risk scores'),
  low('Risk 0–29'),
  moderate('Risk 30–59'),
  high('Risk 60+');

  const HealthSnapshotRiskFilter(this.label);

  final String label;
}

List<HealthSnapshot> filterHealthSnapshots(
  Iterable<HealthSnapshot> snapshots, {
  DateTime? from,
  DateTime? to,
  HealthSnapshotMetricFilter metric = HealthSnapshotMetricFilter.all,
  HealthSnapshotRiskFilter risk = HealthSnapshotRiskFilter.all,
}) {
  final normalizedFrom = from == null
      ? null
      : DateTime(from.year, from.month, from.day);
  final normalizedTo = to == null ? null : DateTime(to.year, to.month, to.day);

  return snapshots
      .where((snapshot) {
        final rawDate = snapshot.snapshotDate;
        final parsedDate = rawDate == null ? null : DateTime.tryParse(rawDate);
        final date = parsedDate == null
            ? null
            : DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

        if (normalizedFrom != null &&
            (date == null || date.isBefore(normalizedFrom))) {
          return false;
        }
        if (normalizedTo != null &&
            (date == null || date.isAfter(normalizedTo))) {
          return false;
        }

        if (!_matchesMetric(snapshot, metric)) return false;
        if (!_matchesRisk(snapshot.riskScore, risk)) return false;

        return true;
      })
      .toList(growable: false);
}

bool _matchesMetric(
  HealthSnapshot snapshot,
  HealthSnapshotMetricFilter filter,
) {
  return switch (filter) {
    HealthSnapshotMetricFilter.all => true,
    HealthSnapshotMetricFilter.bloodSugar => snapshot.bloodSugar != null,
    HealthSnapshotMetricFilter.bloodPressure =>
      snapshot.latestVitals?.bloodPressureSystolic != null ||
          snapshot.latestVitals?.bloodPressureDiastolic != null,
    HealthSnapshotMetricFilter.cholesterol => snapshot.cholesterol != null,
    HealthSnapshotMetricFilter.bmi => snapshot.bmi != null,
    HealthSnapshotMetricFilter.conditions =>
      (snapshot.otherConditions ?? '').trim().isNotEmpty,
  };
}

bool _matchesRisk(double? score, HealthSnapshotRiskFilter filter) {
  if (filter == HealthSnapshotRiskFilter.all) return true;
  if (score == null) return false;

  return switch (filter) {
    HealthSnapshotRiskFilter.all => true,
    HealthSnapshotRiskFilter.low => score < 30,
    HealthSnapshotRiskFilter.moderate => score >= 30 && score < 60,
    HealthSnapshotRiskFilter.high => score >= 60,
  };
}
