import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig({
    required this.appName,
    required this.apiBaseUrl,
    required this.healthEndpoint,
    required this.showDevOtp,
    this.sarvamApiKey = '',
  });

  final String appName;
  final String apiBaseUrl;
  final String healthEndpoint;
  final bool showDevOtp;
  final String sarvamApiKey;

  factory AppConfig.fromEnvironment() {
    final env = _readDotEnv();
    final showDevOtp = const bool.hasEnvironment('SHOW_DEV_OTP')
        ? const bool.fromEnvironment('SHOW_DEV_OTP')
        : (_readBool(env['SHOW_DEV_OTP']) ?? !kReleaseMode);
    const definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');

    return AppConfig(
      appName: env['APP_NAME'] ?? 'Biohelix',
      apiBaseUrl: definedApiBaseUrl.isNotEmpty
          ? definedApiBaseUrl
          : (env['API_BASE_URL'] ?? 'https://www.bhrchospital.com/api/v1'),
      healthEndpoint: env['HEALTH_ENDPOINT'] ?? '/health',
      showDevOtp: showDevOtp,
      sarvamApiKey: env['SARVAM_API_KEY'] ?? '',
    );
  }

  static Map<String, String> _readDotEnv() {
    try {
      return dotenv.env;
    } catch (_) {
      return const {};
    }
  }

  static bool? _readBool(String? value) {
    if (value == null) return null;

    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
      default:
        return null;
    }
  }
}
