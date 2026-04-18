part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

const Map<int, String> _weekdayNames = {
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

String _doctorWorkingDaysLabel(DoctorListing doctor) {
  final working = doctor.workingDays;
  if ((working ?? '').trim().isNotEmpty) {
    final labels = working!
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .map((day) {
          final normalized = day == 0 ? DateTime.sunday : day;
          return _weekdayNames[normalized];
        })
        .whereType<String>()
        .toList();

    if (labels.isNotEmpty) return labels.join(', ');
  }

  if ((doctor.availableDates ?? '').trim().isNotEmpty) {
    return doctor.availableDates!;
  }

  return 'Flexible schedule';
}

String _doctorTimeLabel(DoctorListing doctor) {
  final start = doctor.workStartTime;
  final end = doctor.workEndTime;
  if ((start ?? '').isNotEmpty && (end ?? '').isNotEmpty) {
    return '$start - $end';
  }

  if ((doctor.availableTime ?? '').isNotEmpty) {
    return doctor.availableTime!;
  }

  return 'Contact for timings';
}

String _doctorBreakLabel(DoctorListing doctor) {
  final breakStart = doctor.breakStartTime;
  final breakEnd = doctor.breakEndTime;
  if ((breakStart ?? '').isNotEmpty && (breakEnd ?? '').isNotEmpty) {
    return '$breakStart - $breakEnd';
  }

  return 'No break';
}

bool _isDoctorWorkingOnDate(DoctorListing doctor, DateTime date) {
  final working = doctor.workingDays;
  if ((working ?? '').trim().isNotEmpty) {
    final validDays = working!
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toSet();

    final apiDay = date.weekday == DateTime.sunday ? 0 : date.weekday;
    return validDays.contains(apiDay);
  }

  final legacyDays = (doctor.availableDates ?? '')
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();

  if (legacyDays.isEmpty) return true;
  final dayName = _weekdayNames[date.weekday];
  return dayName != null && legacyDays.contains(dayName);
}

DateTime _nextWorkingDateForDoctor(DoctorListing doctor, DateTime fromDate) {
  final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
  for (var offset = 0; offset <= 365; offset++) {
    final candidate = start.add(Duration(days: offset));
    if (_isDoctorWorkingOnDate(doctor, candidate)) {
      return candidate;
    }
  }

  return start;
}

class _DoctorImageFallback extends StatelessWidget {
  const _DoctorImageFallback({required this.doctor});

  final DoctorListing doctor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = doctor.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.8),
            theme.colorScheme.secondaryContainer.withOpacity(0.6),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withOpacity(0.25),
            child: Text(
              initials.isEmpty ? 'DR' : initials,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Icon(
            Icons.medical_services_outlined,
            size: 20,
            color: Colors.white.withOpacity(0.7),
          ),
        ],
      ),
    );
  }
}

class _DoctorDetailPage extends StatelessWidget {
  const _DoctorDetailPage({required this.doctor});
  final DoctorListing doctor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = Provider.of<AppConfig>(context, listen: false);
    final apiBase = config.apiBaseUrl.replaceAll('/api', '');

