import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MyClub parses lifetime level progress and masked leaderboard', () {
    final myClub = MyClubSummary.fromJson({
      'patientId': 8,
      'points': 400,
      'currencyValue': 400,
      'tier': 'Classic',
      'nextTierName': 'Gold',
      'pointsToNextTier': 900,
      'progressPercent': 10,
      'transactions': const [],
      'gamification': {
        'lifetime_points': 600,
        'rank': 2,
        'level': {'name': 'Silver', 'color': '#64748B'},
        'privacy_note': 'Leaderboard names are masked.',
        'leaderboard': const [
          {
            'rank': 1,
            'display_name': 'BHRC Member •4321',
            'lifetime_points': 1600,
            'level': 'Gold',
            'level_color': '#D97706',
            'is_current_patient': false,
          },
          {
            'rank': 2,
            'display_name': 'You',
            'lifetime_points': 600,
            'level': 'Silver',
            'level_color': '#64748B',
            'is_current_patient': true,
          },
        ],
      },
    });

    expect(myClub.points, 400);
    expect(myClub.lifetimePoints, 600);
    expect(myClub.levelName, 'Silver');
    expect(myClub.leaderboardRank, 2);
    expect(myClub.leaderboard, hasLength(2));
    expect(myClub.leaderboard.first.displayName, 'BHRC Member •4321');
    expect(myClub.leaderboard.last.isCurrentPatient, isTrue);
  });
}
