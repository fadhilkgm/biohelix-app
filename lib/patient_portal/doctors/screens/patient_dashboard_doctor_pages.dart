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
  List<String> _availableSlots = [];
  bool _loadingSlots = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _nextWorkingDateForDoctor(widget.doctor, DateTime.now());
  }

  Future<void> _loadSlots() async {
    if (_selectedDate == null) return;
    setState(() => _loadingSlots = true);
    
    final portal = Provider.of<PatientPortalProvider>(context, listen: false);
    final fallbackSlots = ['09:00 AM', '10:00 AM', '11:30 AM', '02:00 PM', '04:15 PM'];
    
    try {
      final slots = await portal.getDoctorAvailableSlots(
        doctorId: widget.doctor.id,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate!),
      );
      setState(() {
        _availableSlots = slots.isNotEmpty ? slots : fallbackSlots;
        if (!_availableSlots.contains(_selectedSlot)) {
          _selectedSlot = null;
        }
      });
    } catch (_) {
      setState(() {
        _availableSlots = fallbackSlots;
        if (!_availableSlots.contains(_selectedSlot)) {
          _selectedSlot = null;
        }
      });
    } finally {
      setState(() => _loadingSlots = false);
    }
  }
  String _getSelectedDateTimings() {
    if (_loadingSlots) return 'Calculating...';
    if (_availableSlots.isEmpty) return 'No slots available';
    
    String formatTime(String time) {
      if (time.toLowerCase().contains('am') || time.toLowerCase().contains('pm')) return time;
      try {
        final parts = time.trim().split(':');
        final hh = int.parse(parts[0]);
        final mm = parts[1];
        final period = hh >= 12 ? 'PM' : 'AM';
        final hour12 = hh == 0 ? 12 : (hh > 12 ? hh - 12 : hh);
        return '${hour12.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')} $period';
      } catch(e) {
        return time;
      }
    }

    try {
      List<int> startMins = [];
      List<int> endMins = [];
      for (var slot in _availableSlots) {
        if (slot.contains('-')) {
          final parts = slot.split('-');
          final sTime = parts[0].trim().split(':');
          final eTime = parts[1].trim().split(':');
          startMins.add(int.parse(sTime[0]) * 60 + int.parse(sTime[1]));
          endMins.add(int.parse(eTime[0]) * 60 + int.parse(eTime[1]));
        }
      }
      
      if (startMins.isEmpty) {
        return '${_availableSlots.first} - ${_availableSlots.last}';
      }
      
      final intervals = List.generate(startMins.length, (i) => [startMins[i], endMins[i]]);
      intervals.sort((a, b) => a[0].compareTo(b[0]));
      
      List<List<int>> merged = [];
      for (var interval in intervals) {
        if (merged.isEmpty) {
          merged.add(interval);
        } else {
          var last = merged.last;
          if (interval[0] <= last[1]) {
            last[1] = interval[1] > last[1] ? interval[1] : last[1];
          } else {
            merged.add(interval);
          }
        }
      }
      
      String minToTime(int m) {
        final hh = m ~/ 60;
        final mm = m % 60;
        return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
      }
      
      return merged.map((block) => '${formatTime(minToTime(block[0]))} - ${formatTime(minToTime(block[1]))}').join(', ');
      
    } catch (_) {
      return '${_availableSlots.first} - ${_availableSlots.last}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfig>(context, listen: false);
    final apiBase = config.apiBaseUrl.replaceAll('/api', '');

    if (!_initialized) {
      _initialized = true;
      Future.microtask(_loadSlots);
    }

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
                                errorBuilder: (_, __, ___) => _DoctorImageFallback(height: 450),
                              )
                            : _DoctorImageFallback(height: 450),
                      ),
                    ),
                    // Status Bar Utilities
                    SafeArea(
                      child: Padding(
                         padding: const EdgeInsets.only(left: 10, right: 32, bottom: 32, top: 52),
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
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF192233), size: 20),
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
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(50)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
                        Text(
                          (widget.doctor.departmentName ?? "General").toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5A88F1),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Professional Credentials Row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            children: [
                              _DoctorMetricChip(
                                icon: Icons.medical_services_outlined,
                                label: widget.doctor.specialization,
                                sublabel: 'Specialty',
                                color: const Color(0xFF5A88F1),
                              ),
                              _DoctorMetricChip(
                                icon: Icons.school_outlined,
                                label: widget.doctor.qualifications ?? 'MBBS, MD',
                                sublabel: 'Education',
                                color: const Color(0xFF1B6A4F),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Full Width Timing Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F7FB),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB703).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.access_time_filled_rounded, color: Color(0xFFFFB703), size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getSelectedDateTimings(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF192233),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Available Timings',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black.withOpacity(0.4),
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
                                const Icon(Icons.arrow_back_ios_rounded, size: 14, color: Colors.black45),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('MMMM').format(_selectedDate ?? DateTime.now()),
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF192233)),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black45),
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
                            _loadSlots();
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
                        if (_loadingSlots)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_availableSlots.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text('No slots available for this date.', style: TextStyle(color: Colors.black45)),
                            ),
                          )
                        else
                          _VerticalTimeGrid(
                            slots: _availableSlots,
                            selectedSlot: _selectedSlot,
                            onSlotSelected: (slot) {
                              setState(() => _selectedSlot = slot);
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
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              height: 60,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedSlot == null || portal.isCreatingBooking) ? null : () => _bookNow(portal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A88F1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF5A88F1).withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: portal.isCreatingBooking
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text(
                        'Book Session',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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

    try {
      await portal.createBooking(
        doctorId: widget.doctor.id,
        bookingDate: DateFormat('yyyy-MM-dd').format(date),
        timeslot: slot,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment booked successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 200),
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
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF192233)),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black.withOpacity(0.4)),
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
    final dates = List.generate(21, (index) => today.add(Duration(days: index)))
        .where((date) => _isDoctorWorkingOnDate(doctor, date))
        .toList();

    if (dates.isEmpty) {
      return const SizedBox(
        height: 90,
        child: Center(child: Text('No available dates found.', style: TextStyle(color: Colors.black45))),
      );
    }

    return SizedBox(
      height: 95,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = selectedDate != null &&
              selectedDate!.year == date.year &&
              selectedDate!.month == date.month &&
              selectedDate!.day == date.day;

          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: Container(
              width: 75,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF5A88F1) : const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF5A88F1).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
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
                      color: isSelected ? Colors.white : const Color(0xFF192233),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('E').format(date),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white.withOpacity(0.85) : Colors.black38,
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

