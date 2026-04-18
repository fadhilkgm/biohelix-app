import 'package:flutter/material.dart';

import '../theme/app_shadows.dart';

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final bool isOutlined;
  final Widget? icon;

  /// When true (default) the button expands to full available width.
  final bool fullWidth;

  /// Use on dark backgrounds — renders as white-filled (default) or white-outlined.
  final bool onDark;

  const CustomButton({
    super.key,
    this.onPressed,
    required this.text,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.fullWidth = true,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final br = BorderRadius.circular(14);
    final isEnabled = onPressed != null;

    // Resolve colors based on mode
    final Color bgColor = onDark
        ? (isOutlined ? Colors.transparent : Colors.white)
        : (isEnabled ? primary : Colors.grey.shade400);
    final Color fgColor = onDark
        ? (isOutlined ? Colors.white : primary)
        : (isEnabled ? Colors.white : Colors.white70);
    final Color borderColor = onDark
        ? Colors.white
        : (isEnabled ? primary : Colors.grey.shade400);

    Widget btn;

    if (isOutlined) {
      btn = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: br,
          color: Colors.transparent,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: br,
          child: InkWell(
            borderRadius: br,
            onTap: (isLoading || !isEnabled) ? null : onPressed,
            splashColor: borderColor.withValues(alpha: 0.12),
            highlightColor: borderColor.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: _buildContent(fgColor),
            ),
          ),
        ),
      );
    } else {
      btn = AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: (isLoading || !isEnabled) ? 0.65 : 1.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: br,
            color: bgColor,
            boxShadow: (isLoading || onDark)
                ? null
                : AppShadows.low(dark: isDark),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: br,
            child: InkWell(
              borderRadius: br,
              onTap: (isLoading || !isEnabled) ? null : onPressed,
              splashColor: Colors.white24,
              highlightColor: Colors.white10,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: _buildContent(fgColor),
              ),
            ),
          ),
        ),
      );
    }

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  Widget _buildContent(Color fgColor) {
    if (isLoading) {
      return Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(fgColor),
          ),
        ),
      );
    }

    final label = Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: fgColor,
      ),
    );

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [icon!, const SizedBox(width: 8), label],
      );
    }

    return Center(child: label);
  }
}
