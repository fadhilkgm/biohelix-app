part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _TestsTab extends StatefulWidget {
  const _TestsTab();

  @override
  State<_TestsTab> createState() => _TestsTabState();
}

class _TestsTabState extends State<_TestsTab> {
  String _activeView = 'discovery'; // 'discovery' or 'results'
  String _selectedOrgan = 'Heart';
  String _filter = 'all';

  final List<Map<String, dynamic>> _hotspots = [
    {'key': 'brain', 'organ': 'Brain', 'x': 50.0, 'y': 10.0},
    {'key': 'thyroid', 'organ': 'Thyroid', 'x': 50.0, 'y': 20.0},
    {'key': 'lungs', 'organ': 'Lungs', 'x': 42.0, 'y': 30.0},
    {'key': 'heart', 'organ': 'Heart', 'x': 54.0, 'y': 32.0},
    {'key': 'liver', 'organ': 'Liver', 'x': 42.0, 'y': 40.0},
    {'key': 'stomach', 'organ': 'Stomach', 'x': 54.0, 'y': 42.0},
    {'key': 'kidneys', 'organ': 'Kidneys', 'x': 60.0, 'y': 44.0},
    {'key': 'pancreas', 'organ': 'Pancreas', 'x': 50.0, 'y': 44.0},
    {'key': 'intestine', 'organ': 'Intestine', 'x': 50.0, 'y': 52.0},
    {'key': 'spine', 'organ': 'Spine', 'x': 50.0, 'y': 36.0},
    {'key': 'bones', 'organ': 'Bones', 'x': 35.0, 'y': 60.0},
    {'key': 'urine', 'organ': 'Urine', 'x': 50.0, 'y': 58.0},
    {'key': 'blood', 'organ': 'Blood', 'x': 62.0, 'y': 32.0},
    {'key': 'cancer', 'organ': 'Tumor/Cancer', 'x': 46.0, 'y': 38.0},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 52,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ViewToggle(
                    label: 'Find Tests',
                    icon: Icons.search_rounded,
                    selected: _activeView == 'discovery',
                    onTap: () => setState(() => _activeView = 'discovery'),
                  ),
                ),
                Expanded(
                  child: _ViewToggle(
                    label: 'Results',
                    icon: Icons.assignment_outlined,
                    selected: _activeView == 'results',
                    onTap: () => setState(() => _activeView = 'results'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _activeView == 'discovery'
                ? _buildDiscoveryView(context)
                : _buildResultsView(context),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryView(BuildContext context) {
    final theme = Theme.of(context);
    final config = Provider.of<AppConfig>(context, listen: false);
    final apiBase = config.apiBaseUrl.replaceAll('/api', '');

    String resolveUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) return url;
      final cleanUrl = url.startsWith('/') ? url.substring(1) : url;
      return '$apiBase/$cleanUrl';
    }

    return Consumer<PatientPortalProvider>(
      builder: (context, portal, _) {
        final filteredTests = portal.labTests.where((test) {
          final name = test.testName.toLowerCase();
          final category = test.categoryName.toLowerCase();
          final organ = _selectedOrgan.toLowerCase();

          // Rough mapping logic as we don't have explicit organ mapping in metadata
          if (organ == 'heart' &&
              (name.contains('lipid') ||
                  name.contains('troponin') ||
                  name.contains('heart'))) {
            return true;
          }
          if (organ == 'liver' &&
              (name.contains('lft') ||
                  name.contains('liver') ||
                  name.contains('bilirubin'))) {
            return true;
          }
          if (organ == 'kidneys' &&
              (name.contains('kft') ||
                  name.contains('kidney') ||
                  name.contains('creatinine'))) {
            return true;
          }
          if (organ == 'thyroid' &&
              (name.contains('thyroid') ||
                  name.contains('tsh') ||
                  name.contains('t3') ||
                  name.contains('t4'))) {
            return true;
          }
          if (organ == 'blood' &&
              (name.contains('cbc') ||
                  name.contains('blood') ||
                  name.contains('hemoglobin'))) {
            return true;
          }
          if (organ == 'urine' &&
              (name.contains('urine') || name.contains('urinalysis'))) {
            return true;
          }
          if (organ == 'stomach' &&
              (name.contains('pylori') || name.contains('gastrin'))) {
            return true;
          }
          if (organ == 'lungs' &&
              (name.contains('pft') ||
                  name.contains('lung') ||
                  name.contains('chest'))) {
            return true;
          }
          if (organ == 'pancreas' &&
              (name.contains('amylase') ||
                  name.contains('lipase') ||
                  name.contains('sugar') ||
                  name.contains('insulin'))) {
            return true;
          }
          if (organ == 'brain' &&
              (name.contains('brain') || name.contains('neuro'))) {
            return true;
          }
          if (organ == 'spine' &&
              (name.contains('spine') || name.contains('back'))) {
            return true;
          }
          if (organ == 'bones' &&
              (name.contains('bone') ||
                  name.contains('calcium') ||
                  name.contains('vitamin d'))) {
            return true;
          }
          if (organ == 'tumor/cancer' &&
              (name.contains('cancer') ||
                  name.contains('cea') ||
                  name.contains('psa') ||
                  name.contains('afp'))) {
            return true;
          }

          return category.contains(organ) || name.contains(organ);
        }).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find tests by body area',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select an organ to see suitable diagnostic tests.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const _BannerPackageLandingPage(
                              packageTarget: null,
                              isSpecific: false,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('View health packages'),
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            [
                                  'Brain',
                                  'Heart',
                                  'Lungs',
                                  'Liver',
                                  'Kidneys',
                                  'Stomach',
                                  'Thyroid',
                                  'Blood',
                                  'Urine',
                                  'Pancreas',
                                  'Intestine',
                                  'Spine',
                                  'Bones',
                                  'Tumor/Cancer',
                                ]
                                .map(
                                  (o) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(o),
                                      selected: _selectedOrgan == o,
                                      onSelected: (val) =>
                                          setState(() => _selectedOrgan = o),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 300,
                        height: 400,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withOpacity(
                              0.5,
                            ),
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Since we can't bundle images easily here, we use a simple visual placeholder
                            // or wait for the system to provide the image.
                            // For now, let's use a network image if available or just draw the points.
                            Center(
                              child: Image.asset(
                                'assets/images/body-organ-map.png',
                                width: 300,
                                height: 400,
                                fit: BoxFit.contain,
                              ),
                            ),
                            ..._hotspots.map((h) {
                              final isActive = _selectedOrgan == h['organ'];
                              return Positioned(
                                left: h['x'] * 3.0 - 10,
                                top: h['y'] * 4.0 - 10,
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _selectedOrgan = h['organ'],
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isActive
                                          ? Colors.green
                                          : Colors.redAccent.withOpacity(0.8),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        if (isActive)
                                          BoxShadow(
                                            color: Colors.green.withOpacity(
                                              0.4,
                                            ),
                                            blurRadius: 10,
                                            spreadRadius: 4,
                                          ),
                                      ],
                                    ),
                                    child: Icon(
                                      isActive ? Icons.check : Icons.circle,
                                      size: isActive ? 12 : 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recommended for $_selectedOrgan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (filteredTests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No specific tests found for this area yet.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else
              ...filteredTests.map(
                (test) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: () {
                      final imageUrl = resolveUrl(test.imageUrl);
                      if (imageUrl.isEmpty) {
                        return CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.science_outlined,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        );
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          imageUrl,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.science_outlined,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    }(),
                    title: Text(
                      test.testName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      test.categoryName,
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LabTestDetailPage(test: test),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildResultsView(BuildContext context) {
    return Consumer<PatientPortalProvider>(
      builder: (context, portal, _) {
        final prescriptions = portal.prescriptions;
        final documents = portal.documents;
        final summaries = portal.summaries;
        final theme = Theme.of(context);

        final items = <Widget>[];
        if (_filter == 'all' || _filter == 'documents') {
          items.addAll(
            documents.map(
              (document) => _DocumentRecordCard(
                document: document,
                isAnalyzing: portal.analyzingDocumentId == document.id,
                onOpen: () => _openDocumentDetail(context, document: document),
                onAnalyze: document.hasAnalysis
                    ? null
                    : () => _analyzeDocument(context, portal, document),
              ),
            ),
          );
        }
        if (_filter == 'all' || _filter == 'prescriptions') {
          items.addAll(
            prescriptions.map(
              (prescription) => _RecordCard(
                icon: Icons.medication_outlined,
                title: prescription.diagnosis ?? 'Prescription',
                subtitle:
                    '${prescription.doctorName} • ${prescription.medicines.length} medicines',
                meta: prescription.date,
                badge: prescription.followUpDate == null
                    ? 'Active'
                    : 'Follow-up',
                accentColor: const Color(0xFF1E8E5A),
              ),
            ),
          );
        }
        if (_filter == 'all' || _filter == 'summaries') {
          items.addAll(
            summaries.map(
              (summary) => _RecordCard(
                icon: Icons.summarize_outlined,
                title: summary.type,
                subtitle: summary.summary,
                meta: summary.date,
                badge: 'Summary',
                accentColor: const Color(0xFF0F766E),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Medical Records',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Keep your reports and prescriptions organized.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.folder_copy_outlined,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            icon: Icons.apps_rounded,
                            count: items.length,
                            selected: _filter == 'all',
                            onTap: () => setState(() => _filter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Docs',
                            icon: Icons.description_outlined,
                            count: documents.length,
                            selected: _filter == 'documents',
                            onTap: () => setState(() => _filter = 'documents'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Rx',
                            icon: Icons.medication_outlined,
                            count: prescriptions.length,
                            selected: _filter == 'prescriptions',
                            onTap: () =>
                                setState(() => _filter = 'prescriptions'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No records found.'),
                ),
              )
            else
              ...items,
          ],
        );
      },
    );
  }

  Future<void> _analyzeDocument(
    BuildContext context,
    PatientPortalProvider portal,
    DocumentRecord document,
  ) async {
    try {
      await portal.analyzeDocument(document.id);
      if (!context.mounted) return;
      final result = portal.lastAnalysisResult;
      if (result != null) {
        _showAnalysisSheet(
          context,
          title: document.documentType.toUpperCase(),
          summary: result.summary,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showAnalysisSheet(
    BuildContext context, {
    required String title,
    required String summary,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(summary),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocumentDetail(
    BuildContext context, {
    required DocumentRecord document,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _DocumentDetailSheet(document: document),
    );
  }
}
