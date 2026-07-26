import 'package:flutter/material.dart';

class AppChevronBackButton extends StatelessWidget {
  const AppChevronBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Back',
  });

  static const double size = 44;
  static const double iconSize = 28;
  static const Color foregroundColor = Color(0xFF192233);

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: size / 2,
        iconSize: iconSize,
        color: foregroundColor,
        icon: const BackButtonIcon(),
      ),
    );
  }
}
