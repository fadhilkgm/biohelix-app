import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/core/referrals/referral_link_provider.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/my_club/screens/patient_loyalty_panel.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('captures and persists a cold-start universal referral link', () async {
    SharedPreferences.setMockInitialValues({});
    final linkEvents = StreamController<Uri>();
    final provider = ReferralLinkProvider(
      initialLinkReader: () async =>
          Uri.parse('https://demo.bhrchospital.com/r/bhrcabc12345'),
      linkStream: linkEvents.stream,
      installReferrerReader: () async => null,
      preferencesReader: SharedPreferences.getInstance,
    );

    await provider.initialize();

    expect(provider.pendingCode, 'BHRCABC12345');
    expect(provider.pendingSource, 'initial_app_link');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('pending_referral_code'), 'BHRCABC12345');

    provider.dispose();
    await linkEvents.close();
  });

  test(
    'restores an Android Play install referral and consumes it once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ReferralLinkProvider(
        initialLinkReader: () async => null,
        linkStream: const Stream.empty(),
        installReferrerReader: () async =>
            'referral_code%3DBHRCPLAY1234%26utm_source%3Dpatient_referral',
        preferencesReader: SharedPreferences.getInstance,
      );

      await provider.initialize();
      expect(provider.pendingCode, 'BHRCPLAY1234');
      expect(provider.pendingSource, 'play_install_referrer');

      await provider.consumeIfMatches('bhrcplay1234');
      expect(provider.pendingCode, isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'pending_referral_code',
        ),
        isNull,
      );
      provider.dispose();
    },
  );

  test('rejects referral links from an untrusted HTTPS host', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ReferralLinkProvider(
      initialLinkReader: () async =>
          Uri.parse('https://attacker.example/r/BHRCBAD12345'),
      linkStream: const Stream.empty(),
      installReferrerReader: () async => null,
      preferencesReader: SharedPreferences.getInstance,
    );

    await provider.initialize();

    expect(provider.pendingCode, isNull);
    provider.dispose();
  });

  test('rejects referral links delivered over insecure HTTP', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ReferralLinkProvider(
      initialLinkReader: () async =>
          Uri.parse('http://demo.bhrchospital.com/r/BHRCBAD12345'),
      linkStream: const Stream.empty(),
      installReferrerReader: () async => null,
      preferencesReader: SharedPreferences.getInstance,
    );

    await provider.initialize();

    expect(provider.pendingCode, isNull);
    provider.dispose();
  });

  test('signup sends a normalized referral code to the API', () async {
    final adapter = _ReferralAdapter({
      'success': true,
      'message': 'OTP sent',
      'dev_otp': '123456',
    });
    final repository = PatientRepository(apiClient: _client(adapter));

    await repository.signUp(
      phone: '+919876543210',
      name: 'New Patient',
      dob: '1995-05-10',
      place: 'Kozhikode',
      referralCode: '  bhrcabc123  ',
    );

    expect(adapter.path, '/auth/signup');
    expect(adapter.method, 'POST');
    expect(
      (adapter.data as Map<String, dynamic>)['referral_code'],
      'BHRCABC123',
    );
  });

  test('referral summary parses both sides of the relationship', () {
    final summary = ReferralSummary.fromJson({
      'code': 'BHRCOWN123',
      'share_url': 'https://example.test/r/BHRCOWN123',
      'invited_by': {
        'id': 1,
        'patient_id': 10,
        'name': 'Aisha Referrer',
        'patient_number': 'PAT-10',
        'status': 'rewarded',
      },
      'invited_users': [
        {
          'id': 2,
          'patient_id': 20,
          'name': 'Bilal Invitee',
          'patient_number': 'PAT-20',
          'status': 'verified',
        },
      ],
      'stats': {'invited': 1, 'verified': 1, 'rewarded': 0, 'points_earned': 0},
      'reward_terms': {
        'referrer_points': 100,
        'new_patient_points': 50,
        'qualification': 'Complete the first paid service.',
      },
    });

    expect(summary.invitedBy?.name, 'Aisha Referrer');
    expect(summary.invitedUsers.single.name, 'Bilal Invitee');
    expect(summary.rewardTerms.referrerPoints, 100);
    expect(summary.rewardTerms.newPatientPoints, 50);
  });

  testWidgets('rewards page shows who invited the user and who they invited', (
    tester,
  ) async {
    final languageApi = _client(_ReferralAdapter(const {}));
    const referrals = ReferralSummary(
      code: 'BHRCOWN123',
      shareUrl: 'https://example.test/r/BHRCOWN123',
      invitedBy: ReferralRelationship(
        id: 1,
        patientId: 10,
        name: 'Aisha Referrer',
        patientNumber: 'PAT-10',
        status: 'rewarded',
      ),
      invitedUsers: [
        ReferralRelationship(
          id: 2,
          patientId: 20,
          name: 'Bilal Invitee',
          patientNumber: 'PAT-20',
          status: 'verified',
        ),
      ],
      stats: ReferralStats(invited: 1, verified: 1),
      rewardTerms: ReferralRewardTerms(
        referrerPoints: 100,
        newPatientPoints: 50,
        qualification: 'Complete the first paid service.',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(apiClient: languageApi),
        child: const MaterialApp(
          home: Scaffold(
            body: PatientLoyaltyDetailsContent(
              idCard: IdCardInfo(
                registrationNumber: 'PAT-20',
                patientName: 'Current Patient',
                membershipTier: 'Classic',
                qrValue: 'CARD-20',
                barcodeValue: 'PAT-20',
              ),
              myClub: MyClubSummary(
                patientId: 20,
                points: 50,
                currencyValue: 50,
                tier: 'Classic',
                transactions: [],
                referrals: referrals,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('referral_relationships_card')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Who invited you'), findsOneWidget);
    expect(find.text('Aisha Referrer'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('People you invited'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bilal Invitee'), findsOneWidget);
    expect(find.text('BHRCOWN123'), findsOneWidget);
  });
}

ApiClient _client(_ReferralAdapter adapter) {
  return ApiClient(
    config: AppConfig(
      appName: 'BioHelix Test',
      apiBaseUrl: 'http://localhost:8000/api/v1',
      healthEndpoint: '/health',
      showDevOtp: true,
    ),
    httpClientAdapter: adapter,
  );
}

class _ReferralAdapter implements HttpClientAdapter {
  _ReferralAdapter(this.response);

  final Map<String, dynamic> response;
  String? path;
  String? method;
  Object? data;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    method = options.method;
    data = options.data;
    return ResponseBody.fromString(
      _encode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _encode(Map<String, dynamic> value) {
  return jsonEncode(value);
}
