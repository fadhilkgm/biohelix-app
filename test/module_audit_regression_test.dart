import 'dart:async';

import 'package:biohelix_app/core/network/api_exception.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/features/auth/presentation/widgets/otp_input.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/inworld_signaling_api.dart';
import 'package:biohelix_app/patient_portal/fitness/models/fitness_activity_models.dart';
import 'package:biohelix_app/patient_portal/fitness/providers/fitness_provider.dart';
import 'package:biohelix_app/patient_portal/fitness/services/android_fitness_service.dart';
import 'package:biohelix_app/patient_portal/lab_booking/models/lab_booking_models.dart';
import 'package:biohelix_app/patient_portal/lab_booking/state/lab_booking_controller.dart';
import 'package:biohelix_app/patient_portal/records/screens/in_app_document_viewer.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/audit_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('report downloads keep patient credentials on the API origin', () {
    Map<String, String> headers(String url) =>
        InAppDocumentViewer.requestHeaders(
          url: url,
          apiBaseUrl: auditConfig.apiBaseUrl,
          authToken: 'patient-token',
        );
    expect(headers('https://example.test/api/reports/1'), {
      'Authorization': 'Bearer patient-token',
    });
    expect(
      headers('https://storage.test/report.pdf?signature=signed'),
      isEmpty,
    );
    expect(headers('http://example.test/report.pdf'), isEmpty);
    expect(headers('https://example.test:8443/report.pdf'), isEmpty);
    expect(headers('https://example.test.attacker.test/report.pdf'), isEmpty);
  });

  test('browser report bytes upload without a local filesystem path', () async {
    final adapter = AuditAdapter(
      respond: (_) async => AuditAdapter.jsonResponse({
        'document': {'id': 22, 'documentPath': '/uploads/report.pdf'},
      }),
    );
    final repository = PatientRepository(
      apiClient: auditClient(adapter: adapter),
    );
    final uploaded = await repository.uploadDocument(
      '',
      fileName: 'report.pdf',
      documentType: 'lab',
      fileBytes: [37, 80, 68, 70],
    );
    expect(uploaded.id, 22);
    final form = adapter.requests.single.data as FormData;
    expect(form.files.single.key, 'document');
    expect(form.files.single.value.filename, 'report.pdf');
    expect(form.files.single.value.length, 4);
    expect(Map<String, String>.fromEntries(form.fields)['documentType'], 'lab');
  });

  test('a second send cannot create another thread during bootstrap', () async {
    final created = Completer<ChatThreadSummary>();
    final repository = AuditRepository()
      ..createThreadRequest = () => created.future;
    final session = repository.session();
    final portal = await authenticatedAuditPortal(repository, session);
    final first = portal.sendChatMessage('First message');
    await portal.sendChatMessage('Second message');
    expect(repository.createThreadCalls, 1);
    // Changing patient while the first request is pending also verifies that
    // its newly created thread cannot enter the new patient's history.
    session.updatePatient(auditPatientFor(2));
    created.complete(const ChatThreadSummary(id: 'old-thread', title: 'Old'));
    await first;
    expect(portal.chatThreads, isEmpty);
    portal.dispose();
    session.dispose();
  });

  group('session recovery', () {
    test(
      'profile outage after signup still finishes OTP and offers assessment',
      () async {
        final repository = AuditRepository()
          ..patient = auditPatient.copyWith(
            hasCompletedInitialHealthAssessment: false,
          )
          ..profileRequest = () async =>
              throw ApiException('Unavailable', statusCode: 500);
        final session = repository.session();
        await session.signUp(
          phone: '9998887777',
          name: 'New Patient',
          dob: '2000-01-01',
          place: 'Ponnani',
          bloodGroup: 'O+',
        );
        await session.verifyOtp(otp: '123456');
        expect(session.state, SessionState.signedIn);
        expect(session.shouldOfferInitialHealthAssessment, isTrue);
        expect(session.pendingPhone, isNull);
        expect(session.isPendingSignupOtp, isFalse);
        expect(session.familyProfiles.single.patient.id, 1);
        expect(
          session.errorMessage,
          contains('blood group could not be saved'),
        );
        session.dispose();
      },
    );
    test('all expired saved profiles finish startup signed out', () async {
      await _storeProfiles();
      final repository = AuditRepository()
        ..currentPatient = () async =>
            throw ApiException('Expired', statusCode: 401);
      final session = repository.session();
      await session.initialize();
      expect(session.state, SessionState.signedOut);
      expect(session.isAuthenticated, isFalse);
      expect(await AuthStorage().readToken(), isNull);
      session.dispose();
    });

    test(
      'recovery tries every saved profile until a valid one is found',
      () async {
        await _storeProfiles(count: 3);
        var calls = 0;
        final repository = AuditRepository()
          ..currentPatient = () async {
            calls++;
            if (calls < 3) throw ApiException('Expired', statusCode: 401);
            return auditPatientFor(3);
          };
        final session = repository.session();
        await session.initialize();
        expect(session.patient?.id, 3);
        expect(session.authToken, 'token-3');
        expect(calls, 3);
        session.dispose();
      },
    );

    test(
      'a temporary network outage preserves the saved active profile',
      () async {
        await _storeProfiles();
        final repository = AuditRepository()
          ..currentPatient = () async => throw ApiException('Offline');
        final session = repository.session();
        await session.initialize();
        expect(session.patient?.id, 1);
        expect(session.authToken, 'token-1');
        expect(session.familyProfiles.length, 2);
        session.dispose();
      },
    );

    test(
      'a failed family switch restores the profile that was active',
      () async {
        await _storeProfiles(count: 3);
        final repository = AuditRepository();
        final session = repository.session();
        await session.initialize();
        repository.currentPatient = () async => throw ApiException('Offline');
        await session.switchFamilyProfile('token-3');
        expect(session.authToken, 'token-1');
        expect(session.patient?.id, 1);
        expect(session.state, SessionState.signedIn);
        session.dispose();
      },
    );

    test('concurrent sign-out requests revoke the token only once', () async {
      final gate = Completer<void>();
      final repository = AuditRepository()..logoutRequest = () => gate.future;
      final session = repository.session();
      await session.sendOtp(phone: '9998887777');
      await session.verifyOtp(otp: '123456');
      final first = session.signOut();
      final second = session.signOut();
      expect(repository.logoutCalls, 1);
      gate.complete();
      await Future.wait([first, second]);
      expect(session.isAuthenticated, isFalse);
      session.dispose();
    });

    test(
      'a profile refresh cannot restore an old patient after switching',
      () async {
        final gate = Completer<PatientIdentity>();
        final repository = AuditRepository();
        final session = repository.session();
        await session.sendOtp(phone: '9998887777');
        await session.verifyOtp(otp: '123456');
        repository.currentPatient = () => gate.future;
        final pending = session.refreshPatient();
        repository.patient = auditPatientFor(2, name: 'Family Patient');
        await session.sendOtp(phone: '8887776666');
        await session.verifyOtp(otp: '123456');
        gate.complete(auditPatient);
        await pending;
        expect(session.patient?.id, 2);
        session.dispose();
      },
    );
  });

  group('unauthorized responses', () {
    test(
      'a late 401 for the old token does not expire the new session',
      () async {
        final gate = Completer<ResponseBody>();
        final started = Completer<void>();
        var unauthorized = 0;
        final client = auditClient(
          adapter: AuditAdapter(
            respond: (_) {
              started.complete();
              return gate.future;
            },
          ),
          onUnauthorized: () => unauthorized++,
        )..updateAuthToken('old-token');
        final pending = client.getJson('/patients/me');
        final expectation = expectLater(pending, throwsA(isA<ApiException>()));
        await started.future;
        client.updateAuthToken('new-token');
        gate.complete(
          AuditAdapter.jsonResponse({'error': 'Expired'}, status: 401),
        );
        await expectation;
        expect(unauthorized, 0);
      },
    );

    test(
      'invalid family OTP does not invalidate an authenticated account',
      () async {
        var unauthorized = 0;
        final client = auditClient(
          adapter: AuditAdapter(
            respond: (_) async => AuditAdapter.jsonResponse({
              'error': 'Invalid OTP',
            }, status: 401),
          ),
          onUnauthorized: () => unauthorized++,
        )..updateAuthToken('active-token');
        await expectLater(
          client.postJson('/auth/otp/verify', data: {'otp': '000000'}),
          throwsA(isA<ApiException>()),
        );
        expect(unauthorized, 0);
      },
    );

    test('a current authenticated 401 still expires the session', () async {
      var unauthorized = 0;
      final client = auditClient(
        adapter: AuditAdapter(
          respond: (_) async => AuditAdapter.jsonResponse({}, status: 401),
        ),
        onUnauthorized: () => unauthorized++,
      )..updateAuthToken('active-token');
      await expectLater(
        client.getJson('/patients/me'),
        throwsA(isA<ApiException>()),
      );
      expect(unauthorized, 1);
    });

    test(
      'profile authorization failure is not retried as a legacy request',
      () async {
        final adapter = AuditAdapter(
          respond: (_) async => AuditAdapter.jsonResponse({}, status: 401),
        );
        final repository = PatientRepository(
          apiClient: auditClient(adapter: adapter),
        );
        await expectLater(
          repository.getCurrentPatient(),
          throwsA(isA<ApiException>()),
        );
        expect(adapter.requests.length, 1);
      },
    );
  });

  group('patient scope', () {
    test(
      'accepting a suggestion leaves the other suggestions unchanged',
      () async {
        final repository = AuditRepository()
          ..suggestions = [
            for (var id = 1; id <= 2; id++)
              AiSuggestionItem(
                id: id,
                recommendationType: 'test',
                reason: '',
                score: 0.8,
                isAccepted: false,
              ),
          ];
        final session = repository.session();
        final portal = await authenticatedAuditPortal(repository, session);
        await portal.acceptAiSuggestion(1);
        expect(portal.aiSuggestions.map((item) => item.isAccepted), [
          true,
          false,
        ]);
        portal.dispose();
        session.dispose();
      },
    );

    test(
      'a late profile save cannot replace the newly selected patient',
      () async {
        final gate = Completer<PatientIdentity>();
        final repository = AuditRepository()
          ..profileRequest = () => gate.future;
        final session = repository.session();
        final portal = await authenticatedAuditPortal(repository, session);
        final pending = portal.saveProfile(auditPatient);
        session.updatePatient(auditPatientFor(2));
        gate.complete(auditPatient.copyWith(name: 'Updated old patient'));
        await pending;
        expect(session.patient?.id, 2);
        expect(portal.dashboard, isNull);
        expect(portal.isSavingProfile, isFalse);
        portal.dispose();
        session.dispose();
      },
    );

    test('a late family list cannot populate another patient scope', () async {
      final gate = Completer<List<FamilyMember>>();
      final repository = AuditRepository();
      final session = repository.session();
      final portal = await authenticatedAuditPortal(repository, session);
      repository.familyRequest = () => gate.future;
      final pending = portal.refreshFamilyMembers();
      session.updatePatient(auditPatientFor(2));
      gate.complete([
        FamilyMember.fromJson({'link_id': 21, 'name': 'Old family'}),
      ]);
      await pending;
      expect(portal.familyMembers, isEmpty);
      portal.dispose();
      session.dispose();
    });

    test(
      'a late report chat reply is ignored after patient switching',
      () async {
        final gate = Completer<ChatMessage>();
        final repository = AuditRepository()..documentReply = () => gate.future;
        final session = repository.session();
        final portal = await authenticatedAuditPortal(repository, session);
        final pending = portal.sendDocumentChatMessage(
          documentId: 4,
          message: 'Explain',
        );
        session.updatePatient(auditPatientFor(2));
        gate.complete(
          const ChatMessage(role: 'ai', content: 'Old private report'),
        );
        await pending;
        expect(portal.documentChatFor(4), isEmpty);
        portal.dispose();
        session.dispose();
      },
    );

    test(
      'chat bootstrap cannot load old threads after patient switching',
      () async {
        final gate = Completer<List<ChatThreadSummary>>();
        final repository = AuditRepository()
          ..threadsRequest = () => gate.future;
        final session = repository.session();
        final portal = await authenticatedAuditPortal(repository, session);
        final pending = portal.initializeChatThreads();
        session.updatePatient(auditPatientFor(2));
        gate.complete([
          const ChatThreadSummary(id: 'private-thread', title: 'Old patient'),
        ]);
        await pending;
        expect(portal.chatThreads, isEmpty);
        expect(portal.activeChatThreadId, isNull);
        portal.dispose();
        session.dispose();
      },
    );

    test('sign-out immediately clears cached patient portal data', () async {
      final repository = AuditRepository();
      final session = repository.session();
      final portal = await authenticatedAuditPortal(repository, session);
      expect(portal.dashboard, isNotNull);
      await session.signOut();
      expect(portal.dashboard, isNull);
      expect(portal.chatThreads, isEmpty);
      portal.dispose();
      session.dispose();
    });
  });

  test('doctor schedules accept twelve-hour slots, ranges, and noon', () async {
    final repository = AuditRepository()
      ..doctorItems = [
        const DoctorListing(
          id: 1,
          name: 'Doctor',
          specialization: 'General',
          schedules: [
            DoctorSchedule(
              id: 1,
              dayOfWeek: 'Monday',
              sessionName: 'Morning',
              startTime: '09:00:00',
              endTime: '13:00:00',
            ),
          ],
        ),
      ]
      ..slots = ['9:00 AM', '10:15-10:30', '12:00 PM', '2:00 PM'];
    final session = repository.session();
    final portal = await authenticatedAuditPortal(repository, session);
    expect(
      await portal.getDoctorAvailableSlots(doctorId: 1, date: '2026-10-05'),
      ['9:00 AM', '10:15-10:30', '12:00 PM'],
    );
    portal.dispose();
    session.dispose();
  });

  test(
    'an empty server availability stays empty on a scheduled working day',
    () async {
      final repository = AuditRepository()
        ..doctorItems = [
          const DoctorListing(
            id: 1,
            name: 'Doctor',
            specialization: 'General',
            schedules: [
              DoctorSchedule(
                id: 1,
                dayOfWeek: 'Monday',
                sessionName: 'Morning',
                startTime: '09:00',
                endTime: '12:00',
              ),
            ],
          ),
        ];
      final session = repository.session();
      final portal = await authenticatedAuditPortal(repository, session);
      expect(
        await portal.getDoctorAvailableSlots(doctorId: 1, date: '2026-10-05'),
        isEmpty,
      );
      expect(
        await portal.getDoctorSlotAvailability(doctorId: 1, date: '2026-10-05'),
        isEmpty,
      );
      portal.dispose();
      session.dispose();
    },
  );

  group('live voice configuration', () {
    test(
      'concurrent English and Malayalam starts use the requested language',
      () async {
        final english = Completer<ResponseBody>();
        final malayalam = Completer<ResponseBody>();
        final bothStarted = Completer<void>();
        var requests = 0;
        final adapter = AuditAdapter(
          respond: (options) async {
            if (options.path == '/realtime/ice') {
              return AuditAdapter.jsonResponse({});
            }
            if (++requests == 2) bothStarted.complete();
            return options.queryParameters['language'] == 'ml'
                ? malayalam.future
                : english.future;
          },
        );
        final signaling = InworldSignalingApi(auditClient(adapter: adapter));
        final en = signaling.bootstrap(locale: 'en-IN');
        final ml = signaling.bootstrap(locale: 'ml-IN');
        await bothStarted.future;
        english.complete(_voiceConfig('en'));
        malayalam.complete(_voiceConfig('ml'));
        expect((await en).sessionUpdate['session'], {'language': 'en'});
        expect((await ml).sessionUpdate['session'], {'language': 'ml'});
      },
    );

    test(
      'invalidated pending configuration cannot repopulate the cache',
      () async {
        final firstResponse = Completer<ResponseBody>();
        final started = Completer<void>();
        var requests = 0;
        final adapter = AuditAdapter(
          respond: (options) async {
            if (options.path == '/realtime/ice') {
              return AuditAdapter.jsonResponse({});
            }
            if (++requests == 1) {
              started.complete();
              return firstResponse.future;
            }
            return _voiceConfig('en');
          },
        );
        final signaling = InworldSignalingApi(auditClient(adapter: adapter));
        final pending = signaling.bootstrap(locale: 'en-IN');
        await started.future;
        signaling.invalidateBootstrap();
        firstResponse.complete(_voiceConfig('en'));
        await pending;
        await signaling.bootstrap(locale: 'en-IN');
        expect(requests, 2);
      },
    );
  });

  group('lab checkout', () {
    test(
      'inactive catalogue tests cannot be selected from the visible list',
      () {
        final controller = LabBookingController(
          patientName: 'Patient',
          tests: [
            auditLabTest,
            const LabTestItem(
              id: 12,
              testName: 'Inactive',
              categoryId: 1,
              categoryName: 'Lab',
              status: false,
              basePrice: 100,
            ),
          ],
          bodyPoints: [],
        );
        expect(controller.filteredTests.map((item) => item.id), [11]);
        controller.dispose();
      },
    );

    test(
      'an old home-collection quote cannot overwrite a lab-visit quote',
      () async {
        final gate = Completer<LabOrderQuote>();
        final repository = AuditRepository()..quoteRequest = () => gate.future;
        final session = repository.session();
        final portal = await authenticatedAuditPortal(repository, session);
        final controller = _cart();
        final pending = controller.refreshQuote(portal);
        controller.setCollectionType(CollectionType.lab);
        repository.quoteRequest = () async =>
            const LabOrderQuote(subtotal: 250, collectionFee: 0, amount: 250);
        await controller.refreshQuote(portal);
        gate.complete(
          const LabOrderQuote(subtotal: 250, collectionFee: 99, amount: 349),
        );
        await pending;
        expect(controller.total, 250);
        expect(controller.collectionFee, 0);
        controller.dispose();
        portal.dispose();
        session.dispose();
      },
    );

    test('a removed cart item invalidates an in-flight quote', () async {
      final gate = Completer<LabOrderQuote>();
      final repository = AuditRepository()..quoteRequest = () => gate.future;
      final session = repository.session();
      final portal = await authenticatedAuditPortal(repository, session);
      final controller = _cart();
      final pending = controller.refreshQuote(portal);
      controller.updateQty(11, 0);
      gate.complete(
        const LabOrderQuote(subtotal: 250, collectionFee: 99, amount: 349),
      );
      await pending;
      expect(controller.subtotal, 0);
      expect(controller.quoteLoading, isFalse);
      controller.dispose();
      portal.dispose();
      session.dispose();
    });

    test(
      'home orders require an address and a selected collection time',
      () async {
        final repository = AuditRepository();
        final session = repository.session();
        final portal = await authenticatedAuditPortal(repository, session);
        final controller = _cart();
        await expectLater(controller.placeOrder(portal), throwsStateError);
        controller.addAddress(label: 'Home', fullAddress: 'Actual address');
        controller.setSlot(controller.slot!);
        await expectLater(controller.placeOrder(portal), throwsStateError);
        expect(repository.orderCalls, 0);
        controller.dispose();
        portal.dispose();
        session.dispose();
      },
    );

    test('disposing checkout while a quote is pending is safe', () async {
      final gate = Completer<LabOrderQuote>();
      final repository = AuditRepository()..quoteRequest = () => gate.future;
      final session = repository.session();
      final portal = await authenticatedAuditPortal(repository, session);
      final controller = _cart();
      final pending = controller.refreshQuote(portal);
      controller.dispose();
      gate.complete(
        const LabOrderQuote(subtotal: 250, collectionFee: 99, amount: 349),
      );
      await pending;
      portal.dispose();
      session.dispose();
    });

    test(
      'a successful order clears both the cart and its price quote',
      () async {
        final repository = AuditRepository();
        final session = repository.session();
        final portal = await authenticatedAuditPortal(repository, session);
        final controller = _cart()
          ..addAddress(label: 'Home', fullAddress: 'Actual address');
        expect(await controller.placeOrder(portal), 'LAB-1');
        expect(repository.orderCalls, 1);
        expect(controller.cart, isEmpty);
        expect(controller.subtotal, 0);
        controller.dispose();
        portal.dispose();
        session.dispose();
      },
    );
  });

  testWidgets('pasting a complete OTP fills six boxes and completes once', (
    tester,
  ) async {
    var completions = 0;
    var value = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpInput(
            onChanged: (next) => value = next,
            onCompleted: (_) => completions++,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pump();
    expect(value, '123456');
    expect(completions, 1);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller!.text),
      ['1', '2', '3', '4', '5', '6'],
    );
  });

  testWidgets(
    'backspace updates the OTP value when clearing the previous box',
    (tester) async {
      var value = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInput(
              onChanged: (next) => value = next,
              onCompleted: (_) {},
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '1');
      await tester.pump();
      final listener = tester
          .widgetList<KeyboardListener>(find.byType(KeyboardListener))
          .elementAt(1);
      listener.onKeyEvent!(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.backspace,
          logicalKey: LogicalKeyboardKey.backspace,
          timeStamp: Duration.zero,
        ),
      );
      expect(value, '');
    },
  );

  test(
    'fitness never uploads device activity to a newly switched patient',
    () async {
      SharedPreferences.setMockInitialValues({
        'fitness_device_owner_patient_id': 1,
      });
      final repository = AuditRepository();
      final session = repository.session();
      await session.sendOtp(phone: '9998887777');
      await session.verifyOtp(otp: '123456');
      final service = _PausedFitnessService();
      final fitness = FitnessProvider(
        repository: repository,
        sessionProvider: session,
        service: service,
      );
      final pending = fitness.initialize();
      await service.started.future;
      session.updatePatient(auditPatientFor(2));
      service.activity.complete(
        const AndroidFitnessReadResult(
          timezone: 'Asia/Kolkata',
          days: [DailyFitnessActivity(date: '2026-10-02', steps: 9000)],
        ),
      );
      await pending;
      expect(repository.fitnessSyncCalls, 0);
      expect(fitness.today, isNull);
      expect(fitness.state, FitnessConnectionState.blockedForDifferentPatient);
      fitness.dispose();
      session.dispose();
    },
  );
}

Future<void> _storeProfiles({int count = 2}) async {
  final storage = AuthStorage();
  await storage.writeToken('token-1');
  await storage.writeFamilyProfiles([
    for (var id = 1; id <= count; id++)
      SavedPatientProfile(
        token: 'token-$id',
        patient: auditPatientFor(id),
        lastUsedAt: '2026-10-02T00:00:00',
      ),
  ]);
}

LabBookingController _cart() => LabBookingController(
  patientName: 'Patient',
  tests: [auditLabTest],
  bodyPoints: [],
  initialTestIds: [11],
);

ResponseBody _voiceConfig(String language) => AuditAdapter.jsonResponse({
  'type': 'session.update',
  'session': {'language': language},
});

class _PausedFitnessService extends AndroidFitnessService {
  final started = Completer<void>();
  final activity = Completer<AndroidFitnessReadResult>();
  @override
  bool get isSupportedPlatform => true;
  @override
  Future<FitnessPlatformStatus> status() async => const FitnessPlatformStatus(
    status: 'available',
    permissionsGranted: true,
    nativePhoneStepTracking: false,
    androidVersion: 34,
  );
  @override
  Future<AndroidFitnessReadResult> readActivity({int days = 7}) {
    started.complete();
    return activity.future;
  }
}
