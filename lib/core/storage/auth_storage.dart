import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../patient_portal/core/models/patient_models.dart';

class AuthStorage {
  static const _authTokenKey = 'auth_token';
  static const _familyProfilesKey = 'family_profiles';

  Future<String?> readToken() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_authTokenKey);
  }

  Future<void> writeToken(String token) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_authTokenKey, token);
  }

  Future<List<SavedPatientProfile>> readFamilyProfiles() async {
    final preferences = await SharedPreferences.getInstance();
    final rawProfiles =
        preferences.getStringList(_familyProfilesKey) ?? const <String>[];

    return rawProfiles
        .map((rawProfile) {
          try {
            return SavedPatientProfile.fromJson(
              Map<String, dynamic>.from(jsonDecode(rawProfile) as Map),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedPatientProfile>()
        .toList();
  }

  Future<void> writeFamilyProfiles(List<SavedPatientProfile> profiles) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _familyProfilesKey,
      profiles.map((profile) => jsonEncode(profile.toJson())).toList(),
    );
  }

  Future<void> clearToken() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_authTokenKey);
  }

  Future<void> clearAll() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_authTokenKey);
    await preferences.remove(_familyProfilesKey);
  }
}
