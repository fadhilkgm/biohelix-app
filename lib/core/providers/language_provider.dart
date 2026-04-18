import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { en, ml }

class LanguageProvider extends ChangeNotifier {
  static const _storageKey = 'app_language';

  AppLanguage _language = AppLanguage.en;

  AppLanguage get language => _language;

  bool get isEnglish => _language == AppLanguage.en;

  bool get isMalayalam => _language == AppLanguage.ml;

  Locale get locale => switch (_language) {
    AppLanguage.en => const Locale('en'),
    AppLanguage.ml => const Locale('ml'),
  };

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored == 'ml') {
      _language = AppLanguage.ml;
    }
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
    final next = isEnglish ? AppLanguage.ml : AppLanguage.en;
    await setLanguage(next);
  }
}
