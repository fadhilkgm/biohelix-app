import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:biohelix_app/app.dart';

void main() {
  testWidgets('renders BioHelix starter shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {});

    await tester.pumpWidget(const BioHelixApp());
    await tester.pump();

    expect(find.text('BioHelix'), findsNWidgets(2));
    expect(find.text('Backend status'), findsOneWidget);
  });
}
