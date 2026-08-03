import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/language_provider.dart';
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
Future<void> showHealthSnapshotEntrySheet(
  BuildContext context, {
  HealthSnapshot? initialSnapshot,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _HealthSnapshotEntrySheet(initialSnapshot: initialSnapshot),
  );
}

class _HealthSnapshotEntrySheet extends StatefulWidget {
  const _HealthSnapshotEntrySheet({this.initialSnapshot});

  final HealthSnapshot? initialSnapshot;

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

  static const _stepCount = 7;
  int _step = 0;
  String? _sugarContext;
  bool _saving = false;
  String? _error;
  HealthSnapshot? _resultSnapshot;

  @override
  void initState() {
    super.initState();
    final snapshot = widget.initialSnapshot;
    if (snapshot == null) return;

    _systolicCtrl.text = _numberText(
      snapshot.latestVitals?.bloodPressureSystolic,
    );
    _diastolicCtrl.text = _numberText(
      snapshot.latestVitals?.bloodPressureDiastolic,
    );
    _sugarCtrl.text = _numberText(snapshot.bloodSugar);
    _sugarContext = snapshot.bloodSugarContext;
    _cholesterolCtrl.text = _numberText(snapshot.cholesterol);
    _weightCtrl.text = _numberText(snapshot.latestVitals?.weight);
    _conditionsCtrl.text = snapshot.otherConditions?.trim() ?? '';
  }

  String _numberText(num? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

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
  String? _validate(_HealthEntryCopy copy) {
    final systolic = int.tryParse(_systolicCtrl.text.trim());
    final diastolic = int.tryParse(_diastolicCtrl.text.trim());
    final sugar = double.tryParse(_sugarCtrl.text.trim());
    final cholesterol = double.tryParse(_cholesterolCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());
    final conditions = _conditionsCtrl.text.trim();

    if (_systolicCtrl.text.trim().isNotEmpty &&
        (systolic == null || systolic < 50 || systolic > 300)) {
      return copy.invalidSystolic;
    }
    if (_diastolicCtrl.text.trim().isNotEmpty &&
        (diastolic == null || diastolic < 30 || diastolic > 200)) {
      return copy.invalidDiastolic;
    }
    if (_sugarCtrl.text.trim().isNotEmpty &&
        (sugar == null || sugar < 0 || sugar > 1000)) {
      return copy.invalidSugar;
    }
    if (sugar != null && _sugarContext == null) {
      return copy.selectSugarContext;
    }
    if (_cholesterolCtrl.text.trim().isNotEmpty &&
        (cholesterol == null || cholesterol < 0 || cholesterol > 1000)) {
      return copy.invalidCholesterol;
    }
    if (_weightCtrl.text.trim().isNotEmpty &&
        (weight == null || weight < 1 || weight > 500)) {
      return copy.invalidWeight;
    }
    if (conditions.length > 1000) {
      return copy.invalidConditions;
    }
    if (systolic == null &&
        diastolic == null &&
        sugar == null &&
        cholesterol == null &&
        weight == null &&
        conditions.isEmpty) {
      return copy.enterOneReading;
    }
    return null;
  }

  Future<void> _submit() async {
    final copy = _HealthEntryCopy.of(context.read<LanguageProvider>().language);
    final error = _validate(copy);
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
      final portal = context.read<PatientPortalProvider>();
      await portal.submitHealthSnapshot(
        HealthSnapshotInput(
          bloodPressureSystolic: int.tryParse(_systolicCtrl.text.trim()),
          bloodPressureDiastolic: int.tryParse(_diastolicCtrl.text.trim()),
          bloodSugar: double.tryParse(_sugarCtrl.text.trim()),
          bloodSugarContext: _sugarCtrl.text.trim().isEmpty
              ? null
              : _sugarContext,
          cholesterol: double.tryParse(_cholesterolCtrl.text.trim()),
          weight: double.tryParse(_weightCtrl.text.trim()),
          otherConditions: conditions.isEmpty ? null : conditions,
        ),
      );
      if (!mounted) return;
      setState(() => _resultSnapshot = portal.healthSnapshot);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next(_HealthEntryCopy copy) {
    final error = _validateCurrentStep(copy);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _step = (_step + 1).clamp(0, _stepCount - 1);
    });
  }

