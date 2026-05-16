import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../core/models/patient_models.dart';
import '../../core/providers/patient_portal_provider.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../lab_booking/screens/package_booking_screen.dart';
import '../services/ai_checkup_service.dart';
import '../../shell/patient_app_shell.dart';

typedef AiCheckupServiceFactory =
    AiCheckupService Function(BuildContext context);

AiCheckupService _defaultAiCheckupServiceFactory(BuildContext context) {
  final config = context.read<AppConfig>();
  final session = context.read<SessionProvider>();
  return AiCheckupService(
    apiBaseUrl: config.apiBaseUrl,
    authToken: session.authToken ?? '',
  );
}

class AiCheckupTab extends StatefulWidget {
  const AiCheckupTab({super.key, this.serviceFactory});

  final AiCheckupServiceFactory? serviceFactory;

  @override
  State<AiCheckupTab> createState() => _AiCheckupTabState();
}

class _AiCheckupTabState extends State<AiCheckupTab> {
  String _step = 'language';
  String _language = 'en';
  bool _loadingHistory = true;
  AiHealthAssessmentResponse? _result;
  List<Map<String, dynamic>> _history = [];

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
    _fetchHistory();
  }

  void _reset() {
    setState(() {
      _step = 'history';
      _result = null;
      _answers.clear();
      _messages.clear();
      _language = 'en';
    });
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final service =
          (widget.serviceFactory ?? _defaultAiCheckupServiceFactory)(context);
      final history = await service.getHistory();
      if (!mounted) return;
      setState(() {
        _history = history;
        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
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
    final portal = context.read<PatientPortalProvider>();
    final p = portal.dashboard?.patient;
    final latestVitals = portal.vitalTrend.isNotEmpty ? portal.vitalTrend.last : null;

    if (p != null) {
      _nameCtrl.text = p.name;
      _ageCtrl.text = p.age?.toString() ?? '';
    }
    if (latestVitals != null) {
      _weightCtrl.text = latestVitals.weight.toString();
      _heightCtrl.text = latestVitals.height.toString();
    }

    _answers['name'] = _nameCtrl.text.trim();
    _answers['age'] = int.tryParse(_ageCtrl.text.trim()) ?? 30;
    _answers['weight'] = _weightCtrl.text.trim();
    _answers['height'] = _heightCtrl.text.trim();
    _answers['gender'] = p?.gender ?? 'unknown';

    // Initial message to AI to start questioning
    _messages.clear();
    _messages.add({
      'role': 'user',
      'content':
          'I am starting my health checkup. My details: ${_answers.toString()}. Please ask me some questions to assess my health risks.',
    });

    setState(() => _step = 'ai_chat');
  }

  Future<void> _analyze() async {
    setState(() {
      _step = 'analyzing';
    });

    try {
      final service =
          (widget.serviceFactory ?? _defaultAiCheckupServiceFactory)(context);

      final response = await service.analyzeHealth(
        answers: _answers,
        language: _language,
      );
      if (!mounted) return;

      setState(() {
        _result = response;
        _step = 'results';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = 'ai_chat';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis failed: $e'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(label: 'Retry', onPressed: _analyze),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'AI Health Checkup',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF192233),
          ),
        ),
        backgroundColor: const Color(0xFFF8F9FB),
        foregroundColor: const Color(0xFF192233),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
        leading: _step != 'history'
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF192233),
                ),
                onPressed: () {
                  if (_step == 'results' || _step == 'analyzing') {
                    _reset();
                    return;
                  }
                  setState(() {
                    _step = switch (_step) {
                      'language' => 'history',
                      'welcome' => 'language',
                      'basic' => 'welcome',
                      'ai_chat' => 'basic',
                      _ => 'history',
                    };
                  });
                },
              )
            : null,
      ),
      body: switch (_step) {
        'history' => _HistoryScreen(
          loading: _loadingHistory,
          history: _history,
          onStartNew: () => setState(() => _step = 'language'),
          onSelect: (item) {
            try {
              final assessment = Map<String, dynamic>.from(
                jsonDecode(item['assessmentJson'] as String),
              );
              setState(() {
                _result = AiHealthAssessmentResponse.fromJson(assessment);
                _step = 'results';
              });
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to load assessment result'),
                ),
              );
            }
          },
        ),
        'language' => _LanguageSelectionScreen(
          onSelect: (lang) {
            setState(() {
              _language = lang;
            });
            _startAiChat();
          },
          onReset: _reset,
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
          serviceFactory:
              widget.serviceFactory ?? _defaultAiCheckupServiceFactory,
        ),
        'analyzing' => _AnalyzingScreen(language: _language),
        'results' =>
          _result != null
              ? _ResultsScreen(
                  language: _language,
                  result: _result!,
                  onRetake: _reset,
                  onReset: _reset,
                )
              : const SizedBox.shrink(),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _LanguageSelectionScreen extends StatelessWidget {
  final ValueChanged<String> onSelect;
  final VoidCallback onReset;
  const _LanguageSelectionScreen({
    required this.onSelect,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Choose Language',
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF192233),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select your preferred language for the health assessment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 15,
              color: const Color(0xFF192233).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 40),
          _OptionCard(label: 'English', onTap: () => onSelect('en')),
          _OptionCard(
            label: 'മലയാളം (Malayalam)',
            onTap: () => onSelect('ml'),
          ),
          const SizedBox(height: 20),
          TextButton(onPressed: onReset, child: const Text('Back to History')),
        ],
      ),
    );
  }
}

