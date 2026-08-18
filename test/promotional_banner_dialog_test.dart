import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/shared/widgets/promotional_banner_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const actionableBanner = HomeBannerItem(
    id: 1,
    title: 'Package',
    subtitle: 'Health package',
    imageUrl: '',
    ctaTarget: 'packages',
    placement: 'mobile_promo_popup',
  );

  testWidgets('tapping promotion copy returns the actionable banner', (
    tester,
  ) async {
    HomeBannerItem? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<HomeBannerItem>(
                context: context,
                builder: (_) =>
                    const PromotionalBannerDialog(banner: actionableBanner),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Package'));
    await tester.pumpAndSettle();

    expect(result, same(actionableBanner));
    expect(find.byType(PromotionalBannerDialog), findsNothing);
  });

  testWidgets('banner without a destination remains non-actionable', (
    tester,
  ) async {
    const banner = HomeBannerItem(
      id: 2,
      title: 'Information only',
      imageUrl: '',
      placement: 'mobile_promo_popup',
    );

    await tester.pumpWidget(
      const MaterialApp(home: PromotionalBannerDialog(banner: banner)),
    );

    await tester.tap(find.text('Information only'));
    await tester.pump();

    expect(find.byType(PromotionalBannerDialog), findsOneWidget);
  });

  test('package target matches the CMS package code', () {
    const package = LabPackageItem(
      id: 21,
      name: 'Full Body Checkup',
      slug: 'full-body-checkup',
      packageCode: 'PKG-001',
      status: true,
      basePrice: 1499,
    );

    expect(package.matchesTarget('PKG-001'), isTrue);
    expect(package.matchesTarget('full-body-checkup'), isTrue);
    expect(package.matchesTarget('21'), isTrue);
    expect(package.matchesTarget('another-package'), isFalse);
  });
}
