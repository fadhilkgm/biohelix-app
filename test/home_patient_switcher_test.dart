import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/patient_portal/premium_home/widgets/home_hero_header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('home header exposes the patient account switch action', (
    tester,
  ) async {
    var tapped = false;
    final languageProvider = LanguageProvider(
      apiClient: ApiClient(
        config: AppConfig(
          appName: 'Test',
          apiBaseUrl: 'https://example.test/api',
          healthEndpoint: '/health',
          showDevOtp: false,
        ),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: languageProvider,
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF06489B),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: HomeHeroHeaderWidget(
                greeting: 'Good morning',
                patientName: 'Amina',
                onSwitchPatient: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('Switch'), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-switch-patient-button')));

    expect(tapped, isTrue);
  });
}
