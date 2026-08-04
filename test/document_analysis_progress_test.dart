import 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('document processing shows one simple AI analysis message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DocumentAnalysisProgressCard())),
    );

    expect(find.text('AI analysing…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('masking', findRichText: true), findsNothing);
    expect(find.textContaining('summary', findRichText: true), findsNothing);
  });
}
