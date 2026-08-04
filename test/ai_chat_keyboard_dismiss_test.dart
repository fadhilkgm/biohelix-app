import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('swiping down on the AI composer hides the keyboard', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final apiClient = ApiClient(
      config: AppConfig(
        appName: 'BioHelix Test',
        apiBaseUrl: 'https://example.test/api',
        healthEndpoint: '/health',
        showDevOtp: true,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(apiClient: apiClient),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatInputWidget(
                controller: controller,
                isBusy: false,
                isListening: false,
                isLiveMode: false,
                onAttach: _doNothing,
                onLiveTap: _doNothing,
                onVoiceTap: _doNothing,
                onSend: _doNothing,
              ),
            ),
          ),
        ),
      ),
    );

    final input = find.byType(TextField);
    await tester.tap(input);
    await tester.pump();
    expect(tester.widget<TextField>(input).focusNode?.hasFocus, isTrue);

    await tester.drag(input, const Offset(0, 80));
    await tester.pump();

    expect(tester.widget<TextField>(input).focusNode?.hasFocus, isFalse);
  });
}

void _doNothing() {}