class _HistoryScreen extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> history;
  final VoidCallback onStartNew;
  final Function(Map<String, dynamic> item) onSelect;

  const _HistoryScreen({
    required this.loading,
    required this.history,
    required this.onStartNew,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Health Checkup History',
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF192233),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'View your previous AI health assessments or start a new one.',
            style: GoogleFonts.manrope(
              fontSize: 15,
              color: const Color(0xFF192233).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5A88F1)),
                  )
                : history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 64,
                          color: const Color(0xFF192233).withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No previous assessments found',
                          style: GoogleFonts.manrope(
                            color: const Color(
                              0xFF192233,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final dateStr = item['createdAt'] as String;
                      final score = item['healthScore'] as int;

                      String displayDate = dateStr;
                      try {
                        // SQLite datetime('now') returns UTC.
                        // We replace space with T and append Z to make it a valid UTC ISO string
                        final isoStr = dateStr.contains('T')
                            ? dateStr
                            : '${dateStr.replaceFirst(' ', 'T')}Z';
                        final dt = DateTime.parse(isoStr).toLocal();
                        displayDate = DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(dt);
                      } catch (e) {
                        displayDate = dateStr;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E9F0)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          onTap: () => onSelect(item),
                          title: Text(
                            displayDate,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text('Health Score: $score%'),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF5A88F1),
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.analytics_rounded,
                              color: Color(0xFF5A88F1),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStartNew,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A88F1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Start New Assessment',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FF),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              size: 56,
              color: Color(0xFF5A88F1),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            isMl
                ? 'AI ഹെൽത്ത് ചെക്കപ്പ്' : 'AI Health Checkup',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF192233),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isMl
                ? 'നിങ്ങളുടെ ജീവിതരീതിയെയും ആരോഗ്യത്തെയും കുറിച്ചുള്ള ഏതാനും ചോദ്യങ്ങൾക്ക് മറുപടി നൽകുക. ഞങ്ങളുടെ AI നിങ്ങളുടെ ഉത്തരങ്ങൾ വിശകലനം ചെയ്യുകയും നിങ്ങൾക്ക് അനുയോജ്യമായ പരിശോധനകൾ നിർദ്ദേശിക്കുകയും ചെയ്യും.' : 'Answer a few questions about your lifestyle and health. Our AI will analyze your responses and suggest preventive lab tests tailored for you.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 15,
              color: const Color(0xFF192233).withValues(alpha: 0.6),
              height: 1.5,
            ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                isMl
                    ? 'പരിശോധന ആരംഭിക്കുക' : 'Start Assessment',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
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
          isMl
              ? 'വിവരങ്ങൾ നൽകുക' : 'Please Enter Your Details',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF192233),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF5A88F1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 32),
        _TextField(
          label: isMl ? 'പൂർണ്ണനാമം' : 'Full Name',
          controller: nameCtrl,
        ),
        const SizedBox(height: 16),
        _TextField(
          label: isMl ? 'പ്രായം' : 'Age',
          controller: ageCtrl,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TextField(
                label: isMl ? 'ഭാരം (kg)' : 'Weight (kg)',
                controller: weightCtrl,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TextField(
                label: isMl ? 'ഉയരം (ft/inch)' : 'Height (ft/inch)',
                controller: heightCtrl,
              ),
            ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isMl ? 'തുടരുക' : 'Continue',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
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
  const _TextField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF192233),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
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
              vertical: 16,
            ),
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
  final AiCheckupServiceFactory serviceFactory;

  const _AiChatScreen({
    required this.language,
    required this.messages,
    required this.patientInfo,
    required this.onComplete,
    required this.serviceFactory,
  });

  @override
  State<_AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<_AiChatScreen> {
  bool _loading = false;
  String? _question;
  List<String> _options = ['Yes', 'No'];
  final Map<String, dynamic> _chatAnswers = {};
  int _questionCount = 0;
  final int _maxQuestions = 10;
  
  final Map<String, int> _scores = {
    'HbA1c': 0,
    'Lipid Profile': 0,
    'Thyroid Profile': 0,
    'CBC': 0,
  };

  final List<({String en, String ml, String test, int points})> _staticQuestions = [
    (
      en: 'Do you experience excessive thirst or frequent urination?',
      ml: 'നിങ്ങൾക്ക് അധികമായ ദാഹമോ ഇടയ്ക്കിടെയുള്ള മൂത്രവിസർജ്ജനമോ അനുഭവപ്പെടുന്നുണ്ടോ?',
      test: 'HbA1c',
      points: 3,
    ),
    (
      en: 'Have you noticed unexplained weight gain or loss recently?',
      ml: 'ഈയിടെയായി വിശദീകരിക്കാനാകാത്ത ശരീരഭാര വ്യതിയാനം ശ്രദ്ധിച്ചിട്ടുണ്ടോ?',
      test: 'Thyroid Profile',
      points: 3,
    ),
    (
      en: 'Do you feel tired or fatigued even after a full night\'s sleep?',
      ml: 'മലയാളം ചോദ്യം ലഭ്യമല്ല',
      test: 'CBC',
      points: 2,
    ),
    (
      en: 'Do you have a family history of heart disease or high blood pressure?',
      ml: 'നിങ്ങളുടെ കുടുംബത്തിൽ ആർക്കെങ്കിലും ഹൃദ്രോഗമോ ഉയർന്ന രക്തസമ്മർദ്ദമോ ഉണ്ടോ?',
      test: 'Lipid Profile',
      points: 3,
    ),
    (
      en: 'Do you often crave sugary foods or experience energy crashes?',
      ml: 'നിങ്ങൾക്ക് പലപ്പോഴും മധുരപലഹാരങ്ങളോട് അമിതമായ ആസക്തി തോന്നാറുണ്ടോ?',
      test: 'HbA1c',
      points: 2,
    ),
    (
      en: 'Have you noticed changes in your skin, hair, or sensitivity to cold/heat?',
      ml: 'ചർമ്മത്തിലോ മുടിയിലോ മാറ്റങ്ങളോ തണുപ്പിനോ ചൂടിനോടുള്ള അമിത സംവേദനക്ഷമതയോ ഉണ്ടോ?',
      test: 'Thyroid Profile',
      points: 3,
    ),
    (
      en: 'Do you experience shortness of breath during light physical activity?',
      ml: 'ചെറിയ ശാരീരിക അധ്വാനത്തിൽ പോലും നിങ്ങൾക്ക് ശ്വാസംമുട്ടൽ അനുഭവപ്പെടുന്നുണ്ടോ?',
      test: 'Lipid Profile',
      points: 2,
    ),
    (
      en: 'Do you consume fried foods or high-fat meals frequently?',
      ml: 'നിങ്ങൾ വറുത്ത ഭക്ഷണങ്ങളും കൊഴുപ്പുള്ള ആഹാരങ്ങളും ഇടയ്ക്കിടെ കഴിക്കാറുണ്ടോ?',
      test: 'Lipid Profile',
      points: 3,
    ),
    (
      en: 'Do you frequently get minor infections or take a long time to heal?',
      ml: 'നിങ്ങൾക്ക് ഇടയ്ക്കിടെ അണുബാധകൾ ഉണ്ടാകാറുണ്ടോ അതോ മുറിവുകൾ ഉണങ്ങാൻ താമസമെടുക്കാറുണ്ടോ?',
      test: 'CBC',
      points: 3,
    ),
    (
      en: 'Are you over 45 years old or have a sedentary lifestyle?',
      ml: 'നിങ്ങൾക്ക് 45 വയസ്സിൽ കൂടുതൽ പ്രായമുണ്ടോ അതോ വ്യായാമമില്ലാത്ത ജീവിതരീതിയാണോ?',
      test: 'HbA1c',
      points: 1,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentQuestion();
  }



  void _loadCurrentQuestion() {
    final isMl = widget.language == 'ml';
    final q = _staticQuestions[_questionCount];
    setState(() {
      _question = isMl ? q.ml : q.en;
      _options = isMl ? ['അതെ', 'അല്ല'] : ['Yes', 'No'];
    });
    
    widget.messages.add({'role': 'assistant', 'content': _question ?? ''});
  }

  void _onAnswer(String answer) {
    final isYes = answer == 'Yes' || answer == 'അതെ';
    final q = _staticQuestions[_questionCount];
    
    if (isYes) {
      _scores[q.test] = (_scores[q.test] ?? 0) + q.points;
      // Secondary scores
      if (q.test == 'CBC') _scores['Thyroid Profile'] = (_scores['Thyroid Profile'] ?? 0) + 1;
      if (q.test == 'Lipid Profile') _scores['CBC'] = (_scores['CBC'] ?? 0) + 1;
    }

    // Only include question text for "Yes" answers to avoid triggering rule-based risks on "No"
    _chatAnswers['q${_questionCount + 1}'] = {
      'question': isYes ? q.en : '', 
      'answer': answer,
    };

    widget.messages.add({'role': 'user', 'content': answer});

    if (_questionCount < _maxQuestions - 1) {
      _questionCount++;
      _loadCurrentQuestion();
    } else {
      _completeAssessment();
    }
  }

  void _completeAssessment() {
    // Determine top recommendation and total risk score
    int totalRiskPoints = 0;
    _scores.forEach((key, value) => totalRiskPoints += value);
    
    int calculatedScore = 100 - (totalRiskPoints * 3);
    calculatedScore = calculatedScore.clamp(15, 98);

    final recommendedTest = _scores.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    
    // Pass essential data in a flat format to prevent backend parsing issues
    _chatAnswers['health_score_hint'] = calculatedScore;
    _chatAnswers['priority_test'] = recommendedTest;
    _chatAnswers['risk_level'] = totalRiskPoints > 15 ? 'High' : (totalRiskPoints > 7 ? 'Medium' : 'Low');
    
    widget.messages.add({
      'role': 'system',
      'content': 'Questionnaire Finished. Risk Priority: $recommendedTest. Calculated Score: $calculatedScore%.',
    });
    
    widget.onComplete(_chatAnswers);
  }

  void _goBack() {
    if (_questionCount > 0) {
      setState(() {
        _questionCount--;
        // Remove last user answer and last AI question from message history
        if (widget.messages.length >= 2) {
          widget.messages.removeLast(); // User A
          widget.messages.removeLast(); // AI Q
        }
        _loadCurrentQuestion();
      });
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
              isMl ? 'എഐ ആലോചിക്കുന്നു...' : 'AI is thinking...',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final currentAnswer = _chatAnswers['q${_questionCount + 1}']?['answer'];

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isMl
                    ? 'à´šàµ‹à´¦àµà´¯à´‚ ${_questionCount + 1}'
                    : 'Question ${_questionCount + 1}',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5A88F1),
                ),
              ),
              if (_questionCount > 0)
                TextButton.icon(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(
                    isMl ? 'തിരികെ' : 'Back',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8DA0BA),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _question ?? '',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF192233),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                ..._options.map(
                  (opt) => _OptionCard(
                    label: opt,
                    isSelected: currentAnswer == opt,
                    onTap: () => _onAnswer(opt),
                  ),
                ),
                if (currentAnswer != null) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _onAnswer(currentAnswer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5A88F1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isMl ? 'തുടരുക' : 'Continue',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => widget.onComplete(_chatAnswers),
              child: Text(
                isMl
                    ? 'വിശകലനം ചെയ്യുക' : 'Skip & Analyze Now',
                style: GoogleFonts.manrope(
                  color: const Color(0xFF8DA0BA),
                  fontWeight: FontWeight.w700,
                ),
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
  final bool isSelected;
  final VoidCallback onTap;
  const _OptionCard({
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

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
              color: isSelected ? const Color(0xFFF4F7FF) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF5A88F1)
                    : const Color(0xFFE5E9F0),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF5A88F1)
                        : Colors.transparent,
                    border: Border.all(
                      color: const Color(0xFF5A88F1),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF5A88F1)
                          : const Color(0xFF192233),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isSelected
                      ? const Color(0xFF5A88F1)
                      : const Color(0xFF8DA0BA),
                ),
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
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: Color(0xFF5A88F1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isMl
                ? 'ആരോഗ്യം വിശകലനം ചെയ്യുന്നു...' : 'Analyzing your health...',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF192233),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isMl
                ? 'ഞങ്ങളുടെ AI വിവരങ്ങൾ പരിശോധിച്ചു വരികയാണ്.' : 'Our AI is reviewing your lifestyle and health history.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: const Color(0xFF192233).withValues(alpha: 0.5),
            ),
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
  final VoidCallback onReset;
  const _ResultsScreen({
    required this.language,
    required this.result,
    required this.onRetake,
    required this.onReset,
  });

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
    final scoreColor = score >= 70
        ? const Color(0xFF1F9A6D)
        : score >= 40
        ? const Color(0xFFF5A623)
        : const Color(0xFFFF5C5C);

    final isMl = widget.language == 'ml';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildScoreCard(score, scoreColor),
        if (widget.result.risks.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            isMl
                ? 'കണ്ടെത്തിയ ആരോഗ്യ പ്രശ്നങ്ങൾ' : 'Suggested Issues',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF192233),
            ),
          ),
          const SizedBox(height: 16),
          _buildRisksCard(),
        ],
        if (widget.result.matchedPackages.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            isMl
                ? 'നിർദ്ദേശിച്ച പാക്കേജുകൾ' : 'Recommended Packages',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF192233),
            ),
          ),
          const SizedBox(height: 16),
          ...widget.result.matchedPackages.map(
            (pkg) => _PackageResultCard(
              pkg: pkg,
              isAvailable: true,
              onBook: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PackageBookingScreen(
                      package: LabPackageItem.fromJson(pkg),
                    ),
                  ),
                );
              },
            ),
          ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    isMl
                        ? 'അടുത്തത് : പാക്കേജുകൾ കാണുക' : 'Next: View Packages',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w900,
                      fontSize: isMl ? 16 : 18,
                    ),
                  ),
                ),
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
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF5A88F1),
              ),
            ),
            Expanded(
              child: Text(
                isMl
                    ? 'നിർദ്ദേശിച്ച പാക്കേജുകൾ' : 'Suggested Packages',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF192233),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.result.matchedPackages.isNotEmpty)
          ...widget.result.matchedPackages.map(
            (pkg) => _PackageResultCard(
              pkg: pkg,
              isAvailable: true,
              onBook: () => _bookPackage(context, pkg),
            ),
          ),
        if (widget.result.unmatchedPackages.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            isMl
                ? 'മറ്റ് നിർദ്ദേശങ്ങൾ' : 'Also Recommended',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF192233),
            ),
          ),
          const SizedBox(height: 16),
          ...widget.result.unmatchedPackages.map(
            (pkg) => _PackageResultCard(pkg: pkg, isAvailable: false),
          ),
        ],
        if (widget.result.testRecommendations.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            isMl
                ? 'നിർദ്ദേശിച്ച പരിശോധനകൾ' : 'Suggested Individual Tests',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF192233),
            ),
          ),
          const SizedBox(height: 16),
          _buildTestsCard(),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onRetake,
            icon: const Icon(Icons.replay_rounded),
            label: Text(
              isMl
                  ? 'വീണ്ടും പരിശോധിക്കുക' : 'Retake Assessment',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5A88F1),
              side: const BorderSide(color: Color(0xFF5A88F1)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              widget.onReset();
              PatientAppShell.of(context).goHome();
            },
            icon: Icon(
              Icons.home_rounded,
              size: 20,
              color: const Color(0xFF192233).withValues(alpha: 0.6),
            ),
            label: Text(
              isMl
                  ? 'തിരികെ ഹോമിലേക്ക്' : 'Back to Home',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF192233).withValues(alpha: 0.6),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: const Color(0xFF192233).withValues(alpha: 0.12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isMl
                ? 'നിങ്ങളുടെ ആരോഗ്യ സ്കോർ' : 'Your Health Score',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF192233),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 140,
            height: 140,
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
                  child: Text(
                    '$score%',
                    style: GoogleFonts.manrope(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF192233),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.result.peerComparison.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.result.peerComparison,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF5A623),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRisksCard() {
    final isMl = widget.language == 'ml';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: widget.result.risks.map((risk) {
          final name = risk['name'] ?? '';
          final reason = risk['reason'] ?? '';
          final precaution = risk['precaution'] ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4F4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: Color(0xFFFF5C5C),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF192233),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (reason.isNotEmpty)
                            Text(
                              reason,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                height: 1.5,
                                color: const Color(
                                  0xFF192233,
                                ).withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (precaution.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF5A88F1).withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 16,
                          color: Color(0xFF5A88F1),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${isMl ? 'മുൻകരുതൽ' : 'Precaution'}: $precaution",
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5A88F1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.result.risks.indexOf(risk) <
                    widget.result.risks.length - 1) ...[
                  const SizedBox(height: 20),
                  Divider(
                    color: const Color(0xFFE5E9F0).withValues(alpha: 0.5),
                  ),
                ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.biotech_outlined,
                    color: Color(0xFF5A88F1),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF192233),
                        ),
                      ),
                      if (reason.isNotEmpty)
                        Text(
                          reason,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: const Color(
                              0xFF192233,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
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
      discountedPrice:
          pkg['discountedPrice'] != null || pkg['discounted_price'] != null
          ? _parseInt(pkg['discountedPrice'] ?? pkg['discounted_price'])
          : null,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PackageBookingScreen(package: package)),
    );
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
  const _PackageResultCard({
    required this.pkg,
    required this.isAvailable,
    this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        pkg['name'] as String? ??
        pkg['package']?['name'] as String? ??
        'Package';
    final reason =
        pkg['reason'] as String? ?? pkg['package']?['reason'] as String? ?? '';
    final basePrice = (pkg['basePrice'] ?? pkg['base_price'] ?? 0) as num;
    final discountedPrice = pkg['discountedPrice'] ?? pkg['discounted_price'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: const Color(0xFFF4F7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF5A88F1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF192233),
                      ),
                    ),
                    if (reason.isNotEmpty)
                      Text(
                        reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: const Color(0xFF192233).withValues(alpha: 0.5),
                        ),
                      ),
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
                  Text(
                    '\u20B9${(discountedPrice as num).toInt()}',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF5A88F1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\u20B9${basePrice.toInt()}',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      decoration: TextDecoration.lineThrough,
                      color: const Color(0xFF192233).withValues(alpha: 0.3),
                    ),
                  ),
                ] else
                  Text(
                    '\u20B9${basePrice.toInt()}',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF5A88F1),
                    ),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A88F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Book Now',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Not available in our lab yet',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5A88F1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
