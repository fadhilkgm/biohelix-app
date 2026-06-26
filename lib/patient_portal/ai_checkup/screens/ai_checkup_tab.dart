import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../core/models/patient_models.dart';
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

const _kInk = Color(0xFF192233);
const _kAccent = Color(0xFF5A88F1);
const _kBg = Color(0xFFF8F9FB);

int _parsePrice(String? raw) {
  if (raw == null) return 0;
  return double.tryParse(raw)?.round() ?? int.tryParse(raw) ?? 0;
}

/// AI Health Checkup, backed by the documented `/health-assessment` flow:
/// start a session -> answer the generated multiple-choice questions ->
/// submit for evaluation -> view risk level, insights and recommendations.
class AiCheckupTab extends StatefulWidget {
  const AiCheckupTab({super.key, this.serviceFactory});

  final AiCheckupServiceFactory? serviceFactory;

  @override
  State<AiCheckupTab> createState() => _AiCheckupTabState();
}

class _AiCheckupTabState extends State<AiCheckupTab> {
  String _step = 'language';
  String _language = 'en';

  AssessmentSession? _session;
  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  AssessmentResults? _results;
  String? _error;

  AiCheckupService get _service =>
      (widget.serviceFactory ?? _defaultAiCheckupServiceFactory)(context);

  void _reset() {
    setState(() {
      _step = 'language';
      _language = 'en';
      _session = null;
      _currentIndex = 0;
      _answers.clear();
      _results = null;
      _error = null;
    });
  }

  Future<void> _start() async {
    setState(() {
      _step = 'starting';
      _error = null;
    });
    try {
      final session = await _service.startAssessment(language: _language);
      if (!mounted) return;
      if (session.questions.isEmpty) {
        setState(() {
          _step = 'welcome';
          _error = 'No questions are available right now. Please try again.';
        });
        return;
      }
      setState(() {
        _session = session;
        _currentIndex = 0;
        _answers.clear();
        _step = 'questions';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _step = 'welcome';
        _error = error.toString();
      });
    }
  }

  void _answer(AssessmentQuestion question, String optionKey) {
    _answers[question.id.toString()] = optionKey;
    final isLast = _currentIndex >= (_session!.questions.length - 1);
    if (isLast) {
      _submit();
    } else {
      setState(() => _currentIndex++);
    }
  }

