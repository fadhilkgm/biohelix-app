import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/data/patient_repository.dart';
import '../../core/models/patient_models.dart';
import '../../core/providers/patient_portal_provider.dart';

const Color _bg = Color(0xFFF8F9FB);
const Color _ink = Color(0xFF192233);
const Color _accent = Color(0xFF5A88F1);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health snapshot recorded.')),
      );
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
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'All fields are optional. Saving again today updates the '
                'same entry instead of creating a new one.',
                style: GoogleFonts.manrope(
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
                  style: GoogleFonts.manrope(fontSize: 13, color: _danger),
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
                          style: GoogleFonts.manrope(
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
            style: GoogleFonts.manrope(
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
            style: GoogleFonts.manrope(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          'Health Snapshot History',
          style: GoogleFonts.manrope(
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

          if (portal.isLoadingHealthSnapshotHistory && history.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }

          if (history.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  portal.errorMessage != null
                      ? 'Could not load history. Pull to retry.'
                      : 'No past snapshots yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: _ink.withValues(alpha: 0.6),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: _accent,
            onRefresh: () => context
                .read<PatientPortalProvider>()
                .loadHealthSnapshotHistory(),
            notificationPredicate: (_) => false,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              itemCount:
                  history.length +
                  (portal.hasMoreHealthSnapshotHistory ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= history.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent,
                        ),
                      ),
                    ),
                  );
                }
                return _historyCard(history[index]);
              },
            ),
          );
        },
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
            style: GoogleFonts.manrope(
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
                        style: GoogleFonts.manrope(
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
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.4,
                color: _ink.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
