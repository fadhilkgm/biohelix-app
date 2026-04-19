part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _RecordsTab extends StatefulWidget {
  const _RecordsTab({super.key});

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  String _filter = 'all';

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

  Future<void> _openDocument(String documentPath) async {
    final trimmed = documentPath.trim();
    if (trimmed.isEmpty) return;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid report link.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open report.')),
      );
    }
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
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 52, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Back Button ─────────────────────────────────────
                      IconButton(
                        onPressed: () => PatientAppShell.of(context).goHome(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface,
                          foregroundColor: theme.colorScheme.onSurface,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ── Header ──────────────────────────────────────────
                      Text(
                        'Medical Records',
                        style: GoogleFonts.manrope(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${items.length} records in your vault',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                              onTap: () => setState(() => _filter = 'prescription'),
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
                      const SizedBox(height: 20),
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
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = visibleItems[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RecordsListCard(item: item, onTap: item.onTap),
                        );
                      },
                      childCount: visibleItems.length,
                    ),
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
                    ? () => _openDocument(record.documentPath!)
                : null,
          ),
        )
        .toList();

    items.sort((a, b) => b.meta.compareTo(a.meta));
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
        return const Color(0xFF16A34A);
      case 'summary':
        return const Color(0xFFF97316);
      default:
        return record.status == 'available'
            ? const Color(0xFF3B82F6)
            : const Color(0xFFF59E0B);
    }
  }

  Color _buildRecordBackground(MedicalRecordItem record) {
    switch (record.category) {
      case 'prescription':
        return const Color(0xFFEAF8EF);
      case 'summary':
        return const Color(0xFFFFF3E8);
      default:
        return record.status == 'available'
            ? const Color(0xFFE8F1FF)
            : const Color(0xFFFFF4E5);
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
    return DateFormat('yyyy-MM-dd').format(parsed);
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
    const activeColor = AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
         duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? activeColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected ? AppShadows.low() : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.low(
          dark: theme.brightness == Brightness.dark,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
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
                        style: GoogleFonts.manrope(
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
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(
                                alpha: 0.7,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.calendar_today_rounded,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.meta}   •   ${item.kindLabel}',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
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
    final isAvailable = label.toLowerCase() == 'available';
    final accentColor = isAvailable
        ? AppColors.success
        : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: accentColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
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
        boxShadow: AppShadows.low(
          dark: theme.brightness == Brightness.dark,
        ),
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
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your medical vault is empty. New reports will appear here automatically after your consultations.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
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
              child: const Text('Close'),
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
