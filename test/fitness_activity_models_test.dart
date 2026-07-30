import 'package:biohelix_app/patient_portal/fitness/models/fitness_activity_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activity score follows the transparent 80/20 reward formula', () {
    expect(calculateActivityScore(0, 0), 0);
    expect(calculateActivityScore(7500, 0), 60);
    expect(calculateActivityScore(10000, 0), 80);
    expect(calculateActivityScore(10000, 500), 100);
    expect(calculateActivityScore(30000, 3000), 100);
  });

  test('fitness API summary parses daily rewards and unlocked offers', () {
    final summary = FitnessActivitySummary.fromJson({
      'today': {
        'date': '2026-07-29',
        'steps': 10000,
        'active_calories': 500,
        'distance_meters': 7200,
        'activity_score': 100,
        'reward_points_awarded': 15,
      },
      'history': const [],
      'reward_program': {
        'step_goal': 10000,
        'active_calorie_goal': 500,
        'daily_points_cap': 100,
        'step_reward': {'points': 10, 'steps': 1000},
      },
      'unlocked_offers': const [
        {'title': 'Active Day reward unlocked'},
      ],
    });

    expect(summary.today?.steps, 10000);
    expect(summary.today?.activityScore, 100);
    expect(summary.today?.rewardPointsAwarded, 15);
    expect(summary.rewardProgram.dailyPointsCap, 100);
    expect(
      summary.rewardProgram.stepRewardLabel,
      'Earn 10 points for every 1000 verified steps.',
    );
    expect(summary.unlockedOfferTitle, 'Active Day reward unlocked');
  });
}
