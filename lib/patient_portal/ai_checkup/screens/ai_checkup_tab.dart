import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../core/models/patient_models.dart';
import '../../core/providers/patient_portal_provider.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../lab_booking/screens/package_booking_screen.dart';
import '../services/ai_checkup_service.dart';

class AiCheckupTab extends StatefulWidget {
  const AiCheckupTab({super.key});

  @override
  State<AiCheckupTab> createState() => _AiCheckupTabState();
}

class _AiCheckupTabState extends State<AiCheckupTab> {
  String _step = 'welcome';
  bool _loading = false;
  AiHealthAssessmentResponse? _result;

  final _answers = <String, dynamic>{};

  // Controllers for basic details
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final portal = context.read<PatientPortalProvider>();
    final p = portal.dashboard?.patient;
    if (p != null) {
      _nameCtrl.text = p.name;
      _ageCtrl.text = p.age?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  void _next(String nextStep) => setState(() => _step = nextStep);

  Future<void> _analyze() async {
    setState(() {
      _step = 'analyzing';
      _loading = true;
    });

    try {
      final config = context.read<AppConfig>();
      final session = context.read<SessionProvider>();
      final service = AiCheckupService(
        apiBaseUrl: config.apiBaseUrl.replaceAll('/api', ''),
        authToken: session.patient?.uuid ?? '',
      );

      _answers['name'] = _nameCtrl.text.trim();
      _answers['age'] = int.tryParse(_ageCtrl.text.trim()) ?? 30;
      _answers['weight'] = _weightCtrl.text.trim();
      _answers['height'] = _heightCtrl.text.trim();

      final response = await service.analyzeHealth(answers: _answers);
      if (!mounted) return;

      setState(() {
        _result = response;
        _step = 'results';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = 'lifestyle';
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text('AI Health Checkup', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: switch (_step) {
        'welcome' => _WelcomeScreen(onStart: () => _next('basic')),
        'basic' => _BasicDetailsScreen(
          nameCtrl: _nameCtrl,
          ageCtrl: _ageCtrl,
          weightCtrl: _weightCtrl,
          heightCtrl: _heightCtrl,
          onNext: () => _next('lifestyle'),
        ),
        'lifestyle' => _LifestyleQuestionnaire(
          answers: _answers,
          onNext: () => _next('health'),
        ),
        'health' => _HealthHistoryQuestionnaire(
          answers: _answers,
          onAnalyze: _analyze,
        ),
        'analyzing' => const _AnalyzingScreen(),
        'results' => _result != null
            ? _ResultsScreen(result: _result!, onRetake: () => setState(() { _step = 'basic'; _result = null; _answers.clear(); }))
            : const SizedBox.shrink(),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  final VoidCallback onStart;
  const _WelcomeScreen({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FF),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(Icons.health_and_safety_rounded, size: 56, color: Color(0xFF5A88F1)),
          ),
          const SizedBox(height: 32),
          Text(
            'AI Health Checkup',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF192233)),
          ),
          const SizedBox(height: 12),
          Text(
            'Answer a few questions about your lifestyle and health. Our AI will analyze your responses and suggest preventive lab tests tailored for you.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 15, color: const Color(0xFF192233).withValues(alpha: 0.6), height: 1.5),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A88F1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Start Assessment', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 18)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _BasicDetailsScreen extends StatelessWidget {
  final TextEditingController nameCtrl, ageCtrl, weightCtrl, heightCtrl;
  final VoidCallback onNext;
  const _BasicDetailsScreen({required this.nameCtrl, required this.ageCtrl, required this.weightCtrl, required this.heightCtrl, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Please Enter Your Details', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF192233))),
        const SizedBox(height: 4),
        Container(width: 60, height: 4, decoration: BoxDecoration(color: const Color(0xFF5A88F1), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 32),
        _TextField(label: 'Full Name', controller: nameCtrl),
        const SizedBox(height: 16),
        _TextField(label: 'Age', controller: ageCtrl, keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _TextField(label: 'Weight (kg)', controller: weightCtrl, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _TextField(label: 'Height (ft/inch)', controller: heightCtrl)),
          ],
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A88F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Continue', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const _TextField({required this.label, required this.controller, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF192233))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _LifestyleQuestionnaire extends StatefulWidget {
  final Map<String, dynamic> answers;
  final VoidCallback onNext;
  const _LifestyleQuestionnaire({required this.answers, required this.onNext});

  @override
  State<_LifestyleQuestionnaire> createState() => _LifestyleQuestionnaireState();
}

class _LifestyleQuestionnaireState extends State<_LifestyleQuestionnaire> {
  int _qIndex = 0;

  final _questions = [
    {
      'key': 'diet',
      'title': 'Tell Us About Your Lifestyle',
      'question': 'What best describes your diet?',
      'options': ['Non-Veg (4-6 times a week)', 'Occasional Non-Veg (1-3 times)', 'Vegetarian', 'Vegan / No dairy', 'Gluten Free'],
    },
    {
      'key': 'exercise',
      'title': 'Physical Activity',
      'question': 'How often do you exercise?',
      'options': ['Daily (30+ min)', '3-5 times a week', '1-2 times a week', 'Rarely', 'Never'],
    },
    {
      'key': 'sleep',
      'title': 'Sleep Patterns',
      'question': 'How many hours do you sleep on average?',
      'options': ['Less than 5 hours', '5-6 hours', '7-8 hours', 'More than 8 hours'],
    },
    {
      'key': 'smoking',
      'title': 'Smoking Habits',
      'question': 'Do you smoke?',
      'options': ['No, never', 'Occasionally', 'Yes, regularly', 'Used to, but quit'],
    },
    {
      'key': 'alcohol',
      'title': 'Alcohol Consumption',
      'question': 'How often do you consume alcohol?',
      'options': ['Never', 'Occasionally (social)', 'Weekly', 'Daily'],
    },
    {
      'key': 'stress',
      'title': 'Stress Level',
      'question': 'How would you rate your daily stress?',
      'options': ['Low', 'Moderate', 'High', 'Very High'],
    },
  ];

  void _select(String value) {
    final q = _questions[_qIndex];
    widget.answers[q['key'] as String] = value;
    if (_qIndex < _questions.length - 1) {
      setState(() => _qIndex++);
    } else {
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_qIndex];
    final progress = (_qIndex + 1) / _questions.length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: const Color(0xFFEBEDF2), color: const Color(0xFF5A88F1)),
          ),
          const SizedBox(height: 32),
          Text(q['title'] as String, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF5A88F1))),
          const SizedBox(height: 12),
          Text(q['question'] as String, style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF192233))),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: (q['options'] as List<String>).map((opt) => _OptionCard(
                label: opt,
                onTap: () => _select(opt),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OptionCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E9F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF5A88F1), width: 2)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF192233)))),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF8DA0BA)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HealthHistoryQuestionnaire extends StatefulWidget {
  final Map<String, dynamic> answers;
  final VoidCallback onAnalyze;
  const _HealthHistoryQuestionnaire({required this.answers, required this.onAnalyze});

  @override
  State<_HealthHistoryQuestionnaire> createState() => _HealthHistoryQuestionnaireState();
}

