part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class AiChatColors {
  static const background = Color(0xFFF5F7FB);
  static const bubbleAi = Color(0xFFFFFFFF);
  static const bubbleAiSoft = Color(0xFFF1F4F8);
  static const textPrimary = Color(0xFF1D2939);
  static const textSecondary = Color(0xFF667085);
  static const inputSurface = Color(0xFFFFFFFF);
  static const online = Color(0xFF18B87A);
  static const gradientStart = Color(0xFF2B79FF);
  static const gradientEnd = Color(0xFF16B5A4);

  static const userBubbleGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> softShadow = const [
    BoxShadow(color: Color(0x140F172A), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

class AppTextStyles {
  static TextStyle title(BuildContext context) => GoogleFonts.manrope(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AiChatColors.textPrimary,
  );

  static TextStyle subtitle(BuildContext context) => GoogleFonts.manrope(
    fontSize: 12,
    fontWeight: FontWeight.w600,
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
    height: 1.5,
    fontWeight: FontWeight.w500,
    color: AiChatColors.textPrimary,
  );

  static TextStyle dateSeparator(BuildContext context) => GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AiChatColors.textSecondary,
    letterSpacing: 0.3,
  );

  static TextStyle inputHint(BuildContext context) =>
      GoogleFonts.manrope(fontSize: 15, color: AiChatColors.textSecondary);
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
