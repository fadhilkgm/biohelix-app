import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../core/models/patient_models.dart';
import '../../core/providers/patient_portal_provider.dart';
import '../../lab_booking/models/lab_booking_models.dart';
import '../../lab_booking/state/lab_booking_controller.dart';
import '../../lab_booking/screens/cart_screen.dart';

class LabTestDetailPage extends StatelessWidget {
  const LabTestDetailPage({super.key, required this.test});
  final LabTestItem test;

  BookableLabTest _toBookableTest(LabTestItem item) {
    final lower = item.testName.toLowerCase();
    final blood =
        lower.contains('cbc') ||
        lower.contains('thyroid') ||
        lower.contains('fbs');
    final urine = lower.contains('urine');
    final category = urine
        ? 'Urine'
        : (blood
              ? 'Blood'
              : (item.categoryName.toLowerCase().contains('scan')
                    ? 'Scan'
                    : 'Blood'));
    return BookableLabTest(
      id: item.id,
      name: item.testName,
      category: category,
      description:
          'Advanced ${item.testName} profile with clinically reviewed parameters and fast turnaround.',
      preparation: (item.instructions ?? '').trim().isNotEmpty
        ? item.instructions!.trim()
        : (lower.contains('fbs')
          ? 'Fasting required for 8-10 hours before sample collection.'
          : 'Stay hydrated and follow physician instructions before collection.'),
      parameters: lower.contains('cbc')
          ? const ['Hemoglobin', 'WBC', 'RBC', 'Platelets']
          : const ['Primary marker', 'Secondary marker', 'Reference range'],
      price: (item.discountedPrice ?? item.basePrice).toDouble(),
      basePrice: item.basePrice.toDouble(),
      popular: item.id % 2 == 0,
      originalItem: item,
    );
  }

  Future<void> _openNewLabBookingFlow(
    BuildContext context,
    PatientPortalProvider portal,
  ) async {
    if (portal.labTests.isEmpty) {
      await portal.refresh();
      if (!context.mounted) return;
      if (portal.labTests.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No lab tests are available right now.'),
          ),
        );
        return;
      }
    }

    final patientName = portal.dashboard?.patient.name ?? 'Patient';
    final controller = LabBookingController(
      patientName: patientName,
      tests: portal.labTests,
    );
    controller.addToCart(_toBookableTest(test));

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: controller,
          child: const CartScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF5A88F1),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'test_image_${test.id}',
                child: Consumer<AppConfig>(
                  builder: (context, config, _) {
                    final apiBase = config.apiBaseUrl.replaceAll('/api', '');
                    final path = test.imageUrl ?? '';
                    
                    String resolvedUrl = '';
                    if (path.isNotEmpty) {
                      if (path.startsWith('http')) {
                        resolvedUrl = path;
                      } else {
                        final base = apiBase.endsWith('/') 
                            ? apiBase.substring(0, apiBase.length - 1) 
                            : apiBase;
                        final normalizedPath = path.startsWith('/') ? path : '/$path';
                        resolvedUrl = '$base$normalizedPath';
                      }
                    }

                    if (resolvedUrl.isEmpty) {
                      return Image.asset(
                        'assets/images/lab.png',
                        fit: BoxFit.cover,
                      );
                    }

                    return Image.network(
                      resolvedUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: const Color(0xFFF4F7FF),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/lab.png',
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      test.categoryName.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    test.testName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _InfoSection(
                    title: 'Description',
                    content:
                        'This ${test.testName} is a diagnostic test categorized under ${test.categoryName}. It is used to evaluate various biomarkers to help detect or monitor medical conditions.',
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Test Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TestDetailTile(
                    icon: Icons.access_time_rounded,
                    title: 'Reporting Time',
                    value: test.resultEta ?? 'Within 24 hours',
                  ),
                  _TestDetailTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Test Type',
                    value: 'Standard Diagnostic',
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Consumer<PatientPortalProvider>(
          builder: (context, portal, _) {
            return ElevatedButton(
              onPressed: test.status
                  ? () async {
                      await _openNewLabBookingFlow(context, portal);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A6EAA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    test.status ? 'Book Now' : 'Not available now',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TestDetailTile extends StatelessWidget {
  const _TestDetailTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
