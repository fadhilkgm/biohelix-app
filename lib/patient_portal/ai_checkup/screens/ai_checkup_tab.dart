import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../core/models/patient_models.dart';
import '../../core/providers/patient_portal_provider.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../lab_booking/screens/package_booking_screen.dart';
import '../services/ai_checkup_service.dart';
import '../../shell/patient_app_shell.dart';

class AiCheckupTab extends StatefulWidget {
  const AiCheckupTab({super.key});

  @override
  State<AiCheckupTab> createState() => _AiCheckupTabState();
}

class _AiCheckupTabState extends State<AiCheckupTab> {
  String _step = 'language';
  String _language = 'en';
  bool _loading = false;
  AiHealthAssessmentResponse? _result;

  final _answers = <String, dynamic>{};
  final List<Map<String, dynamic>> _messages = [];

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
      _answers['gender'] = p.gender ?? 'unknown';
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

  void _startAiChat() {
    _answers['name'] = _nameCtrl.text.trim();
    _answers['age'] = int.tryParse(_ageCtrl.text.trim()) ?? 30;
    _answers['weight'] = _weightCtrl.text.trim();
    _answers['height'] = _heightCtrl.text.trim();
    
    // Initial message to AI to start questioning
    _messages.clear();
    _messages.add({
      'role': 'user',
      'content': 'I am starting my health checkup. My details: ${_answers.toString()}. Please ask me some questions to assess my health risks.'
    });
    
    setState(() => _step = 'ai_chat');
  }

