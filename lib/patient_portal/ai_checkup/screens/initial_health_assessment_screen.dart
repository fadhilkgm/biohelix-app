import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/language_provider.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../core/data/patient_repository.dart';

class InitialHealthAssessmentScreen extends StatefulWidget {
  const InitialHealthAssessmentScreen({super.key});

  @override
  State<InitialHealthAssessmentScreen> createState() =>
      _InitialHealthAssessmentScreenState();
}

class _InitialHealthAssessmentScreenState
    extends State<InitialHealthAssessmentScreen> {
  static const _stepCount = 7;

  final _height = TextEditingController();
  final _allergies = TextEditingController();
  final _medications = TextEditingController();
  final _conditions = TextEditingController();
  final _weight = TextEditingController();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _bloodSugar = TextEditingController();
  final _cholesterol = TextEditingController();

  int _step = 0;
  String? _activityLevel;
  String? _smokingStatus;
  String? _sleepQuality;
  String _sugarContext = 'unsure';
  bool _saving = false;
  String? _error;

  bool get _isMalayalam =>
      context.read<LanguageProvider>().language == AppLanguage.ml;

  String _text(String english, String malayalam) =>
      _isMalayalam ? malayalam : english;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    for (final controller in [
      _height,
      _allergies,
      _medications,
      _conditions,
      _weight,
      _systolic,
      _diastolic,
      _bloodSugar,
      _cholesterol,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _items(String text) => text
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step < _stepCount - 1) {
      setState(() {
        _step++;
        _error = null;
      });
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    await _completeAssessment(
      InitialHealthAssessmentInput(
        height: double.tryParse(_height.text.trim()),
        weight: double.tryParse(_weight.text.trim()),
        bloodPressureSystolic: int.tryParse(_systolic.text.trim()),
        bloodPressureDiastolic: int.tryParse(_diastolic.text.trim()),
        bloodSugar: double.tryParse(_bloodSugar.text.trim()),
        bloodSugarContext: _sugarContext,
        cholesterol: double.tryParse(_cholesterol.text.trim()),
        allergies: _items(_allergies.text),
        currentMedications: _items(_medications.text),
        chronicConditions: _items(_conditions.text),
        activityLevel: _activityLevel,
        smokingStatus: _smokingStatus,
        sleepQuality: _sleepQuality,
      ),
    );
  }

  Future<void> _skip() async {
    FocusScope.of(context).unfocus();
    await _completeAssessment(const InitialHealthAssessmentInput());
  }

  Future<void> _completeAssessment(InitialHealthAssessmentInput input) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final patient = await context
          .read<PatientRepository>()
          .completeInitialHealthAssessment(input);
      if (!mounted) return;
      context.read<SessionProvider>().updatePatient(patient);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF7F9FC),
        surfaceTintColor: Colors.transparent,
        title: Text(
          _text('Your health profile', 'നിങ്ങളുടെ ആരോഗ്യ പ്രൊഫൈൽ'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _skip,
            child: Text(
              _text('Skip', 'ഒഴിവാക്കുക'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _stepCount,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE2E8F2),
                  color: const Color(0xFF0754A6),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _text(
                      'A one-time check to personalise your care',
                      'നിങ്ങളുടെ പരിചരണം വ്യക്തിഗതമാക്കാനുള്ള ഒറ്റത്തവണ പരിശോധന',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '${_step + 1}/$_stepCount',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0754A6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: SingleChildScrollView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: _AssessmentCard(child: _stepContent()),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() => _step--),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(_text('Back', 'പിന്നോട്ട്')),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _next,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: const Color(0xFF0754A6),
                      ),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _step == _stepCount - 1
                                  ? _text('Finish', 'പൂർത്തിയാക്കുക')
                                  : _text('Next', 'അടുത്തത്'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepContent() {
    return switch (_step) {
      0 => _question(
        icon: Icons.height_rounded,
        title: _text('What is your height?', 'നിങ്ങളുടെ ഉയരം എത്രയാണ്?'),
        subtitle: _knownOnly,
        children: [
          _field(
            controller: _height,
            label: _text('Height in cm (optional)', 'ഉയരം cm-ൽ (optional)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: 'cm',
          ),
        ],
      ),
      1 => _question(
        icon: Icons.warning_amber_rounded,
        title: _text(
          'Do you have any allergies?',
          'നിങ്ങൾക്ക് ഏതെങ്കിലും അലർജിയുണ്ടോ?',
        ),
        subtitle: _text(
          'Separate multiple items with commas. Leave blank if none or unknown.',
          'ഒന്നിലധികം വിവരങ്ങൾ കോമ ഉപയോഗിച്ച് വേർതിരിക്കുക. ഇല്ലെങ്കിൽ അല്ലെങ്കിൽ അറിയില്ലെങ്കിൽ ഒഴിച്ചിടാം.',
        ),
        children: [
          _field(
            controller: _allergies,
            label: _text('Allergies (optional)', 'അലർജികൾ (optional)'),
            maxLines: 2,
          ),
        ],
      ),
      2 => _question(
        icon: Icons.medication_outlined,
        title: _text(
          'Are you taking any medications?',
          'നിങ്ങൾ നിലവിൽ ഏതെങ്കിലും മരുന്നുകൾ കഴിക്കുന്നുണ്ടോ?',
        ),
        subtitle: _text(
          'Separate multiple medicines with commas. Leave blank if none or unknown.',
          'ഒന്നിലധികം മരുന്നുകൾ കോമ ഉപയോഗിച്ച് വേർതിരിക്കുക. ഇല്ലെങ്കിൽ അല്ലെങ്കിൽ അറിയില്ലെങ്കിൽ ഒഴിച്ചിടാം.',
        ),
        children: [
          _field(
            controller: _medications,
            label: _text(
              'Current medications (optional)',
              'നിലവിലെ മരുന്നുകൾ (optional)',
            ),
            maxLines: 2,
          ),
        ],
      ),
      3 => _question(
        icon: Icons.medical_information_outlined,
        title: _text(
          'Do you have any known health conditions?',
          'നിങ്ങൾക്ക് അറിയാവുന്ന ആരോഗ്യപ്രശ്നങ്ങളുണ്ടോ?',
        ),
        subtitle: _text(
          'Separate multiple conditions with commas. Leave blank if none or unknown.',
          'ഒന്നിലധികം ആരോഗ്യപ്രശ്നങ്ങൾ കോമ ഉപയോഗിച്ച് വേർതിരിക്കുക. ഇല്ലെങ്കിൽ അല്ലെങ്കിൽ അറിയില്ലെങ്കിൽ ഒഴിച്ചിടാം.',
        ),
        children: [
          _field(
            controller: _conditions,
            label: _text(
              'Known health conditions (optional)',
              'അറിയാവുന്ന ആരോഗ്യപ്രശ്നങ്ങൾ (optional)',
            ),
            maxLines: 2,
          ),
        ],
      ),
      4 => _question(
        icon: Icons.directions_walk_rounded,
        title: _text(
          'A little about your routine',
          'നിങ്ങളുടെ ദിനചര്യയെക്കുറിച്ച്',
        ),
        subtitle: _text(
          'These answers help us understand everyday health risks.',
          'ദൈനംദിന ആരോഗ്യ അപകടസാധ്യത മനസ്സിലാക്കാൻ ഈ ഉത്തരങ്ങൾ സഹായിക്കും.',
        ),
        children: [
          _choices(
            label: _text('Activity level', 'ശാരീരിക പ്രവർത്തനം'),
            value: _activityLevel,
            options: {
              'low': _text('Low', 'കുറവ്'),
              'moderate': _text('Moderate', 'മിതം'),
              'active': _text('Active', 'സജീവം'),
            },
            onChanged: (value) => setState(() => _activityLevel = value),
          ),
          const SizedBox(height: 18),
          _choices(
            label: _text('Smoking', 'പുകവലി'),
            value: _smokingStatus,
            options: {
              'never': _text('Never', 'ഒരിക്കലുമില്ല'),
              'former': _text('Former', 'മുമ്പ്'),
              'current': _text('Current', 'നിലവിൽ'),
            },
            onChanged: (value) => setState(() => _smokingStatus = value),
          ),
          const SizedBox(height: 18),
          _choices(
            label: _text('Sleep quality', 'ഉറക്കത്തിന്റെ നിലവാരം'),
            value: _sleepQuality,
            options: {
              'good': _text('Good', 'നല്ലത്'),
              'average': _text('Average', 'ശരാശരി'),
              'poor': _text('Poor', 'മോശം'),
            },
            onChanged: (value) => setState(() => _sleepQuality = value),
          ),
        ],
      ),
      5 => _question(
        icon: Icons.monitor_heart_outlined,
        title: _text(
          'Do you know these readings?',
          'ഈ അളവുകൾ നിങ്ങൾക്ക് അറിയാമോ?',
        ),
        subtitle: _knownOnly,
        children: [
          _field(
            controller: _weight,
            label: _text('Weight in kg (optional)', 'ഭാരം kg-ൽ (optional)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: 'kg',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _systolic,
                  label: _text('BP upper', 'BP മുകൾ'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('/'),
              ),
              Expanded(
                child: _field(
                  controller: _diastolic,
                  label: _text('BP lower', 'BP താഴെ'),
                  keyboardType: TextInputType.number,
                  suffix: 'mmHg',
                ),
              ),
            ],
          ),
        ],
      ),
      _ => _question(
        icon: Icons.bloodtype_outlined,
        title: _text(
          'Any recent test values?',
          'സമീപകാല പരിശോധനാ മൂല്യങ്ങൾ ഉണ്ടോ?',
        ),
        subtitle: _knownOnly,
        children: [
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _bloodSugar,
                  label: _text('Blood sugar', 'രക്തത്തിലെ പഞ്ചസാര'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  suffix: 'mg/dL',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sugarContext,
                  decoration: InputDecoration(
                    labelText: _text('Reading type', 'അളവിന്റെ തരം'),
                  ),
                  items:
                      {
                            'fasting': _text('Fasting', 'ഉപവാസം'),
                            'before_meal': _text(
                              'Before meal',
                              'ഭക്ഷണത്തിന് മുമ്പ്',
                            ),
                            'after_meal': _text(
                              'After meal',
                              'ഭക്ഷണത്തിന് ശേഷം',
                            ),
                            'random': _text('Random', 'ഏത് സമയത്തും'),
                            'unsure': _text('Not sure', 'അറിയില്ല'),
                          }.entries
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.key,
                              child: Text(item.value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setState(() => _sugarContext = value ?? 'unsure'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field(
            controller: _cholesterol,
            label: _text(
              'Total cholesterol (optional)',
              'ആകെ കൊളസ്ട്രോൾ (optional)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: 'mg/dL',
          ),
        ],
      ),
    };
  }

  String get _knownOnly => _text(
    'Enter it only if you know it. You can leave this blank.',
    'അറിയാമെങ്കിൽ മാത്രം നൽകുക. ഇത് ഒഴിച്ചിടാവുന്നതാണ്.',
  );

  Widget _question({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF0754A6)),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF64748B), height: 1.45),
        ),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? suffix,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _choices({
    required String label,
    required String? value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries
              .map(
                (option) => ChoiceChip(
                  label: Text(option.value),
                  selected: value == option.key,
                  onSelected: (_) => onChanged(option.key),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
