import 'package:biohelix_app/patient_portal/fitness/models/fitness_activity_models.dart';
import 'package:biohelix_app/patient_portal/fitness/providers/fitness_provider.dart';
import 'package:biohelix_app/patient_portal/fitness/services/android_fitness_service.dart';
import 'package:biohelix_app/patient_portal/fitness/widgets/fitness_activity_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/audit_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.biohelix.app/fitness');
  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'getStatus' => {'status': 'available', 'permissionsGranted': true},
        'requestPermissions' => {'granted': true},
        'readActivity' => {
          'timezone': 'Asia/Kolkata',
          'days': [
            {'date': '2026-10-09', 'steps': 9000},
          ],
        },
        _ => null,
      };
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'Android cannot request permission read activity or open a health provider',
    () async {
      final service = AndroidFitnessService();
      expect(service.isSupportedPlatform, isFalse);
      expect((await service.status()).isAvailable, isFalse);
      expect(await service.requestPermissions(), isFalse);
      await expectLater(
        service.readActivity(),
        throwsA(isA<UnsupportedError>()),
      );
      await service.openHealthConnect();
      expect(calls, isEmpty);
    },
  );

  test(
    'an Android upgrade clears the saved connection and never fetches or syncs activity',
    () async {
      SharedPreferences.setMockInitialValues({
        'fitness_device_owner_patient_id': 1,
      });
      var summaryRequests = 0;
      final repository = AuditRepository()
        ..fitnessRequest = () async {
          summaryRequests++;
          return const FitnessActivitySummary();
        };
      final session = repository.session();
      await session.sendOtp(phone: '9998887777');
      await session.verifyOtp(otp: '123456');
      final provider = FitnessProvider(
        repository: repository,
        sessionProvider: session,
      );
      await provider.initialize();
      expect(
        (await SharedPreferences.getInstance()).getInt(
          'fitness_device_owner_patient_id',
        ),
        isNull,
      );
      expect(provider.hasDeviceOwner, isFalse);
      expect(provider.state, FitnessConnectionState.unavailable);
      await provider.connect();
      await provider.refreshAndSync();
      await provider.openHealthConnect();
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      session.updatePatient(auditPatientFor(2));
      expect(summaryRequests, 0);
      expect(repository.fitnessSyncCalls, 0);
      expect(calls, isEmpty);
      provider.dispose();
      session.dispose();
    },
  );

  testWidgets('Android offers no activity card or connect action', (
    tester,
  ) async {
    final repository = AuditRepository();
    final session = repository.session();
    final provider = FitnessProvider(
      repository: repository,
      sessionProvider: session,
    );
    await provider.initialize();
    await tester.pumpWidget(
      ChangeNotifierProvider<FitnessProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [Text('BHRC Hospital'), FitnessActivityCard()],
            ),
          ),
        ),
      ),
    );
    expect(find.text('BHRC Hospital'), findsOneWidget);
    expect(find.text('Activity Rewards'), findsNothing);
    expect(find.text('Connect activity'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(calls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    session.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS can still use its existing Apple Health channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final service = AndroidFitnessService();
    expect(service.isSupportedPlatform, isTrue);
    expect(service.platformName, 'Apple Health');
    expect((await service.status()).isAvailable, isTrue);
    expect(await service.requestPermissions(), isTrue);
    final activity = await service.readActivity();
    expect(activity.days.single.steps, 9000);
    await service.openHealthConnect();
    expect(calls, [
      'getStatus',
      'requestPermissions',
      'readActivity',
      'openHealthConnect',
    ]);
  });
}
