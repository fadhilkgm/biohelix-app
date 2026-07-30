import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/data/patient_repository.dart';
import '../../core/models/patient_models.dart';
import '../../core/providers/patient_portal_provider.dart';
import '../models/health_snapshot_filters.dart';

const Color _bg = Color(0xFFF8F9FB);
const Color _ink = Color(0xFF192233);
const Color _accent = Color(0xFF06489B);
const Color _danger = Color(0xFFDB4C4C);

/// Opens the manual "add/update today's readings" form as a bottom sheet.
/// Backed by `POST /patients/me/health-snapshot` (upserts today's row).
Future<void> showHealthSnapshotEntrySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _HealthSnapshotEntrySheet(),
  );
}

class _HealthSnapshotEntrySheet extends StatefulWidget {
  const _HealthSnapshotEntrySheet();

  @override
  State<_HealthSnapshotEntrySheet> createState() =>
      _HealthSnapshotEntrySheetState();
}

class _HealthSnapshotEntrySheetState extends State<_HealthSnapshotEntrySheet> {
  final _systolicCtrl = TextEditingController();
  final _diastolicCtrl = TextEditingController();
  final _sugarCtrl = TextEditingController();
  final _cholesterolCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    _sugarCtrl.dispose();
    _cholesterolCtrl.dispose();
    _weightCtrl.dispose();
    _conditionsCtrl.dispose();
    super.dispose();
  }

  // Mirrors the validation ranges documented for `POST
  // /patients/me/health-snapshot`. All fields are optional; a value is only
  // range-checked when the patient actually typed something.
  String? _validate() {
    final systolic = int.tryParse(_systolicCtrl.text.trim());
    final diastolic = int.tryParse(_diastolicCtrl.text.trim());
    final sugar = double.tryParse(_sugarCtrl.text.trim());
    final cholesterol = double.tryParse(_cholesterolCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());
    final conditions = _conditionsCtrl.text.trim();

    if (_systolicCtrl.text.trim().isNotEmpty &&
        (systolic == null || systolic < 50 || systolic > 300)) {
      return 'Systolic BP must be between 50 and 300.';
    }
    if (_diastolicCtrl.text.trim().isNotEmpty &&
        (diastolic == null || diastolic < 30 || diastolic > 200)) {
      return 'Diastolic BP must be between 30 and 200.';
    }
    if (_sugarCtrl.text.trim().isNotEmpty &&
        (sugar == null || sugar < 0 || sugar > 1000)) {
      return 'Blood sugar must be between 0 and 1000 mg/dL.';
    }
    if (_cholesterolCtrl.text.trim().isNotEmpty &&
        (cholesterol == null || cholesterol < 0 || cholesterol > 1000)) {
      return 'Cholesterol must be between 0 and 1000 mg/dL.';
    }
    if (_weightCtrl.text.trim().isNotEmpty &&
        (weight == null || weight < 1 || weight > 500)) {
      return 'Weight must be between 1 and 500 kg.';
    }
    if (conditions.length > 1000) {
      return 'Other conditions must be 1000 characters or fewer.';
    }
    if (systolic == null &&
        diastolic == null &&
        sugar == null &&
        cholesterol == null &&
        weight == null &&
        conditions.isEmpty) {
      return 'Enter at least one reading.';
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final conditions = _conditionsCtrl.text.trim();
      await context.read<PatientPortalProvider>().submitHealthSnapshot(
        HealthSnapshotInput(
          bloodPressureSystolic: int.tryParse(_systolicCtrl.text.trim()),
          bloodPressureDiastolic: int.tryParse(_diastolicCtrl.text.trim()),
          bloodSugar: double.tryParse(_sugarCtrl.text.trim()),
          cholesterol: double.tryParse(_cholesterolCtrl.text.trim()),
          weight: double.tryParse(_weightCtrl.text.trim()),
          otherConditions: conditions.isEmpty ? null : conditions,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Health update saved.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E8F2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "Add / Update Today's Readings",
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'All fields are optional. Saving again today updates the '
                'same entry instead of creating a new one.',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  height: 1.4,
                  color: _ink.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      label: 'BP systolic',
                      hint: '50–300',
                      controller: _systolicCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      label: 'BP diastolic',
                      hint: '30–200',
                      controller: _diastolicCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      label: 'Blood sugar (mg/dL)',
                      hint: '0–1000',
                      controller: _sugarCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      label: 'Cholesterol (mg/dL)',
                      hint: '0–1000',
                      controller: _cholesterolCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              _field(
                label: 'Weight (kg)',
                hint: '1–500',
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              _field(
                label: 'Other conditions',
                hint: 'e.g. Mild fever since yesterday, sore throat',
                controller: _conditionsCtrl,
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    color: _danger,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save Readings',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paginated history of daily snapshots, newest first. Backed by
/// `GET /patients/me/health-snapshot/history`.
class HealthSnapshotHistoryScreen extends StatefulWidget {
  const HealthSnapshotHistoryScreen({super.key});

  @override
  State<HealthSnapshotHistoryScreen> createState() =>
      _HealthSnapshotHistoryScreenState();
}

class _HealthSnapshotHistoryScreenState
    extends State<HealthSnapshotHistoryScreen> {
  final _scrollController = ScrollController();
  DateTimeRange? _dateRange;
  HealthSnapshotMetricFilter _metricFilter = HealthSnapshotMetricFilter.all;
  HealthSnapshotRiskFilter _riskFilter = HealthSnapshotRiskFilter.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PatientPortalProvider>().loadHealthSnapshotHistory();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 240;
    if (_scrollController.position.pixels >= threshold) {
      context.read<PatientPortalProvider>().loadMoreHealthSnapshotHistory();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Unknown date';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      helpText: 'Filter health update dates',
    );
    if (picked == null || !mounted) return;
    setState(() => _dateRange = picked);
  }

  void _clearFilters() {
    setState(() {
      _dateRange = null;
      _metricFilter = HealthSnapshotMetricFilter.all;
      _riskFilter = HealthSnapshotRiskFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          'Health Update History',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        backgroundColor: _bg,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Consumer<PatientPortalProvider>(
        builder: (context, portal, _) {
          final history = portal.healthSnapshotHistory;
          final filtered = filterHealthSnapshots(
            history,
            from: _dateRange?.start,
            to: _dateRange?.end,
            metric: _metricFilter,
            risk: _riskFilter,
          );

          if (portal.isLoadingHealthSnapshotHistory && history.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }

          return RefreshIndicator(
            color: _accent,
            onRefresh: () => context
                .read<PatientPortalProvider>()
                .loadHealthSnapshotHistory(),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                _HistoryFilterPanel(
                  dateRange: _dateRange,
                  metricFilter: _metricFilter,
                  riskFilter: _riskFilter,
                  onPickDates: _pickDateRange,
                  onMetricChanged: (value) {
                    setState(() => _metricFilter = value);
                  },
                  onRiskChanged: (value) {
                    setState(() => _riskFilter = value);
                  },
                  onClear: _clearFilters,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Showing ${filtered.length} of ${history.length} loaded health updates',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          color: _ink.withValues(alpha: 0.68),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (portal.hasMoreHealthSnapshotHistory)
                      const Text(
                        'More available',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  _historyMessage(
                    portal.errorMessage != null
                        ? 'Could not load history. Pull to retry.'
                        : 'No past health updates yet.',
                  )
                else if (filtered.isEmpty)
                  _historyMessage(
                    portal.hasMoreHealthSnapshotHistory
                        ? 'No loaded health updates match these filters. Load more history or clear the filters.'
                        : 'No health updates match the selected filters.',
                  )
                else
                  ...filtered.map(_historyCard),
                if (portal.hasMoreHealthSnapshotHistory) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: portal.isLoadingMoreHealthSnapshotHistory
                          ? null
                          : portal.loadMoreHealthSnapshotHistory,
                      icon: portal.isLoadingMoreHealthSnapshotHistory
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _accent,
                              ),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(
                        portal.isLoadingMoreHealthSnapshotHistory
                            ? 'Loading history…'
                            : 'Load more history',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _historyMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E9F0)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          color: _ink.withValues(alpha: 0.65),
        ),
      ),
    );
  }

  Widget _historyCard(HealthSnapshot snapshot) {
    final metrics = <String>[
      if (snapshot.healthScore != null)
        'Health ${snapshot.healthScore!.toStringAsFixed(0)}',
      if (snapshot.riskScore != null)
        'Risk ${snapshot.riskScore!.toStringAsFixed(0)}',
      if (snapshot.bmi != null) 'BMI ${snapshot.bmi!.toStringAsFixed(1)}',
      if (snapshot.latestVitals?.bloodPressureSystolic != null)
        'BP ${_historyBloodPressure(snapshot)}',
      if (snapshot.bloodSugar != null)
        'Sugar ${snapshot.bloodSugar!.toStringAsFixed(0)} mg/dL',
      if (snapshot.cholesterol != null)
        'Cholesterol ${snapshot.cholesterol!.toStringAsFixed(0)} mg/dL',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(snapshot.snapshotDate),
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: _ink,
            ),
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metrics
                  .map(
                    (metric) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        metric,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if ((snapshot.aiSummary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              snapshot.aiSummary!.trim(),
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                height: 1.4,
                color: _ink.withValues(alpha: 0.75),
              ),
            ),
          ],
          if ((snapshot.otherConditions ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reported conditions: ${snapshot.otherConditions!.trim()}',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF9A4D13),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _historyBloodPressure(HealthSnapshot snapshot) {
    final systolic = snapshot.latestVitals?.bloodPressureSystolic;
    final diastolic = snapshot.latestVitals?.bloodPressureDiastolic;
    if (systolic == null) return '—';

    return diastolic == null ? '$systolic' : '$systolic/$diastolic';
  }
}

class _HistoryFilterPanel extends StatelessWidget {
  const _HistoryFilterPanel({
    required this.dateRange,
    required this.metricFilter,
    required this.riskFilter,
    required this.onPickDates,
    required this.onMetricChanged,
    required this.onRiskChanged,
    required this.onClear,
  });

  final DateTimeRange? dateRange;
  final HealthSnapshotMetricFilter metricFilter;
  final HealthSnapshotRiskFilter riskFilter;
  final VoidCallback onPickDates;
  final ValueChanged<HealthSnapshotMetricFilter> onMetricChanged;
  final ValueChanged<HealthSnapshotRiskFilter> onRiskChanged;
  final VoidCallback onClear;

  bool get _hasFilters =>
      dateRange != null ||
      metricFilter != HealthSnapshotMetricFilter.all ||
      riskFilter != HealthSnapshotRiskFilter.all;

  @override
  Widget build(BuildContext context) {
    final dateLabel = dateRange == null
        ? 'All dates'
        : '${DateFormat('dd MMM yyyy').format(dateRange!.start)} – '
              '${DateFormat('dd MMM yyyy').format(dateRange!.end)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E9F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, color: _accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Filter history',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              if (_hasFilters)
                TextButton(onPressed: onClear, child: const Text('Clear all')),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPickDates,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(dateLabel),
          ),
          const SizedBox(height: 14),
          const Text(
            'Measurement',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF526176),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: HealthSnapshotMetricFilter.values
                .map(
                  (filter) => FilterChip(
                    label: Text(filter.label),
                    selected: metricFilter == filter,
                    onSelected: (_) => onMetricChanged(filter),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Risk score',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF526176),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: HealthSnapshotRiskFilter.values
                .map(
                  (filter) => FilterChip(
                    label: Text(filter.label),
                    selected: riskFilter == filter,
                    onSelected: (_) => onRiskChanged(filter),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
