import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig({
    required this.appName,
    required this.apiBaseUrl,
    required this.healthEndpoint,
    required this.showDevOtp,
  });

  final String appName;
  final String apiBaseUrl;
  final String healthEndpoint;
  final bool showDevOtp;

  factory AppConfig.fromEnvironment() {
    final env = _readDotEnv();
    final showDevOtp =
        _readBool(env['SHOW_DEV_OTP']) ??
        const bool.fromEnvironment('SHOW_DEV_OTP', defaultValue: !kReleaseMode);

    return AppConfig(
      appName: env['APP_NAME'] ?? 'Biohelix',
      apiBaseUrl:
          env['API_BASE_URL'] ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://192.168.1.13/api',
          ),
      healthEndpoint: env['HEALTH_ENDPOINT'] ?? '/health',
      showDevOtp: showDevOtp,
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
