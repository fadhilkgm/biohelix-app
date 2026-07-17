import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/patient_models.dart';

class PromotionalBannerLaunchGate {
  PromotionalBannerLaunchGate._();

  static bool _shownThisLaunch = false;

  static Future<void> showOnce(
    BuildContext context,
    List<HomeBannerItem> banners, {
    ValueChanged<HomeBannerItem>? onTap,
  }) async {
    if (_shownThisLaunch || !context.mounted) return;

    final banner = _firstDisplayableBanner(banners);
    if (banner == null) return;

    _shownThisLaunch = true;
    final tappedBanner = await showDialog<HomeBannerItem>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PromotionalBannerDialog(banner: banner),
    );

    if (tappedBanner != null && context.mounted) {
      onTap?.call(tappedBanner);
    }
  }

  static HomeBannerItem? _firstDisplayableBanner(List<HomeBannerItem> banners) {
    final activeBanners =
        banners
            .where(
              (banner) =>
                  banner.isActive &&
                  banner.isMobilePromoPopup &&
                  banner.imageUrl.trim().isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (activeBanners.isEmpty) return null;
    return activeBanners.first;
  }
}

class PromotionalBannerDialog extends StatelessWidget {
  const PromotionalBannerDialog({super.key, required this.banner});

  final HomeBannerItem banner;

  bool get _hasAction => (banner.ctaTarget ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final posterSize = math.min(
      math.min(screenSize.width - 32, screenSize.height * 0.72),
      420.0,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: SizedBox(
          width: posterSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Material(
              color: Colors.white,
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    InkWell(
                      onTap: _hasAction
                          ? () => Navigator.of(context).pop(banner)
                          : null,
                      child: Image.network(
                        banner.imageUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) =>
                            const _PromotionFallback(),
                      ),
                    ),
                    if (banner.title.trim().isNotEmpty ||
                        (banner.subtitle ?? '').trim().isNotEmpty)
                      const _PromotionScrim(),
                    if (banner.title.trim().isNotEmpty ||
                        (banner.subtitle ?? '').trim().isNotEmpty ||
                        (banner.ctaLabel ?? '').trim().isNotEmpty)
                      _PromotionCopy(banner: banner, hasAction: _hasAction),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _CloseButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromotionCopy extends StatelessWidget {
  const _PromotionCopy({required this.banner, required this.hasAction});

  final HomeBannerItem banner;
  final bool hasAction;

  @override
  Widget build(BuildContext context) {
    final title = banner.title.trim();
    final subtitle = (banner.subtitle ?? '').trim();
    final ctaLabel = (banner.ctaLabel ?? '').trim();

    return Positioned(
      left: 18,
      right: 18,
      bottom: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.05,
                letterSpacing: 0,
              ),
            ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          ],
          if (hasAction && ctaLabel.isNotEmpty) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(banner),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF192233),
                minimumSize: const Size(0, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                ctaLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PromotionScrim extends StatelessWidget {
  const _PromotionScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0x11000000), Color(0xBB000000)],
          stops: [0.45, 0.62, 1],
        ),
      ),
    );
  }
}

class _PromotionFallback extends StatelessWidget {
  const _PromotionFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A88F1), Color(0xFF19A49A)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_hospital_rounded,
          color: Colors.white,
          size: 80,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.close_rounded),
        color: Colors.white,
        tooltip: 'Close promotion',
        iconSize: 22,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
