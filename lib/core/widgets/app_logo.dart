import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.size,
    this.fit = BoxFit.contain,
    this.borderRadius = 0,
    this.backgroundColor,
  });

  final double? width;
  final double? height;
  final double? size;
  final BoxFit fit;
  final double borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = size ?? width;
    final resolvedHeight = size ?? height;

    Widget image = Image.asset(
      AppAssets.logo,
      width: resolvedWidth,
      height: resolvedHeight,
      fit: fit,
    );

    if (borderRadius > 0) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      );
    }

    if (backgroundColor != null) {
      return ColoredBox(
        color: backgroundColor!,
        child: image,
      );
    }

    return image;
  }
}

/// Branded fallback when remote images are missing or fail to load.
class AppLogoPlaceholder extends StatelessWidget {
  const AppLogoPlaceholder({
    super.key,
    this.width,
    this.height,
    this.backgroundColor = const Color(0xFFF0F4FF),
    this.padding = 24,
  });

  final double? width;
  final double? height;
  final Color backgroundColor;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: backgroundColor,
      alignment: Alignment.center,
      padding: EdgeInsets.all(padding),
      child: const AppLogo(fit: BoxFit.contain),
    );
  }
}
