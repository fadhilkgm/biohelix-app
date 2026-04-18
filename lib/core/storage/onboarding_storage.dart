import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStorage {
  static const _onboardingCompletedKey = 'onboarding_completed';

  Future<bool> hasCompletedOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> markOnboardingCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingCompletedKey, true);
  }
}