  String? _validateCurrentStep(_HealthEntryCopy copy) {
    final text = switch (_step) {
      0 => _weightCtrl.text.trim(),
      3 => _sugarCtrl.text.trim(),
      4 => _cholesterolCtrl.text.trim(),
      5 => _conditionsCtrl.text.trim(),
      _ => '',
    };

    if (_step == 0 && text.isNotEmpty) {
      final value = double.tryParse(text);
      if (value == null || value < 1 || value > 500) {
        return copy.invalidWeight;
      }
    }
    if (_step == 1) {
      final systolicText = _systolicCtrl.text.trim();
      final diastolicText = _diastolicCtrl.text.trim();
      final systolic = int.tryParse(systolicText);
      final diastolic = int.tryParse(diastolicText);
      if (systolicText.isNotEmpty &&
          (systolic == null || systolic < 50 || systolic > 300)) {
        return copy.invalidSystolic;
      }
      if (diastolicText.isNotEmpty &&
          (diastolic == null || diastolic < 30 || diastolic > 200)) {
        return copy.invalidDiastolic;
      }
    }
    if (_step == 3 && text.isNotEmpty) {
      final value = double.tryParse(text);
      if (value == null || value < 0 || value > 1000) {
        return copy.invalidSugar;
      }
      if (_sugarContext == null) return copy.selectSugarContext;
    }
    if (_step == 4 && text.isNotEmpty) {
      final value = double.tryParse(text);
      if (value == null || value < 0 || value > 1000) {
        return copy.invalidCholesterol;
      }
    }
    if (_step == 5 && text.length > 1000) return copy.invalidConditions;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final copy = _HealthEntryCopy.of(
      context.watch<LanguageProvider>().language,
    );
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight:
              availableHeight *
              (mediaQuery.viewInsets.bottom > 0 ? 0.92 : 0.76),
        ),
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
                widget.initialSnapshot == null ? copy.addTitle : copy.editTitle,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontFamilyFallback: ['AnekMalayalam'],
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.initialSnapshot == null ? copy.addIntro : copy.editIntro,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontFamilyFallback: const ['AnekMalayalam'],
                  fontSize: 13,
                  height: 1.4,
                  color: _ink.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      copy.step(_step + 1, _stepCount),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontFamilyFallback: ['AnekMalayalam'],
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF617084),
                      ),
                    ),
                  ),
                  Text(
                    '${((_step + 1) / _stepCount * 100).round()}%',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _stepCount,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFDCE6F2),
                  color: _accent,
                ),
              ),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildStep(copy),
              ),
              const SizedBox(height: 28),
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
              if (_resultSnapshot != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      copy.done,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontFamilyFallback: ['AnekMalayalam'],
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () {
                                  FocusScope.of(context).unfocus();
                                  setState(() {
                                    _error = null;
                                    _step--;
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accent,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: const BorderSide(color: Color(0xFFB8CDE5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 19),
                          label: Text(
                            copy.back,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontFamilyFallback: ['AnekMalayalam'],
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving
                            ? null
                            : _step == _stepCount - 1
                            ? _submit
                            : () => _next(copy),
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _step == _stepCount - 1
                                        ? copy.save
                                        : copy.next,
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontFamilyFallback: ['AnekMalayalam'],
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (_step < _stepCount - 1) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 19,
                                    ),
                                  ],
                                ],
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

  Widget _buildStep(_HealthEntryCopy copy) {
    if (_saving) return _analysisLoading(copy);
    if (_resultSnapshot != null) {
      return _summaryResult(copy, _resultSnapshot!);
    }

    return switch (_step) {
      0 => _question(
        key: const ValueKey('weight'),
        icon: Icons.monitor_weight_outlined,
        title: copy.weightQuestion,
        helper: copy.weightHelper,
        optional: copy.optional,
        child: _field(
          label: copy.weightLabel,
          hint: '0.0 kg',
          controller: _weightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ),
      1 => _question(
        key: const ValueKey('blood-pressure'),
        icon: Icons.monitor_heart_outlined,
        title: copy.bpQuestion,
        helper: copy.bpHelper,
        optional: copy.optional,
        child: Row(
          children: [
            Expanded(
              child: _field(
                label: copy.systolic,
                hint: '120',
                controller: _systolicCtrl,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _field(
                label: copy.diastolic,
                hint: '80',
                controller: _diastolicCtrl,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ),
      2 => _sugarContextQuestion(copy),
      3 => _question(
        key: const ValueKey('blood-sugar'),
        icon: Icons.water_drop_outlined,
        title: copy.sugarQuestion,
        helper: copy.sugarHelper,
        optional: copy.optional,
        child: _field(
          label: copy.sugarLabel,
          hint: '100 mg/dL',
          controller: _sugarCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ),
      4 => _question(
        key: const ValueKey('cholesterol'),
        icon: Icons.science_outlined,
        title: copy.cholesterolQuestion,
        helper: copy.cholesterolHelper,
        optional: copy.optional,
        child: _field(
          label: copy.cholesterolLabel,
          hint: '180 mg/dL',
          controller: _cholesterolCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ),
      5 => _question(
        key: const ValueKey('conditions'),
        icon: Icons.medical_information_outlined,
        title: copy.conditionsQuestion,
        helper: copy.conditionsHelper,
        optional: copy.optional,
        child: _field(
          label: copy.conditionsLabel,
          hint: copy.conditionsHint,
          controller: _conditionsCtrl,
          maxLines: 3,
        ),
      ),
      _ => _review(copy),
    };
  }

  Widget _sugarContextQuestion(_HealthEntryCopy copy) {
    final options = <({String value, String label})>[
      (value: 'fasting', label: copy.sugarContextFasting),
      (value: 'before_meal', label: copy.sugarContextBeforeMeal),
      (value: 'after_meal', label: copy.sugarContextAfterMeal),
      (value: 'random', label: copy.sugarContextRandom),
      (value: 'unsure', label: copy.sugarContextUnsure),
    ];

    return _question(
      key: const ValueKey('blood-sugar-context'),
      icon: Icons.schedule_rounded,
      title: copy.sugarContextQuestion,
      helper: copy.sugarContextHelper,
      optional: copy.optional,
      child: Column(
        children: options.map((option) {
          final selected = _sugarContext == option.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Material(
              color: selected ? const Color(0xFFEAF2FF) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() {
                  _sugarContext = option.value;
                  _error = null;
                }),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? _accent : const Color(0xFFE1E8F2),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontFamilyFallback: const ['AnekMalayalam'],
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: selected ? _accent : _ink,
                          ),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected ? _accent : const Color(0xFF9AA7B8),
                        size: 21,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _analysisLoading(_HealthEntryCopy copy) {
    return Container(
      key: const ValueKey('ai-loading'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE7F2)),
      ),
      child: Column(
        children: [
          SizedBox.square(
            dimension: 132,
            child: Image.asset(
              'assets/images/brain.gif',
              fit: BoxFit.cover,
              gaplessPlayback: true,
              semanticLabel: copy.analyzingTitle,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            copy.analyzingTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontFamilyFallback: ['AnekMalayalam'],
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            copy.analyzingHelper,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontFamilyFallback: const ['AnekMalayalam'],
              fontSize: 13,
              height: 1.45,
              color: _ink.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryResult(_HealthEntryCopy copy, HealthSnapshot snapshot) {
    final summary = (snapshot.aiSummary ?? '').trim();

    return Container(
      key: const ValueKey('ai-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCFE1F2)),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F7),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF1A9EA5),
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  copy.summaryTitle,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: ['AnekMalayalam'],
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          if (snapshot.healthScore != null || snapshot.riskScore != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (snapshot.healthScore != null)
                  _summaryMetric(
                    copy.healthScore,
                    '${snapshot.healthScore!.toStringAsFixed(0)}/100',
                    const Color(0xFF167A58),
                  ),
                if (snapshot.riskScore != null)
                  _summaryMetric(
                    copy.riskScore,
                    '${snapshot.riskScore!.toStringAsFixed(0)}/100',
                    const Color(0xFFB66A12),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              summary.isEmpty ? copy.summaryPending : summary,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['AnekMalayalam'],
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF42566E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            copy.summaryDisclaimer,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontFamilyFallback: ['AnekMalayalam'],
              fontSize: 10,
              height: 1.4,
              color: Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontFamilyFallback: const ['AnekMalayalam'],
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _question({
    required Key key,
    required IconData icon,
    required String title,
    required String helper,
    required String optional,
    required Widget child,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _accent, size: 23),
        ),
        const SizedBox(height: 13),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: ['AnekMalayalam'],
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          helper,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: const ['AnekMalayalam'],
            fontSize: 13,
            height: 1.4,
            color: _ink.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF2F6),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            optional,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontFamilyFallback: ['AnekMalayalam'],
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF617084),
            ),
          ),
        ),
        const SizedBox(height: 18),
        child,
      ],
    );
  }

  Widget _review(_HealthEntryCopy copy) {
    final systolic = _systolicCtrl.text.trim();
    final diastolic = _diastolicCtrl.text.trim();
    final pressure = systolic.isEmpty && diastolic.isEmpty
        ? copy.notProvided
        : '${systolic.isEmpty ? '—' : systolic}/'
              '${diastolic.isEmpty ? '—' : diastolic}';

    String reading(String value, String unit) {
      final clean = value.trim();
      return clean.isEmpty ? copy.notProvided : '$clean $unit';
    }

    final sugarReading = _sugarCtrl.text.trim().isEmpty
        ? copy.notProvided
        : '${copy.sugarContextLabel(_sugarContext)} · '
              '${_sugarCtrl.text.trim()} mg/dL';

    return Column(
      key: const ValueKey('review'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.fact_check_outlined,
          color: Color(0xFF167A58),
          size: 40,
        ),
        const SizedBox(height: 10),
        Text(
          copy.reviewTitle,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: ['AnekMalayalam'],
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          copy.reviewHelper,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: const ['AnekMalayalam'],
            fontSize: 13,
            color: _ink.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFE1E8F2)),
          ),
          child: Column(
            children: [
              _reviewRow(copy.weightLabel, reading(_weightCtrl.text, 'kg')),
              _reviewRow(copy.bpLabel, pressure),
              _reviewRow(copy.sugarLabel, sugarReading),
              _reviewRow(
                copy.cholesterolLabel,
                reading(_cholesterolCtrl.text, 'mg/dL'),
              ),
              _reviewRow(
                copy.conditionsLabel,
                _conditionsCtrl.text.trim().isEmpty
                    ? copy.notProvided
                    : _conditionsCtrl.text.trim(),
                divider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value, {bool divider = true}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: Color(0xFFEDF0F4)))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['AnekMalayalam'],
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF617084),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['AnekMalayalam'],
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 24),
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

class _HealthEntryCopy {
  const _HealthEntryCopy(this.isMalayalam);

  final bool isMalayalam;

  static _HealthEntryCopy of(AppLanguage language) {
    return _HealthEntryCopy(language == AppLanguage.ml);
  }

  String get addTitle => isMalayalam
      ? 'ഇന്നത്തെ ആരോഗ്യ വിവരങ്ങൾ ചേർക്കുക'
      : "Add Today's Readings";
  String get editTitle => isMalayalam
      ? 'ഇന്നത്തെ ആരോഗ്യ വിവരങ്ങൾ തിരുത്തുക'
      : "Edit Today's Readings";
  String get addIntro => isMalayalam
      ? 'ഓരോ ചോദ്യത്തിനും അറിയാവുന്ന വിവരങ്ങൾ നൽകുക.'
      : 'Answer what you know. Every question is optional.';
  String get editIntro => isMalayalam
      ? 'നിലവിലെ വിവരങ്ങൾ പരിശോധിച്ച് ആവശ്യമായ മാറ്റങ്ങൾ വരുത്തുക.'
      : 'Review your current values and update anything that changed.';
  String step(int current, int total) =>
      isMalayalam ? 'ഘട്ടം $current / $total' : 'Step $current of $total';
  String get optional => 'Optional';
  String get next => isMalayalam ? 'അടുത്തത്' : 'Next';
  String get back => isMalayalam ? 'പിന്നോട്ട്' : 'Back';
  String get save => isMalayalam ? 'സംരക്ഷിക്കുക' : 'Save';
  String get done => isMalayalam ? 'പൂർത്തിയായി' : 'Done';
  String get saved =>
      isMalayalam ? 'ആരോഗ്യ വിവരങ്ങൾ സംരക്ഷിച്ചു.' : 'Health update saved.';
  String get analyzingTitle => isMalayalam
      ? 'AI ആരോഗ്യ വിശകലനം തയ്യാറാക്കുന്നു'
      : 'Preparing your AI summary';
  String get analyzingHelper => isMalayalam
      ? 'നിങ്ങൾ നൽകിയ വിവരങ്ങൾ വിശകലനം ചെയ്യുന്നു. ഒരു നിമിഷം കാത്തിരിക്കൂ.'
      : 'We are analyzing your readings. This should only take a moment.';
  String get summaryTitle =>
      isMalayalam ? 'നിങ്ങളുടെ AI ആരോഗ്യ സംഗ്രഹം' : 'Your AI health summary';
  String get summaryPending => isMalayalam
      ? 'ആരോഗ്യ വിവരങ്ങൾ സംരക്ഷിച്ചു. AI സംഗ്രഹം ഉടൻ ലഭ്യമാകും.'
      : 'Your readings were saved. The AI summary will be available shortly.';
  String get summaryDisclaimer => isMalayalam
      ? 'ഇത് ഒരു ആരോഗ്യ സൂചന മാത്രമാണ്; മെഡിക്കൽ രോഗനിർണയം അല്ല.'
      : 'This is a wellness insight, not a medical diagnosis.';
  String get healthScore => isMalayalam ? 'ആരോഗ്യ സ്കോർ' : 'Health';
  String get riskScore => isMalayalam ? 'റിസ്ക് സ്കോർ' : 'Risk';

  String get weightQuestion => isMalayalam
      ? 'ഇപ്പോൾ നിങ്ങളുടെ ഭാരം എത്രയാണ്?'
      : 'What is your weight now?';
  String get weightHelper => isMalayalam
      ? 'കിലോഗ്രാമിൽ നൽകുക. അറിയില്ലെങ്കിൽ അടുത്തതിലേക്ക് പോകാം.'
      : 'Enter it in kilograms, or continue if you do not know.';
  String get weightLabel => isMalayalam ? 'ഭാരം' : 'Weight';

  String get bpQuestion => isMalayalam
      ? 'നിങ്ങളുടെ ഇപ്പോഴത്തെ രക്തസമ്മർദ്ദം എത്രയാണ്?'
      : 'What is your current blood pressure?';
  String get bpHelper => isMalayalam
      ? 'മുകളിലെ സംഖ്യയും താഴെയുള്ള സംഖ്യയും നൽകുക.'
      : 'Enter the upper and lower numbers from your reading.';
  String get bpLabel => isMalayalam ? 'രക്തസമ്മർദ്ദം' : 'Blood pressure';
  String get systolic => isMalayalam ? 'സിസ്റ്റോളിക്' : 'Systolic';
  String get diastolic => isMalayalam ? 'ഡയാസ്റ്റോളിക്' : 'Diastolic';

  String get sugarQuestion => isMalayalam
      ? 'ഏറ്റവും പുതിയ രക്തത്തിലെ പഞ്ചസാര എത്രയാണ്?'
      : 'What is your latest blood sugar reading?';
  String get sugarHelper =>
      isMalayalam ? 'അളവ് mg/dL-ൽ നൽകുക.' : 'Enter the reading in mg/dL.';
  String get sugarLabel => isMalayalam ? 'രക്തത്തിലെ പഞ്ചസാര' : 'Blood sugar';
  String get sugarContextQuestion => isMalayalam
      ? 'ഈ രക്തത്തിലെ പഞ്ചസാര എപ്പോൾ അളന്നു?'
      : 'When was this blood sugar measured?';
  String get sugarContextHelper => isMalayalam
      ? 'ശരിയായ സമയം തിരഞ്ഞെടുക്കുന്നത് ഫലം കൂടുതൽ കൃത്യമായി മനസ്സിലാക്കാൻ സഹായിക്കും.'
      : 'Choose the timing so the reading can be interpreted correctly.';
  String get sugarContextFasting => isMalayalam ? 'ഉപവാസത്തിൽ' : 'Fasting';
  String get sugarContextBeforeMeal =>
      isMalayalam ? 'ഭക്ഷണത്തിന് മുമ്പ്' : 'Before a meal';
  String get sugarContextAfterMeal =>
      isMalayalam ? 'ഭക്ഷണത്തിന് 1–2 മണിക്കൂർ ശേഷം' : '1–2 hours after a meal';
  String get sugarContextRandom => isMalayalam ? 'ഏത് സമയത്തും' : 'Random';
  String get sugarContextUnsure => isMalayalam ? 'ഉറപ്പില്ല' : 'Not sure';

  String sugarContextLabel(String? context) {
    return switch (context) {
      'fasting' => sugarContextFasting,
      'before_meal' => sugarContextBeforeMeal,
      'after_meal' => sugarContextAfterMeal,
      'random' => sugarContextRandom,
      _ => sugarContextUnsure,
    };
  }

  String get cholesterolQuestion => isMalayalam
      ? 'ഏറ്റവും പുതിയ കൊളസ്‌ട്രോൾ അളവ് എത്രയാണ്?'
      : 'What is your latest cholesterol reading?';
  String get cholesterolHelper =>
      isMalayalam ? 'അളവ് mg/dL-ൽ നൽകുക.' : 'Enter the reading in mg/dL.';
  String get cholesterolLabel => isMalayalam ? 'കൊളസ്‌ട്രോൾ' : 'Cholesterol';

  String get conditionsQuestion => isMalayalam
      ? 'ഇപ്പോൾ മറ്റേതെങ്കിലും ആരോഗ്യ പ്രശ്നങ്ങളുണ്ടോ?'
      : 'Do you have any other health concerns today?';
  String get conditionsHelper => isMalayalam
      ? 'ലക്ഷണങ്ങളോ നിലവിലുള്ള ആരോഗ്യ പ്രശ്നങ്ങളോ ചുരുക്കമായി എഴുതുക.'
      : 'Briefly mention symptoms or existing conditions.';
  String get conditionsLabel =>
      isMalayalam ? 'മറ്റ് ആരോഗ്യ പ്രശ്നങ്ങൾ' : 'Other conditions';
  String get conditionsHint =>
      isMalayalam ? 'ഉദാ: പനി, തൊണ്ടവേദന' : 'e.g. Mild fever or sore throat';

  String get reviewTitle =>
      isMalayalam ? 'വിവരങ്ങൾ പരിശോധിക്കുക' : 'Review your readings';
  String get reviewHelper => isMalayalam
      ? 'സംരക്ഷിക്കുന്നതിന് മുമ്പ് നൽകിയ വിവരങ്ങൾ ശരിയാണെന്ന് ഉറപ്പാക്കുക.'
      : 'Make sure everything looks right before saving.';
  String get notProvided => isMalayalam ? 'നൽകിയിട്ടില്ല' : 'Not provided';

  String get invalidSystolic => isMalayalam
      ? 'സിസ്റ്റോളിക് BP 50 നും 300 നും ഇടയിൽ ആയിരിക്കണം.'
      : 'Systolic BP must be between 50 and 300.';
  String get invalidDiastolic => isMalayalam
      ? 'ഡയാസ്റ്റോളിക് BP 30 നും 200 നും ഇടയിൽ ആയിരിക്കണം.'
      : 'Diastolic BP must be between 30 and 200.';
  String get invalidSugar => isMalayalam
      ? 'രക്തത്തിലെ പഞ്ചസാര 0 നും 1000 mg/dL നും ഇടയിൽ ആയിരിക്കണം.'
      : 'Blood sugar must be between 0 and 1000 mg/dL.';
  String get selectSugarContext => isMalayalam
      ? 'രക്തത്തിലെ പഞ്ചസാര അളന്ന സമയം തിരഞ്ഞെടുക്കുക.'
      : 'Select when the blood sugar was measured.';
  String get invalidCholesterol => isMalayalam
      ? 'കൊളസ്‌ട്രോൾ 0 നും 1000 mg/dL നും ഇടയിൽ ആയിരിക്കണം.'
      : 'Cholesterol must be between 0 and 1000 mg/dL.';
  String get invalidWeight => isMalayalam
      ? 'ഭാരം 1 നും 500 കിലോഗ്രാമിനും ഇടയിൽ ആയിരിക്കണം.'
      : 'Weight must be between 1 and 500 kg.';
  String get invalidConditions => isMalayalam
      ? 'മറ്റ് ആരോഗ്യ പ്രശ്നങ്ങൾ 1000 അക്ഷരങ്ങളിൽ കവിയരുത്.'
      : 'Other conditions must be 1000 characters or fewer.';
  String get enterOneReading => isMalayalam
      ? 'കുറഞ്ഞത് ഒരു ആരോഗ്യ വിവരമെങ്കിലും നൽകുക.'
      : 'Enter at least one reading.';
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
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: _accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${filtered.length} health '
                      '${filtered.length == 1 ? 'update' : 'updates'}',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (filtered.length != history.length) ...[
                      const SizedBox(width: 6),
                      Text(
                        'of ${history.length}',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          color: _ink.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const Spacer(),
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
    final copy = _HealthEntryCopy.of(context.read<LanguageProvider>().language);
    final metrics = <_HistoryMetric>[
      if (snapshot.healthScore != null)
        _HistoryMetric(
          icon: Icons.favorite_rounded,
          label: 'Health ${snapshot.healthScore!.toStringAsFixed(0)}',
          color: const Color(0xFF167A58),
        ),
      if (snapshot.riskScore != null)
        _HistoryMetric(
          icon: Icons.shield_outlined,
          label: 'Risk ${snapshot.riskScore!.toStringAsFixed(0)}',
          color: _riskColor(snapshot.riskScore!),
        ),
      if (snapshot.bmi != null)
        _HistoryMetric(
          icon: Icons.accessibility_new_rounded,
          label: 'BMI ${snapshot.bmi!.toStringAsFixed(1)}',
          color: const Color(0xFF27748A),
        ),
      if (snapshot.latestVitals?.bloodPressureSystolic != null)
        _HistoryMetric(
          icon: Icons.monitor_heart_outlined,
          label: 'BP ${_historyBloodPressure(snapshot)}',
          color: const Color(0xFF4E63C8),
        ),
      if (snapshot.bloodSugar != null)
        _HistoryMetric(
          icon: Icons.water_drop_outlined,
          label:
              'Sugar ${snapshot.bloodSugar!.toStringAsFixed(0)} mg/dL · '
              '${copy.sugarContextLabel(snapshot.bloodSugarContext)}',
          color: const Color(0xFF9A5B13),
        ),
      if (snapshot.cholesterol != null)
        _HistoryMetric(
          icon: Icons.science_outlined,
          label:
              'Cholesterol ${snapshot.cholesterol!.toStringAsFixed(0)} mg/dL',
          color: const Color(0xFF8754B4),
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E8F2)),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: _accent,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formatDate(snapshot.snapshotDate),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          if (snapshot.updatedByName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Updated by ${snapshot.updatedByName}'
              '${snapshot.generatedAt == null ? '' : ' · ${_formatDate(snapshot.generatedAt)}'}',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF718096),
              ),
            ),
          ],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metrics
                  .map(
                    (metric) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: metric.color.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(metric.icon, size: 13, color: metric.color),
                          const SizedBox(width: 5),
                          Text(
                            metric.label,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: metric.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if ((snapshot.aiSummary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: _accent,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      snapshot.aiSummary!.trim(),
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        height: 1.45,
                        color: _ink.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
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

  Color _riskColor(double riskScore) {
    if (riskScore >= 60) return const Color(0xFFB54747);
    if (riskScore >= 30) return const Color(0xFFB66A12);
    return const Color(0xFF167A58);
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

  int get _activeFilterCount =>
      (dateRange == null ? 0 : 1) +
      (metricFilter == HealthSnapshotMetricFilter.all ? 0 : 1) +
      (riskFilter == HealthSnapshotRiskFilter.all ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final dateLabel = dateRange == null
        ? 'All dates'
        : '${DateFormat('dd MMM yyyy').format(dateRange!.start)} – '
              '${DateFormat('dd MMM yyyy').format(dateRange!.end)}';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1E8F2)),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ExpansionTile(
          initiallyExpanded: _hasFilters,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tune_rounded, color: _accent, size: 20),
          ),
          title: const Text(
            'Filters',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          subtitle: Text(
            _hasFilters
                ? '$_activeFilterCount active'
                : 'All dates, measurements and risk scores',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _ink.withValues(alpha: 0.58),
            ),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickDates,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      minimumSize: const Size.fromHeight(46),
                      side: const BorderSide(color: Color(0xFFC9D9EE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.calendar_month_rounded, size: 19),
                    label: Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_hasFilters) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onClear,
                    tooltip: 'Clear filters',
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFFB54747),
                      backgroundColor: const Color(0xFFFFEEEE),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Measurement',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF526176),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: HealthSnapshotMetricFilter.values.map((filter) {
                  final selected = metricFilter == filter;
                  return FilterChip(
                    label: Text(filter.label),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: _accent,
                    backgroundColor: const Color(0xFFF6F8FC),
                    side: BorderSide(
                      color: selected ? _accent : const Color(0xFFE1E8F2),
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: const StadiumBorder(),
                    onSelected: (_) => onMetricChanged(filter),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Risk score',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF526176),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: HealthSnapshotRiskFilter.values.map((filter) {
                  final selected = riskFilter == filter;
                  return FilterChip(
                    label: Text(filter.label),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: _accent,
                    backgroundColor: const Color(0xFFF6F8FC),
                    side: BorderSide(
                      color: selected ? _accent : const Color(0xFFE1E8F2),
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: const StadiumBorder(),
                    onSelected: (_) => onRiskChanged(filter),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryMetric {
  const _HistoryMetric({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}
