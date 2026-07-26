part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _RecordsTab extends StatefulWidget {
  const _RecordsTab({super.key});

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  String _filter = 'all';

  Future<void> _addDocument(PatientPortalProvider portal) async {
    final reportType = await showModalBottomSheet<_PatientReportType>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _ReportTypeSheet(),
    );
    if (reportType == null || !mounted) return;

    final source = await showModalBottomSheet<_MedicalRecordUploadSource>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _MedicalRecordSourceSheet(),
    );
    if (source == null || !mounted) return;

    final files = <({String path, String name})>[];
    if (source == _MedicalRecordUploadSource.gallery) {
      final photos = await ImagePicker().pickMultiImage(imageQuality: 92);
      files.addAll(photos.map((photo) => (path: photo.path, name: photo.name)));
    } else {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        allowMultiple: true,
        withData: false,
      );
      if (picked != null) {
        files.addAll(
          picked.files
              .where(
                (file) => file.path != null && file.path!.trim().isNotEmpty,
              )
              .map((file) => (path: file.path!, name: file.name)),
        );
      }
    }
    if (files.isEmpty || !mounted) return;

    try {
      for (final file in files) {
        await portal.uploadDocument(
          file.path,
          fileName: file.name,
          documentType: reportType.value,
        );
      }
      if (!mounted) return;
      final itemLabel = files.length == 1 ? reportType.label : 'records';
      _showSuccessBanner(
        files.length == 1
            ? '$itemLabel added successfully.'
            : '${files.length} $itemLabel added successfully.',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _showSuccessBanner(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF14845D),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Close',
          textColor: Colors.white,
          onPressed: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }

  void setFilter(String filter) {
    if (!mounted) return;
    setState(() {
      _filter = filter;
    });
  }

  Future<void> _openPrescriptionDetail({required MedicalRecordItem record}) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _PrescriptionDetailSheet(record: record),
    );
  }

  Future<void> _openRecordDetail({required MedicalRecordItem record}) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _RecordDetailSheet(record: record),
    );
  }

  Future<void> _openDocument({
    required String title,
    required String documentPath,
  }) async {
    final trimmed = documentPath.trim();
    if (trimmed.isEmpty) return;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(
              context.read<LanguageProvider>().language,
            ).invalidReportLink,
          ),
        ),
      );
      return;
    }

    await InAppDocumentViewer.open(
      context,
      title: title,
      url: uri.toString(),
      authToken: context.read<SessionProvider>().authToken,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientPortalProvider>(
      builder: (context, portal, _) {
        final items = _buildItems(portal.medicalRecords);
        final visibleItems = _applyFilter(items);
        final theme = Theme.of(context);

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.of(context).padding.top + 14,
                    16,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Back Button ─────────────────────────────────────
                      AppChevronBackButton(
                        onPressed: () => PatientAppShell.of(context).goHome(),
                        tooltip: 'Back to Home',
                      ),
                      const SizedBox(height: 16),
                      // ── Header ──────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Medical Records',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: portal.isUploadingDocument
                                ? null
                                : () => _addDocument(portal),
                            icon: portal.isUploadingDocument
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_rounded),
                            label: Text(
                              portal.isUploadingDocument ? 'Adding…' : 'Add',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${items.length} records in your vault',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // ── Filter chips ─────────────────────────────────────
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: [
                            _RecordsFilterChip(
                              label: 'All',
                              icon: Icons.apps_rounded,
                              selected: _filter == 'all',
                              onTap: () => setState(() => _filter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _RecordsFilterChip(
                              label: 'Lab Reports',
                              icon: Icons.science_rounded,
                              selected: _filter == 'lab',
                              onTap: () => setState(() => _filter = 'lab'),
                            ),
                            const SizedBox(width: 8),
                            _RecordsFilterChip(
                              label: 'Prescriptions',
                              icon: Icons.medication_rounded,
                              selected: _filter == 'prescription',
                              onTap: () =>
                                  setState(() => _filter = 'prescription'),
                            ),
                            const SizedBox(width: 8),
                            _RecordsFilterChip(
                              label: 'Summaries',
                              icon: Icons.description_rounded,
                              selected: _filter == 'summary',
                              onTap: () => setState(() => _filter = 'summary'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
              if (visibleItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _RecordsEmptyState(activeFilter: _filter),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = visibleItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecordsListCard(item: item, onTap: item.onTap),
                      );
                    }, childCount: visibleItems.length),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<_RecordsTabItem> _applyFilter(List<_RecordsTabItem> items) {
    if (_filter == 'all') return items;
    return items.where((item) => item.category == _filter).toList();
  }

  List<_RecordsTabItem> _buildItems(List<MedicalRecordItem> records) {
    final items = records
        .map(
          (record) => _RecordsTabItem(
            category: _mapRecordCategory(record),
            title: record.title.trim().isEmpty
                ? 'Medical Record'
                : record.title,
            subtitle: _buildRecordSubtitle(record),
            meta: _formatDate(record.date),
            kindLabel: record.kindLabel,
            statusLabel: _buildStatusLabel(record.status),
            accentColor: _buildRecordAccent(record),
            backgroundColor: _buildRecordBackground(record),
            icon: _buildRecordIcon(record),
            onTap: record.category == 'prescription'
                ? () => _openPrescriptionDetail(record: record)
                : (record.documentPath ?? '').trim().isNotEmpty
                ? () => _openDocument(
                    title: record.title,
                    documentPath: record.documentPath!,
                  )
                : (record.summary ?? '').trim().isNotEmpty
                ? () => _openRecordDetail(record: record)
                : null,
          ),
        )
        .toList();

    // Records arrive already sorted by date (newest first) from the API.
    return items;
  }

  String _mapRecordCategory(MedicalRecordItem record) {
    if (record.category == 'prescription') return 'prescription';
    if (record.category == 'summary') return 'summary';
    return 'lab';
  }

  String _buildRecordSubtitle(MedicalRecordItem record) {
    final subtitle = record.subtitle.trim();
    if (subtitle.isNotEmpty) return _trimSummary(subtitle);
    if ((record.doctorName ?? '').trim().isNotEmpty) {
      return record.doctorName!.trim();
    }
    return record.kindLabel;
  }

  String _buildStatusLabel(String rawStatus) {
    return _toTitleCase(rawStatus);
  }

  Color _buildRecordAccent(MedicalRecordItem record) {
    switch (record.category) {
      case 'prescription':
        return const Color(0xFF0D9488); // Teal
      case 'summary':
        return const Color(0xFFEA580C); // Orange/Amber
      default:
        return record.status == 'available'
            ? const Color(0xFF2563EB) // Blue
            : const Color(0xFF8B5CF6); // Violet
    }
  }

  Color _buildRecordBackground(MedicalRecordItem record) {
    switch (record.category) {
      case 'prescription':
        return const Color(0xFFF0FDFA);
      case 'summary':
        return const Color(0xFFFFF7ED);
      default:
        return record.status == 'available'
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFF5F3FF);
    }
  }

  IconData _buildRecordIcon(MedicalRecordItem record) {
    final type = '${record.recordType} ${record.kindLabel}'.toLowerCase();
    if (record.category == 'prescription') return Icons.medication_rounded;
    if (type.contains('scan') ||
        type.contains('x-ray') ||
        type.contains('mri')) {
      return Icons.center_focus_strong_rounded;
    }
    if (record.category == 'summary') {
      return Icons.description_rounded;
    }
    return Icons.science_rounded;
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM, yyyy').format(parsed);
  }

  String _trimSummary(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 44) return compact;
    return '${compact.substring(0, 41)}...';
  }

  String _toTitleCase(String input) {
    return input
        .split(RegExp(r'[\s_-]+'))
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) =>
              '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

enum _MedicalRecordUploadSource { gallery, files }

class _MedicalRecordSourceSheet extends StatelessWidget {
  const _MedicalRecordSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add medical record',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose photos from your gallery or select documents from Files.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE8F1FC),
              foregroundColor: Color(0xFF06489B),
              child: Icon(Icons.photo_library_outlined),
            ),
            title: const Text(
              'Choose from Gallery',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Select one or multiple photos'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () =>
                Navigator.of(context).pop(_MedicalRecordUploadSource.gallery),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE8F1FC),
              foregroundColor: Color(0xFF06489B),
              child: Icon(Icons.folder_open_outlined),
            ),
            title: const Text(
              'Choose from Files',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('PDF, JPG, PNG or WebP'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () =>
                Navigator.of(context).pop(_MedicalRecordUploadSource.files),
          ),
        ],
      ),
    );
  }
}

