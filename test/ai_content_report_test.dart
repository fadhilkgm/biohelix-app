import 'dart:async';

import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/patient_portal/assistant/widgets/ai_content_report_dialog.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/audit_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sends only the selected reply and report context', () async {
    final adapter = AuditAdapter(
      respond: (_) async => AuditAdapter.jsonResponse({
        'report': {'id': 1, 'status': 'pending'},
      }, status: 201),
    );
    final repository = PatientRepository(
      apiClient: auditClient(adapter: adapter),
    );
    await repository.reportAiContent(
      content: 'Selected reply',
      source: 'chat',
      reason: 'incorrect_information',
      conversationId: '12',
      messageId: 34,
    );
    expect(adapter.requests.single.path, '/patients/ai/content-reports');
    expect(adapter.requests.single.data, {
      'content': 'Selected reply',
      'source': 'chat',
      'reason': 'incorrect_information',
      'conversation_id': '12',
      'message_id': 34,
    });
  });

  test('limits snapshots without splitting Unicode characters', () async {
    final adapter = AuditAdapter(
      respond: (_) async => AuditAdapter.jsonResponse({
        'report': {'id': 2},
      }),
    );
    final repository = PatientRepository(
      apiClient: auditClient(adapter: adapter),
    );
    await repository.reportAiContent(
      content: '🧬' * 8001,
      source: 'voice',
      reason: 'other',
      messageId: 55,
    );
    expect(adapter.requests.single.data['content'], '🧬' * 8000);
    expect(adapter.requests.single.data.containsKey('message_id'), isFalse);
  });

  test(
    'does not acknowledge a report when the server has not accepted it',
    () async {
      final adapter = AuditAdapter(
        respond: (_) async => AuditAdapter.jsonResponse({}),
      );
      final repository = PatientRepository(
        apiClient: auditClient(adapter: adapter),
      );
      await expectLater(
        repository.reportAiContent(
          content: 'Reply',
          source: 'voice',
          reason: 'other',
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  Future<SessionProvider> signIn(AuditRepository repository) async {
    final session = repository.session();
    await session.sendOtp(phone: '9998887777');
    await session.verifyOtp(otp: '123456');
    return session;
  }

  Future<void> openReport(
    WidgetTester tester,
    AuditRepository repository,
    SessionProvider session,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PatientRepository>.value(value: repository),
          ChangeNotifierProvider<SessionProvider>.value(value: session),
          ChangeNotifierProvider(
            create: (_) => LanguageProvider(apiClient: repository.client),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiContentReportButton(
              content: 'Selected reply',
              source: 'chat',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Report AI response'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'blocks repeated submissions until the server acknowledges receipt',
    (tester) async {
      final gate = Completer<ResponseBody>();
      final adapter = AuditAdapter(respond: (_) => gate.future);
      final repository = AuditRepository(client: auditClient(adapter: adapter));
      final session = await signIn(repository);
      await openReport(tester, repository, session);
      await tester.tap(find.byKey(const ValueKey('submit_ai_content_report')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit_ai_content_report')));
      await tester.pumpAndSettle();
      expect(adapter.requests.length, 1);
      expect(find.text('Report received by BHRC.'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      gate.complete(
        AuditAdapter.jsonResponse({
          'report': {'id': 3},
        }, status: 201),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Report received by BHRC.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );

  testWidgets('retains the report and permits retry after an API failure', (
    tester,
  ) async {
    var attempts = 0;
    final adapter = AuditAdapter(
      respond: (_) async {
        attempts++;
        return attempts == 1
            ? AuditAdapter.jsonResponse({'message': 'failure'}, status: 500)
            : AuditAdapter.jsonResponse({
                'report': {'id': 4},
              }, status: 201);
      },
    );
    final repository = AuditRepository(client: auditClient(adapter: adapter));
    final session = await signIn(repository);
    await openReport(tester, repository, session);
    await tester.tap(find.byKey(const ValueKey('submit_ai_content_report')));
    await tester.pumpAndSettle();
    expect(
      find.text('The report was not sent. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Report received by BHRC.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('submit_ai_content_report')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Report received by BHRC.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });

  testWidgets('rejects submission after switching to a different patient', (
    tester,
  ) async {
    final adapter = AuditAdapter();
    final repository = AuditRepository(client: auditClient(adapter: adapter));
    final session = await signIn(repository);
    await openReport(tester, repository, session);
    repository.patient = auditPatientFor(2);
    await session.sendOtp(phone: '8887776666');
    await session.verifyOtp(otp: '123456');
    await tester.tap(find.byKey(const ValueKey('submit_ai_content_report')));
    await tester.pumpAndSettle();
    expect(adapter.requests, isEmpty);
    expect(
      find.text('Your profile changed. Close this report and try again.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
