import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  // Common theme configuration
  static const double borderRadius = 12.0;
  static const double iconSize = 24.0;
  static const EdgeInsets defaultPadding = EdgeInsets.all(16.0);

  static ThemeData light() {
    final textTheme = _textTheme(color: AppColors.textPrimaryLight);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.surfaceLight,
        secondary: AppColors.accent,
        onSecondary: AppColors.surfaceLight,
        error: AppColors.error,
        onError: AppColors.surfaceLight,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      primaryColor: AppColors.primary,

      // Typography
      textTheme: textTheme,
      fontFamily: 'Manrope',

      // Card Theme
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: AppColors.dividerLight),
        ),
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0.5,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        titleTextStyle: _fontStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimaryLight,
        ),
      ),

      // Input Base Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackgroundLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: AppTextStyles.body1.copyWith(
          color: AppColors.textSecondaryLight,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surfaceLight,
          elevation: 0,
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),

      // Snackbar Theme
      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: Colors.white,
        disabledActionTextColor: Colors.white70,
      ),
    );
  }

  static ThemeData dark() {
    final textTheme = _textTheme(color: AppColors.textPrimaryDark);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        onPrimary: AppColors.surfaceLight,
        secondary: AppColors.accent,
        onSecondary: AppColors.surfaceLight,
        error: AppColors.error,
        onError: AppColors.surfaceLight,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.primaryLight,

      // Typography
      textTheme: textTheme,
      fontFamily: 'Manrope',

      // Card Theme
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: AppColors.dividerDark),
        ),
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0.5,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        titleTextStyle: _fontStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimaryDark,
        ),
      ),

      // Input Base Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackgroundDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: AppTextStyles.body1.copyWith(
          color: AppColors.textSecondaryDark,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.surfaceLight,
          elevation: 0,
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
        space: 1,
      ),

      // Snackbar Theme
      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: Colors.white,
        disabledActionTextColor: Colors.white70,
      ),
    );
  }

  static TextTheme _textTheme({required Color color}) {
    const base = TextTheme(
      displayLarge: AppTextStyles.h1,
      displayMedium: AppTextStyles.h2,
      displaySmall: AppTextStyles.h3,
      titleLarge: AppTextStyles.subtitle1,
      titleMedium: AppTextStyles.subtitle2,
      bodyLarge: AppTextStyles.body1,
      bodyMedium: AppTextStyles.body2,
      labelLarge: AppTextStyles.button,
      bodySmall: AppTextStyles.caption,
    );

    final themed = base.apply(fontFamily: 'Manrope');

    return _withMalayalamFallback(
      themed.apply(bodyColor: color, displayColor: color),
    );
  }

  static TextStyle _fontStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontFamilyFallback: const ['AnekMalayalam'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextTheme _withMalayalamFallback(TextTheme theme) {
    TextStyle? addFallback(TextStyle? style) =>
        style?.copyWith(fontFamilyFallback: const ['AnekMalayalam']);

    return theme.copyWith(
      displayLarge: addFallback(theme.displayLarge),
      displayMedium: addFallback(theme.displayMedium),
      displaySmall: addFallback(theme.displaySmall),
      headlineLarge: addFallback(theme.headlineLarge),
      headlineMedium: addFallback(theme.headlineMedium),
      headlineSmall: addFallback(theme.headlineSmall),
      titleLarge: addFallback(theme.titleLarge),
      titleMedium: addFallback(theme.titleMedium),
      titleSmall: addFallback(theme.titleSmall),
      bodyLarge: addFallback(theme.bodyLarge),
      bodyMedium: addFallback(theme.bodyMedium),
      bodySmall: addFallback(theme.bodySmall),
      labelLarge: addFallback(theme.labelLarge),
      labelMedium: addFallback(theme.labelMedium),
      labelSmall: addFallback(theme.labelSmall),
    );
  }
}
