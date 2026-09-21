import 'package:flutter/material.dart';

/// Which surface the back button is drawn on.
///
/// The button has no control over what sits behind it, so the caller states it.
/// Picking the wrong one is a contrast bug, not a style preference.
enum AppBackButtonSurface {
  /// Light page chrome: a plain dark chevron, no scrim.
  light,

  /// Photography, video, or a saturated brand header. Renders a white chevron
  /// on a translucent dark scrim so it stays legible whatever is behind it —
  /// a bare chevron over an uncontrolled image is unreadable half the time.
  dark,
}

class AppChevronBackButton extends StatelessWidget {
  const AppChevronBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Back',
    this.surface = AppBackButtonSurface.light,
  });

  static const double size = 44;
  static const double iconSize = 28;
  static const Color foregroundColor = Color(0xFF192233);
  static const Color onDarkForegroundColor = Colors.white;
  static const Color onDarkScrimColor = Color(0x47000000);

  final VoidCallback onPressed;
  final String tooltip;
  final AppBackButtonSurface surface;

  @override
  Widget build(BuildContext context) {
    final onDark = surface == AppBackButtonSurface.dark;

    final button = SizedBox.square(
      dimension: size,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: size / 2,
        iconSize: onDark ? iconSize - 4 : iconSize,
        color: onDark ? onDarkForegroundColor : foregroundColor,
        icon: const BackButtonIcon(),
      ),
    );

    if (!onDark) return button;

    return Material(
      color: onDarkScrimColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: button,
    );
  }
}
