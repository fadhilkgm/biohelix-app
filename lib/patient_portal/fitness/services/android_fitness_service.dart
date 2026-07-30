import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/fitness_activity_models.dart';

class AndroidFitnessReadResult {
  const AndroidFitnessReadResult({required this.timezone, required this.days});

  final String timezone;
  final List<DailyFitnessActivity> days;
}

class AndroidFitnessService {
  AndroidFitnessService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.biohelix.app/fitness');

  final MethodChannel _channel;

  bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<FitnessPlatformStatus> status() async {
    if (!isSupportedPlatform) {
      return const FitnessPlatformStatus(
        status: 'unavailable',
        permissionsGranted: false,
        nativePhoneStepTracking: false,
        androidVersion: 0,
      );
    }
    final response = await _channel.invokeMapMethod<dynamic, dynamic>(
      'getStatus',
    );
    return FitnessPlatformStatus.fromJson(response ?? const {});
  }

  Future<bool> requestPermissions() async {
    final response = await _channel.invokeMapMethod<dynamic, dynamic>(
      'requestPermissions',
    );
    return response?['granted'] == true;
  }

  Future<AndroidFitnessReadResult> readActivity({int days = 7}) async {
    final response = await _channel.invokeMapMethod<dynamic, dynamic>(
      'readActivity',
      {'days': days},
    );
    final rawDays = response?['days'] as List<dynamic>? ?? const [];
    return AndroidFitnessReadResult(
      timezone: response?['timezone']?.toString() ?? 'UTC',
      days: rawDays
          .whereType<Map>()
          .map(DailyFitnessActivity.fromPlatform)
          .where((day) => day.date.isNotEmpty)
          .toList(),
    );
  }

  Future<void> openHealthConnect() async {
    await _channel.invokeMethod<void>('openHealthConnect');
  }
}
