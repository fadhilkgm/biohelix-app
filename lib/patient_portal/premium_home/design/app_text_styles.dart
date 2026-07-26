import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  static TextStyle headerTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
      fontFamily: 'Manrope',
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      height: 1.15,
    );
  }

  static TextStyle subText(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontFamily: 'Manrope',
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w500,
      height: 1.35,
    );
  }

  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium!.copyWith(
      fontFamily: 'Manrope',
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    );
  }

  static TextStyle cardTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall!.copyWith(
      fontFamily: 'Manrope',
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    );
  }

  static TextStyle cardSubtitle(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall!.copyWith(
      fontFamily: 'Manrope',
      color: AppColors.secondary,
      fontWeight: FontWeight.w600,
    );
  }
}
