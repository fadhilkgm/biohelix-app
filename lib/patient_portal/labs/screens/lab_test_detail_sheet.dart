import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../core/models/patient_models.dart';
import '../../core/providers/patient_portal_provider.dart';
import '../../lab_booking/models/lab_booking_models.dart';
import '../../lab_booking/state/lab_booking_controller.dart';
import '../../lab_booking/screens/test_booking_screen.dart';

/// Quick-look sheet for a single lab test.
///
/// The catalogue only carries a name, code, price and status per test, so a
/// full screen would be mostly empty. This sheet shows what is known and gets
/// the patient straight to booking, and grows automatically if the hospital
/// later fills in a description or category.
class LabTestDetailSheet extends StatelessWidget {
  const LabTestDetailSheet._({required this.test, this.controller});

  final LabTestItem test;
  final LabBookingController? controller;

  static const _brand = Color(0xFF06489B);

  static Future<void> show(
    BuildContext context, {
    required LabTestItem test,
    LabBookingController? controller,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => LabTestDetailSheet._(test: test, controller: controller),
    );
  }

  Future<void> _book(BuildContext sheetContext) async {
    final navigator = Navigator.of(sheetContext);
    final portal = sheetContext.read<PatientPortalProvider>();
    final messenger = ScaffoldMessenger.of(sheetContext);
    final strings = AppStrings.of(
      sheetContext.read<LanguageProvider>().language,
    );

    if (portal.labTests.isEmpty) {
      await portal.refresh();
      if (portal.labTests.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(strings.noLabTestsAvailable)),
        );
        return;
      }
    }

    final patient = portal.dashboard?.patient;
    final targetController =
        controller ??
        LabBookingController(
          patientName: patient?.name ?? 'Patient',
          patientPhone: patient?.phone,
          patientAge: patient?.age,
          patientGender: patient?.gender,
          patientAddress: patient?.address,
          tests: portal.labTests,
          bodyPoints: portal.bodyPoints,
        );
    targetController.addToCart(BookableLabTest.fromLabTest(test));

    // Close the sheet before pushing so the booking flow owns the screen.
    navigator.pop();
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: targetController,
          child: const TestBookingScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = test.discountedPrice ?? test.basePrice;
    final isDiscounted =
        test.discountedPrice != null && test.discountedPrice! < test.basePrice;
    final category = test.categoryName.trim();
    final description = (test.instructions ?? '').trim();
    final resultEta = (test.resultEta ?? '').trim();
    final areas = test.bodyPoints
        .map((point) => point.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (category.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _brand,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              test.testName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${price.toStringAsFixed(0)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: _brand,
                  ),
                ),
                if (isDiscounted) ...[
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '₹${test.basePrice.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
            if (resultEta.isNotEmpty || areas.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (resultEta.isNotEmpty)
                    _InfoChip(
                      icon: Icons.access_time_rounded,
                      label: resultEta,
                    ),
                  ...areas.map(
                    (area) =>
                        _InfoChip(icon: Icons.biotech_outlined, label: area),
                  ),
                ],
              ),
            ],
            if (!test.status) ...[
              const SizedBox(height: 14),
              Text(
                'This test is not available for booking right now. '
                'Please contact the hospital for assistance.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: test.status ? () => _book(context) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: Text(
                  test.status
                      ? 'Book now · ₹${price.toStringAsFixed(0)}'
                      : 'Not available',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
