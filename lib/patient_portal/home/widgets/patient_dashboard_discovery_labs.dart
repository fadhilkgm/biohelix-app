part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _HomeLabTestsPreviewSection extends StatelessWidget {
  const _HomeLabTestsPreviewSection({
    required this.labTests,
    required this.onViewAll,
  });

  final List<LabTestItem> labTests;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeSectionHeader(
          title: 'Popular Lab Tests',
          subtitle: 'Accurate results from certified labs',
          onViewAll: onViewAll,
        ),
        const SizedBox(height: 16),
        if (labTests.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                'No lab tests are configured yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: labTests.length,
              clipBehavior: Clip.none,
              itemExtent: 280,
              itemBuilder: (context, index) {
                final test = labTests[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _LabTestCard(test: test),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _LabTestCard extends StatelessWidget {
  const _LabTestCard({required this.test});
  final LabTestItem test;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final config = Provider.of<AppConfig>(context, listen: false);
    final apiBase = config.apiBaseUrl.replaceAll('/api', '');

    String resolveUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) return url;
      final cleanUrl = url.startsWith('/') ? url.substring(1) : url;
      return '$apiBase/$cleanUrl';
    }

    final imageUrl = resolveUrl(test.imageUrl);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LabTestDetailPage(test: test),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'test_image_${test.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 96,
                  height: 96,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _LabTestImagePlaceholder(test: test),
                        )
                      : _LabTestImagePlaceholder(test: test),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      test.categoryName.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    test.testName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '24h Result',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'VIEW',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabTestImagePlaceholder extends StatelessWidget {
  const _LabTestImagePlaceholder({required this.test});
  final LabTestItem test;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.secondaryContainer.withOpacity(0.6),
            theme.colorScheme.tertiaryContainer.withOpacity(0.4),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.biotech_rounded,
              size: 32,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TEST',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSecondaryContainer.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
