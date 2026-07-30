class FitnessPlatformStatus {
  const FitnessPlatformStatus({
    required this.status,
    required this.permissionsGranted,
    required this.nativePhoneStepTracking,
    required this.androidVersion,
  });

  final String status;
  final bool permissionsGranted;
  final bool nativePhoneStepTracking;
  final int androidVersion;

  bool get isAvailable => status == 'available';
  bool get requiresUpdate => status == 'update_required';

  factory FitnessPlatformStatus.fromJson(Map<dynamic, dynamic> json) {
    return FitnessPlatformStatus(
      status: json['status']?.toString() ?? 'unavailable',
      permissionsGranted: json['permissionsGranted'] == true,
      nativePhoneStepTracking: json['nativePhoneStepTracking'] == true,
      androidVersion: (json['androidVersion'] as num?)?.toInt() ?? 0,
    );
  }
}

class DailyFitnessActivity {
  const DailyFitnessActivity({
    required this.date,
    required this.steps,
    required this.activeCalories,
    required this.distanceMeters,
    this.activityScore = 0,
    this.rewardPointsAwarded = 0,
    this.source = 'health_connect',
    this.syncedAt,
  });

  final String date;
  final int steps;
  final double activeCalories;
  final double distanceMeters;
  final int activityScore;
  final int rewardPointsAwarded;
  final String source;
  final String? syncedAt;

  factory DailyFitnessActivity.fromPlatform(Map<dynamic, dynamic> json) {
    final steps = (json['steps'] as num?)?.toInt() ?? 0;
    final activeCalories = (json['activeCalories'] as num?)?.toDouble() ?? 0;
    return DailyFitnessActivity(
      date: json['date']?.toString() ?? '',
      steps: steps,
      activeCalories: activeCalories,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      activityScore: calculateActivityScore(steps, activeCalories),
    );
  }

  factory DailyFitnessActivity.fromApi(Map<String, dynamic> json) {
    return DailyFitnessActivity(
      date: json['date']?.toString() ?? '',
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      activeCalories:
          (json['active_calories'] as num?)?.toDouble() ??
          (json['activeCalories'] as num?)?.toDouble() ??
          0,
      distanceMeters:
          (json['distance_meters'] as num?)?.toDouble() ??
          (json['distanceMeters'] as num?)?.toDouble() ??
          0,
      activityScore:
          (json['activity_score'] as num?)?.toInt() ??
          (json['activityScore'] as num?)?.toInt() ??
          0,
      rewardPointsAwarded:
          (json['reward_points_awarded'] as num?)?.toInt() ??
          (json['rewardPointsAwarded'] as num?)?.toInt() ??
          0,
      source: json['source']?.toString() ?? 'health_connect',
      syncedAt: json['synced_at']?.toString() ?? json['syncedAt']?.toString(),
    );
  }

  Map<String, dynamic> toSyncJson() => {
    'date': date,
    'steps': steps,
    'active_calories': activeCalories,
    'distance_meters': distanceMeters,
  };
}

class FitnessRewardProgram {
  const FitnessRewardProgram({
    this.stepGoal = 10000,
    this.activeCalorieGoal = 500,
    this.dailyPointsCap = 0,
    this.disclaimer = 'Activity scores are wellness indicators.',
    this.stepRewardPoints = 0,
    this.stepRewardSteps = 0,
  });

  final int stepGoal;
  final int activeCalorieGoal;
  final int dailyPointsCap;
  final String disclaimer;
  final int stepRewardPoints;
  final int stepRewardSteps;

  String get stepRewardLabel {
    if (stepRewardPoints <= 0 || stepRewardSteps <= 0) {
      return 'Activity rewards are configured by BHRC.';
    }
    return 'Earn $stepRewardPoints points for every '
        '$stepRewardSteps verified steps.';
  }

  factory FitnessRewardProgram.fromJson(Map<String, dynamic> json) {
    final stepReward = json['step_reward'] is Map
        ? Map<String, dynamic>.from(json['step_reward'] as Map)
        : const <String, dynamic>{};
    return FitnessRewardProgram(
      stepGoal: (json['step_goal'] as num?)?.toInt() ?? 10000,
      activeCalorieGoal: (json['active_calorie_goal'] as num?)?.toInt() ?? 500,
      dailyPointsCap: (json['daily_points_cap'] as num?)?.toInt() ?? 0,
      disclaimer:
          json['disclaimer']?.toString() ??
          'Activity scores are wellness indicators.',
      stepRewardPoints: (stepReward['points'] as num?)?.toInt() ?? 0,
      stepRewardSteps: (stepReward['steps'] as num?)?.toInt() ?? 0,
    );
  }
}

class FitnessActivitySummary {
  const FitnessActivitySummary({
    this.today,
    this.history = const [],
    this.rewardProgram = const FitnessRewardProgram(),
    this.unlockedOfferTitle,
  });

  final DailyFitnessActivity? today;
  final List<DailyFitnessActivity> history;
  final FitnessRewardProgram rewardProgram;
  final String? unlockedOfferTitle;

  factory FitnessActivitySummary.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'] as List<dynamic>? ?? const [];
    final rawToday = json['today'];
    final rawOffers = json['unlocked_offers'] as List<dynamic>? ?? const [];
    return FitnessActivitySummary(
      today: rawToday is Map
          ? DailyFitnessActivity.fromApi(Map<String, dynamic>.from(rawToday))
          : null,
      history: rawHistory
          .whereType<Map>()
          .map(
            (item) =>
                DailyFitnessActivity.fromApi(Map<String, dynamic>.from(item)),
          )
          .toList(),
      rewardProgram: FitnessRewardProgram.fromJson(
        json['reward_program'] is Map
            ? Map<String, dynamic>.from(json['reward_program'] as Map)
            : const <String, dynamic>{},
      ),
      unlockedOfferTitle: rawOffers.isNotEmpty && rawOffers.first is Map
          ? (rawOffers.first as Map)['title']?.toString()
          : null,
    );
  }
}

int calculateActivityScore(int steps, double activeCalories) {
  final stepScore = ((steps / 10000) * 80).clamp(0, 80);
  final calorieScore = ((activeCalories / 500) * 20).clamp(0, 20);
  return (stepScore + calorieScore).clamp(0, 100).round();
}
