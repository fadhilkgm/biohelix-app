import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/widgets/app_chevron_back_button.dart';
import '../../core/models/patient_models.dart';
import '../../core/providers/patient_portal_provider.dart';
import 'health_snapshot_screen.dart';

class HealthStatusTab extends StatefulWidget {
  const HealthStatusTab({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<HealthStatusTab> createState() => _HealthStatusTabState();
}

class _HealthStatusTabState extends State<HealthStatusTab> {
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final portal = context.read<PatientPortalProvider>();
      if (portal.healthSnapshotHistory.isEmpty) {
        portal.loadHealthSnapshotHistory();
      }
    });
  }

  DateTime? _dateOf(HealthSnapshot snapshot) {
    final raw = snapshot.snapshotDate;
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> _pickDate({
    required bool isFrom,
    required DateTime firstDate,
    required DateTime lastDate,
    required DateTime initialDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to != null && picked.isAfter(_to!)) _to = picked;
      } else {
        _to = picked;
        if (_from != null && picked.isBefore(_from!)) _from = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    return Consumer<PatientPortalProvider>(
      builder: (context, portal, _) {
        final dated =
            portal.healthSnapshotHistory
                .where((snapshot) => _dateOf(snapshot) != null)
                .toList()
              ..sort((a, b) => _dateOf(a)!.compareTo(_dateOf(b)!));

        if (portal.isLoadingHealthSnapshotHistory && dated.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (dated.isEmpty) {
          return _EmptyHealthStatus(
            message: strings.noHealthStatusData,
            onRefresh: portal.loadHealthSnapshotHistory,
          );
        }

        final oldest = _dateOf(dated.first)!;
        final newest = _dateOf(dated.last)!;
        final from = _from ?? oldest;
        final to = _to ?? newest;
        final selected = dated.where((snapshot) {
          final date = _dateOf(snapshot)!;
          return !date.isBefore(from) && !date.isAfter(to);
        }).toList();
        final currentSnapshot = dated.last;
        final recentSnapshots = dated.reversed.take(5).toList(growable: false);
        final hasMoreSnapshots =
            dated.length > recentSnapshots.length ||
            portal.hasMoreHealthSnapshotHistory;

        return RefreshIndicator(
          onRefresh: portal.loadHealthSnapshotHistory,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
            children: [
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: AppChevronBackButton(onPressed: widget.onBack),
              ),
              const SizedBox(height: 10),
              Text(
                strings.healthStatus,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF192233),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.healthStatusSubtitle,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF617086),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              _CurrentHealthValuesCard(
                snapshot: currentSnapshot,
                strings: strings,
              ),
              const SizedBox(height: 18),
              _ComprehensiveSummaryCard(
                snapshots: selected,
                fallbackSnapshot: currentSnapshot,
                from: from,
                to: to,
                strings: strings,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _DateSelector(
                      label: strings.fromDate,
                      date: from,
                      onTap: () => _pickDate(
                        isFrom: true,
                        firstDate: oldest,
                        lastDate: newest,
                        initialDate: from,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateSelector(
                      label: strings.toDate,
                      date: to,
                      onTap: () => _pickDate(
                        isFrom: false,
                        firstDate: oldest,
                        lastDate: newest,
                        initialDate: to,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _HealthTrendCard(snapshots: selected, strings: strings),
              const SizedBox(height: 18),
              _SnapshotUpdatesCard(
                snapshots: recentSnapshots,
                hasMore: hasMoreSnapshots,
                onViewAll: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HealthSnapshotHistoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDDE5EF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF6B788B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: Color(0xFF06489B),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      DateFormat('dd MMM yyyy').format(date),
                      style: const TextStyle(
                        color: Color(0xFF192233),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthTrendCard extends StatelessWidget {
  const _HealthTrendCard({required this.snapshots, required this.strings});

  final List<HealthSnapshot> snapshots;
  final LocalizedStrings strings;

  @override
  Widget build(BuildContext context) {
    final points = snapshots
        .where((snapshot) => snapshot.healthScore != null)
        .map(
          (snapshot) => _HealthPoint(
            date: DateTime.parse(snapshot.snapshotDate!),
            score: snapshot.healthScore!,
          ),
        )
        .toList();
    return _HealthCard(
      title: strings.healthScoreTrend,
      child: points.isEmpty
          ? SizedBox(
              height: 180,
              child: Center(child: Text(strings.noDataInSelectedRange)),
            )
          : SizedBox(
              height: 220,
              child: CustomPaint(
                painter: _HealthGraphPainter(points),
                child: const SizedBox.expand(),
              ),
            ),
    );
  }
}

class _ComprehensiveSummaryCard extends StatelessWidget {
  const _ComprehensiveSummaryCard({
    required this.snapshots,
    required this.fallbackSnapshot,
    required this.from,
    required this.to,
    required this.strings,
  });

  final List<HealthSnapshot> snapshots;
  final HealthSnapshot fallbackSnapshot;
  final DateTime from;
  final DateTime to;
  final LocalizedStrings strings;

  @override
  Widget build(BuildContext context) {
    final latestSnapshot = snapshots.isEmpty
        ? fallbackSnapshot
        : snapshots.last;
    final scores = snapshots
        .map((snapshot) => snapshot.healthScore)
        .whereType<double>()
        .toList();
    final average = scores.isEmpty
        ? null
        : scores.reduce((a, b) => a + b) / scores.length;
    final change = scores.length < 2 ? null : scores.last - scores.first;
    final range =
        '${DateFormat('dd MMM yyyy').format(from)} – ${DateFormat('dd MMM yyyy').format(to)}';
    final narrative = _buildNarrative(
      latest: latestSnapshot,
      count: snapshots.length,
      average: average,
      change: change,
    );

    return _HealthCard(
      title: strings.comprehensiveSummary,
      subtitle: range,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            narrative,
            style: const TextStyle(
              color: Color(0xFF2F4056),
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryBadge(
                label:
                    '${strings.latestScore}: ${latestSnapshot.healthScore?.toStringAsFixed(0) ?? '—'}',
              ),
              _SummaryBadge(
                label:
                    '${strings.averageScore}: ${average?.toStringAsFixed(1) ?? '—'}',
              ),
              _SummaryBadge(
                label: '${strings.reportsInRange}: ${snapshots.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildNarrative({
    required HealthSnapshot latest,
    required int count,
    required double? average,
    required double? change,
  }) {
    final date = _formatSnapshotDate(latest.snapshotDate);
    final readings = <String>[
      if (latest.latestVitals?.bloodPressureSystolic != null)
        'blood pressure ${_bloodPressure(latest)} mmHg',
      if (latest.bloodSugar != null)
        'blood sugar ${latest.bloodSugar!.toStringAsFixed(0)} mg/dL',
      if (latest.cholesterol != null)
        'cholesterol ${latest.cholesterol!.toStringAsFixed(0)} mg/dL',
      if (latest.bmi != null) 'BMI ${latest.bmi!.toStringAsFixed(1)}',
      if (latest.latestVitals?.heartRate != null)
        'heart rate ${latest.latestVitals!.heartRate} bpm',
      if (latest.latestVitals?.oxygenSaturation != null)
        'oxygen saturation ${latest.latestVitals!.oxygenSaturation}%',
    ];

    final parts = <String>[];
    if (readings.isNotEmpty) {
      parts.add(
        'The latest health update${date == null ? '' : ' from $date'} records ${_joinReadings(readings)}.',
      );
    }
    if (latest.healthScore != null || latest.riskScore != null) {
      parts.add(
        'The current health score is ${latest.healthScore?.toStringAsFixed(0) ?? 'not available'} out of 100, with a risk score of ${latest.riskScore?.toStringAsFixed(0) ?? 'not available'} out of 100.',
      );
    }
    if (count > 1 && average != null) {
      final direction = change == null || change.abs() < 0.5
          ? 'has remained broadly stable'
          : change > 0
          ? 'has improved by ${change.toStringAsFixed(0)} points'
          : 'has reduced by ${change.abs().toStringAsFixed(0)} points';
      parts.add(
        'Across $count health updates in the selected period, the average health score is ${average.toStringAsFixed(1)} and the score $direction.',
      );
    }
    final generated = (latest.aiSummary ?? '').trim();
    if (generated.isNotEmpty) parts.add(generated);
    if (parts.isEmpty) {
      return 'There is not enough recorded information to prepare a comprehensive summary for this period.';
    }

    return parts.join(' ');
  }
}

class _CurrentHealthValuesCard extends StatelessWidget {
  const _CurrentHealthValuesCard({
    required this.snapshot,
    required this.strings,
  });

  final HealthSnapshot snapshot;
  final LocalizedStrings strings;

  @override
  Widget build(BuildContext context) {
    final vitals = snapshot.latestVitals;
    final readings = <_HealthReading>[
      if (vitals?.bloodPressureSystolic != null)
        _HealthReading(
          label: 'Blood pressure',
          value: _bloodPressure(snapshot),
          unit: 'mmHg',
          icon: Icons.favorite_outline_rounded,
          color: const Color(0xFFD05A45),
        ),
      if (snapshot.bloodSugar != null)
        _HealthReading(
          label: strings.bloodSugarLabel,
          value: snapshot.bloodSugar!.toStringAsFixed(0),
          unit: 'mg/dL',
          icon: Icons.water_drop_outlined,
          color: const Color(0xFF7C3AED),
        ),
      if (snapshot.cholesterol != null)
        _HealthReading(
          label: strings.cholesterolLabel,
          value: snapshot.cholesterol!.toStringAsFixed(0),
          unit: 'mg/dL',
          icon: Icons.science_outlined,
          color: const Color(0xFFD97706),
        ),
      if (snapshot.bmi != null)
        _HealthReading(
          label: 'BMI',
          value: snapshot.bmi!.toStringAsFixed(1),
          unit: '',
          icon: Icons.monitor_weight_outlined,
          color: const Color(0xFF147D73),
        ),
      if (vitals?.heartRate != null)
        _HealthReading(
          label: 'Heart rate',
          value: '${vitals!.heartRate}',
          unit: 'bpm',
          icon: Icons.monitor_heart_outlined,
          color: const Color(0xFFDB4C4C),
        ),
      if (vitals?.oxygenSaturation != null)
        _HealthReading(
          label: 'Oxygen',
          value: '${vitals!.oxygenSaturation}',
          unit: '%',
          icon: Icons.air_rounded,
          color: const Color(0xFF0284C7),
        ),
      if (vitals?.weight != null)
        _HealthReading(
          label: 'Weight',
          value: vitals!.weight!.toStringAsFixed(1),
          unit: 'kg',
          icon: Icons.scale_outlined,
          color: const Color(0xFF4F46E5),
        ),
      if (snapshot.healthScore != null)
        _HealthReading(
          label: strings.healthMetric,
          value: snapshot.healthScore!.toStringAsFixed(0),
          unit: '/100',
          icon: Icons.health_and_safety_outlined,
          color: const Color(0xFF13866F),
        ),
      if (snapshot.riskScore != null)
        _HealthReading(
          label: strings.riskMetric,
          value: snapshot.riskScore!.toStringAsFixed(0),
          unit: '/100',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFD05A45),
        ),
    ];

    return _HealthCard(
      title: 'Current health values',
      subtitle: snapshot.snapshotDate == null
          ? null
          : DateFormat(
              'dd MMM yyyy',
            ).format(DateTime.parse(snapshot.snapshotDate!)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 10) / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (readings.isEmpty)
                const Text('No current readings are available.')
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: readings
                      .map(
                        (reading) => SizedBox(
                          width: itemWidth,
                          child: _HealthReadingTile(reading: reading),
                        ),
                      )
                      .toList(),
                ),
              if ((snapshot.otherConditions ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Reported conditions: ${snapshot.otherConditions!.trim()}',
                    style: const TextStyle(
                      color: Color(0xFF9A4D13),
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HealthReadingTile extends StatelessWidget {
  const _HealthReadingTile({required this.reading});

  final _HealthReading reading;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(reading.icon, color: reading.color, size: 20),
          const SizedBox(height: 8),
          Text(
            reading.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B788B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text.rich(
            TextSpan(
              text: reading.value,
              style: TextStyle(
                color: reading.color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
              children: [
                if (reading.unit.isNotEmpty)
                  TextSpan(
                    text: ' ${reading.unit}',
                    style: const TextStyle(
                      color: Color(0xFF6B788B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotUpdatesCard extends StatelessWidget {
  const _SnapshotUpdatesCard({
    required this.snapshots,
    required this.hasMore,
    required this.onViewAll,
  });

  final List<HealthSnapshot> snapshots;
  final bool hasMore;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _HealthCard(
      title: 'Health update history',
      subtitle: 'Latest ${snapshots.length} updates',
      child: Column(
        children: [
          ...snapshots.map(_SnapshotUpdateRow.new),
          if (hasMore) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.history_rounded),
                label: const Text('View all history & filters'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SnapshotUpdateRow extends StatelessWidget {
  const _SnapshotUpdateRow(this.snapshot);

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (snapshot.healthScore != null)
        'Health ${snapshot.healthScore!.toStringAsFixed(0)}',
      if (snapshot.riskScore != null)
        'Risk ${snapshot.riskScore!.toStringAsFixed(0)}',
      if (snapshot.latestVitals?.bloodPressureSystolic != null)
        'BP ${_bloodPressure(snapshot)}',
      if (snapshot.bloodSugar != null)
        'Sugar ${snapshot.bloodSugar!.toStringAsFixed(0)}',
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.update_rounded,
                size: 18,
                color: Color(0xFF06489B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatSnapshotDate(snapshot.snapshotDate) ?? 'Unknown date',
                  style: const TextStyle(
                    color: Color(0xFF192233),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              details.join('  •  '),
              style: const TextStyle(
                color: Color(0xFF526176),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if ((snapshot.aiSummary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              snapshot.aiSummary!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6B788B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE5EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF192233),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF6B788B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF06489B),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HealthReading {
  const _HealthReading({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
}

String _bloodPressure(HealthSnapshot snapshot) {
  final systolic = snapshot.latestVitals?.bloodPressureSystolic;
  final diastolic = snapshot.latestVitals?.bloodPressureDiastolic;
  if (systolic == null) return '—';

  return diastolic == null ? '$systolic' : '$systolic/$diastolic';
}

String? _formatSnapshotDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  return DateFormat('dd MMM yyyy').format(parsed.toLocal());
}

String _joinReadings(List<String> values) {
  if (values.length == 1) return values.first;
  if (values.length == 2) return '${values.first} and ${values.last}';

  return '${values.take(values.length - 1).join(', ')}, and ${values.last}';
}

class _EmptyHealthStatus extends StatelessWidget {
  const _EmptyHealthStatus({required this.message, required this.onRefresh});

  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monitor_heart_outlined,
              size: 54,
              color: Color(0xFF06489B),
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthPoint {
  const _HealthPoint({required this.date, required this.score});

  final DateTime date;
  final double score;
}

class _HealthGraphPainter extends CustomPainter {
  const _HealthGraphPainter(this.points);

  final List<_HealthPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const top = 12.0;
    const right = 10.0;
    const bottom = 30.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFFE4EAF2)
      ..strokeWidth = 1;
    final labelPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (var value = 0; value <= 100; value += 25) {
      final y = chart.bottom - (value / 100) * chart.height;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      labelPainter.text = TextSpan(
        text: '$value',
        style: const TextStyle(color: Color(0xFF8491A3), fontSize: 9),
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(2, y - labelPainter.height / 2));
    }

    final line = Path();
    final pointPaint = Paint()..color = const Color(0xFF06489B);
    final linePaint = Paint()
      ..color = const Color(0xFF147D73)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final count = math.max(points.length - 1, 1);
    for (var index = 0; index < points.length; index++) {
      final x = chart.left + (index / count) * chart.width;
      final score = points[index].score.clamp(0, 100);
      final y = chart.bottom - (score / 100) * chart.height;
      if (index == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
    if (points.length > 1) canvas.drawPath(line, linePaint);

    final labelIndexes = points.length <= 3
        ? List.generate(points.length, (index) => index)
        : [0, points.length ~/ 2, points.length - 1];
    for (final index in labelIndexes) {
      final x = chart.left + (index / count) * chart.width;
      labelPainter.text = TextSpan(
        text: DateFormat('dd MMM').format(points[index].date),
        style: const TextStyle(color: Color(0xFF6B788B), fontSize: 9),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(
          (x - labelPainter.width / 2).clamp(
            0,
            size.width - labelPainter.width,
          ),
          chart.bottom + 9,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HealthGraphPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
