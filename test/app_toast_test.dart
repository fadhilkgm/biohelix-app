import 'package:biohelix_app/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app toast uses the standard floating light presentation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => AppToast.show(
                context,
                message: 'Report uploaded and ready.',
                type: AppToastType.success,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.white);
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(find.text('Report uploaded and ready.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsOneWidget);
  });
}
