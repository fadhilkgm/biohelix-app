part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class AiChatColors {
  // Light theme aligned with the BioHelix app palette (deep green / sea green).
  static const background = Color(0xFFF9FAFB); // app backgroundLight
  static const backgroundBlue = Color(0xFFE8F2EC); // soft green tint
  static const bubbleAi = Color(0xFFFFFFFF);
  static const bubbleAiSoft = Color(0xFFF3F4F6);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF4B5563);
  static const inputSurface = Color(0xFFFFFFFF);
  static const online = Color(0xFF10B981);

  // Brand accents
  static const primary = Color(0xFF1B4D3E); // deep green
  static const accent = Color(0xFF2E8B57); // sea green
  static const border = Color(0xFFE5E7EB);
  static const surfaceTint = Color(0xFFECF5F1);

  static const gradientStart = primary;
  static const gradientEnd = accent;

  static const userBubbleGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Clean, flat UI — rely on borders instead of drop shadows.
  static List<BoxShadow> softShadow = const [];
}

class AppTextStyles {
  static TextStyle title(BuildContext context) => GoogleFonts.manrope(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: AiChatColors.textPrimary,
    letterSpacing: -0.4,
  );

  static TextStyle subtitle(BuildContext context) => GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AiChatColors.textSecondary,
  );

  static TextStyle bubbleUser(BuildContext context) => GoogleFonts.manrope(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static TextStyle bubbleAi(BuildContext context) => GoogleFonts.manrope(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AiChatColors.textPrimary,
  );

  static TextStyle dateSeparator(BuildContext context) => GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AiChatColors.textSecondary,
    letterSpacing: 0.3,
  );

  static TextStyle inputHint(BuildContext context) => GoogleFonts.manrope(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AiChatColors.textSecondary,
    letterSpacing: -0.2,
  );
}

class AppSpacing {
  static const s8 = 8.0;
  static const s10 = 10.0;
  static const s12 = 12.0;
  static const s14 = 14.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
}

class AppRadius {
  static const bubble = 18.0;
  static const bubbleTight = 12.0;
  static const card = 16.0;
  static const input = 24.0;
  static const avatar = 14.0;
}
