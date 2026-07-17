part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _HomeCareScreen extends StatefulWidget {
  const _HomeCareScreen();

  @override
  State<_HomeCareScreen> createState() => _HomeCareScreenState();
}

class _HomeCareScreenState extends State<_HomeCareScreen> {
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _notesController = TextEditingController();
  int? _selectedServiceId;
  int? _selectedPatientId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedSlot = 'Morning';

  static const _slots = ['Morning', 'Afternoon', 'Evening'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<PatientPortalProvider>().refreshHomeCare());
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _landmarkController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        title: const Text('Home Care'),
        backgroundColor: const Color(0xFFF4F7F8),
        surfaceTintColor: Colors.transparent,
      ),
      body: Consumer2<SessionProvider, PatientPortalProvider>(
        builder: (context, session, portal, _) {
          final patient = session.patient;
          final services = portal.homeCareServices;
          final members = portal.familyMembers
              .where((member) => member.canBookAppointments)
              .toList();
          HomeCareServiceItem? selectedService;
          for (final service in services) {
            if (service.id == _selectedServiceId) {
              selectedService = service;
              break;
            }
          }

          if (_selectedServiceId == null && services.isNotEmpty) {
            _selectedServiceId = services.first.id;
          }

          return RefreshIndicator(
            onRefresh: portal.refreshHomeCare,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _HomeCareHero(patientName: patient?.name ?? 'there'),
                const SizedBox(height: 16),
                _HomeCareSection(
                  title: 'Choose service',
                  child: services.isEmpty
                      ? const _HomeCareEmptyText(
                          text: 'No active home care services available.',
                        )
                      : Column(
                          children: services
                              .map(
                                (service) => _HomeCareServiceCard(
                                  service: service,
                                  selected: service.id == _selectedServiceId,
                                  onTap: () => setState(() {
                                    _selectedServiceId = service.id;
                                  }),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                _HomeCareSection(
                  title: 'Book for',
                  child: Column(
                    children: [
                      _BookForTile(
                        title: patient?.name ?? 'Myself',
                        subtitle: 'Self',
                        selected: _selectedPatientId == null,
                        onTap: () => setState(() => _selectedPatientId = null),
                      ),
                      ...members.map(
                        (member) => _BookForTile(
                          title: member.name,
                          subtitle: member.relationship,
                          selected: _selectedPatientId == member.patientId,
                          onTap: () => setState(() {
                            _selectedPatientId = member.patientId;
                          }),
                        ),
                      ),
                      if (members.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Add family members from Profile to book care for them.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _showAddFamilyDialog(portal),
                          icon: const Icon(Icons.group_add_rounded),
                          label: const Text('Add family member'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _HomeCareSection(
                  title: 'Visit details',
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_rounded),
                        title: Text(
                          DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                        ),
                        subtitle: const Text('Preferred date'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _pickDate,
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: _slots
                            .map(
                              (slot) => ButtonSegment<String>(
                                value: slot,
                                label: Text(slot),
                              ),
                            )
                            .toList(),
                        selected: {_selectedSlot},
                        onSelectionChanged: (value) {
                          setState(() => _selectedSlot = value.first);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _addressController,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _landmarkController,
                        decoration: const InputDecoration(
                          labelText: 'Landmark',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes for care team',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      portal.isCreatingHomeCareBooking ||
                          selectedService == null
                      ? null
                      : () {
                          final service = selectedService;
                          if (service == null) return;
                          _submit(portal, service);
                        },
                  icon: portal.isCreatingHomeCareBooking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.home_repair_service_rounded),
                  label: Text(
                    portal.isCreatingHomeCareBooking
                        ? 'Submitting...'
                        : 'Request home care',
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Recent requests',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (portal.homeCareBookings.isEmpty)
                  const _HomeCareEmptyText(text: 'No home care requests yet.')
                else
                  ...portal.homeCareBookings.map(
                    (booking) => _HomeCareBookingCard(
                      booking: booking,
                      onCancel:
                          booking.status == 'pending' ||
                              booking.status == 'confirmed'
                          ? () => _cancel(portal, booking)
                          : null,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit(
    PatientPortalProvider portal,
    HomeCareServiceItem service,
  ) async {
    if (service.requiresAddress && _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the visit address.')),
      );
      return;
    }

    try {
      await portal.createHomeCareBooking(
        HomeCareBookingInput(
          serviceId: service.id,
          patientId: _selectedPatientId,
          preferredDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
          timeSlot: _selectedSlot,
          addressLine: _addressController.text,
          landmark: _landmarkController.text,
          notes: _notesController.text,
        ),
      );
      if (!mounted) return;
      _notesController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Home care request submitted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showAddFamilyDialog(PatientPortalProvider portal) async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final phoneController = TextEditingController();
    final dobController = TextEditingController();
    String relationship = 'father';
    String gender = 'male';

    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Add family member'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: firstNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'First name'),
                  ),
                  TextField(
                    controller: lastNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Last name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: relationship,
                    decoration: const InputDecoration(labelText: 'Relation'),
                    items:
                        const [
                              'father',
                              'mother',
                              'spouse',
                              'son',
                              'daughter',
                              'brother',
                              'sister',
                              'other',
                            ]
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => relationship = value);
                      }
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: const ['male', 'female', 'other']
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => gender = value);
                    },
                  ),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  TextField(
                    controller: dobController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      suffixIcon: Icon(Icons.event_rounded),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: DateTime.now().subtract(
                          const Duration(days: 365 * 25),
                        ),
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        dobController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (firstNameController.text.trim().isEmpty) return;
                  try {
                    await portal.addLinkedFamilyMember(
                      firstName: firstNameController.text,
                      lastName: lastNameController.text,
                      relationship: relationship,
                      gender: gender,
                      phone: phoneController.text,
                      dateOfBirth: dobController.text,
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  } catch (error) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    dobController.dispose();

    if (added == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Family member linked.')));
    }
  }

  Future<void> _cancel(
    PatientPortalProvider portal,
    HomeCareBookingItem booking,
  ) async {
    try {
      await portal.cancelHomeCareBooking(
        booking.id,
        patientId: _selectedPatientId,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _HomeCareHero extends StatelessWidget {
  const _HomeCareHero({required this.patientName});

  final String patientName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.health_and_safety_rounded,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Care at home',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Request nursing or support visits for $patientName or a linked family member.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
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

class _HomeCareSection extends StatelessWidget {
  const _HomeCareSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HomeCareServiceCard extends StatelessWidget {
  const _HomeCareServiceCard({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final HomeCareServiceItem service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF0F766E)
                  : const Color(0xFFE5ECEF),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.home_repair_service_outlined,
                color: const Color(0xFF0F766E),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if ((service.description ?? '').isNotEmpty)
                      Text(
                        service.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Text('Rs ${service.basePrice.toStringAsFixed(0)}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookForTile extends StatelessWidget {
  const _BookForTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? const Color(0xFF0F766E) : Colors.black38,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _HomeCareBookingCard extends StatelessWidget {
  const _HomeCareBookingCard({required this.booking, this.onCancel});

  final HomeCareBookingItem booking;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5ECEF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.home_repair_service_rounded,
            color: Color(0xFF0F766E),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.serviceName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${booking.preferredDate} · ${booking.timeSlot ?? 'Any time'} · ${booking.status}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onCancel != null)
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _HomeCareEmptyText extends StatelessWidget {
  const _HomeCareEmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
