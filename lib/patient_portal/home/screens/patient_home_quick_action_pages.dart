part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _HealthTrendsPage extends StatelessWidget {
  const _HealthTrendsPage({required this.showAiInsights});

  final bool showAiInsights;

  @override
  Widget build(BuildContext context) {
    final title = showAiInsights ? 'AI Trend Analysis' : 'Health Trends';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Consumer2<SessionProvider, PatientPortalProvider>(
        builder: (context, session, portal, _) {
          final vitals = portal.vitalTrend;
          final latest = vitals.isNotEmpty ? vitals.last : null;
          final previous = vitals.length > 1 ? vitals[vitals.length - 2] : null;
          final documents = portal.documents;
          final analyzedDocuments = documents
              .where((item) => item.hasAnalysis)
              .toList(growable: false);
          final insights = _buildTrendInsights(
            patient: session.patient,
            portal: portal,
            latest: latest,
            previous: previous,
            analyzedDocuments: analyzedDocuments.length,
            useAiTone: showAiInsights,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _TrendHeroCard(
                title: title,
                subtitle: showAiInsights
                    ? 'Summaries combine recent vitals and analyzed reports.'
                    : 'Track the latest changes across your core health signals.',
                vitalCount: vitals.length,
                analyzedDocumentCount: analyzedDocuments.length,
              ),
              const SizedBox(height: 16),
              _TrendMetricGrid(latest: latest, previous: previous),
              const SizedBox(height: 16),
              _TrendInsightCard(title: 'Highlights', items: insights),
              if (analyzedDocuments.isNotEmpty) ...[
                const SizedBox(height: 16),
                _RecentAnalysisCard(documents: analyzedDocuments),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AiPackageDesignPage extends StatelessWidget {
  const _AiPackageDesignPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Package Design')),
      body: Consumer2<SessionProvider, PatientPortalProvider>(
        builder: (context, session, portal, _) {
          final patient = session.patient;
          if (patient == null) {
            return const SizedBox.shrink();
          }

          final latestVitals = portal.vitalTrend.isNotEmpty
              ? portal.vitalTrend.last
              : null;
          final bmi =
              latestVitals?.bmi ??
              _calculateBmi(latestVitals?.height, latestVitals?.weight);
          final goal = _resolvePlannerGoal(patient.chronicConditions ?? '');
          final plan = _buildPeriodicPlan(
            age: patient.age ?? _inferAge(patient.dob),
            bmi: bmi,
            goal: goal,
            hasSymptoms: false,
            conditions: patient.chronicConditions ?? '',
            concerns: patient.allergies ?? '',
            wantsYearlyPlan: true,
            documentCount: portal.documents.length,
            labOrderCount: portal.labOrders.length,
          );
          final packages = _recommendedPackages(portal.labPackages, goal);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _PackagePlanHero(
                plan: plan,
                goal: goal,
                patientName: patient.name,
              ),
              const SizedBox(height: 16),
              _TrendInsightCard(
                title: 'Suggested tests',
                items: plan.tests
                    .take(4)
                    .map((test) => '${test.name} • ${test.reason}')
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              _TrendInsightCard(
                title: 'Care plan notes',
                items: [
                  plan.summary,
                  plan.doctorConsultReason,
                  ...plan.healthTips.take(2),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Recommended packages',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (packages.isEmpty)
                _EmptyPackageCard(onTap: () => _openPackageLanding(context))
              else
                ...packages.map(
                  (package) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RecommendedPackageCard(
                      package: package,
                      onTap: () => _openPackageLanding(context, package),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _openPackageLanding(BuildContext context, [LabPackageItem? package]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _BannerPackageLandingPage(
          packageTarget: package?.slug,
          isSpecific: package != null,
          package: package,
        ),
      ),
    );
  }
}

class _TrendHeroCard extends StatelessWidget {
  const _TrendHeroCard({
    required this.title,
    required this.subtitle,
    required this.vitalCount,
    required this.analyzedDocumentCount,
  });

  final String title;
  final String subtitle;
  final int vitalCount;
  final int analyzedDocumentCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PillLabel(label: '$vitalCount vital snapshots'),
                _PillLabel(label: '$analyzedDocumentCount analyzed reports'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendMetricGrid extends StatelessWidget {
  const _TrendMetricGrid({required this.latest, required this.previous});

  final VitalRecord? latest;
  final VitalRecord? previous;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricSummary(
        'BMI',
        _metricValue(latest?.bmi, 1),
        _metricDelta(latest?.bmi, previous?.bmi, 1),
      ),
      _MetricSummary(
        'Weight',
        _metricValue(latest?.weight, 1, suffix: 'kg'),
        _metricDelta(latest?.weight, previous?.weight, 1, suffix: 'kg'),
      ),
      _MetricSummary(
        'Heart Rate',
        _metricValue(latest?.heartRate, 0, suffix: 'bpm'),
        _metricDelta(
          latest?.heartRate?.toDouble(),
          previous?.heartRate?.toDouble(),
          0,
          suffix: 'bpm',
        ),
      ),
      _MetricSummary(
        'BP',
        _bloodPressure(latest),
        _bloodPressureDelta(latest, previous),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemBuilder: (context, index) =>
          _TrendMetricCard(summary: metrics[index]),
    );
  }
}

class _TrendInsightCard extends StatelessWidget {
  const _TrendInsightCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentAnalysisCard extends StatelessWidget {
  const _RecentAnalysisCard({required this.documents});

  final List<DocumentRecord> documents;

  @override
  Widget build(BuildContext context) {
    return _TrendInsightCard(
      title: 'Recent AI summaries',
      items: documents
          .take(3)
          .map((document) {
            final summary = (document.summary ?? '').trim();
            final preview = summary.isEmpty
                ? 'Analysis is available in the report view.'
                : summary;
            return '${document.documentType.toUpperCase()} • $preview';
          })
          .toList(growable: false),
    );
  }
}

class _PackagePlanHero extends StatelessWidget {
  const _PackagePlanHero({
    required this.plan,
    required this.goal,
    required this.patientName,
  });

  final _PeriodicPlan plan;
  final String goal;
  final String patientName;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Designed for $patientName',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              plan.headline,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(plan.summary),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PillLabel(label: 'Goal: $goal'),
                _PillLabel(label: 'Risk score ${plan.riskScore}'),
                _PillLabel(label: plan.tier),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedPackageCard extends StatelessWidget {
  const _RecommendedPackageCard({required this.package, required this.onTap});

  final LabPackageItem package;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = (package.discountedPrice ?? package.basePrice)
        .toStringAsFixed(0);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        title: Text(
          package.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          package.description ?? package.category ?? 'Preventive package',
        ),
        trailing: FilledButton(onPressed: onTap, child: Text('Book ₹$amount')),
      ),
    );
  }
}

class _EmptyPackageCard extends StatelessWidget {
  const _EmptyPackageCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No tailored package match yet.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open the full package catalog to review the latest preventive bundles.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onTap,
              child: const Text('Browse packages'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _TrendMetricCard extends StatelessWidget {
  const _TrendMetricCard({required this.summary});

  final _MetricSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary.label, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              summary.value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(summary.delta, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MetricSummary {
  const _MetricSummary(this.label, this.value, this.delta);

  final String label;
  final String value;
  final String delta;
}

List<String> _buildTrendInsights({
  required PatientIdentity? patient,
  required PatientPortalProvider portal,
  required VitalRecord? latest,
  required VitalRecord? previous,
  required int analyzedDocuments,
  required bool useAiTone,
}) {
  final insights = <String>[];
  final bmi = latest?.bmi ?? _calculateBmi(latest?.height, latest?.weight);
  if (bmi != null) {
    insights.add(
      useAiTone
          ? 'Current BMI is ${bmi.toStringAsFixed(1)} (${_bmiLabel(bmi)}), which helps frame the next screening package.'
          : 'Current BMI is ${bmi.toStringAsFixed(1)} (${_bmiLabel(bmi)}).',
    );
  }
  if (latest?.bloodPressureSystolic != null &&
      previous?.bloodPressureSystolic != null) {
    final change =
        latest!.bloodPressureSystolic! - previous!.bloodPressureSystolic!;
    insights.add(
      'Systolic blood pressure changed by $change mmHg since the prior reading.',
    );
  }
  if (analyzedDocuments > 0) {
    insights.add(
      '$analyzedDocuments report summaries are available for follow-up questions.',
    );
  }
  if ((patient?.chronicConditions ?? '').trim().isNotEmpty) {
    insights.add('Known conditions on file: ${patient!.chronicConditions}.');
  }
  if (portal.vitalTrend.isEmpty) {
    insights.add(
      'No vitals history yet. Save vitals in Profile to improve trend tracking.',
    );
  }
  return insights.isEmpty
      ? <String>[
          'Add vitals and upload analyzed reports to unlock more useful trend insights.',
        ]
      : insights;
}

String _metricValue(num? value, int decimals, {String suffix = ''}) {
  if (value == null) return 'No data';
  final formatted = decimals == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(decimals);
  return suffix.isEmpty ? formatted : '$formatted $suffix';
}

String _metricDelta(
  double? latest,
  double? previous,
  int decimals, {
  String suffix = '',
}) {
  if (latest == null || previous == null) return 'Waiting for another reading';
  final delta = latest - previous;
  final prefix = delta >= 0 ? '+' : '';
  final formatted = delta.toStringAsFixed(decimals);
  return '$prefix$formatted ${suffix.isEmpty ? '' : suffix} vs previous'.trim();
}

String _bloodPressure(VitalRecord? record) {
  final systolic = record?.bloodPressureSystolic;
  final diastolic = record?.bloodPressureDiastolic;
  if (systolic == null || diastolic == null) return 'No data';
  return '$systolic/$diastolic mmHg';
}

String _bloodPressureDelta(VitalRecord? latest, VitalRecord? previous) {
  if (latest?.bloodPressureSystolic == null ||
      previous?.bloodPressureSystolic == null) {
    return 'Waiting for another reading';
  }
  final delta =
      latest!.bloodPressureSystolic! - previous!.bloodPressureSystolic!;
  final prefix = delta >= 0 ? '+' : '';
  return '$prefix$delta systolic vs previous';
}

String _resolvePlannerGoal(String conditions) {
  final normalized = conditions.toLowerCase();
  if (normalized.contains('diabetes')) return 'Diabetes';
  if (normalized.contains('thyroid')) return 'Thyroid';
  if (normalized.contains('heart') || normalized.contains('card')) {
    return 'Cardiac';
  }
  if (normalized.contains('weight') || normalized.contains('obesity')) {
    return 'Weight';
  }
  return 'General';
}

int _inferAge(String? dob) {
  final parsed = DateTime.tryParse(dob ?? '');
  if (parsed == null) return 30;
  final now = DateTime.now();
  var age = now.year - parsed.year;
  final hadBirthday =
      now.month > parsed.month ||
      (now.month == parsed.month && now.day >= parsed.day);
  if (!hadBirthday) age -= 1;
  return age.clamp(0, 120);
}

List<LabPackageItem> _recommendedPackages(
  List<LabPackageItem> packages,
  String goal,
) {
  if (packages.isEmpty) return const [];
  final normalizedGoal = goal.toLowerCase();
  final matches = packages
      .where((item) {
        final haystack = '${item.name} ${item.slug} ${item.category ?? ''}'
            .toLowerCase();
        return haystack.contains(normalizedGoal);
      })
      .toList(growable: false);
  if (matches.isNotEmpty) return matches.take(3).toList(growable: false);
  return packages.take(3).toList(growable: false);
}
