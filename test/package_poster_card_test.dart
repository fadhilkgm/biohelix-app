import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/premium_home/screens/home_screen.dart';
import 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home package card shows its square poster without cropping', (
    tester,
  ) async {
    const package = LabPackageItem(
      id: 21,
      name: 'Executive Health Package',
      slug: 'executive-health-package',
      status: true,
      basePrice: 3200,
      discountedPrice: 2800,
      totalTests: 12,
      includedTests: ['CBC', 'Lipid Profile'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 350,
              height: 550,
              child: HomePackageCard(
                pkg: package,
                width: 350,
                margin: EdgeInsets.zero,
                onTap: _doNothing,
                resolvedImageUrl: 'https://example.test/square-poster.png',
              ),
            ),
          ),
        ),
      ),
    );

    final poster = tester.widget<Image>(
      find.byKey(const ValueKey('home-package-poster-21')),
    );
    final posterSize = tester.getSize(
      find.byKey(const ValueKey('home-package-poster-21')),
    );

    expect(poster.fit, BoxFit.contain);
    expect(posterSize.width, posterSize.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('package detail header uses the complete poster as background', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.square(
            dimension: 390,
            child: HealthPackageDetailPoster(
              packageId: 21,
              imageUrl: 'https://example.test/square-poster.png',
            ),
          ),
        ),
      ),
    );

    final posterFinder = find.byKey(const ValueKey('package-detail-poster-21'));
    final poster = tester.widget<Image>(posterFinder);
    final posterSize = tester.getSize(posterFinder);

    expect(poster.fit, BoxFit.contain);
    expect(posterSize, const Size.square(390));
    expect(tester.takeException(), isNull);
  });
}

void _doNothing() {}
