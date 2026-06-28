import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/widgets/custom_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCompleted});

  final Future<void> Function() onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isCompleting = false;

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() {
      _isCompleting = true;
    });
    await widget.onCompleted();
    if (!mounted) return;
    setState(() {
      _isCompleting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(AppLanguage.en);
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final isShortScreen = size.height < 760;
    final horizontalPadding = size.width < 360 ? 24.0 : 28.0;
    final heroHeight = size.height * (isShortScreen ? 0.58 : 0.64);
    final titleSize = size.width < 360 ? 30.0 : 34.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF0F4FF), Color(0xFFFFFFFF)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black, Colors.transparent],
                  stops: [0.0, 0.68, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                'assets/images/onboarding-realistic-doctor.png',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.92),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.48, 0.66, 0.82],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                mediaQuery.padding.bottom + (isShortScreen ? 24 : 34),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.onboardingTitle,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF192233),
                      height: 1.05,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    strings.onboardingDescription,
                    style: TextStyle(
                      fontSize: size.width < 360 ? 15 : 17,
                      color: const Color(0xFF192233).withValues(alpha: 0.7),
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: isShortScreen ? 28 : 38),
                  CustomButton(
                    onPressed: _completeOnboarding,
                    text: strings.getStarted,
                    isLoading: _isCompleting,
                    color: const Color(0xFF537DE8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
