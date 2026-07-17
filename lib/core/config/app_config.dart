import 'package:flutter/foundation.dart';

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
    final showDevOtp = const bool.hasEnvironment('SHOW_DEV_OTP')
        ? const bool.fromEnvironment('SHOW_DEV_OTP')
        : !kReleaseMode;
    const definedAppName = String.fromEnvironment('APP_NAME');
    const definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const definedHealthEndpoint = String.fromEnvironment('HEALTH_ENDPOINT');

    String defaultBaseUrl = definedApiBaseUrl.isNotEmpty
        ? definedApiBaseUrl
        : kReleaseMode
        ? 'https://www.bhrchospital.com/api/v1'
        : 'http://localhost:8000/api/v1';

    if (!kIsWeb && defaultBaseUrl.contains('localhost')) {
      // In Flutter, if running on Android emulator, localhost points to the emulator.
      // 10.0.2.2 is a special alias to the host loopback interface.
      if (defaultTargetPlatform == TargetPlatform.android) {
        defaultBaseUrl = defaultBaseUrl.replaceAll('localhost', '10.0.2.2');
      }
    }

    debugPrint('API_BASE_URL=$defaultBaseUrl');

    return AppConfig(
      appName: definedAppName.isEmpty ? 'BHRC' : definedAppName,
      apiBaseUrl: defaultBaseUrl,
      healthEndpoint: definedHealthEndpoint.isEmpty
          ? '/health'
          : definedHealthEndpoint,
      showDevOtp: showDevOtp,
    );
  }
}
