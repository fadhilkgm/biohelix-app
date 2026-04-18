part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.onOpenTestsHub});

  final VoidCallback onOpenTestsHub;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _heartRateController = TextEditingController();

  int? _deletingDocumentId;
  final Set<int> _autoSummaryRequested = <int>{};
  final Set<int> _autoSummaryAttempted = <int>{};
  final Set<int> _autoSummaryFailed = <int>{};

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    super.dispose();
  }

  void _ensureAutoSummary(
    BuildContext context,
    PatientPortalProvider portal,
    DocumentRecord document,
  ) {
    final hasSummary =
        (portal.analysisFor(document.id)?.summary ?? document.summary ?? '')
            .trim()
            .isNotEmpty;
    if (hasSummary) {
      _autoSummaryRequested.remove(document.id);
      _autoSummaryFailed.remove(document.id);
      return;
    }

    if (_autoSummaryAttempted.contains(document.id)) {
      return;
    }

    if (_autoSummaryRequested.contains(document.id) ||
        portal.analyzingDocumentId == document.id) {
      return;
    }

    _autoSummaryAttempted.add(document.id);
    _autoSummaryRequested.add(document.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(() async {
        try {
          await portal.analyzeDocument(document.id);
          final resolvedSummary =
              (portal.analysisFor(document.id)?.summary ??
                      document.summary ??
                      '')
                  .trim();
          if (resolvedSummary.isEmpty) {
            _autoSummaryFailed.add(document.id);
          } else {
            _autoSummaryFailed.remove(document.id);
          }
        } catch (_) {
          _autoSummaryFailed.add(document.id);
        } finally {
          _autoSummaryRequested.remove(document.id);
          if (mounted) {
            setState(() {});
          }
        }
      }());
    });
  }

  List<String> _extractDocumentPaths(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return const [];
    if (!trimmed.startsWith('[')) {
      return [trimmed];
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    } catch (_) {
      return [trimmed];
    }

    return [trimmed];
  }

  String _resolveReportUrl(BuildContext context, String rawUrl) {
    final value = rawUrl.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final config = Provider.of<AppConfig>(context, listen: false);
    final origin = Uri.parse(config.apiBaseUrl).resolve('/').toString();
    final path = value.startsWith('/') ? value.substring(1) : value;
    return Uri.parse(origin).resolve(path).toString();
  }

  bool _isImageReport(DocumentRecord document, String resolvedUrl) {
    final type = document.documentType.toLowerCase();
    if (type.startsWith('image/')) return true;

    final lower = resolvedUrl.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  Future<void> _openReportPreview(
    BuildContext context,
    DocumentRecord document,
  ) async {
    final paths = _extractDocumentPaths(document.documentPath);
    final first = paths.isEmpty ? '' : paths.first;
    final resolved = _resolveReportUrl(context, first);
    if (resolved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report preview unavailable.')),
      );
      return;
    }

    if (_isImageReport(document, resolved)) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
            ),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.network(
                resolved,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Could not preview this image.'),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    await launchUrl(Uri.parse(resolved), mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteReport(
    BuildContext context,
    PatientPortalProvider portal,
    DocumentRecord document,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete report'),
        content: const Text(
          'This report will be removed from your profile and will not be used in future chat context.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() {
      _deletingDocumentId = document.id;
    });

    try {
      await portal.deleteDocument(document.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report deleted.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _deletingDocumentId = null;
        });
      }
    }
  }

  Future<void> _showAddFamilyMemberDialog(
    BuildContext context,
    PatientPortalProvider portal,
  ) async {
    final session = context.read<SessionProvider>();
    var otpRequested = false;
    var isBusy = false;
    var errorText = '';
    var devOtp = '';
    var phone = '';
    var mrn = '';
    var otp = '';

    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(
              otpRequested ? 'Verify family member' : 'Add family member',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!otpRequested) ...[
                    TextField(
                      keyboardType: TextInputType.phone,
                      onChanged: (value) => phone = value,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (value) => mrn = value,
                      decoration: const InputDecoration(
                        labelText: 'MRN number',
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Enter the OTP sent for ${phone.trim()} and MRN ${mrn.trim().toUpperCase()}.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (value) => otp = value,
                      decoration: const InputDecoration(labelText: 'OTP'),
                    ),
                    if (devOtp.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Dev OTP: $devOtp',
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                    ],
                  ],
                  if (errorText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isBusy
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: Text(otpRequested ? 'Cancel' : 'Close'),
              ),
              FilledButton(
                onPressed: isBusy
                    ? null
                    : () async {
                        setDialogState(() {
                          isBusy = true;
                          errorText = '';
                        });

                        if (!otpRequested) {
                          await session.sendOtp(phone: phone, mrn: mrn);

                          if (!dialogContext.mounted) {
                            return;
                          }

                          setDialogState(() {
                            isBusy = false;
                            errorText = session.errorMessage ?? '';
                            otpRequested =
                                errorText.isEmpty &&
                                (session.pendingPhone ?? '').isNotEmpty;
                            devOtp = session.devOtp ?? '';
                          });
                          return;
                        }

                        await session.verifyOtp(otp: otp);

                        if (!dialogContext.mounted) {
                          return;
                        }

                        if (session.errorMessage != null) {
                          setDialogState(() {
                            isBusy = false;
                            errorText = session.errorMessage ?? '';
                          });
                          return;
                        }

                        Navigator.of(dialogContext).pop(true);
                      },
                child: Text(otpRequested ? 'Verify & switch' : 'Send OTP'),
              ),
            ],
          ),
        );
      },
    );

    if (added != true) {
      session.cancelPendingOtp();
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Family member added and switched.')),
    );
  }

  Future<void> _switchFamilyProfile(
    BuildContext context,
    String token,
  ) async {
    final session = context.read<SessionProvider>();

    try {
      await session.switchFamilyProfile(token);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showFamilyProfilesSheet(
    BuildContext context,
    PatientPortalProvider portal,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer<SessionProvider>(
          builder: (sheetContext, session, _) {
            final profiles = session.familyProfiles;
            final activePatientId = session.patient?.id;
            final theme = Theme.of(sheetContext);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FF),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0C5B97), Color(0xFF0EA0CF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Switch Profile',
                                    style: theme.textTheme.titleLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Choose a saved patient or add a new family member.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (profiles.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Text(
                                  'No saved family members yet.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              )
                            else
                              ...profiles.map((profile) {
                                final isActive =
                                    profile.patient.id == activePatientId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(22),
                                      onTap: isActive
                                          ? null
                                          : () async {
                                              Navigator.of(sheetContext).pop();
                                              await _switchFamilyProfile(
                                                context,
                                                profile.token,
                                              );
                                            },
                                      child: Ink(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(
                                            color: isActive
                                                ? const Color(0xFF0EA0CF)
                                                : const Color(0xFFE3EAF5),
                                            width: isActive ? 1.6 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF0C5B97),
                                                    Color(0xFF0EA0CF),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                profile.patient.name.isEmpty
                                                    ? 'P'
                                                    : profile
                                                        .patient
                                                        .name
                                                        .characters
                                                        .first
                                                        .toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    profile.patient.name,
                                                    style: theme.textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    profile.patient
                                                        .registrationNumber,
                                                    style: theme.textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: const Color(
                                                            0xFF275A9A,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    profile.patient.phone,
                                                    style: theme.textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: const Color(
                                                            0xFF7E8BA0,
                                                          ),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isActive)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFDDF6FF,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                ),
                                                child: const Text(
                                                  'Active',
                                                  style: TextStyle(
                                                    color: Color(0xFF0C5B97),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              )
                                            else
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                color: Color(0xFF8DA0BA),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  Navigator.of(sheetContext).pop();
                                  await _showAddFamilyMemberDialog(
                                    context,
                                    portal,
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0C5B97),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: const Icon(Icons.person_add_alt_1_rounded),
                                label: const Text(
                                  'Add Family Member',
                                  style: TextStyle(fontWeight: FontWeight.w800),
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
          },
        );
      },
    );
  }

  Widget _buildFamilyProfilesCard(
    BuildContext context,
    SessionProvider session,
    PatientPortalProvider portal,
  ) {
    final profiles = session.familyProfiles;
    final activePatientId = session.patient?.id;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
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
                        'Family profiles',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Save multiple patients on this device and switch from here.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showAddFamilyMemberDialog(context, portal),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (profiles.isEmpty)
              Text(
                'No saved family members yet.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...profiles.map((profile) {
                final isActive = profile.patient.id == activePatientId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: isActive ? 0.6 : 0.35),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Text(
                            profile.patient.name.isEmpty
                                ? 'P'
                                : profile.patient.name.characters.first
                                      .toUpperCase(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.patient.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${profile.patient.registrationNumber}  •  ${profile.patient.phone}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          const Chip(label: Text('Active'))
                        else
                          OutlinedButton(
                            onPressed: () => _switchFamilyProfile(
                              context,
                              profile.token,
                            ),
                            child: const Text('Switch'),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileEditor(
    BuildContext context,
    SessionProvider session,
    PatientPortalProvider portal,
  ) {
    final patient = session.patient!;
    final theme = Theme.of(context);

    _nameController.text = patient.name;
    _emailController.text = patient.email ?? '';
    _addressController.text = patient.address ?? '';
    _bloodGroupController.text = patient.bloodGroup ?? '';
    _allergiesController.text = patient.allergies ?? '';
    _conditionsController.text = patient.chronicConditions ?? '';

    final latestVitals = portal.vitalTrend.isNotEmpty
        ? portal.vitalTrend.last
        : null;
    _heightController.text =
        latestVitals?.height?.toString() ?? _heightController.text;
    _weightController.text =
        latestVitals?.weight?.toString() ?? _weightController.text;
    _systolicController.text =
        latestVitals?.bloodPressureSystolic?.toString() ??
        _systolicController.text;
    _diastolicController.text =
        latestVitals?.bloodPressureDiastolic?.toString() ??
        _diastolicController.text;
    _heartRateController.text =
        latestVitals?.heartRate?.toString() ?? _heartRateController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    hintText: patient.phone,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bloodGroupController,
                        decoration: const InputDecoration(
                          labelText: 'Blood group',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _allergiesController,
                        decoration: const InputDecoration(
                          labelText: 'Allergies',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _conditionsController,
                  decoration: const InputDecoration(
                    labelText: 'Chronic conditions',
                  ),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  onPressed: () async {
                    try {
                      final updated = patient.copyWith(
                        name: _nameController.text.trim(),
                        email: _emailController.text.trim(),
                        address: _addressController.text.trim(),
                        bloodGroup: _bloodGroupController.text.trim(),
                        allergies: _allergiesController.text.trim(),
                        chronicConditions: _conditionsController.text.trim(),
                      );
                      await portal.saveProfile(updated);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated.')),
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  },
                  text: 'Save profile',
                  isLoading: portal.isSavingProfile,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health tracking',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Height (cm)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _systolicController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'BP systolic',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _diastolicController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'BP diastolic',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _heartRateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Heart rate'),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  onPressed: () async {
                    try {
                      await portal.saveVitals(
                        VitalInput(
                          height: double.tryParse(_heightController.text),
                          weight: double.tryParse(_weightController.text),
                          bloodPressureSystolic: int.tryParse(
                            _systolicController.text,
                          ),
                          bloodPressureDiastolic: int.tryParse(
                            _diastolicController.text,
                          ),
                          heartRate: int.tryParse(_heartRateController.text),
                        ),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vitals saved.')),
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  },
                  text: 'Save vitals',
                  isLoading: portal.isSavingVitals,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportsGallery(
    BuildContext context,
    PatientPortalProvider portal,
  ) {
    final theme = Theme.of(context);
    final documents = portal.documents;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uploaded Reports',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage files used by Health AI and document chat.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${documents.length} files',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (documents.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No uploaded reports yet.'),
              ),
            )
          else
            ...documents.map((document) {
              _ensureAutoSummary(context, portal, document);

              final paths = _extractDocumentPaths(document.documentPath);
              final primaryPath = paths.isEmpty ? '' : paths.first;
              final resolvedUrl = _resolveReportUrl(context, primaryPath);
              final isImage = _isImageReport(document, resolvedUrl);
              final summary =
                  portal.analysisFor(document.id)?.summary ??
                  document.summary ??
                  '';
              final isDeleting = _deletingDocumentId == document.id;
              final isGeneratingSummary =
                  _autoSummaryRequested.contains(document.id) ||
                  portal.analyzingDocumentId == document.id;
              final summaryFailed = _autoSummaryFailed.contains(document.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 56,
                              height: 56,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: isImage && resolvedUrl.isNotEmpty
                                  ? Image.network(
                                      resolvedUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.image_not_supported_outlined,
                                      ),
                                    )
                                  : Icon(
                                      document.documentType
                                              .toLowerCase()
                                              .contains('pdf')
                                          ? Icons.picture_as_pdf_outlined
                                          : Icons.description_outlined,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  document.documentType.toUpperCase(),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  document.time == null ||
                                          document.time!.isEmpty
                                      ? document.date
                                      : '${document.date} • ${document.time}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: document.hasAnalysis
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              document.hasAnalysis ? 'Analyzed' : 'Pending',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          summary.trim().isEmpty
                              ? isGeneratingSummary
                                    ? 'Generating summary...'
                                    : summaryFailed
                                    ? 'Summary could not be generated for this report yet.'
                                    : 'Summary will appear automatically after upload.'
                              : summary.trim(),
                          style: theme.textTheme.bodySmall,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openReportPreview(context, document),
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                            ),
                            label: const Text('Open'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: isDeleting
                                ? null
                                : () =>
                                      _deleteReport(context, portal, document),
                            icon: isDeleting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 16,
                                  ),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SessionProvider, PatientPortalProvider>(
      builder: (context, session, portal, _) {
        final patient = session.patient;
        if (patient == null) {
          return const SizedBox.shrink();
        }

        final dashboard = portal.dashboard;
        final idCard =
            dashboard?.idCard ??
            IdCardInfo(
              registrationNumber: patient.registrationNumber,
              patientName: patient.name,
              membershipTier: 'Classic',
              qrValue: patient.uuid,
              bloodGroup: patient.bloodGroup,
              barcodeValue: patient.registrationNumber,
            );
        final myClub =
            dashboard?.myClub ??
            MyClubSummary(
              patientId: patient.id,
              points: 0,
              currencyValue: 0,
              tier: idCard.membershipTier,
              transactions: const [],
            );

        return Container(
          color: const Color(0xFFF4F7F8),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
            children: [
              _RedesignedProfileSection(
                patient: patient,
                idCard: idCard,
                myClub: myClub,
                onOpenTestsHub: widget.onOpenTestsHub,
                onSwitchProfiles: () =>
                    _showFamilyProfilesSheet(context, portal),
                onSignOut: () {
                  unawaited(session.signOut());
                },
              ),
              /*
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Text(
                  'Legacy Profile (Old Design)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildProfileEditor(context, session, portal),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Legacy Reports (Old Design)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildReportsGallery(context, portal),
              */
              Offstage(
                offstage: true,
                child: Column(
                  children: [
                    _buildFamilyProfilesCard(context, session, portal),
                    _buildProfileEditor(context, session, portal),
                    _buildReportsGallery(context, portal),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
