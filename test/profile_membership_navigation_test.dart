import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/my_club/screens/patient_loyalty_panel.dart';
import 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('profile membership card opens points and transaction history', (
    tester,
  ) async {
    const patient = PatientIdentity(
      id: 42,
      name: 'Amina Patient',
      phone: '7034598461',
      registrationNumber: 'BHRC-42',
      uuid: 'patient-42',
    );
    const idCard = IdCardInfo(
      registrationNumber: 'BHRC-42',
      patientName: 'Amina Patient',
      membershipTier: 'Silver',
      qrValue: 'patient-42',
    );
    const myClub = MyClubSummary(
      patientId: 42,
      points: 115,
      currencyValue: 11.5,
      tier: 'Silver',
      levelName: 'Silver',
      levelColor: '#64748B',
      lifetimePoints: 600,
      nextTierName: 'Gold',
      pointsToNextTier: 900,
      progressPercent: 10,
      leaderboardRank: 2,
      benefits: [
        'Start earning MyClub rewards',
        'Priority appointment support',
      ],
      transactions: [
        MyClubTransaction(
          id: 1,
          date: '2026-07-29',
          description: 'Doctor consultation reward',
          points: 25,
          type: 'earn',
        ),
        MyClubTransaction(
          id: 2,
          date: '2026-07-29',
          description: 'Offer redemption',
          points: -10,
          type: 'redeem',
        ),
      ],
    );
    final language = LanguageProvider(
      apiClient: ApiClient(
        config: AppConfig(
          appName: 'BHRC Test',
          apiBaseUrl: 'https://example.test/api/v1',
          healthEndpoint: '/health',
          showDevOtp: false,
        ),
      ),
    );
    var inviteTapped = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: language,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: SingleChildScrollView(
                child: ProfileMembershipCard(
                  patient: patient,
                  idCard: idCard,
                  myClub: myClub,
                  onInvite: () => inviteTapped = true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const PatientLoyaltyDetailsPage(myClub: myClub),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Silver Membership'), findsOneWidget);
    expect(find.text('600 lifetime points'), findsOneWidget);
    expect(find.text('900 points to Gold'), findsOneWidget);
    expect(find.text('Rank #2'), findsOneWidget);
    expect(find.text('Start earning MyClub rewards'), findsNothing);
    expect(find.text('Priority appointment support'), findsOneWidget);
    expect(find.text('Invite Friends'), findsOneWidget);
    await tester.ensureVisible(find.text('Invite Friends'));
    await tester.tap(find.text('Invite Friends'));
    await tester.pump();
    expect(inviteTapped, isTrue);
    expect(find.text('View points & transactions'), findsOneWidget);
    await tester.ensureVisible(find.text('View points & transactions'));
    await tester.tap(find.text('View points & transactions'));
    await tester.pumpAndSettle();

    expect(find.text('Rewards Wallet'), findsOneWidget);
    expect(find.text('BHRC Member Card'), findsNothing);
    expect(find.text('Member ID'), findsNothing);
    expect(find.text('Redemption setup'), findsNothing);
    final detailsScrollable = find
        .descendant(
          of: find.byType(PatientLoyaltyDetailsContent),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Points credit history'),
      400,
      scrollable: detailsScrollable,
    );
    expect(find.text('Points credit history'), findsOneWidget);
    expect(find.text('Doctor consultation reward'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Redemption history'),
      400,
      scrollable: detailsScrollable,
    );
    expect(find.text('Redemption history'), findsOneWidget);
    expect(find.text('Offer redemption'), findsWidgets);
  });
}
