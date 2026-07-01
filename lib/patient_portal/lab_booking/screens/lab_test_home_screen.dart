import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../core/providers/patient_portal_provider.dart';
import '../../lab_booking/design/app_colors.dart';
import '../../lab_booking/design/app_spacing.dart';
import '../../lab_booking/design/app_text_styles.dart';
import '../../lab_booking/models/lab_booking_models.dart';
import '../../lab_booking/state/lab_booking_controller.dart';
import '../../lab_booking/widgets/anatomy_map_widget.dart';
import '../../lab_booking/widgets/category_chip_widget.dart';
import '../../lab_booking/widgets/test_card_widget.dart';
import '../../labs/screens/lab_test_detail_page.dart';
import 'cart_screen.dart';
import 'test_booking_screen.dart';
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
        patientPhone: portal.dashboard?.patient.phone,
        tests: portal.labTests,
        bodyPoints: portal.bodyPoints,
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
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    return Scaffold(
      backgroundColor: AppColors.shellGradient.first,
      appBar: AppBar(
        title: Text(
          'Lab Tests',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF192233),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            color: Color(0xFF192233),
            size: 30,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${c.cartCount}'),
              isLabelVisible: c.cartCount > 0,
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: Color(0xFF192233),
              ),
            ),
            onPressed: () => _push(context, const CartScreen()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DecoratedBox(
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
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: CategoryChipWidget(
                      label: 'All',
                      selected: c.selectedBodyPoint == null,
                      onTap: () => c.setSelectedBodyPoint(null),
                    ),
                  ),
                  ...c.bodyPoints.map(
                    (bp) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: CategoryChipWidget(
                        label: bp.name,
                        selected: c.selectedBodyPoint?.id == bp.id,
                        onTap: () => c.setSelectedBodyPoint(bp),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AnatomyMapWidget(
              bodyPoints: c.bodyPoints,
              selectedBodyPoint: c.selectedBodyPoint,
              onSelect: c.setSelectedBodyPoint,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text(
                  c.selectedBodyPoint == null
                      ? 'Popular Tests'
                      : '${c.selectedBodyPoint!.name} Tests',
                  style: AppTextStyles.section(context),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _push(context, const TestListScreen()),
                  child: Text(strings.viewAll),
                ),
              ],
            ),
            if (c.popularTests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Text(
                    'No tests found for this body system.',
                    style: AppTextStyles.body(context).copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              ...c.popularTests.map(
                (t) => TestCardWidget(
                  test: t,
                  onAdd: () => _handleAddToCart(context, c, t),
                  onOpen: () {
                    if (t.originalItem != null) {
                      _push(
                        context,
                        LabTestDetailPage(
                          test: t.originalItem!,
                          controller: c,
                        ),
                      );
                    } else {
                      c.addToCart(t);
                      _push(context, const TestBookingScreen());
                    }
                  },
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildCartBottomBar(context, c),
    );
  }

  Widget? _buildCartBottomBar(BuildContext context, LabBookingController c) {
    if (c.cartCount == 0) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () => _push(context, const CartScreen()),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5A88F1),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Confirm Booking',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${c.cartCount}',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    if (!added) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1500),
        content: Text(
          '${test.name} added',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
