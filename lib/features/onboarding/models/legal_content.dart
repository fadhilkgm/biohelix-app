import '../../../core/providers/language_provider.dart';

class LocalizedLegalDocument {
  const LocalizedLegalDocument({
    required this.english,
    required this.malayalam,
  });

  final String english;
  final String malayalam;

  factory LocalizedLegalDocument.fromJson(Object? json) {
    final data = json is Map ? json : const <String, dynamic>{};
    return LocalizedLegalDocument(
      english: data['en']?.toString().trim() ?? '',
      malayalam: data['ml']?.toString().trim() ?? '',
    );
  }

  String forLanguage(AppLanguage language) {
    if (language == AppLanguage.ml && malayalam.isNotEmpty) return malayalam;
    return english;
  }
}

class LegalContent {
  const LegalContent({
    required this.privacyPolicy,
    required this.termsAndConditions,
  });

  final LocalizedLegalDocument privacyPolicy;
  final LocalizedLegalDocument termsAndConditions;

  factory LegalContent.fromJson(Map<String, dynamic> json) {
    final payload = json['data'];
    final data = payload is Map ? payload : const <String, dynamic>{};
    return LegalContent(
      privacyPolicy: LocalizedLegalDocument.fromJson(data['privacy_policy']),
      termsAndConditions: LocalizedLegalDocument.fromJson(
        data['terms_and_conditions'],
      ),
    );
  }
}
