import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  static TextStyle title(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
      fontFamily: 'Manrope',
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      letterSpacing: -0.4,
    );
  }

  static TextStyle section(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium!.copyWith(
      fontFamily: 'Manrope',
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );
  }

  static TextStyle body(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontFamily: 'Manrope',
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
      height: 1.35,
    );
  }

  static TextStyle cardTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall!.copyWith(
      fontFamily: 'Manrope',
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      letterSpacing: -0.2,
    );
  }
}
