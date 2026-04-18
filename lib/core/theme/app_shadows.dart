import 'package:flutter/material.dart';

/// Centralised shadow definitions.
/// Change [level] scale values here to control app-wide shadow intensity.
class AppShadows {
  // ── Shadow opacity scale ──────────────────────────────────────────────────
  static const double _lightOpacity = 0.06;
  static const double _mediumOpacity = 0.10;
  static const double _strongOpacity = 0.16;
  static const double _darkModeFactor = 0.5; // darken all in dark mode

  // ── Prebuilt shadow levels ────────────────────────────────────────────────

  /// Subtle lift – cards at rest
  static List<BoxShadow> low({bool dark = false}) {
    final o = dark ? _lightOpacity * _darkModeFactor : _lightOpacity;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: o),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Medium elevation – floating cards, bottom bars
  static List<BoxShadow> medium({bool dark = false}) {
    final o = dark ? _mediumOpacity * _darkModeFactor : _mediumOpacity;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: o),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: o * 0.5),
        blurRadius: 6,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// High elevation – drawers, modals, sidebars
  static List<BoxShadow> high({bool dark = false}) {
    final o = dark ? _strongOpacity * _darkModeFactor : _strongOpacity;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: o),
        blurRadius: 28,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: o * 0.4),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Coloured primary glow – hero buttons
  static List<BoxShadow> primary(Color color, {bool dark = false}) {
    final o = dark ? 0.20 : 0.30;
    return [
      BoxShadow(
        color: color.withValues(alpha: o),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ];
  }
}