  Future<void> _analyze() async {
    setState(() {
      _step = 'analyzing';
      _loading = true;
    });

    try {
      final config = context.read<AppConfig>();
      final session = context.read<SessionProvider>();
      final service = AiCheckupService(
        apiBaseUrl: config.apiBaseUrl,
        authToken: session.authToken ?? '',
      );

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
        _step = 'ai_chat';
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
        'language' => _LanguageSelectionScreen(
          onSelect: (lang) {
            setState(() {
              _language = lang;
              _step = 'welcome';
            });
          },
        ),
        'welcome' => _WelcomeScreen(
          language: _language,
          onStart: () => _next('basic'),
        ),
        'basic' => _BasicDetailsScreen(
          language: _language,
          nameCtrl: _nameCtrl,
          ageCtrl: _ageCtrl,
          weightCtrl: _weightCtrl,
          heightCtrl: _heightCtrl,
          onNext: _startAiChat,
        ),
        'ai_chat' => _AiChatScreen(
          language: _language,
          messages: _messages,
          patientInfo: {
            'age': int.tryParse(_ageCtrl.text) ?? 30,
            'gender': _answers['gender'] ?? 'unknown',
          },
          onComplete: (allAnswers) {
            _answers.addAll(allAnswers);
            _analyze();
          },
        ),
        'analyzing' => _AnalyzingScreen(language: _language),
        'results' => _result != null
            ? _ResultsScreen(
                language: _language,
                result: _result!,
                onRetake: () => setState(() {
                  _step = 'language';
                  _result = null;
                  _answers.clear();
                  _messages.clear();
                }),
              )
            : const SizedBox.shrink(),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _LanguageSelectionScreen extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _LanguageSelectionScreen({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Choose Language',
            style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF192233)),
          ),
          const SizedBox(height: 12),
          Text(
            'Select your preferred language for the health assessment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 15, color: const Color(0xFF192233).withOpacity(0.6)),
          ),
          const SizedBox(height: 40),
          _OptionCard(
            label: 'English',
            onTap: () => onSelect('en'),
          ),
          _OptionCard(
            label: 'മലയാളം (Malayalam)',
            onTap: () => onSelect('ml'),
          ),
        ],
      ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  final String language;
  final VoidCallback onStart;
  const _WelcomeScreen({required this.language, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final isMl = language == 'ml';
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
            isMl ? 'എഐ ഹെൽത്ത് ചെക്കപ്പ്' : 'AI Health Checkup',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF192233)),
          ),
          const SizedBox(height: 12),
          Text(
            isMl
                ? 'നിങ്ങളുടെ ജീവിതശൈലിയെയും ആരോഗ്യത്തെയും കുറിച്ചുള്ള ഏതാനും ചോദ്യങ്ങൾക്ക് മറുപടി നൽകുക. ഞങ്ങളുടെ എഐ (AI) നിങ്ങളുടെ ഉത്തരങ്ങൾ വിശകലനം ചെയ്യുകയും നിങ്ങൾക്ക് അനുയോജ്യമായ പരിശോധനകൾ നിർദ്ദേശിക്കുകയും ചെയ്യും.'
                : 'Answer a few questions about your lifestyle and health. Our AI will analyze your responses and suggest preventive lab tests tailored for you.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 15, color: const Color(0xFF192233).withOpacity(0.6), height: 1.5),
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
              child: Text(
                isMl ? 'പരിശോധന ആരംഭിക്കുക' : 'Start Assessment',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _BasicDetailsScreen extends StatelessWidget {
  final String language;
  final TextEditingController nameCtrl, ageCtrl, weightCtrl, heightCtrl;
  final VoidCallback onNext;
  const _BasicDetailsScreen({
    required this.language,
    required this.nameCtrl,
    required this.ageCtrl,
    required this.weightCtrl,
    required this.heightCtrl,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isMl = language == 'ml';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          isMl ? 'വിവരങ്ങൾ നൽകുക' : 'Please Enter Your Details',
          style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF192233)),
        ),
        const SizedBox(height: 4),
        Container(width: 60, height: 4, decoration: BoxDecoration(color: const Color(0xFF5A88F1), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 32),
        _TextField(label: isMl ? 'പൂർണ്ണനാമം' : 'Full Name', controller: nameCtrl),
        const SizedBox(height: 16),
        _TextField(label: isMl ? 'പ്രായം' : 'Age', controller: ageCtrl, keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _TextField(label: isMl ? 'ഭാരം (kg)' : 'Weight (kg)', controller: weightCtrl, keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _TextField(label: isMl ? 'ഉയരം (ft/inch)' : 'Height (ft/inch)', controller: heightCtrl)),
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
                Text(
                  isMl ? 'തുടരുക' : 'Continue',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 18),
                ),
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

class _AiChatScreen extends StatefulWidget {
  final String language;
  final List<Map<String, dynamic>> messages;
  final Map<String, dynamic> patientInfo;
  final Function(Map<String, dynamic> answers) onComplete;

  const _AiChatScreen({
    required this.language,
    required this.messages,
    required this.patientInfo,
    required this.onComplete,
  });

  @override
  State<_AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<_AiChatScreen> {
  bool _loading = true;
  String? _question;
  List<String> _options = [];
  final Map<String, dynamic> _chatAnswers = {};
  int _questionCount = 0;
  final int _maxQuestions = 5;

  @override
  void initState() {
    super.initState();
    _fetchNextQuestion();
  }

  Future<void> _fetchNextQuestion() async {
    setState(() => _loading = true);
    try {
      final config = context.read<AppConfig>();
      final session = context.read<SessionProvider>();
      final service = AiCheckupService(
        apiBaseUrl: config.apiBaseUrl,
        authToken: session.authToken ?? '',
      );

      final result = await service.getNextQuestion(
        messages: widget.messages,
        patientInfo: widget.patientInfo,
        step: 'questions',
      );

      final reply = result['reply'];
      if (reply is Map && (reply.containsKey('question') || reply.containsKey('options'))) {
        setState(() {
          _question = reply['question'] as String?;
          _options = List<String>.from(reply['options'] ?? []);
          _loading = false;
        });
        
        // Add AI response to message history
        widget.messages.add({
          'role': 'assistant',
          'content': _question ?? '',
        });
      } else if (reply is Map && reply['finished'] == true) {
        widget.onComplete(_chatAnswers);
      } else {
        // AI returned something unexpected but we'll try to treat it as a final summary or fallback
        if (reply is String && reply.length > 50) {
           widget.onComplete(_chatAnswers);
        } else {
          setState(() => _loading = false);
          throw Exception('AI returned an invalid response format.');
        }
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get next question: $e')),
      );
    }
  }

  void _onAnswer(String answer) {
    _chatAnswers['q${_questionCount + 1}'] = {
      'question': _question,
      'answer': answer,
    };
    
    widget.messages.add({
      'role': 'user',
      'content': answer,
    });

    _questionCount++;
    if (_questionCount >= _maxQuestions) {
      widget.onComplete(_chatAnswers);
    } else {
      _fetchNextQuestion();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMl = widget.language == 'ml';
    final progress = (_questionCount + 1) / _maxQuestions;

    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF5A88F1)),
            const SizedBox(height: 24),
            Text(
              isMl ? 'എഐ ചിന്തിക്കുന്നു...' : 'AI is thinking...',
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFEBEDF2),
              color: const Color(0xFF5A88F1),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            isMl ? 'ചോദ്യം ${_questionCount + 1}' : 'Question ${_questionCount + 1}',
            style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF5A88F1)),
          ),
          const SizedBox(height: 12),
          Text(
            _question ?? '',
            style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF192233)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: _options.map((opt) => _OptionCard(
                label: opt,
                onTap: () => _onAnswer(opt),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => widget.onComplete(_chatAnswers),
              child: Text(
                isMl ? 'വിശകലനം ചെയ്യുക' : 'Skip & Analyze Now',
                style: GoogleFonts.manrope(color: const Color(0xFF8DA0BA), fontWeight: FontWeight.w700),
              ),
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

class _AnalyzingScreen extends StatelessWidget {
  final String language;
  const _AnalyzingScreen({required this.language});

  @override
  Widget build(BuildContext context) {
    final isMl = language == 'ml';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF5A88F1))),
          const SizedBox(height: 24),
          Text(
            isMl ? 'ആരോഗ്യം വിശകലനം ചെയ്യുന്നു...' : 'Analyzing your health...',
            style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF192233)),
          ),
          const SizedBox(height: 8),
          Text(
            isMl
                ? 'ഞങ്ങളുടെ എഐ (AI) വിവരങ്ങൾ പരിശോധിച്ചു വരികയാണ്.'
                : 'Our AI is reviewing your lifestyle and health history.',
            style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF192233).withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}

