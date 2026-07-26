import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/widgets/app_chevron_back_button.dart';
import '../../../core/widgets/custom_button.dart';
import '../models/legal_content.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCompleted});

  final Future<void> Function() onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isCompleting = false;
  bool _legalContentRequested = false;
  bool _hasAgreed = false;
  int _step = 0;
  LegalContent? _legalContent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_legalContentRequested) return;
    _legalContentRequested = true;
    unawaited(_loadLegalContent(context.read<ApiClient>()));
  }

  Future<void> _loadLegalContent(ApiClient apiClient) async {
    try {
      final response = await apiClient.getJson('/legal-content');
      if (!mounted) return;
      setState(() => _legalContent = LegalContent.fromJson(response));
    } catch (_) {
      // The localized summary remains available if the network is unavailable.
    }
  }

  void _goToStep(int step) {
    setState(() => _step = step.clamp(0, 1));
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    await widget.onCompleted();
    if (!mounted) return;
    setState(() => _isCompleting = false);
  }

  Future<void> _showLegalDocument({
    required String title,
    required String markdown,
    required LocalizedStrings strings,
  }) {
    final content = markdown.trim().isEmpty
        ? strings.legalContentUnavailable
        : markdown;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D9E6),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: strings.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Markdown(
                data: content,
                padding: const EdgeInsets.all(20),
                selectable: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>().language;
    final strings = AppStrings.of(language);
    final privacyPolicy =
        _legalContent?.privacyPolicy.forLanguage(language) ?? '';
    final termsAndConditions =
        _legalContent?.termsAndConditions.forLanguage(language) ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingHeader(
              step: _step,
              backLabel: strings.back,
              onBack: _step == 0 ? null : () => _goToStep(_step - 1),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                    child: child,
                  ),
                ),
                child: switch (_step) {
                  0 => _LanguageStep(
                    key: const ValueKey('language'),
                    strings: strings,
                    onNext: () => _goToStep(1),
                  ),
                  1 => _ConsentStep(
                    key: const ValueKey('consent'),
                    strings: strings,
                    isLoading: _legalContent == null,
                    onPrivacyPolicy: () => _showLegalDocument(
                      title: strings.privacyPolicy,
                      markdown: privacyPolicy,
                      strings: strings,
                    ),
                    onTermsAndConditions: () => _showLegalDocument(
                      title: strings.termsAndConditions,
                      markdown: termsAndConditions,
                      strings: strings,
                    ),
                    hasAgreed: _hasAgreed,
                    isCompleting: _isCompleting,
                    onAgreementChanged: (value) {
                      setState(() => _hasAgreed = value);
                    },
                    onGetStarted: _hasAgreed ? _completeOnboarding : null,
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.step,
    required this.backLabel,
    required this.onBack,
  });

  final int step;
  final String backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack == null
                ? null
                : AppChevronBackButton(onPressed: onBack!, tooltip: backLabel),
          ),
          const Spacer(),
          Row(
            children: List.generate(
              2,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: index == step ? 28 : 9,
                height: 9,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index <= step
                      ? const Color(0xFF06489B)
                      : const Color(0xFFD4DCE9),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.icon,
    required this.title,
    required this.description,
    required this.content,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget content;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF06489B),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF15243A),
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF5B687B),
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              content,
              const SizedBox(height: 28),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({super.key, required this.strings, required this.onNext});

  final LocalizedStrings strings;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.translate_rounded,
      title: strings.chooseLanguageTitle,
      description: strings.chooseLanguageDescription,
      content: const _LanguageSelector(),
      action: CustomButton(
        onPressed: onNext,
        text: strings.next,
        color: const Color(0xFF06489B),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    return Column(
      children: [
        _LanguageOption(
          title: 'English',
          subtitle: 'Continue in English',
          code: 'EN',
          isSelected: language.isEnglish,
          onTap: () => language.setLanguage(AppLanguage.en),
        ),
        const SizedBox(height: 12),
        _LanguageOption(
          title: 'മലയാളം',
          subtitle: 'മലയാളത്തിൽ തുടരുക',
          code: 'മ',
          isSelected: language.isMalayalam,
          onTap: () => language.setLanguage(AppLanguage.ml),
        ),
      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.title,
    required this.subtitle,
    required this.code,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String code;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFFE7F0FC) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF06489B)
                  : const Color(0xFFDCE3ED),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF06489B)
                      : const Color(0xFFF0F3F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF44546A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF647287),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isSelected
                    ? const Color(0xFF06489B)
                    : const Color(0xFFB8C2D0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentStep extends StatelessWidget {
  const _ConsentStep({
    super.key,
    required this.strings,
    required this.isLoading,
    required this.onPrivacyPolicy,
    required this.onTermsAndConditions,
    required this.hasAgreed,
    required this.isCompleting,
    required this.onAgreementChanged,
    required this.onGetStarted,
  });

  final LocalizedStrings strings;
  final bool isLoading;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onTermsAndConditions;
  final bool hasAgreed;
  final bool isCompleting;
  final ValueChanged<bool> onAgreementChanged;
  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.shield_outlined,
      title: strings.reviewPoliciesTitle,
      description: strings.reviewPoliciesDescription,
      content: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCE3ED)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PolicyLinkTile(
              icon: Icons.lock_outline_rounded,
              title: strings.privacyPolicy,
              onTap: onPrivacyPolicy,
            ),
            const Divider(height: 24),
            _PolicyLinkTile(
              icon: Icons.description_outlined,
              title: strings.termsAndConditions,
              onTap: onTermsAndConditions,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.health_and_safety_outlined,
                    size: 20,
                    color: Color(0xFF06489B),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.dataPrivacyNoticeBody,
                      style: const TextStyle(
                        color: Color(0xFF526078),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF06489B),
                backgroundColor: Color(0xFFDCE7F5),
              ),
            ],
            const SizedBox(height: 14),
            Material(
              color: hasAgreed
                  ? const Color(0xFFE7F0FC)
                  : const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onAgreementChanged(!hasAgreed),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: hasAgreed,
                        onChanged: (value) =>
                            onAgreementChanged(value ?? false),
                        activeColor: const Color(0xFF06489B),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            strings.agreementConfirmation,
                            style: const TextStyle(
                              color: Color(0xFF34445A),
                              fontSize: 12,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      action: CustomButton(
        onPressed: onGetStarted,
        text: strings.getStarted,
        isLoading: isCompleting,
        color: hasAgreed ? const Color(0xFF06489B) : Colors.grey.shade400,
      ),
    );
  }
}

class _PolicyLinkTile extends StatelessWidget {
  const _PolicyLinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F0FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF06489B), size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF7A8799),
            ),
          ],
        ),
      ),
    );
  }
}