    String resolveUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      if (url.startsWith('http')) return url;
      final cleanUrl = url.startsWith('/') ? url.substring(1) : url;
      return '$apiBase/$cleanUrl';
    }

    final imageUrl = resolveUrl(doctor.imageUrl);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      body: Consumer<PatientPortalProvider>(
        builder: (context, portal, _) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: const Color(0xFFF4F7F8),
                surfaceTintColor: Colors.transparent,
                // title: const Text('Doctor Profile'),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'doctor_${doctor.id}',
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _DoctorImageFallback(doctor: doctor),
                              )
                            : _DoctorImageFallback(doctor: doctor),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctor.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              doctor.specialization,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if ((doctor.departmentName ?? '').isNotEmpty)
                                  _InfoChip(
                                    icon: Icons.apartment_rounded,
                                    label: doctor.departmentName!,
                                  ),
                                _InfoChip(
                                  icon: Icons.schedule_rounded,
                                  label: _doctorTimeLabel(doctor),
                                ),
                                _InfoChip(
                                  icon: Icons.event_available_rounded,
                                  label: _doctorWorkingDaysLabel(doctor),
                                ),
                                _InfoChip(
                                  icon: Icons.free_breakfast_outlined,
                                  label: 'Break: ${_doctorBreakLabel(doctor)}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            CustomButton(
                              onPressed: () =>
                                  _showDoctorBookingSheet(context, portal, doctor),
                              isLoading: portal.isCreatingBooking,
                              text: 'Book Now',
                              icon: const Icon(
                                Icons.calendar_month_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoSection(
                              title: 'About Doctor',
                              content:
                                  'Dr. ${doctor.name} is a dedicated ${doctor.specialization.toLowerCase()} specialist focused on compassionate, evidence-based treatment and long-term patient wellness.',
                            ),
                            const SizedBox(height: 16),
                            if ((doctor.qualifications ?? '').isNotEmpty)
                              _DoctorDetailLine(
                                icon: Icons.workspace_premium_rounded,
                                label: 'Qualifications',
                                value: doctor.qualifications!,
                              ),
                            if ((doctor.registrationNumber ?? '').isNotEmpty)
                              _DoctorDetailLine(
                                icon: Icons.badge_outlined,
                                label: 'Registration Number',
                                value: doctor.registrationNumber!,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showDoctorBookingSheet(
  BuildContext context,
  PatientPortalProvider portal,
  DoctorListing doctor,
) async {
  DateTime? selectedDate = _nextWorkingDateForDoctor(doctor, DateTime.now());
  String? timeslot;
  List<String> availableSlots = const [];
  var loadingSlots = false;
  var initialized = false;

  Future<void> loadSlots(StateSetter setModalState) async {
    final date = selectedDate;
    if (date == null) {
      setModalState(() {
        availableSlots = const [];
        timeslot = null;
        loadingSlots = false;
      });
      return;
    }

    setModalState(() {
      loadingSlots = true;
    });

    try {
      final slots = await portal.getDoctorAvailableSlots(
        doctorId: doctor.id,
        date: DateFormat('yyyy-MM-dd').format(date),
      );
      setModalState(() {
        availableSlots = slots;
        timeslot = slots.contains(timeslot)
            ? timeslot
            : (slots.isNotEmpty ? slots.first : null);
      });
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load available slots.')),
        );
      }
    } finally {
      setModalState(() {
        loadingSlots = false;
      });
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            if (!initialized) {
              initialized = true;
              Future<void>.microtask(() => loadSlots(setState));
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Book with ${doctor.name}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    doctor.specialization,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date'),
                    subtitle: Text(
                      selectedDate == null
                          ? 'Select date'
                          : DateFormat('dd MMM yyyy').format(selectedDate!),
                    ),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                        initialDate:
                            _isDoctorWorkingOnDate(
                              doctor,
                              selectedDate ?? DateTime.now(),
                            )
                            ? (selectedDate ?? DateTime.now())
                            : _nextWorkingDateForDoctor(doctor, DateTime.now()),
                        selectableDayPredicate: (day) =>
                            _isDoctorWorkingOnDate(doctor, day),
                      );
                      if (selected != null) {
                        setState(() {
                          selectedDate = selected;
                        });
                        loadSlots(setState);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (loadingSlots)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: LinearProgressIndicator(minHeight: 2.5),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: timeslot,
                      decoration: const InputDecoration(
                        labelText: 'Available slot',
                      ),
                      items: availableSlots
                          .map(
                            (slot) => DropdownMenuItem<String>(
                              value: slot,
                              child: Text(slot),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          timeslot = value;
                        });
                      },
                    ),
                  if (!loadingSlots && availableSlots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Select a date to see available slots.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 20),
                  CustomButton(
                    onPressed: () async {
                      final date = selectedDate;
                      final chosenSlot = timeslot;
                      if (date == null || chosenSlot == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select date and an available slot.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      try {
                        await portal.createBooking(
                          doctorId: doctor.id,
                          bookingDate: DateFormat('yyyy-MM-dd').format(date),
                          timeslot: chosenSlot.trim(),
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: const [
                                  Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Appointment booked successfully.',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF108E3E), // Success Green
                              margin: EdgeInsets.only(
                                bottom: MediaQuery.of(context).size.height - 160,
                                left: 20,
                                right: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
                    text: 'Confirm appointment',
                    isLoading: portal.isCreatingBooking,
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
