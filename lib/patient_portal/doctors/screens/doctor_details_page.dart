part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

String? _normalizedDoctorSlotStart(String raw) {
  final start = raw.split('-').first.trim();
  if (start.isEmpty) return null;

  for (final pattern in const ['HH:mm', 'H:mm', 'hh:mm a', 'h:mm a']) {
    try {
      final parsed = DateFormat(pattern).parseStrict(start);
      return DateFormat('HH:mm').format(parsed);
    } catch (_) {}
  }
  return null;
}

class _DoctorDetailPage extends StatefulWidget {
  const _DoctorDetailPage({required this.doctor});
  final DoctorListing doctor;

  @override
  State<_DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<_DoctorDetailPage> {
  DateTime? _selectedDate;
  String? _selectedSlot;
  List<DoctorSlotAvailability> _availableSlots = const [];
  List<BookingItem> _selectedPatientBookings = const [];
  int? _selectedBookingPatientId;
  bool _loadingSlots = false;
  bool _loadingPatientBookings = false;

  Set<String> _bookedSlotStarts(PatientPortalProvider portal) {
    final selectedDate = _selectedDate;
    if (selectedDate == null) return const {};

    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    const activeStatuses = {
      'pending',
      'confirmed',
      'rescheduled',
      'approved',
      'active',
    };

    final bookings = _selectedBookingPatientId == null
        ? portal.bookings
        : _selectedPatientBookings;

    return bookings
        .where(
          (booking) =>
              booking.doctorId == widget.doctor.id &&
              booking.bookingDate.trim().startsWith(dateKey) &&
              activeStatuses.contains(
                booking.effectiveStatus().trim().toLowerCase(),
              ),
        )
        .map((booking) => _normalizedDoctorSlotStart(booking.timeslot))
        .whereType<String>()
        .toSet();
  }

  // Kept temporarily for compatibility with the legacy in-booking selector.
  // ignore: unused_element
  Future<void> _selectBookingPatient(
    PatientPortalProvider portal,
    int? patientId,
  ) async {
    if (_selectedBookingPatientId == patientId) return;

    setState(() {
      _selectedBookingPatientId = patientId;
      _selectedPatientBookings = const [];
      _selectedSlot = null;
      _loadingPatientBookings = patientId != null;
    });

    if (patientId != null) {
      try {
        final bookings = await portal.getBookingsForPatient(patientId);
        if (!mounted || _selectedBookingPatientId != patientId) return;
        setState(() => _selectedPatientBookings = bookings);
      } catch (_) {
        if (!mounted || _selectedBookingPatientId != patientId) return;
        setState(() {
          _selectedBookingPatientId = null;
          _selectedPatientBookings = const [];
          _loadingPatientBookings = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load this patient’s bookings.'),
          ),
        );
      } finally {
        if (mounted && _selectedBookingPatientId == patientId) {
          setState(() => _loadingPatientBookings = false);
        }
      }
    }

    if (mounted && _selectedBookingPatientId == patientId) {
      await _loadAvailableSlots(portal);
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _nextWorkingDateForDoctor(widget.doctor, DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final portal = context.read<PatientPortalProvider>();
      _loadAvailableSlots(portal);
    });
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
        final bookedSlotStarts = _bookedSlotStarts(portal);
        final hasExistingBookingForDate = bookedSlotStarts.isNotEmpty;
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
                            colors: [Color(0xFF06489B), Color(0xFF8ECAE6)],
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
                              AppChevronBackButton(
                                onPressed: () => Navigator.pop(context),
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
                                  color: Color(0xFF06489B),
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
                                  color: const Color(0xFF06489B),
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
                                        'Consultation Time',
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
                              _loadAvailableSlots(portal);
                            },
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Available Slots',
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
                          if (hasExistingBookingForDate)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2FC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFC6DDED),
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFF06489B),
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'This patient already has an appointment '
                                      'with this doctor on this date. Choose '
                                      'another date or patient.',
                                      style: TextStyle(
                                        color: Color(0xFF315D91),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _DoctorAvailableSlotGrid(
                            loading: _loadingSlots || _loadingPatientBookings,
                            availableSlots: _availableSlots,
                            selectedSlot: _selectedSlot,
                            bookedSlotStarts: bookedSlotStarts,
                            hasExistingBooking: hasExistingBookingForDate,
                            onSlotSelected: (slot) {
                              setState(() {
                                _selectedSlot = _selectedSlot == slot
                                    ? null
                                    : slot;
                              });
                            },
                          ),
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
                        _loadingSlots ||
                        _loadingPatientBookings ||
                        hasExistingBookingForDate ||
                        portal.isCreatingBooking)
                    ? null
                    : () => _bookNow(portal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06489B),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xFF06489B,
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

  Future<void> _loadAvailableSlots(PatientPortalProvider portal) async {
    final date = _selectedDate;
    if (date == null) return;

    setState(() {
      _loadingSlots = true;
    });

    try {
      final slots = await portal.getDoctorSlotAvailability(
        doctorId: widget.doctor.id,
        date: DateFormat('yyyy-MM-dd').format(date),
      );
      if (!mounted) return;
      final selectableSlots = slots
          .where((item) => item.isAvailable)
          .map((item) => item.slot)
          .toList();
      final bookedStarts = _bookedSlotStarts(portal);
      final unbookedSlots = selectableSlots
          .where(
            (slot) => !bookedStarts.contains(_normalizedDoctorSlotStart(slot)),
          )
          .toList();
      setState(() {
        _availableSlots = slots;
        _selectedSlot = bookedStarts.isNotEmpty
            ? null
            : selectableSlots.contains(_selectedSlot)
            ? _selectedSlot
            : unbookedSlots.isNotEmpty
            ? unbookedSlots.first
            : (selectableSlots.isNotEmpty ? selectableSlots.first : null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableSlots = const [];
        _selectedSlot = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSlots = false;
        });
      }
    }
  }

