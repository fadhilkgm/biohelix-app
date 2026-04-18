part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _LabTestDetailPage extends StatelessWidget {
  const _LabTestDetailPage({required this.test});
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
      price: 399 + (item.id % 10) * 110,
      popular: item.id % 2 == 0,
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
    final config = Provider.of<AppConfig>(context, listen: false);
    final apiBase = config.apiBaseUrl.replaceAll('/api', '');

    String resolveUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) return url;
      final cleanUrl = url.startsWith('/') ? url.substring(1) : url;
      return '$apiBase/$cleanUrl';
    }

    final imageUrl = resolveUrl(test.imageUrl);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'test_image_${test.id}',
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _LabTestImagePlaceholder(test: test),
                      )
                    : _LabTestImagePlaceholder(test: test),
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
                    value: 'Within 24 hours',
                  ),
                  _TestDetailTile(
                    icon: Icons.science_outlined,
                    title: 'Sample required',
                    value: 'Blood / Plasma',
                  ),
                  _TestDetailTile(
                    icon: Icons.no_food_outlined,
                    title: 'Patient Preparation',
                    value: 'Fasting may be required (8-10 hours)',
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
            return CustomButton(
              onPressed: test.status
                  ? () async {
                      await _openNewLabBookingFlow(context, portal);
                    }
                  : null,
              text: test.status
                  ? ' Book Now'
                  : 'Not available now',
              icon: const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white,
                size: 18,
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