class _HealthHistoryQuestionnaireState extends State<_HealthHistoryQuestionnaire> {
  final List<String> _selectedConditions = [];
  final List<String> _selectedSymptoms = [];

  final _conditions = ['Diabetes', 'Hypertension', 'Heart Disease', 'Thyroid Disorder', 'Liver Disease', 'Kidney Disease', 'Cancer', 'None'];
  final _symptoms = ['Fatigue', 'Weight changes', 'Frequent infections', 'Chest pain', 'Shortness of breath', 'Digestive issues', 'Skin problems', 'None'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Health History', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF192233))),
        const SizedBox(height: 24),
        Text('Any family history of these conditions?', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _conditions.map((c) => _Chip(
            label: c,
            selected: _selectedConditions.contains(c),
            onTap: () => setState(() {
              _selectedConditions.contains(c) ? _selectedConditions.remove(c) : _selectedConditions.add(c);
            }),
          )).toList(),
        ),
        const SizedBox(height: 32),
        Text('Are you experiencing any of these symptoms?', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _symptoms.map((s) => _Chip(
            label: s,
            selected: _selectedSymptoms.contains(s),
            onTap: () => setState(() {
              _selectedSymptoms.contains(s) ? _selectedSymptoms.remove(s) : _selectedSymptoms.add(s);
            }),
          )).toList(),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              widget.answers['familyHistory'] = _selectedConditions;
              widget.answers['symptoms'] = _selectedSymptoms;
              widget.onAnalyze();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A88F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Analyze My Health', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 18)),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5A88F1) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? const Color(0xFF5A88F1) : const Color(0xFFE5E9F0)),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF192233),
          ),
        ),
      ),
    );
  }
}

