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
              _RangeSummaryCard(
                snapshots: selected,
                from: from,
                to: to,
                strings: strings,
              ),
              const SizedBox(height: 18),
              if (selected.isNotEmpty)
                _RecentReportCard(snapshot: selected.last, strings: strings),
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

class _RangeSummaryCard extends StatelessWidget {
  const _RangeSummaryCard({
    required this.snapshots,
    required this.from,
    required this.to,
    required this.strings,
  });

  final List<HealthSnapshot> snapshots;
  final DateTime from;
  final DateTime to;
  final LocalizedStrings strings;

  @override
  Widget build(BuildContext context) {
    final scores = snapshots
        .map((snapshot) => snapshot.healthScore)
        .whereType<double>()
        .toList();
    final average = scores.isEmpty
        ? null
        : scores.reduce((a, b) => a + b) / scores.length;
    final latest = scores.isEmpty ? null : scores.last;
    final change = scores.length < 2 ? null : scores.last - scores.first;
    final range =
        '${DateFormat('dd MMM yyyy').format(from)} – ${DateFormat('dd MMM yyyy').format(to)}';

    return _HealthCard(
      title: strings.comprehensiveSummary,
      subtitle: range,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
        children: [
          _SummaryMetric(
            label: strings.latestScore,
            value: latest?.toStringAsFixed(0) ?? '—',
          ),
          _SummaryMetric(
            label: strings.averageScore,
            value: average?.toStringAsFixed(1) ?? '—',
          ),
          _SummaryMetric(
            label: strings.scoreChange,
            value: change == null
                ? '—'
                : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}',
            valueColor: change == null || change >= 0
                ? const Color(0xFF13866F)
                : const Color(0xFFD05A45),
          ),
          _SummaryMetric(
            label: strings.reportsInRange,
            value: '${snapshots.length}',
          ),
        ],
      ),
    );
  }
}

class _RecentReportCard extends StatelessWidget {
  const _RecentReportCard({required this.snapshot, required this.strings});

  final HealthSnapshot snapshot;
  final LocalizedStrings strings;

  @override
  Widget build(BuildContext context) {
    final facts = <String>[
      if (snapshot.bmi != null) 'BMI ${snapshot.bmi!.toStringAsFixed(1)}',
      if (snapshot.bloodSugar != null)
        '${strings.bloodSugarLabel} ${snapshot.bloodSugar!.toStringAsFixed(0)} mg/dL',
      if (snapshot.cholesterol != null)
        '${strings.cholesterolLabel} ${snapshot.cholesterol!.toStringAsFixed(0)} mg/dL',
    ];
    return _HealthCard(
      title: strings.recentHealthReport,
      subtitle: snapshot.snapshotDate == null
          ? null
          : DateFormat(
              'dd MMM yyyy',
            ).format(DateTime.parse(snapshot.snapshotDate!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (snapshot.aiSummary ?? '').trim().isEmpty
                ? strings.healthSnapshotReady
                : snapshot.aiSummary!.trim(),
            style: const TextStyle(
              color: Color(0xFF2F4056),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: facts
                  .map(
                    (fact) => Chip(
                      label: Text(fact),
                      backgroundColor: const Color(0xFFEAF3FD),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
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

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF06489B),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(
              color: Color(0xFF6B788B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
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
