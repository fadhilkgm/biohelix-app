import 'package:flutter/material.dart';

import '../../models/onboarding_page_content.dart';

class OnboardingPageCard extends StatelessWidget {
  const OnboardingPageCard({super.key, required this.page});

  final OnboardingPageContent page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    final contentBottomOffset = 156.0 + bottomSafeArea;
    final softenedTint = page.imageTint.withValues(
      alpha: page.imageTint.a * 0.78,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: page.backdropColors,
            ),
          ),
        ),
        ColorFiltered(
          colorFilter: ColorFilter.mode(softenedTint, BlendMode.srcATop),
          child: Image.asset(
            page.imageAsset,
            fit: BoxFit.cover,
            alignment: page.imageAlignment,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                page.overlayColor.withValues(alpha: 0.1),
                page.overlayColor.withValues(alpha: 0.24),
                page.overlayColor.withValues(alpha: 0.82),
              ],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: contentBottomOffset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                page.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 0.95,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                page.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
