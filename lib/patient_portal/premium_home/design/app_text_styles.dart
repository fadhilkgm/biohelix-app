import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  static TextStyle headerTitle(BuildContext context) {
    return GoogleFonts.manrope(
      textStyle: Theme.of(context).textTheme.titleLarge,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      height: 1.15,
    );
  }

  static TextStyle subText(BuildContext context) {
    return GoogleFonts.manrope(
      textStyle: Theme.of(context).textTheme.bodyMedium,
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w500,
      height: 1.35,
    );
  }

  static TextStyle sectionTitle(BuildContext context) {
    return GoogleFonts.manrope(
      textStyle: Theme.of(context).textTheme.titleMedium,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    );
  }

  static TextStyle cardTitle(BuildContext context) {
    return GoogleFonts.manrope(
      textStyle: Theme.of(context).textTheme.titleSmall,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    );
  }

  static TextStyle cardSubtitle(BuildContext context) {
    return GoogleFonts.manrope(
      textStyle: Theme.of(context).textTheme.bodySmall,
      color: AppColors.secondary,
      fontWeight: FontWeight.w600,
    );
  }
}