  void _back() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  Future<void> _submit() async {
    setState(() => _step = 'analyzing');
    try {
      final results = await _service.submitAnswers(
        sessionToken: _session!.sessionToken,
        answers: _answers,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _step = 'results';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _step = 'questions');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Analysis failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          'AI Health Checkup',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _kInk,
          ),
        ),
        backgroundColor: _kBg,
        foregroundColor: _kInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
        leading: _step != 'language'
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded, color: _kInk),
                onPressed: () {
                  if (_step == 'results' || _step == 'analyzing') {
                    _reset();
                    return;
                  }
                  if (_step == 'questions' && _currentIndex > 0) {
                    _back();
                    return;
                  }
                  setState(() {
                    _step = switch (_step) {
                      'welcome' => 'language',
                      'questions' => 'welcome',
                      _ => 'language',
                    };
                  });
                },
              )
            : null,
      ),
      body: switch (_step) {
        'language' => _LanguageSelectionScreen(
          onSelect: (lang) => setState(() {
            _language = lang;
            _step = 'welcome';
          }),
        ),
        'welcome' => _WelcomeScreen(
          language: _language,
          error: _error,
          onStart: _start,
        ),
        'starting' => _LoadingScreen(
          language: _language,
          message: _language == 'ml'
              ? 'നിങ്ങൾക്കായി ചോദ്യങ്ങൾ തയ്യാറാക്കുന്നു...'
              : 'Preparing your questions...',
        ),
        'questions' =>
          _session == null
              ? const SizedBox.shrink()
              : _QuestionScreen(
                  language: _language,
                  question: _session!.questions[_currentIndex],
                  index: _currentIndex,
                  total: _session!.questions.length,
                  selectedKey:
                      _answers[_session!.questions[_currentIndex].id.toString()],
                  onAnswer: _answer,
                  onBack: _currentIndex > 0 ? _back : null,
                ),
        'analyzing' => _LoadingScreen(
          language: _language,
          message: _language == 'ml'
              ? 'നിങ്ങളുടെ ഉത്തരങ്ങൾ വിശകലനം ചെയ്യുന്നു...'
              : 'Analyzing your answers...',
        ),
        'results' =>
          _results != null
              ? _ResultsScreen(
                  language: _language,
                  results: _results!,
                  onReset: _reset,
                )
              : const SizedBox.shrink(),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _LanguageSelectionScreen extends StatelessWidget {
  const _LanguageSelectionScreen({required this.onSelect});

  final ValueChanged<String> onSelect;

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
              color: _kInk,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select your preferred language for the health assessment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 15,
              color: _kInk.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 40),
          _OptionCard(label: 'English', onTap: () => onSelect('en')),
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
  const _WelcomeScreen({
    required this.language,
    required this.onStart,
    this.error,
  });

  final String language;
  final VoidCallback onStart;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final isMl = language == 'ml';
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FF),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                size: 56,
                color: _kAccent,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            isMl ? 'എഐ ഹെൽത്ത് ചെക്കപ്പ്' : 'AI Health Checkup',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isMl
                ? 'കുറച്ച് ചോദ്യങ്ങൾക്ക് മറുപടി നൽകുക. നിങ്ങളുടെ ഉത്തരങ്ങൾ വിലയിരുത്തി അനുയോജ്യമായ പരിശോധനകൾ നിർദ്ദേശിക്കും.'
                : 'Answer a few questions about your health. Our AI will assess your risk and suggest preventive lab tests tailored for you.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 15,
              color: _kInk.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: const Color(0xFFDB4C4C),
              ),
            ),
          ],
          const SizedBox(height: 40),
          _PrimaryButton(
            label: isMl ? 'പരിശോധന ആരംഭിക്കുക' : 'Start Assessment',
            onPressed: onStart,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.language, required this.message});

  final String language;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(strokeWidth: 4, color: _kAccent),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionScreen extends StatelessWidget {
  const _QuestionScreen({
    required this.language,
    required this.question,
    required this.index,
    required this.total,
    required this.selectedKey,
    required this.onAnswer,
    required this.onBack,
  });

  final String language;
  final AssessmentQuestion question;
  final int index;
  final int total;
  final String? selectedKey;
  final void Function(AssessmentQuestion question, String optionKey) onAnswer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final isMl = language == 'ml';
    final progress = (index + 1) / total;

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
              color: _kAccent,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isMl ? 'ചോദ്യം ${index + 1}/$total' : 'Question ${index + 1}/$total',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kAccent,
                ),
              ),
              if (onBack != null)
                TextButton.icon(
                  onPressed: onBack,
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
            question.question,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: question.options
                  .map(
                    (option) => _OptionCard(
                      label: option.text,
                      isSelected: selectedKey == option.key,
                      onTap: () => onAnswer(question, option.key),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

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
                color: isSelected ? _kAccent : const Color(0xFFE5E9F0),
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
                    color: isSelected ? _kAccent : Colors.transparent,
                    border: Border.all(color: _kAccent, width: 2),
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
                      color: isSelected ? _kAccent : _kInk,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isSelected ? _kAccent : const Color(0xFF8DA0BA),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsScreen extends StatelessWidget {
  const _ResultsScreen({
    required this.language,
    required this.results,
    required this.onReset,
  });

  final String language;
  final AssessmentResults results;
  final VoidCallback onReset;

  ({Color color, String label}) _risk(String level) {
    final isMl = language == 'ml';
    switch (level.toLowerCase()) {
      case 'high':
        return (
          color: const Color(0xFFFF5C5C),
          label: isMl ? 'ഉയർന്ന അപകടസാധ്യത' : 'High Risk',
        );
      case 'moderate':
        return (
          color: const Color(0xFFF5A623),
          label: isMl ? 'മിതമായ അപകടസാധ്യത' : 'Moderate Risk',
        );
      default:
        return (
          color: const Color(0xFF1F9A6D),
          label: isMl ? 'കുറഞ്ഞ അപകടസാധ്യത' : 'Low Risk',
        );
    }
  }

  void _bookPackage(BuildContext context, int id, String name, String? price) {
    final package = LabPackageItem(
      id: id,
      name: name,
      slug: '',
      status: true,
      basePrice: _parsePrice(price),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PackageBookingScreen(package: package)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMl = language == 'ml';
    final risk = _risk(results.riskLevel);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _RiskCard(risk: risk, summary: results.summary, language: language),
        if (results.insights.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionTitle(isMl ? 'പ്രധാന നിർദ്ദേശങ്ങൾ' : 'Key Insights'),
          const SizedBox(height: 12),
          _InsightsCard(insights: results.insights),
        ],
        if (results.recommendedPackages.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionTitle(isMl ? 'നിർദ്ദേശിച്ച പാക്കേജുകൾ' : 'Recommended Packages'),
          const SizedBox(height: 12),
          ...results.recommendedPackages.map(
            (pkg) => _PackageCard(
              title: pkg.packageName,
              price: pkg.price,
              testCount: pkg.tests.length,
              onBook: () =>
                  _bookPackage(context, pkg.id, pkg.packageName, pkg.price),
            ),
          ),
        ],
        if (results.customPackage != null) ...[
          const SizedBox(height: 28),
          _SectionTitle(isMl ? 'നിങ്ങൾക്കായുള്ള പാക്കേജ്' : 'Tailored For You'),
          const SizedBox(height: 12),
          _PackageCard(
            title: results.customPackage!.name,
            subtitle: results.customPackage!.reason,
            price: results.customPackage!.price,
            testCount: results.customPackage!.tests.length,
          ),
        ],
        if (results.recommendedTests.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionTitle(
            isMl ? 'നിർദ്ദേശിച്ച പരിശോധനകൾ' : 'Suggested Individual Tests',
          ),
          const SizedBox(height: 12),
          _TestsCard(tests: results.recommendedTests),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.replay_rounded),
            label: Text(
              isMl ? 'വീണ്ടും പരിശോധിക്കുക' : 'Retake Assessment',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kAccent,
              side: const BorderSide(color: _kAccent),
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
              onReset();
              PatientAppShell.of(context).goHome();
            },
            icon: Icon(
              Icons.home_rounded,
              size: 20,
              color: _kInk.withValues(alpha: 0.6),
            ),
            label: Text(
              isMl ? 'ഹോമിലേക്ക് മടങ്ങുക' : 'Back to Home',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: _kInk.withValues(alpha: 0.6),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _kInk.withValues(alpha: 0.12)),
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
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({
    required this.risk,
    required this.summary,
    required this.language,
  });

  final ({Color color, String label}) risk;
  final String summary;
  final String language;

  @override
  Widget build(BuildContext context) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: risk.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, size: 18, color: risk.color),
                const SizedBox(width: 8),
                Text(
                  risk.label,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: risk.color,
                  ),
                ),
              ],
            ),
          ),
          if (summary.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              summary.trim(),
              style: GoogleFonts.manrope(
                fontSize: 14,
                height: 1.6,
                color: _kInk.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
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
        children: insights
            .map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: _kAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        insight,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          height: 1.5,
                          color: _kInk.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.title,
    this.subtitle,
    this.price,
    this.testCount = 0,
    this.onBook,
  });

  final String title;
  final String? subtitle;
  final String? price;
  final int testCount;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final priceValue = _parsePrice(price);
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
                  color: _kAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                    if ((subtitle ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!.trim(),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: _kInk.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    if (testCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '$testCount tests',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kInk.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (priceValue > 0 || onBook != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (priceValue > 0)
                  Text(
                    '₹$priceValue',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _kAccent,
                    ),
                  ),
                const Spacer(),
                if (onBook != null)
                  ElevatedButton(
                    onPressed: onBook,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
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
          ],
        ],
      ),
    );
  }
}

class _TestsCard extends StatelessWidget {
  const _TestsCard({required this.tests});

  final List<AssessmentRecommendedTest> tests;

  @override
  Widget build(BuildContext context) {
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
        children: tests.map((test) {
          final priceValue = _parsePrice(test.price);
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
                    color: _kAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.testName,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _kInk,
                        ),
                      ),
                      if ((test.category ?? '').trim().isNotEmpty)
                        Text(
                          test.category!.trim(),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: _kInk.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
                if (priceValue > 0)
                  Text(
                    '₹$priceValue',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kAccent,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: _kInk,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
    );
  }
}
