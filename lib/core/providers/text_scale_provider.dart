import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-app text size, on top of whatever the operating system is already set to.
///
/// Many older patients never find Android's own font-size setting, so the app
/// offers its own. The chosen step multiplies the system scale rather than
/// replacing it, so someone who has already enlarged text system-wide is not
/// silently reset to a smaller size.
enum AppTextScale {
  normal(1.0, 'Normal'),
  large(1.15, 'Large'),
  larger(1.3, 'Larger');

  const AppTextScale(this.factor, this.label);

  final double factor;
  final String label;

  String labelFor(bool malayalam) {
    if (!malayalam) return label;
    return switch (this) {
      AppTextScale.normal => 'സാധാരണ',
      AppTextScale.large => 'വലുത്',
      AppTextScale.larger => 'കൂടുതൽ വലുത്',
    };
  }
}

class TextScaleProvider extends ChangeNotifier {
  static const _storageKey = 'app_text_scale';

  /// Beyond this, layouts stop being usable however carefully they are built,
  /// so the combined scale is capped rather than allowed to run away.
  static const double maxCombinedScale = 2.0;

  AppTextScale _scale = AppTextScale.normal;

  AppTextScale get scale => _scale;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    for (final option in AppTextScale.values) {
      if (option.name == stored) {
        _scale = option;
        break;
      }
    }
    notifyListeners();
  }

  Future<void> setScale(AppTextScale value) async {
    if (_scale == value) return;
    _scale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value.name);
  }

  /// Combines the patient's choice with the system setting, capped so a device
  /// already at 2.0x plus "Larger" in-app does not reach 2.6x.
  TextScaler resolve(TextScaler systemScaler) {
    final combined = systemScaler.scale(_scale.factor);
    return TextScaler.linear(
      (combined / 1.0).clamp(1.0, maxCombinedScale).toDouble(),
    );
  }
}