class _PatientReportType {
  const _PatientReportType({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String value;
  final String label;
  final String description;
  final IconData icon;
}

class _ReportTypeSheet extends StatelessWidget {
  const _ReportTypeSheet();

  static const _types = <_PatientReportType>[
    _PatientReportType(
      value: 'lab_report',
      label: 'Lab test report',
      description: 'Blood tests, urine tests, pathology, or other lab results',
      icon: Icons.science_rounded,
    ),
    _PatientReportType(
      value: 'prescription',
      label: 'Prescription',
      description: 'A doctor’s prescription or medicine list',
      icon: Icons.medication_rounded,
    ),
    _PatientReportType(
      value: 'radiology_report',
      label: 'Scan or radiology report',
      description: 'X-ray, ultrasound, CT, MRI, or imaging report',
      icon: Icons.center_focus_strong_rounded,
    ),
    _PatientReportType(
      value: 'discharge_summary',
      label: 'Discharge summary',
      description: 'Hospital discharge notes and follow-up instructions',
      icon: Icons.assignment_turned_in_rounded,
    ),
    _PatientReportType(
      value: 'other',
      label: 'Other medical document',
      description: 'Any medical document that does not match the types above',
      icon: Icons.description_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'What type of report is this?',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose the type yourself so we can organize your document correctly.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ..._types.map(
            (type) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => Navigator.of(context).pop(type),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Icon(type.icon),
                ),
                title: Text(
                  type.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(type.description),
                trailing: const Icon(Icons.chevron_right_rounded),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsTabItem {
  const _RecordsTabItem({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.kindLabel,
    required this.statusLabel,
    required this.accentColor,
    required this.backgroundColor,
    required this.icon,
    this.onTap,
  });

  final String category;
  final String title;
  final String subtitle;
  final String meta;
  final String kindLabel;
  final String statusLabel;
  final Color accentColor;
  final Color backgroundColor;
  final IconData icon;
  final VoidCallback? onTap;
}

class _RecordsFilterChip extends StatelessWidget {
  const _RecordsFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const activeColor = Color(0xFF06489B);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? activeColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordsListCard extends StatelessWidget {
  const _RecordsListCard({required this.item, this.onTap});

  final _RecordsTabItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.low(dark: theme.brightness == Brightness.dark),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: item.accentColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.event_note_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.meta,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _RecordsAvailabilityBadge(label: item.statusLabel),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => item.onTap?.call(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF06489B,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'View Details',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF06489B),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: Color(0xFF06489B),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordsAvailabilityBadge extends StatelessWidget {
  const _RecordsAvailabilityBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final status = label.toLowerCase();
    final isAvailable = status == 'available';
    final isPending = status == 'pending' || status == 'processing';

    final Color accentColor = isAvailable
        ? const Color(0xFF10B981)
        : isPending
        ? const Color(0xFF6366F1)
        : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              color: accentColor,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsEmptyState extends StatelessWidget {
  const _RecordsEmptyState({required this.activeFilter});

  final String activeFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (activeFilter) {
      'lab' => 'lab reports',
      'prescription' => 'prescriptions',
      'summary' => 'summaries',
      _ => 'records',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.low(dark: theme.brightness == Brightness.dark),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No $label yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your medical vault is empty. New reports will appear here automatically after your consultations.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrescriptionDetailSheet extends StatelessWidget {
  const _PrescriptionDetailSheet({required this.record});

  final MedicalRecordItem record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medicines = record.medicines;
    final details = <String>[
      if ((record.doctorName ?? '').trim().isNotEmpty)
        'Doctor: ${record.doctorName!.trim()}',
      if (record.time != null && record.time!.trim().isNotEmpty)
        'Time: ${record.time!.trim()}',
      'Status: ${_toTitleCaseValue(record.status)}',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8EF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: Color(0xFF16A34A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title.trim().isEmpty
                          ? 'Prescription'
                          : record.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatSheetDate(record.date),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SheetInfoCard(lines: details),
          ],
          const SizedBox(height: 18),
          Text(
            'Medicines',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          if (medicines.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'No medicine lines were attached to this prescription.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            ...medicines.map(
              (medicine) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PrescriptionMedicineCard(medicine: medicine),
              ),
            ),
          if ((record.summary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Doctor Notes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                record.summary!.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF334155),
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF123A87),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                AppStrings.of(context.read<LanguageProvider>().language).close,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetInfoCard extends StatelessWidget {
  const _SheetInfoCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  line,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PrescriptionMedicineCard extends StatelessWidget {
  const _PrescriptionMedicineCard({required this.medicine});

  final MedicineItem medicine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <String>[
      if ((medicine.dosage ?? '').trim().isNotEmpty)
        'Dosage: ${medicine.dosage!.trim()}',
      if ((medicine.frequency ?? '').trim().isNotEmpty)
        'Frequency: ${medicine.frequency!.trim()}',
      if ((medicine.duration ?? '').trim().isNotEmpty)
        'Duration: ${medicine.duration!.trim()}',
      if ((medicine.instructions ?? '').trim().isNotEmpty)
        'Instructions: ${medicine.instructions!.trim()}',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            medicine.medicineName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...details.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordDetailSheet extends StatelessWidget {
  const _RecordDetailSheet({required this.record});

  final MedicalRecordItem record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSummary = record.category == 'summary';
    final accent = isSummary
        ? const Color(0xFFEA580C)
        : const Color(0xFF2563EB);
    final background = isSummary
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFEFF6FF);
    final icon = isSummary ? Icons.description_rounded : Icons.science_rounded;

    final details = <String>[
      if ((record.doctorName ?? '').trim().isNotEmpty)
        'Doctor: ${record.doctorName!.trim()}',
      if (record.time != null && record.time!.trim().isNotEmpty)
        'Time: ${record.time!.trim()}',
      'Type: ${record.kindLabel}',
      'Status: ${_toTitleCaseValue(record.status)}',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title.trim().isEmpty
                          ? record.recordType
                          : record.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatSheetDate(record.date),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SheetInfoCard(lines: details),
          if ((record.summary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              isSummary ? 'Summary' : 'Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                record.summary!.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF334155),
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF123A87),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                AppStrings.of(context.read<LanguageProvider>().language).close,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSheetDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat('dd MMM yyyy').format(parsed);
}

String _toTitleCaseValue(String input) {
  return input
      .split(RegExp(r'[\s_-]+'))
      .where((segment) => segment.isNotEmpty)
      .map(
        (segment) =>
            '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
      )
      .join(' ');
}
