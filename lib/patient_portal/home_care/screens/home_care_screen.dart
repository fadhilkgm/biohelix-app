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
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  String get _selectedTimeLabel {
    final hour = _selectedTime.hourOfPeriod == 0
        ? 12
        : _selectedTime.hourOfPeriod;
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    final period = _selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

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
            selectedService = services.first;
          }
          FamilyMember? selectedMember;
          for (final member in members) {
            if (member.patientId == _selectedPatientId) {
              selectedMember = member;
              break;
            }
          }

          return RefreshIndicator(
            onRefresh: portal.refreshHomeCare,
            notificationPredicate: (_) => false,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + 14,
                16,
                32,
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppChevronBackButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Home Care Booking',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF192233),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Professional care delivered safely at your home.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF617086),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                _HomeCareHero(patientName: patient?.name ?? 'there'),
                const SizedBox(height: 18),
                _HomeCareSection(
                  title: 'Choose service',
                  child: services.isEmpty
                      ? const _HomeCareEmptyText(
                          text: 'No active home care services available.',
                        )
                      : _HomeCareDropdownTile(
                          icon: Icons.home_repair_service_outlined,
                          label: 'Service',
                          value: selectedService?.name ?? 'Select a service',
                          subtitle: selectedService == null
                              ? null
                              : '₹${selectedService.basePrice.toStringAsFixed(0)}',
                          onTap: () async {
                            final selected = await _showSelectionSheet<int>(
                              title: 'Choose a service',
                              selectedValue: _selectedServiceId,
                              options: services
                                  .map(
                                    (service) => _HomeCareSelectionOption<int>(
                                      value: service.id,
                                      title: service.name,
                                      subtitle:
                                          '${service.description ?? 'Home care service'} · ₹${service.basePrice.toStringAsFixed(0)}',
                                      icon: Icons.home_repair_service_outlined,
                                    ),
                                  )
                                  .toList(),
                            );
                            if (selected != null && mounted) {
                              setState(() => _selectedServiceId = selected);
                            }
                          },
                        ),
                ),
                const SizedBox(height: 16),
                _HomeCareSection(
                  title: 'Book for',
                  child: Column(
                    children: [
                      _HomeCareDropdownTile(
                        icon: Icons.person_outline_rounded,
                        label: 'Patient',
                        value:
                            selectedMember?.name ?? patient?.name ?? 'Myself',
                        subtitle: selectedMember == null
                            ? 'Self'
                            : _formatRelationship(selectedMember.relationship),
                        onTap: () async {
                          final selected = await _showSelectionSheet<int>(
                            title: 'Who is this booking for?',
                            selectedValue: _selectedPatientId ?? 0,
                            options: [
                              _HomeCareSelectionOption<int>(
                                value: 0,
                                title: patient?.name ?? 'Myself',
                                subtitle: 'Self',
                                icon: Icons.person_outline_rounded,
                              ),
                              ...members.map(
                                (member) => _HomeCareSelectionOption<int>(
                                  value: member.patientId,
                                  title: member.name,
                                  subtitle: _formatRelationship(
                                    member.relationship,
                                  ),
                                  icon: Icons.family_restroom_rounded,
                                ),
                              ),
                            ],
                          );
                          if (selected != null && mounted) {
                            setState(() {
                              _selectedPatientId = selected == 0
                                  ? null
                                  : selected;
                            });
                          }
                        },
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
                          onPressed: _openFamilyMembers,
                          icon: const Icon(Icons.group_add_rounded),
                          label: const Text('Manage family members'),
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
                      _HomeCarePickerTile(
                        icon: Icons.calendar_month_rounded,
                        label: 'Preferred date',
                        value: DateFormat(
                          'EEE, MMM d, yyyy',
                        ).format(_selectedDate),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 12),
                      _HomeCarePickerTile(
                        icon: Icons.schedule_rounded,
                        label: 'Preferred time',
                        value: _selectedTimeLabel,
                        helper: 'Available between 8:00 AM and 6:00 PM',
                        onTap: _pickTime,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _addressController,
                        minLines: 2,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          filled: true,
                          fillColor: Color(0xFFF8FAFC),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _landmarkController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        decoration: const InputDecoration(
                          labelText: 'Landmark',
                          prefixIcon: Icon(Icons.near_me_outlined),
                          filled: true,
                          fillColor: Color(0xFFF8FAFC),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        decoration: const InputDecoration(
                          labelText: 'Notes for care team',
                          prefixIcon: Icon(Icons.notes_rounded),
                          filled: true,
                          fillColor: Color(0xFFF8FAFC),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    backgroundColor: const Color(0xFF06489B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
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

  Future<T?> _showSelectionSheet<T>({
    required String title,
    required List<_HomeCareSelectionOption<T>> options,
    required T? selectedValue,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HomeCareSelectionSheet<T>(
        title: title,
        options: options,
        selectedValue: selectedValue,
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'Select visit time (8:00 AM – 6:00 PM)',
      builder: (context, child) => Localizations.override(
        context: context,
        locale: const Locale('en', 'US'),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final minutes = picked.hour * 60 + picked.minute;
    const openingMinutes = 8 * 60;
    const closingMinutes = 18 * 60;
    if (minutes < openingMinutes || minutes > closingMinutes) {
      _showTimeWarning();
      return;
    }

    setState(() => _selectedTime = picked);
  }

  void _showTimeWarning() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFF5B942),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFF3D2B00)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Please select a time between 8:00 AM and 6:00 PM.',
                style: TextStyle(
                  color: Color(0xFF3D2B00),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Close',
          textColor: const Color(0xFF3D2B00),
          onPressed: messenger.hideCurrentSnackBar,
        ),
      ),
    );
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
          timeSlot:
              '${_selectedTime.hour.toString().padLeft(2, '0')}:'
              '${_selectedTime.minute.toString().padLeft(2, '0')}',
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

  Future<void> _openFamilyMembers() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _FamilyMembersScreen()),
    );
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

class _HomeCareSelectionOption<T> {
  const _HomeCareSelectionOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final T value;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _HomeCareSelectionSheet<T> extends StatelessWidget {
  const _HomeCareSelectionSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
  });

  final String title;
  final List<_HomeCareSelectionOption<T>> options;
  final T? selectedValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFD5DDE8),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF192233),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final option = options[index];
                final selected = option.value == selectedValue;
                return Material(
                  color: selected
                      ? const Color(0xFFEAF2FC)
                      : const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).pop(option.value),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF06489B)
                              : const Color(0xFFE2E8F0),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              option.icon,
                              color: const Color(0xFF06489B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.title,
                                  style: const TextStyle(
                                    color: Color(0xFF192233),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  option.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF617086),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF06489B),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCareDropdownTile extends StatelessWidget {
  const _HomeCareDropdownTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE5EF)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F0FC),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: const Color(0xFF06489B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF192233),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF617086),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF718096),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCarePickerTile extends StatelessWidget {
  const _HomeCarePickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.helper,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? helper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6F9FD),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE6F2)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EFFB),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: const Color(0xFF06489B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF192233),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (helper != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        helper!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF718096),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8DA0BA)),
            ],
          ),
        ),
      ),
    );
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
        color: const Color(0xFF06489B),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06489B).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
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
            color: Color(0xFF06489B),
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
                  '${booking.preferredDate} · ${_formatHomeCareTime(booking.timeSlot)} · ${booking.status}',
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

String _formatHomeCareTime(String? raw) {
  final value = (raw ?? '').trim();
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
  if (match == null) return value.isEmpty ? 'Any time' : value;

  final hour = int.tryParse(match.group(1)!) ?? 0;
  final minute = match.group(2)!;
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  final period = hour < 12 ? 'AM' : 'PM';
  return '$displayHour:$minute $period';
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
