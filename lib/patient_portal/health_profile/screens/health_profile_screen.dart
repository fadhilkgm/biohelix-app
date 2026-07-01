import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../core/data/patient_repository.dart';
import '../../core/models/patient_models.dart';

/// Self-reported health profile: view the latest snapshot, edit and save a new
/// one, and browse the full history (including AI-derived snapshots).
///
/// Backed by the documented `/patients/me/health-profile` endpoints.
class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  static const _bg = Color(0xFFF8F9FB);
  static const _ink = Color(0xFF192233);
  static const _accent = Color(0xFF5A88F1);

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  final _conditionsCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _symptomsCtrl = TextEditingController();
  final _lifestyleCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<HealthProfileSnapshot> _history = const [];

  PatientRepository get _repository => context.read<PatientRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _conditionsCtrl.dispose();
    _medicationsCtrl.dispose();
    _allergiesCtrl.dispose();
    _symptomsCtrl.dispose();
    _lifestyleCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _repository.getHealthProfile();
      final history = await _repository.getHealthProfileHistory();
      if (!mounted) return;
      if (profile != null) {
        _conditionsCtrl.text = profile.chronicConditions.join(', ');
        _medicationsCtrl.text = profile.currentMedications.join(', ');
        _allergiesCtrl.text = profile.allergies.join(', ');
        _symptomsCtrl.text = profile.symptoms ?? '';
        _lifestyleCtrl.text = profile.lifestyleNotes ?? '';
      }
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<String> _splitCsv(String raw) {
    return raw
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.saveHealthProfile(
        chronicConditions: _splitCsv(_conditionsCtrl.text),
        currentMedications: _splitCsv(_medicationsCtrl.text),
        allergies: _splitCsv(_allergiesCtrl.text),
        symptoms: _symptomsCtrl.text,
        lifestyleNotes: _lifestyleCtrl.text,
      );
      if (!mounted) return;
      final strings = AppStrings.of(context.read<LanguageProvider>().language);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.healthProfileSaved)),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      final strings = AppStrings.of(context.read<LanguageProvider>().language);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.couldNotSave(error.toString()))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HealthProfileScreen._bg,
      appBar: AppBar(
        title: Text(
          'Health Profile',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: HealthProfileScreen._ink,
          ),
        ),
        backgroundColor: HealthProfileScreen._bg,
        foregroundColor: HealthProfileScreen._ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: HealthProfileScreen._accent,
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: HealthProfileScreen._accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  Text(
                    'Keep your conditions, medications and allergies up to date. '
                    'Each save is stored as a new timestamped snapshot and helps '
                    'personalise your AI health assessments.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      height: 1.5,
                      color: HealthProfileScreen._ink.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _field(
                    label: 'Chronic conditions',
                    hint: 'e.g. Type 2 Diabetes, Hypertension',
                    controller: _conditionsCtrl,
                  ),
                  _field(
                    label: 'Current medications',
                    hint: 'e.g. Metformin 500mg, Amlodipine 5mg',
                    controller: _medicationsCtrl,
                  ),
                  _field(
                    label: 'Allergies',
                    hint: 'e.g. Penicillin',
                    controller: _allergiesCtrl,
                  ),
                  _field(
                    label: 'Symptoms',
                    hint: 'Describe any current symptoms',
                    controller: _symptomsCtrl,
                    maxLines: 3,
                  ),
                  _field(
                    label: 'Lifestyle notes',
                    hint: 'e.g. Sedentary desk job, high-carb diet',
                    controller: _lifestyleCtrl,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HealthProfileScreen._accent,
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
                              'Save Health Profile',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: const Color(0xFFDB4C4C),
                      ),
                    ),
                  ],
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      'History',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: HealthProfileScreen._ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._history.map(_historyCard),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HealthProfileScreen._ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
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
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static const _sourceLabels = <String, String>{
    'self_reported': 'Self reported',
    'assessment_derived': 'From AI assessment',
    'document_derived': 'From document analysis',
  };

  Widget _historyCard(HealthProfileSnapshot snapshot) {
    String dateLabel = snapshot.recordedAt;
    try {
      dateLabel = DateFormat(
        'dd MMM yyyy, hh:mm a',
      ).format(DateTime.parse(snapshot.recordedAt).toLocal());
    } catch (_) {
      // keep raw value
    }

    final lines = <String>[
      if (snapshot.chronicConditions.isNotEmpty)
        'Conditions: ${snapshot.chronicConditions.join(', ')}',
      if (snapshot.currentMedications.isNotEmpty)
        'Medications: ${snapshot.currentMedications.join(', ')}',
      if (snapshot.allergies.isNotEmpty)
        'Allergies: ${snapshot.allergies.join(', ')}',
      if ((snapshot.symptoms ?? '').trim().isNotEmpty)
        'Symptoms: ${snapshot.symptoms!.trim()}',
      if ((snapshot.lifestyleNotes ?? '').trim().isNotEmpty)
        'Lifestyle: ${snapshot.lifestyleNotes!.trim()}',
      if ((snapshot.notes ?? '').trim().isNotEmpty) snapshot.notes!.trim(),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: HealthProfileScreen._ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _sourceLabels[snapshot.source] ?? snapshot.source,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: HealthProfileScreen._accent,
                  ),
                ),
              ),
            ],
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.4,
                    color: HealthProfileScreen._ink.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