class _ResultsScreen extends StatefulWidget {
  final String language;
  final AiHealthAssessmentResponse result;
  final VoidCallback onRetake;
  const _ResultsScreen({required this.language, required this.result, required this.onRetake});

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

    final isMl = widget.language == 'ml';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildScoreCard(score, scoreColor),
        if (widget.result.risks.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(isMl ? 'കണ്ടെത്തിയ ആരോഗ്യ പ്രശ്നങ്ങൾ' : 'Suggested Issues', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
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
                Text(isMl ? 'അടുത്തത്: പാക്കേജുകൾ കാണുക' : 'Next: View Packages', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 18)),
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
    final isMl = widget.language == 'ml';
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
              child: Text(isMl ? 'നിർദ്ദേശിച്ച പാക്കേജുകൾ' : 'Suggested Packages', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.result.matchedPackages.isNotEmpty)
          ...widget.result.matchedPackages.map((pkg) => _PackageResultCard(pkg: pkg, isAvailable: true, onBook: () => _bookPackage(context, pkg))),
        if (widget.result.unmatchedPackages.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(isMl ? 'മറ്റു നിർദ്ദേശങ്ങൾ' : 'Also Recommended', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
          const SizedBox(height: 16),
          ...widget.result.unmatchedPackages.map((pkg) => _PackageResultCard(pkg: pkg, isAvailable: false)),
        ],
        if (widget.result.testRecommendations.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(isMl ? 'നിർദ്ദേശിച്ച പരിശോധനകൾ' : 'Suggested Individual Tests', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
          const SizedBox(height: 16),
          _buildTestsCard(),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onRetake,
            icon: const Icon(Icons.replay_rounded),
            label: Text(isMl ? 'വീണ്ടും പരിശോധിക്കുക' : 'Retake Assessment', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5A88F1),
              side: const BorderSide(color: Color(0xFF5A88F1)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => PatientAppShell.of(context).goHome(),
            icon: Icon(Icons.home_rounded, size: 20, color: const Color(0xFF192233).withOpacity(0.6)),
            label: Text(
              isMl ? 'തിരികെ ഹോമിലേക്ക്' : 'Back to Home',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF192233).withOpacity(0.6),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: const Color(0xFF192233).withOpacity(0.12)),
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
    final isMl = widget.language == 'ml';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text(isMl ? 'നിങ്ങളുടെ ആരോഗ്യ സ്കോർ' : 'Your Health Score', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF192233))),
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
