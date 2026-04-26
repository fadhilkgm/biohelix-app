import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/patient_portal_provider.dart';
import '../../lab_booking/design/app_colors.dart';
import '../../lab_booking/design/app_spacing.dart';
import '../../lab_booking/design/app_text_styles.dart';
import '../../lab_booking/models/lab_booking_models.dart';
import '../../lab_booking/state/lab_booking_controller.dart';
import '../../lab_booking/widgets/category_chip_widget.dart';
import '../../lab_booking/widgets/test_card_widget.dart';
import 'cart_screen.dart';
import 'test_detail_screen.dart';
import 'test_list_screen.dart';

class LabTestHomeScreen extends StatelessWidget {
  const LabTestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final portal = context.watch<PatientPortalProvider>();
    final patientName = portal.dashboard?.patient.name ?? 'Patient';
    return ChangeNotifierProvider(
      create: (_) => LabBookingController(
        patientName: patientName,
        tests: portal.labTests,
      ),
      child: const _LabHomeContent(),
    );
  }
}

class _LabHomeContent extends StatelessWidget {
  const _LabHomeContent();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LabBookingController>();
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.shellGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _banner(context),
            const SizedBox(height: AppSpacing.md),
            TextField(
              onChanged: c.setQuery,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search tests, profiles, biomarkers',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: c.categories
                    .map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: CategoryChipWidget(
                          label: cat,
                          selected: c.category == cat,
                          onTap: () => c.setCategory(cat),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text('Popular Tests', style: AppTextStyles.section(context)),
                const Spacer(),
                TextButton(
                  onPressed: () => _push(context, const TestListScreen()),
                  child: const Text('View all'),
                ),
              ],
            ),
            ...c.popularTests.map(
              (t) => TestCardWidget(
                test: t,
                onAdd: () => _handleAddToCart(context, c, t),
                onOpen: () => _push(context, TestDetailScreen(test: t)),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _banner(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF5A88F1), Color(0xFF3F6ED1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -10,
            child: Opacity(
              opacity: 0.2,
              child: Image.asset(
                'assets/images/lab.png',
                width: 180,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book Lab Tests',
                        style: AppTextStyles.title(context).copyWith(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Same-day slots, verified labs,\nhome sample collection.',
                        style: AppTextStyles.body(context).copyWith(
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => _push(context, const CartScreen()),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF5A88F1),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('View Cart', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                Image.asset(
                  'assets/images/lab.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget child) {
    final c = context.read<LabBookingController>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(value: c, child: child),
      ),
    );
  }

  void _handleAddToCart(
    BuildContext context,
    LabBookingController controller,
    BookableLabTest test,
  ) {
    final added = controller.addToCart(test);
    final message = added
        ? 'Added to cart'
        : 'This test is already in your cart';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
