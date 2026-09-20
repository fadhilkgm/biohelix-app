import 'package:biohelix_app/core/providers/text_scale_provider.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/lab_booking/models/lab_booking_models.dart';
import 'package:biohelix_app/patient_portal/lab_booking/widgets/test_card_widget.dart';
import 'package:biohelix_app/patient_portal/premium_home/screens/home_screen.dart';
import 'package:biohelix_app/core/widgets/custom_bottom_bar.dart';
import 'package:biohelix_app/patient_portal/shell/widgets/bottom_nav_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Older patients commonly raise the system font size. Android allows up to
/// 2.0x (Settings > Display > Font size, plus Accessibility "Font size"), and
/// the app does not clamp textScaler, so every layout must survive it.
Widget _atScale(double scale, Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: child,
    ),
  );
}

void main() {
  for (final scale in [1.3, 1.6, 2.0]) {
    testWidgets('bottom navigation survives ${scale}x system font', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _atScale(
          scale,
          Scaffold(
            bottomNavigationBar: BottomNavBarWidget(
              selectedIndex: 0,
              onTap: (_) {},
              items: const [
                BottomNavItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                ),
                BottomNavItem(
                  label: 'Bookings',
                  icon: Icons.event_outlined,
                  selectedIcon: Icons.event_rounded,
                ),
                BottomNavItem(
                  label: 'Health AI',
                  icon: Icons.chat_outlined,
                  selectedIcon: Icons.chat_rounded,
                ),
                BottomNavItem(
                  label: 'Records',
                  icon: Icons.folder_outlined,
                  selectedIcon: Icons.folder_rounded,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.15, 1.3, 1.6, 2.0]) {
    testWidgets('home doctor carousel survives ${scale}x system font', (
      tester,
    ) async {
      const doctor = DoctorListing(
        id: 8,
        name: 'Muhammed Shamsudheen',
        specialization: 'Pediatrics',
        departmentName: 'Pediatrics',
        availableTime: '2:00 PM - 6:00 PM',
        consultationFee: 500,
        imageUrl: '',
      );

      await tester.pumpWidget(
        _atScale(
          scale,
          Scaffold(
            body: Builder(
              builder: (context) {
                // Mirrors how the home screen sizes the carousel, so the test
                // fails if that calculation stops tracking the text scale.
                final height =
                    HomeDoctorCard.imageHeight +
                    MediaQuery.textScalerOf(
                      context,
                    ).scale(HomeDoctorCard.detailsHeight);

                return Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 278,
                    height: height,
                    child: const HomeDoctorCard(
                      doc: doctor,
                      onTap: _doNothing,
                      resolvedImageUrl: '',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('lab test card stays within bounds as the font grows', (
    tester,
  ) async {
    const item = LabTestItem(
      id: 1,
      testName: 'Complete Blood Count',
      categoryId: 1,
      categoryName: 'Hematology',
      status: true,
      basePrice: 450,
    );

    for (final scale in [1.0, 1.15, 1.3, 1.6, 2.0]) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _atScale(
          scale,
          Scaffold(
            body: SingleChildScrollView(
              child: TestCardWidget(
                test: BookableLabTest.fromLabTest(item),
                onAdd: _doNothing,
                onOpen: _doNothing,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'overflowed at ${scale}x');
    }
  });

  testWidgets(
    'in-app text scale is combined with the system scale and capped',
    (tester) async {
      SharedPreferences.setMockInitialValues({'app_text_scale': 'larger'});
      final provider = TextScaleProvider();
      await provider.initialize();
      expect(provider.scale, AppTextScale.larger);

      // 1.0 system x 1.3 in-app.
      expect(provider.resolve(const TextScaler.linear(1.0)).scale(10), 13);

      // Already-large system setting must not compound past the cap.
      expect(
        provider.resolve(const TextScaler.linear(2.0)).scale(10),
        TextScaleProvider.maxCombinedScale * 10,
      );
    },
  );
}

void _doNothing() {}