class _AnalyzingScreen extends StatelessWidget {
  const _AnalyzingScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF5A88F1))),
          const SizedBox(height: 24),
          Text('Analyzing your health...', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
          const SizedBox(height: 8),
          Text('Our AI is reviewing your lifestyle and health history.', style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF192233).withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

class _ResultsScreen extends StatefulWidget {
  final AiHealthAssessmentResponse result;
  final VoidCallback onRetake;
  const _ResultsScreen({required this.result, required this.onRetake});

  @override
  State<_ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<_ResultsScreen> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return _page == 0 ? _buildIssuesPage(context) : _buildPackagesPage(context);
  }

  Widget _buildIssuesPage(BuildContext context) {
    final score = widget.result.healthScore;
    final scoreColor = score >= 70 ? const Color(0xFF1F9A6D) : score >= 40 ? const Color(0xFFF5A623) : const Color(0xFFFF5C5C);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildScoreCard(score, scoreColor),
        if (widget.result.risks.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text('Suggested Issues', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
          const SizedBox(height: 16),
          _buildRisksCard(),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => _page = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A88F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Next: View Packages', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPackagesPage(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _page = 0),
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF5A88F1)),
            ),
            Expanded(
              child: Text('Suggested Packages', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.result.matchedPackages.isNotEmpty)
          ...widget.result.matchedPackages.map((pkg) => _PackageResultCard(pkg: pkg, isAvailable: true, onBook: () => _bookPackage(context, pkg))),
        if (widget.result.unmatchedPackages.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Also Recommended', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
          const SizedBox(height: 16),
          ...widget.result.unmatchedPackages.map((pkg) => _PackageResultCard(pkg: pkg, isAvailable: false)),
        ],
        if (widget.result.testRecommendations.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Suggested Individual Tests', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
          const SizedBox(height: 16),
          _buildTestsCard(),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onRetake,
            icon: const Icon(Icons.replay_rounded),
            label: Text('Retake Assessment', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5A88F1),
              side: const BorderSide(color: Color(0xFF5A88F1)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildScoreCard(int score, Color scoreColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text('Your Health Score', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
          const SizedBox(height: 20),
          SizedBox(
            width: 140, height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  backgroundColor: const Color(0xFFF4F7FF),
                  valueColor: AlwaysStoppedAnimation(scoreColor),
                ),
                Center(
                  child: Text('$score%', style: GoogleFonts.manrope(fontSize: 36, fontWeight: FontWeight.w900, color: const Color(0xFF192233))),
                ),
              ],
            ),
          ),
          if (widget.result.peerComparison.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFFFF8F0), borderRadius: BorderRadius.circular(12)),
              child: Text(widget.result.peerComparison, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFF5A623))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRisksCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: widget.result.risks.map((r) {
          final name = r['name'] as String? ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF5A623), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(name, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF192233)))),
                Text('Risk', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFFF5C5C))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTestsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: widget.result.testRecommendations.map((t) {
          final name = t['name'] as String? ?? '';
          final reason = t['reason'] as String? ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: const Color(0xFFF4F7FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.biotech_outlined, color: Color(0xFF5A88F1), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
                      if (reason.isNotEmpty) Text(reason, style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF192233).withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _bookPackage(BuildContext context, Map<String, dynamic> pkg) {
    final package = LabPackageItem(
      id: (pkg['id'] as num?)?.toInt() ?? 0,
      name: pkg['name'] as String? ?? 'Package',
      slug: pkg['slug'] as String? ?? '',
      status: true,
      basePrice: _parseInt(pkg['basePrice'] ?? pkg['base_price']),
      description: pkg['description'] as String?,
      category: pkg['category'] as String?,
      imageUrl: pkg['imageUrl'] as String? ?? pkg['image_url'] as String?,
      totalTests: (pkg['totalTests'] as num?)?.toInt(),
      discountedPrice: pkg['discountedPrice'] != null || pkg['discounted_price'] != null
          ? _parseInt(pkg['discountedPrice'] ?? pkg['discounted_price'])
          : null,
    );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PackageBookingScreen(package: package)));
  }

  int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class _PackageResultCard extends StatelessWidget {
  final Map<String, dynamic> pkg;
  final bool isAvailable;
  final VoidCallback? onBook;
  const _PackageResultCard({required this.pkg, required this.isAvailable, this.onBook});

  @override
  Widget build(BuildContext context) {
    final name = pkg['name'] as String? ?? pkg['package']?['name'] as String? ?? 'Package';
    final reason = pkg['reason'] as String? ?? pkg['package']?['reason'] as String? ?? '';
    final basePrice = (pkg['basePrice'] ?? pkg['base_price'] ?? 0) as num;
    final discountedPrice = pkg['discountedPrice'] ?? pkg['discounted_price'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: const Color(0xFFF4F7FF), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF5A88F1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
                    if (reason.isNotEmpty)
                      Text(reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF192233).withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ],
          ),
          if (isAvailable) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (discountedPrice != null) ...[
                  Text('\u20B9${(discountedPrice as num).toInt()}', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF5A88F1))),
                  const SizedBox(width: 8),
                  Text('\u20B9${basePrice.toInt()}', style: GoogleFonts.manrope(fontSize: 13, decoration: TextDecoration.lineThrough, color: const Color(0xFF192233).withValues(alpha: 0.3))),
                ] else
                  Text('\u20B9${basePrice.toInt()}', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF5A88F1))),
                const Spacer(),
                ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A88F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Book Now', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFF4F7FF), borderRadius: BorderRadius.circular(8)),
              child: Text('Not available in our lab yet', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF5A88F1))),
            ),
          ],
        ],
      ),
    );
  }
}
