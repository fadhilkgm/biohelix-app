import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { en, ml, hi }

class LanguageProvider extends ChangeNotifier {
  static const _storageKey = 'app_language';

  AppLanguage _language = AppLanguage.en;

  AppLanguage get language => _language;

  bool get isEnglish => _language == AppLanguage.en;

  bool get isMalayalam => _language == AppLanguage.ml;

  bool get isHindi => _language == AppLanguage.hi;

  Locale get locale => switch (_language) {
    AppLanguage.en => const Locale('en'),
    AppLanguage.ml => const Locale('ml'),
    AppLanguage.hi => const Locale('hi'),
  };

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    _language = switch (stored) {
      'ml' => AppLanguage.ml,
      'hi' => AppLanguage.hi,
      _ => AppLanguage.en,
    };
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, lang.name);
  }

  Future<void> toggle() async {
    // Cycles through EN -> ML -> HI -> EN
    final next = switch (_language) {
      AppLanguage.en => AppLanguage.ml,
      AppLanguage.ml => AppLanguage.hi,
      AppLanguage.hi => AppLanguage.en,
    };
    await setLanguage(next);
  }
}
