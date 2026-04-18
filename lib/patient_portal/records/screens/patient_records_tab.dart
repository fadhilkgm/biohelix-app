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

        return Container(
          color: const Color(0xFFF5F7FB),
          child: SafeArea(
            bottom: false,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
              children: [
                Text(
                  'Medical Records',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${items.length} records',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _RecordsFilterChip(
                        label: 'All',
                        icon: Icons.apps_rounded,
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _RecordsFilterChip(
                        label: 'Lab Report',
                        icon: Icons.science_outlined,
                        selected: _filter == 'lab',
                        onTap: () => setState(() => _filter = 'lab'),
                      ),
                      const SizedBox(width: 8),
                      _RecordsFilterChip(
                        label: 'Prescription',
                        icon: Icons.medication_outlined,
                        selected: _filter == 'prescription',
                        onTap: () => setState(() => _filter = 'prescription'),
                      ),
                      const SizedBox(width: 8),
                      _RecordsFilterChip(
                        label: 'Discharge Summary',
                        icon: Icons.description_outlined,
                        selected: _filter == 'summary',
                        onTap: () => setState(() => _filter = 'summary'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (visibleItems.isEmpty)
                  _RecordsEmptyState(activeFilter: _filter)
                else
                  ...visibleItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecordsListCard(item: item, onTap: item.onTap),
                    ),
                  ),
              ],
            ),
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
    final foreground = selected ? Colors.white : const Color(0xFF475569);

    return Material(
      color: selected ? const Color(0xFF123A87) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF123A87)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x110F172A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.backgroundColor,
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${item.meta}   ${item.kindLabel}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w700,
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
    );
  }
}

class _RecordsAvailabilityBadge extends StatelessWidget {
  const _RecordsAvailabilityBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isAvailable = label.toLowerCase() == 'available';
    final background = isAvailable
        ? const Color(0xFFDDF9E8)
        : const Color(0xFFFFF1CC);
    final foreground = isAvailable
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: Color(0xFF3B82F6),
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No $label yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This tab is ready for the records flow. We can add upload and detailed actions next.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
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
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
