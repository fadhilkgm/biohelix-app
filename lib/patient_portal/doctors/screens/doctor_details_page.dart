part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _DoctorDetailPage extends StatefulWidget {
  const _DoctorDetailPage({required this.doctor});
  final DoctorListing doctor;

  @override
  State<_DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<_DoctorDetailPage> {
  DateTime? _selectedDate;
  String? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _selectedDate = _nextWorkingDateForDoctor(widget.doctor, DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfig>(context, listen: false);
    final apiBase = config.apiBaseUrl.replaceAll('/api', '');

    String resolveUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) return url;
      final cleanUrl = url.startsWith('/') ? url.substring(1) : url;
      return '$apiBase/$cleanUrl';
    }

    final imageUrl = resolveUrl(widget.doctor.imageUrl);

    return Consumer<PatientPortalProvider>(
      builder: (context, portal, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          extendBodyBehindAppBar: true,
          body: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: CustomScrollView(
              slivers: [
                // 1. Premium Header (Gradient + Image + Utilities)
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Dynamic Background
                      Container(
                        height: 450,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF5A88F1), Color(0xFF8ECAE6)],
                          ),
                        ),
                      ),
                      // High-Impact Portrait
                      Positioned.fill(
                        child: Hero(
                          tag: 'doctor_${widget.doctor.id}',
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                  errorBuilder: (_, _, _) =>
                                      _DoctorImageFallback(height: 450),
                                )
                              : _DoctorImageFallback(height: 450),
                        ),
                      ),
                      // Status Bar Utilities
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 10,
                            right: 32,
                            bottom: 32,
                            top: 52,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Color(0xFF192233),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 2. Overlapping Identity Card & Metrics Section
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -40),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(50),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.fromLTRB(28, 45, 28, 140),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Doctor Name
                          Container(
                            margin: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.doctor.name,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF192233),
                                letterSpacing: -0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Department
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                (widget.doctor.departmentName ?? "General")
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5A88F1),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              if (widget.doctor.consultationFee != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1B6A4F,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '₹${widget.doctor.consultationFee}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1B6A4F),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (widget.doctor.description != null &&
                              widget.doctor.description!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              widget.doctor.description!,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: const Color(
                                  0xFF192233,
                                ).withValues(alpha: 0.8),
                                height: 1.6,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          // Professional Credentials Row
                          Row(
                            children: [
                              Expanded(
                                child: _DoctorMetricChip(
                                  icon: Icons.medical_services_outlined,
                                  label: widget.doctor.specialization,
                                  sublabel: 'Specialty',
                                  color: const Color(0xFF5A88F1),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _DoctorMetricChip(
                                  icon: Icons.school_outlined,
                                  label:
                                      widget.doctor.qualifications ??
                                      'MBBS, MD',
                                  sublabel: 'Education',
                                  color: const Color(0xFF1B6A4F),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const SizedBox(height: 20),
                          // Full Width Timing Card
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7FB),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFFB703,
                                    ).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.access_time_filled_rounded,
                                    color: Color(0xFFFFB703),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.doctor.availabilityWindowLabel,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF192233),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Consultation Window',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Appointment Scheduling
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Select Date',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF192233),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.arrow_back_ios_rounded,
                                    size: 14,
                                    color: Colors.black45,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat(
                                      'MMMM',
                                    ).format(_selectedDate ?? DateTime.now()),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF192233),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: Colors.black45,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _HorizontalDatePicker(
                            selectedDate: _selectedDate,
                            doctor: widget.doctor,
                            onDateSelected: (date) {
                              setState(() {
                                _selectedDate = date;
                                _selectedSlot = null;
                              });
                            },
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Select Time',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF192233),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ScheduleWindowHint(
                            doctor: widget.doctor,
                            date: _selectedDate,
                          ),
                          _TimePickerCard(
                            selectedSlot: _selectedSlot,
                            onTap: () => _pickTime(portal),
                            hasError:
                                _selectedSlot != null &&
                                !_isSelectedSlotAllowed(portal),
                          ),
                          if (_selectedSlot != null &&
                              !_isSelectedSlotAllowed(portal)) ...[
                            const SizedBox(height: 12),
                            Text(
                              _isSelectedSlotBooked(portal)
                                  ? 'This doctor already has an appointment at that time.'
                                  : 'Choose a time within the doctor available window.',
                              style: const TextStyle(
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              height: 60,
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_selectedSlot == null ||
                        portal.isCreatingBooking ||
                        !_isSelectedSlotAllowed(portal))
                    ? null
                    : () => _bookNow(portal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A88F1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xFF5A88F1,
                  ).withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: portal.isCreatingBooking
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Book Session',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _bookNow(PatientPortalProvider portal) async {
    final date = _selectedDate;
    final slot = _selectedSlot;
    if (date == null || slot == null) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (_hasBookedSlot(portal.bookings, dateStr, slot, widget.doctor.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This doctor already has an appointment at that time.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isSlotInsideDoctorSchedule(widget.doctor, date, slot)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This time is outside the doctor available time. Please choose an available slot.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final scheduleId = _scheduleIdForDateAndSlot(date, slot);
      if (scheduleId == null) {
        throw StateError(
          'This doctor does not have a schedule for the selected time.',
        );
      }

      final confirmation = await portal.createBooking(
        doctorId: widget.doctor.id,
        scheduleId: scheduleId,
        bookingDate: DateFormat('yyyy-MM-dd').format(date),
        timeslot: slot,
        notes: 'Booked from BioHelix patient app.',
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(
              bookingId: confirmation.reference,
              title: 'Appointment Booked!',
              subtitle:
                  'Your session has been successfully scheduled. You can track your upcoming sessions in the bookings tab.',
              imagePath: 'assets/images/appoiment-success.png',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickTime(PatientPortalProvider portal) async {
    final date = _selectedDate;
    if (date == null) return;

    final picked = await showTimePicker(
      context: context,
      initialTime:
          _timeOfDayFromSlot(_selectedSlot) ??
          _firstScheduleTimeForDate(widget.doctor, date) ??
          TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;

    final slot = _timeOfDayToSlot(picked);
    setState(() => _selectedSlot = slot);

    if (_hasBookedSlot(
      portal.bookings,
      DateFormat('yyyy-MM-dd').format(date),
      slot,
      widget.doctor.id,
    )) {
      _showTimeWarning('This doctor already has an appointment at that time.');
      return;
    }

    if (!_isSlotInsideDoctorSchedule(widget.doctor, date, slot)) {
      _showTimeWarning('Choose a time within the doctor available window.');
    }
  }

  void _showTimeWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  int? _scheduleIdForDateAndSlot(DateTime date, String slot) {
    final slotTime = _timeOfDayFromSlot(slot);
    if (slotTime == null) return null;
    final slotMinutes = slotTime.hour * 60 + slotTime.minute;

    for (final schedule in _schedulesForDate(widget.doctor, date)) {
      final start = _minutesFromTimeText(schedule.startTime);
      final end = _minutesFromTimeText(schedule.endTime);
      if (start == null || end == null) continue;
      if (slotMinutes >= start && slotMinutes < end) return schedule.id;
    }

    return widget.doctor.schedules.isNotEmpty
        ? widget.doctor.schedules.first.id
        : null;
  }

  bool _isSelectedSlotBooked(PatientPortalProvider portal) {
    final date = _selectedDate;
    final slot = _selectedSlot;
    if (date == null || slot == null) return false;
    return _hasBookedSlot(
      portal.bookings,
      DateFormat('yyyy-MM-dd').format(date),
      slot,
      widget.doctor.id,
    );
  }

  bool _isSelectedSlotAllowed(PatientPortalProvider portal) {
    final date = _selectedDate;
    final slot = _selectedSlot;
    if (date == null || slot == null) return false;
    return !_hasBookedSlot(
          portal.bookings,
          DateFormat('yyyy-MM-dd').format(date),
          slot,
          widget.doctor.id,
        ) &&
        _isSlotInsideDoctorSchedule(widget.doctor, date, slot);
  }
}

class _DoctorMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _DoctorMetricChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      constraints: const BoxConstraints(minHeight: 110),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Color(0xFF192233),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalDatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final DoctorListing doctor;
  final ValueChanged<DateTime> onDateSelected;

  const _HorizontalDatePicker({
    required this.selectedDate,
    required this.doctor,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dates = List.generate(
      21,
      (index) => today.add(Duration(days: index)),
    ).where((date) => _isDoctorWorkingOnDate(doctor, date)).toList();

    if (dates.isEmpty) {
      return const SizedBox(
        height: 90,
        child: Center(
          child: Text(
            'No available dates found.',
            style: TextStyle(color: Colors.black45),
          ),
        ),
      );
    }

    return SizedBox(
      height: 95,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected =
              selectedDate != null &&
              selectedDate!.year == date.year &&
              selectedDate!.month == date.month &&
              selectedDate!.day == date.day;

          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: Container(
              width: 75,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF5A88F1)
                    : const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF5A88F1).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF192233),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('E').format(date),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimePickerCard extends StatelessWidget {
  final String? selectedSlot;
  final VoidCallback onTap;
  final bool hasError;

  const _TimePickerCard({
    required this.selectedSlot,
    required this.onTap,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasError ? const Color(0xFFE65100) : const Color(0xFFE1E8F2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              color: hasError
                  ? const Color(0xFFE65100)
                  : const Color(0xFF5A88F1),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                selectedSlot ?? 'Choose time',
                style: TextStyle(
                  color: hasError
                      ? const Color(0xFFE65100)
                      : const Color(0xFF192233),
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF192233),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

TimeOfDay? _firstScheduleTimeForDate(DoctorListing doctor, DateTime date) {
  final schedules = _schedulesForDate(doctor, date);
  if (schedules.isEmpty) return null;
  final minutes = _minutesFromTimeText(schedules.first.startTime);
  if (minutes == null) return null;
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

String _timeOfDayToSlot(TimeOfDay time) {
  final period = time.hour >= 12 ? 'PM' : 'AM';
  final hour12 = time.hour == 0
      ? 12
      : time.hour > 12
      ? time.hour - 12
      : time.hour;
  return '$hour12:${time.minute.toString().padLeft(2, '0')} $period';
}

class _ScheduleWindowHint extends StatelessWidget {
  const _ScheduleWindowHint({required this.doctor, required this.date});

  final DoctorListing doctor;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final selectedDate = date;
    if (selectedDate == null) return const SizedBox.shrink();

    final schedules = _schedulesForDate(doctor, selectedDate);
    if (schedules.isEmpty) return const SizedBox.shrink();

    final windows = schedules
        .map(
          (schedule) =>
              '${DoctorListing.formatTimeLabel(schedule.startTime)} - ${DoctorListing.formatTimeLabel(schedule.endTime)}',
        )
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1E8F2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              color: Color(0xFF5A88F1),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Available only between $windows',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: const Color(0xFF192233).withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorImageFallback extends StatelessWidget {
  final double? height;
  final DoctorListing? doctor;

  const _DoctorImageFallback({this.height, this.doctor});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/doctor-vector.png',
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
    );
  }
}

bool _isDoctorWorkingOnDate(DoctorListing doctor, DateTime date) {
  if (doctor.schedules.isNotEmpty) {
    return _schedulesForDate(doctor, date).isNotEmpty;
  }

  final isoDate = DateFormat('yyyy-MM-dd').format(date);
  final availableStr = doctor.availableDates ?? '';
  if (availableStr.contains(isoDate)) return true;

  final String workingStr = (doctor.workingDays ?? '').trim();
  if (workingStr.isEmpty || workingStr == '[]' || workingStr == 'null') {
    return false;
  }

  final backendDay = date.weekday == 7 ? 0 : date.weekday;

  try {
    final workingDays = workingStr
        .split(',')
        .map((d) => int.parse(d.trim()))
        .toList();
    return workingDays.contains(backendDay);
  } catch (_) {
    final longWeekday = DateFormat('EEEE').format(date).toLowerCase();
    final shortWeekday = DateFormat('E').format(date).toLowerCase();
    final lowerWorking = workingStr.toLowerCase();
    return lowerWorking.contains(longWeekday) ||
        lowerWorking.contains(shortWeekday);
  }
}

List<DoctorSchedule> _schedulesForDate(DoctorListing doctor, DateTime date) {
  final day = DateFormat('EEEE').format(date).toLowerCase();
  return doctor.schedules
      .where((schedule) => schedule.dayOfWeek.toLowerCase() == day)
      .toList();
}

bool _isSlotInsideDoctorSchedule(
  DoctorListing doctor,
  DateTime date,
  String slot,
) {
  final slotTime = _timeOfDayFromSlot(slot);
  if (slotTime == null) return false;
  final slotMinutes = slotTime.hour * 60 + slotTime.minute;

  for (final schedule in _schedulesForDate(doctor, date)) {
    final start = _minutesFromTimeText(schedule.startTime);
    final end = _minutesFromTimeText(schedule.endTime);
    if (start == null || end == null) continue;
    if (slotMinutes >= start && slotMinutes < end) return true;
  }

  return doctor.schedules.isEmpty;
}

int? _minutesFromTimeText(String value) {
  final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)?').firstMatch(value);
  if (match == null) return null;
  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null) return null;
  final suffix = match.group(3)?.toLowerCase();
  if (suffix == 'pm' && hour < 12) hour += 12;
  if (suffix == 'am' && hour == 12) hour = 0;
  return hour * 60 + minute;
}

DateTime _nextWorkingDateForDoctor(DoctorListing doctor, DateTime fromDate) {
  for (int i = 0; i < 30; i++) {
    final checkDate = fromDate.add(Duration(days: i));
    if (_isDoctorWorkingOnDate(doctor, checkDate)) {
      return checkDate;
    }
  }
  return fromDate;
}

bool _hasBookedSlot(
  List<BookingItem> bookings,
  String bookingDate,
  String slot,
  int doctorId,
) {
  final normalizedSlot = _normalizeSlot(slot);
  final slotTime = _timeOfDayFromSlot(slot);
  return bookings.any((b) {
    if (b.doctorId != doctorId ||
        b.bookingDate != bookingDate ||
        b.status.toLowerCase() == 'cancelled') {
      return false;
    }
    if (_normalizeSlot(b.timeslot) == normalizedSlot) return true;

    final bookedTime = _timeOfDayFromSlot(b.timeslot);
    return slotTime != null &&
        bookedTime != null &&
        slotTime.hour == bookedTime.hour &&
        slotTime.minute == bookedTime.minute;
  });
}

TimeOfDay? _timeOfDayFromSlot(String? slot) {
  if (slot == null) return null;
  final matches = RegExp(
    r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM|am|pm)?',
  ).allMatches(slot).toList();
  if (matches.isEmpty) return null;

  final first = matches.first;
  var hour = int.tryParse(first.group(1) ?? '');
  final minute = int.tryParse(first.group(2) ?? '0') ?? 0;
  if (hour == null || minute < 0 || minute > 59) return null;

  var suffix = first.group(3)?.toLowerCase();
  if (suffix == null && matches.length > 1) {
    final nextSuffix = matches[1].group(3)?.toLowerCase();
    final nextHour = int.tryParse(matches[1].group(1) ?? '');
    if (nextSuffix == 'am') {
      suffix = 'am';
    } else if (nextSuffix == 'pm') {
      final looksLikeMorningToNoon =
          nextHour == 12 && hour < 12 && !slot.toLowerCase().contains('am');
      suffix = looksLikeMorningToNoon ? null : 'pm';
    }
  }

  if (suffix == 'pm' && hour < 12) hour += 12;
  if (suffix == 'am' && hour == 12) hour = 0;
  if (hour < 0 || hour > 23) return null;

  return TimeOfDay(hour: hour, minute: minute);
}

String _normalizeSlot(String slot) {
  return slot.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
