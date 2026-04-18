import 'package:url_launcher/url_launcher.dart';

class EmergencyCallLauncher {
  const EmergencyCallLauncher._();

  static Future<bool> call(String phoneNumber) {
    final uri = Uri(scheme: 'tel', path: _sanitize(phoneNumber));
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String _sanitize(String phoneNumber) {
    final buffer = StringBuffer();

    for (final rune in phoneNumber.runes) {
      final character = String.fromCharCode(rune);
      final isPlus = buffer.isEmpty && character == '+';
      final isDigit = rune >= 48 && rune <= 57;

      if (isPlus || isDigit) {
        buffer.write(character);
      }
    }

    return buffer.toString();
  }
}