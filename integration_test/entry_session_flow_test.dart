import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/core/providers/text_scale_provider.dart';
import 'package:biohelix_app/core/providers/theme_provider.dart';
import 'package:biohelix_app/core/storage/auth_storage.dart';
import 'package:biohelix_app/core/theme/app_theme.dart';
import 'package:biohelix_app/features/session/providers/session_provider.dart';
import 'package:biohelix_app/features/splash/presentation/splash_screen.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';
import 'package:biohelix_app/patient_portal/fitness/providers/fitness_provider.dart';
import 'package:biohelix_app/patient_portal/lab_booking/screens/lab_test_home_screen.dart';
import 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';
import 'package:biohelix_app/patient_portal/shell/widgets/bottom_nav_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/audit_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'current entry, OTP, portal navigation and sign-out work end to end',
    (tester) async {
      final repository = AuditRepository();
      final session = repository.session();
      await session.initialize();
      final portal = PatientPortalProvider(
        repository: repository,
        sessionProvider: session,
      );
      final language = LanguageProvider(apiClient: repository.client);
      final textScale = TextScaleProvider();
      final theme = ThemeProvider();
      final fitness = FitnessProvider(
        repository: repository,
        sessionProvider: session,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppConfig>.value(value: auditConfig),
            Provider<ApiClient>.value(value: repository.client),
            Provider<PatientRepository>.value(value: repository),
            ChangeNotifierProvider<SessionProvider>.value(value: session),
            ChangeNotifierProvider<PatientPortalProvider>.value(value: portal),
            ChangeNotifierProvider<LanguageProvider>.value(value: language),
            ChangeNotifierProvider<TextScaleProvider>.value(value: textScale),
            ChangeNotifierProvider<ThemeProvider>.value(value: theme),
            ChangeNotifierProvider<FitnessProvider>.value(value: fitness),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SplashScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('BHRC'), findsOneWidget);
      expect(find.text('BioHelix Health and Research Center'), findsOneWidget);

      await _waitFor(tester, find.text('Get Started'));
      await tester.tap(find.text('Get Started'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Login'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, '9998887777');
      await tester.ensureVisible(find.text('Send WhatsApp OTP'));
      await tester.tap(find.text('Send WhatsApp OTP'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(repository.otpRequestPhone, '+919998887777');
      expect(session.pendingPhone, '+919998887777');
      expect(find.text('ENTER OTP'), findsOneWidget);

      // Exercise the visible input, including paste and its automatic submit.
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump(const Duration(milliseconds: 600));
      await _waitFor(tester, find.byType(PatientAppShell));
      expect(session.isAuthenticated, isTrue);
      expect(await AuthStorage().readToken(), 'token-1');
      for (
        var attempt = 0;
        attempt < 30 && portal.dashboard == null;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(portal.dashboard?.patient.id, 1);

      final nav = find.byType(BottomNavBarWidget);
      for (final destination in [
        ('Health Status', 1),
        ('Records', 2),
        ('Profile', 3),
        ('Home', 0),
      ]) {
        await tester.tap(
          find.descendant(of: nav, matching: find.text(destination.$1)),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          tester.widget<BottomNavBarWidget>(nav).selectedIndex,
          destination.$2,
        );
        expect(tester.takeException(), isNull);
      }

      var shell =
          tester.state(find.byType(PatientAppShell))
              as PatientAppShellController;
      shell.openAssistant();
      await tester.pump();
      await _waitFor(tester, find.byType(ChatInputWidget));
      await tester.tap(find.byKey(const ValueKey('assistant_medical_notice')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('BHRC is not a medical device.'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pump(const Duration(milliseconds: 300));
      final composer = find.descendant(
        of: find.byType(ChatInputWidget),
        matching: find.byType(TextField),
      );
      await tester.enterText(composer, 'Private draft for the first patient');
      repository.patient = auditPatientFor(2);
      session.updatePatient(repository.patient);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      shell =
          tester.state(find.byType(PatientAppShell))
              as PatientAppShellController;
      shell.openBookings();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await _waitFor(tester, find.text('My Bookings'));
      await tester.tap(find.byTooltip('Back to Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await session.signOut();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Send WhatsApp OTP'), findsOneWidget);
      expect(find.byType(PatientAppShell), findsNothing);
      expect(portal.dashboard, isNull);
      expect(await AuthStorage().readToken(), isNull);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      portal.dispose();
      fitness.dispose();
      session.dispose();
      language.dispose();
      textScale.dispose();
      theme.dispose();
    },
  );

  testWidgets('visible lab cart and checkout finish with a booking', (
    tester,
  ) async {
    final repository = AuditRepository()
      ..labTestItems = [auditLabTest]
      ..patient = auditPatient.copyWith(address: '42 Test Road');
    final session = repository.session();
    final portal = await authenticatedAuditPortal(repository, session);
    final language = LanguageProvider(apiClient: repository.client);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppConfig>.value(value: auditConfig),
          ChangeNotifierProvider<SessionProvider>.value(value: session),
          ChangeNotifierProvider<PatientPortalProvider>.value(value: portal),
          ChangeNotifierProvider<LanguageProvider>.value(value: language),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LabTestHomeScreen(initialTestIds: [11]),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Confirm Booking'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Your Cart'), findsOneWidget);
    expect(find.text('CBC'), findsWidgets);
    await tester.tap(find.text('Proceed to Checkout'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Review Payment'), findsOneWidget);
    await tester.tap(find.text('Review Payment'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Choose Payment Method'), findsOneWidget);
    await tester.tap(find.text('Pay at Collection'));
    await tester.tap(find.text('Confirm Order'));
    await _waitFor(tester, find.text('Tests Booked!'));
    expect(repository.orderCalls, 1);
    expect(find.textContaining('LAB-1'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    portal.dispose();
    session.dispose();
    language.dispose();
  });
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(finder, findsWidgets);
}
