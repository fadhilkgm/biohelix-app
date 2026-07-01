/// Normalizes patient phone numbers for BHRC API + WhatsApp OTP delivery.
///
/// WhatsApp Cloud API expects digits with country code (e.g. `919876543210`).
/// The mobile API accepts E.164 values such as `+919876543210`; the backend
/// strips formatting before calling Meta.
String normalizePatientPhone(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';

  if (digits.length == 10) {
    return '+91$digits';
  }
  if (digits.length == 11 && digits.startsWith('0')) {
    return '+91${digits.substring(1)}';
  }
  if (digits.length == 12 && digits.startsWith('91')) {
    return '+$digits';
  }

  return trimmed.startsWith('+') ? '+$digits' : '+$digits';
}

/// Digits-only phone with country code — matches WhatsApp `to` field format.
String whatsAppPhoneDigits(String normalizedPhone) {
  return normalizedPhone.replaceAll(RegExp(r'\D'), '');
}

String maskPatientPhone(String normalizedPhone) {
  final digits = whatsAppPhoneDigits(normalizedPhone);
  if (digits.length < 4) return normalizedPhone;
  final tail = digits.substring(digits.length - 4);
  if (digits.startsWith('91') && digits.length >= 12) {
    return '+91 XXXXXX$tail';
  }
  return 'XXXXXX$tail';
}