class _VerticalTimeGrid extends StatelessWidget {
  final List<String> slots;
  final String? selectedSlot;
  final ValueChanged<String> onSlotSelected;

  const _VerticalTimeGrid({
    required this.slots,
    required this.selectedSlot,
    required this.onSlotSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = selectedSlot == slot;

        return GestureDetector(
          onTap: () => onSlotSelected(slot),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF5A88F1) : const Color(0xFFF4F7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              slot,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: isSelected ? Colors.white : const Color(0xFF192233),
              ),
            ),
          ),
        );
      },
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
  final isoDate = DateFormat('yyyy-MM-dd').format(date);
  final availableStr = doctor.availableDates ?? '';
  if (availableStr.contains(isoDate)) return true;

  // If it's Sunday, we allow it by default to ensure slots are shown as requested
  if (date.weekday == DateTime.sunday) return true;

  final String workingStr = (doctor.workingDays ?? '').toLowerCase();
  if (workingStr.isEmpty || workingStr == '[]' || workingStr == 'null') {
    return true;
  }
  
  final longWeekday = DateFormat('EEEE').format(date).toLowerCase();
  final shortWeekday = DateFormat('E').format(date).toLowerCase();
  
  if (workingStr.contains(longWeekday) || workingStr.contains(shortWeekday)) {
    return true;
  }
  
  final numString = date.weekday.toString();
  final jsNumString = date.weekday == 7 ? '0' : date.weekday.toString();

  if (RegExp(r'\b' + numString + r'\b').hasMatch(workingStr)) return true;
  if (RegExp(r'\b' + jsNumString + r'\b').hasMatch(workingStr)) return true;
  
  return false;
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