  Future<void> _bookNow(PatientPortalProvider portal) async {
    final date = _selectedDate;
    final slot = _selectedSlot;
    if (date == null || slot == null) return;

    try {
      final confirmation = await portal.createBooking(
        doctorId: widget.doctor.id,
        bookingDate: DateFormat('yyyy-MM-dd').format(date),
        timeslot: slot,
        patientId: _selectedBookingPatientId,
        notes: 'Booked from BHRC patient app.',
      );
      if (mounted) {
        final config = Provider.of<AppConfig>(context, listen: false);
        final apiBase = config.apiBaseUrl.replaceAll('/api', '');
        final doctorImageUrl = _resolveDoctorImageUrl(
          widget.doctor.imageUrl,
          apiBase,
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(
              bookingId: confirmation.reference,
              tokenNumber: confirmation.tokenNumber,
              showMedicalSuccessIcon: true,
              title: 'Appointment Booked!',
              subtitle:
                  'Your session has been successfully scheduled. You can track your upcoming sessions in the bookings tab.',
              doctorName: widget.doctor.name,
              doctorSpecialization: widget.doctor.specialization,
              doctorImageUrl: doctorImageUrl,
              bookingDate: DateFormat('EEE, d MMM yyyy').format(date),
              bookingTime: slot,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.of(
                context.read<LanguageProvider>().language,
              ).errorWithMessage(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _resolveDoctorImageUrl(String? url, String apiBase) {
    if (url == null || url.trim().isEmpty) return '';
    final cleanValue = url.trim();
    if (cleanValue.startsWith('http')) return cleanValue;
    final cleanUrl = cleanValue.startsWith('/')
        ? cleanValue.substring(1)
        : cleanValue;
    return '$apiBase/$cleanUrl';
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
                    ? const Color(0xFF06489B)
                    : const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF06489B).withValues(alpha: 0.2),
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

class _DoctorAvailableSlotGrid extends StatelessWidget {
  const _DoctorAvailableSlotGrid({
    required this.loading,
    required this.availableSlots,
    required this.selectedSlot,
    required this.bookedSlotStarts,
    required this.hasExistingBooking,
    required this.onSlotSelected,
  });

  final bool loading;
  final List<DoctorSlotAvailability> availableSlots;
  final String? selectedSlot;
  final Set<String> bookedSlotStarts;
  final bool hasExistingBooking;
  final ValueChanged<String> onSlotSelected;

  String _formatSlotLabel(String slot) {
    final parts = slot.split('-').map((part) => part.trim()).toList();
    if (parts.length != 2) return DoctorListing.formatTimeLabel(slot);

    final start = DoctorListing.formatTimeLabel(parts.first);
    final end = DoctorListing.formatTimeLabel(parts.last);
    final startPeriod = RegExp(r'\b(AM|PM)$').firstMatch(start)?.group(1);
    final endPeriod = RegExp(r'\b(AM|PM)$').firstMatch(end)?.group(1);

    if (startPeriod != null && startPeriod == endPeriod) {
      final compactStart = start.replaceFirst(RegExp(r'\s+(AM|PM)$'), '');
      return '$compactStart - $end';
    }
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFF06489B),
          ),
        ),
      );
    }

    if (availableSlots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1E8F2)),
        ),
        child: const Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 40, color: Colors.black38),
            SizedBox(height: 12),
            Text(
              'No slots available on this day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.1,
      ),
      itemCount: availableSlots.length,
      itemBuilder: (context, index) {
        final availability = availableSlots[index];
        final slot = availability.slot;
        final isSelected = selectedSlot == slot;
        final isAvailable = availability.isAvailable;
        final isBooked = bookedSlotStarts.contains(
          _normalizedDoctorSlotStart(slot),
        );
        final isBlocked = hasExistingBooking && !isBooked;
        return InkWell(
          onTap: isAvailable && !isBooked && !hasExistingBooking
              ? () => onSlotSelected(slot)
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF06489B)
                  : isBooked
                  ? const Color(0xFFE5F7ED)
                  : isBlocked
                  ? const Color(0xFFF1F3F6)
                  : isAvailable
                  ? Colors.white
                  : const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF06489B)
                    : isBooked
                    ? const Color(0xFF38A169)
                    : isBlocked
                    ? const Color(0xFFD8DDE5)
                    : !isAvailable
                    ? const Color(0xFFD8DDE5)
                    : const Color(0xFFE1E8F2),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatSlotLabel(slot),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : isBooked
                        ? const Color(0xFF147A4B)
                        : isBlocked
                        ? const Color(0xFF8B94A3)
                        : isAvailable
                        ? const Color(0xFF192233)
                        : const Color(0xFF8B94A3),
                  ),
                ),
                if (!isAvailable)
                  const Text(
                    'Full',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB54747),
                    ),
                  ),
                if (isBooked)
                  const Text(
                    'Booked',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF147A4B),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
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
              color: Color(0xFF06489B),
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
    return AppLogo(
      height: height,
      fit: BoxFit.contain,
      backgroundColor: const Color(0xFFF0F4FF),
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

DateTime _nextWorkingDateForDoctor(DoctorListing doctor, DateTime fromDate) {
  for (int i = 0; i < 30; i++) {
    final checkDate = fromDate.add(Duration(days: i));
    if (_isDoctorWorkingOnDate(doctor, checkDate)) {
      return checkDate;
    }
  }
  return fromDate;
}
