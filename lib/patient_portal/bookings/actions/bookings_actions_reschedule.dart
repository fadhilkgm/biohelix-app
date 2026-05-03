part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

extension _BookingsTabRescheduleActions on _BookingsTab {
  Future<void> _showRescheduleBookingSheet(
    BuildContext context,
    PatientPortalProvider portal,
    BookingItem booking,
  ) async {
    DoctorListing? doctor;
    for (final item in portal.doctors) {
      if (item.id == booking.doctorId) {
        doctor = item;
        break;
      }
    }

    if (doctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doctor information is missing. Please refresh.'),
        ),
      );
      return;
    }
    final selectedDoctor = doctor;

    DateTime selectedDate = _nextWorkingDateForDoctor(doctor, DateTime.now());
    String? selectedSlot;
    List<String> availableSlots = const [];
    var loadingSlots = false;

    try {
      final slots = await portal.getDoctorAvailableSlots(
        doctorId: selectedDoctor.id,
        date: DateFormat('yyyy-MM-dd').format(selectedDate),
      );
      availableSlots = slots;
      selectedSlot = slots.isNotEmpty ? slots.first : null;
    } catch (_) {}

    if (!context.mounted) return;

    Future<void> loadSlots(StateSetter setModalState) async {
      setModalState(() {
        loadingSlots = true;
      });

      try {
        final slots = await portal.getDoctorAvailableSlots(
          doctorId: selectedDoctor.id,
          date: DateFormat('yyyy-MM-dd').format(selectedDate),
        );

        setModalState(() {
          availableSlots = slots;
          selectedSlot = slots.contains(selectedSlot)
              ? selectedSlot
              : (slots.isNotEmpty ? slots.first : null);
        });
      } catch (_) {
      } finally {
        setModalState(() {
          loadingSlots = false;
        });
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                MediaQuery.of(context).viewInsets.bottom + 100,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: AppShadows.high(dark: theme.brightness == Brightness.dark),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reschedule',
                        style: GoogleFonts.manrope(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose a new date and time with ${selectedDoctor.name}',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Date Selection Card
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                        initialDate:
                            _isDoctorWorkingOnDate(selectedDoctor, selectedDate)
                            ? selectedDate
                            : _nextWorkingDateForDoctor(
                                selectedDoctor,
                                DateTime.now(),
                              ),
                        selectableDayPredicate: (day) =>
                            _isDoctorWorkingOnDate(selectedDoctor, day),
                      );
                      if (picked == null) return;
                      setModalState(() {
                        selectedDate = picked;
                      });
                      await loadSlots(setModalState);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5A88F1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF5A88F1), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Date',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  DateFormat('EEEE, dd MMM yyyy').format(selectedDate),
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_calendar_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Available Slots',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (loadingSlots)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                  else if (availableSlots.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.event_busy_rounded, size: 40, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            'No slots available on this day',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.6,
                      ),
                      itemCount: availableSlots.length,
                      itemBuilder: (context, index) {
                        final slot = availableSlots[index];
                        final isSelected = selectedSlot == slot;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              if (selectedSlot == slot) {
                                selectedSlot = null;
                              } else {
                                selectedSlot = slot;
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF5A88F1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF5A88F1) : theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              slot,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  CustomButton(
                    onPressed: (portal.bookings.any((b) => 
                        b.id != booking.id && 
                        b.bookingDate == DateFormat('yyyy-MM-dd').format(selectedDate) &&
                        b.status != 'cancelled'
                    )) ? null : () async {
                      if (selectedSlot == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a time slot.')),
                        );
                        return;
                      }

                      try {
                        await portal.rescheduleBooking(
                          bookingId: booking.id,
                          bookingDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                          timeslot: selectedSlot!.trim(),
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Appointment rescheduled successfully.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    text: 'Confirm Reschedule',
                    color: const Color(0xFF5A88F1),
                    isLoading: portal.isCreatingBooking,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRescheduleLabOrderSheet(
    BuildContext context,
    PatientPortalProvider portal,
    LabOrderItem order,
  ) async {
    final List<String> fallbackSlots = [
      '08:00 - 09:00 AM',
      '09:00 - 10:00 AM',
      '10:00 - 11:00 AM',
      '11:00 - 12:00 PM',
      '12:00 - 01:00 PM',
      '01:00 - 02:00 PM',
      '02:00 - 03:00 PM',
      '03:00 - 04:00 PM',
      '04:00 - 05:00 PM',
    ];

    DateTime selectedDate = _tryParseDate(order.date) ?? DateTime.now();
    if (selectedDate.isBefore(DateTime.now())) {
      selectedDate = DateTime.now().add(const Duration(days: 1));
    }
    String? selectedSlot = order.slot;
    List<String> availableSlots = fallbackSlots;
    var loadingSlots = false;

    Future<void> loadSlots(StateSetter setModalState) async {
      setModalState(() {
        loadingSlots = true;
      });

      try {
        final doctorId = portal.doctors.isNotEmpty ? portal.doctors.first.id : null;
        if (doctorId == null) {
          setModalState(() {
            availableSlots = fallbackSlots;
            loadingSlots = false;
          });
          return;
        }

        final slots = await portal.getDoctorAvailableSlots(
          doctorId: doctorId,
          date: DateFormat('yyyy-MM-dd').format(selectedDate),
        );

        setModalState(() {
          availableSlots = slots.isNotEmpty ? slots : fallbackSlots;
          selectedSlot = availableSlots.contains(selectedSlot)
              ? selectedSlot
              : (availableSlots.isNotEmpty ? availableSlots.first : null);
        });
      } catch (_) {
        setModalState(() {
          availableSlots = fallbackSlots;
        });
      } finally {
        setModalState(() {
          loadingSlots = false;
        });
      }
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                MediaQuery.of(context).viewInsets.bottom + 100,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: AppShadows.high(dark: theme.brightness == Brightness.dark),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reschedule Lab Test',
                        style: GoogleFonts.manrope(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order: ${order.testName}',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Date Selection Card
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                        initialDate: selectedDate,
                      );
                      if (picked == null) return;
                      setModalState(() {
                        selectedDate = picked;
                      });
                      await loadSlots(setModalState);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF0EA5E9), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Date',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  DateFormat('EEEE, dd MMM yyyy').format(selectedDate),
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_calendar_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Available Intervals',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (loadingSlots)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.6,
                      ),
                      itemCount: availableSlots.length,
                      itemBuilder: (context, index) {
                        final slot = availableSlots[index];
                        final isSelected = selectedSlot == slot;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              if (selectedSlot == slot) {
                                selectedSlot = null;
                              } else {
                                selectedSlot = slot;
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0EA5E9) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF0EA5E9) : theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              slot,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  CustomButton(
                    onPressed: () async {
                      if (selectedSlot == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a time slot.')),
                        );
                        return;
                      }

                      try {
                        await portal.rescheduleLabOrder(
                          orderId: order.id,
                          date: DateFormat('yyyy-MM-dd').format(selectedDate),
                          slot: selectedSlot!.trim(),
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lab test rescheduled successfully.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    text: 'Confirm Reschedule',
                    color: const Color(0xFF5A88F1),
                    isLoading: portal.isCreatingLabOrder,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRescheduleLabPackageOrderSheet(
    BuildContext context,
    PatientPortalProvider portal,
    LabPackageOrderItem order,
  ) async {
    final List<String> fallbackSlots = [
      '08:00 - 09:00 AM',
      '09:00 - 10:00 AM',
      '10:00 - 11:00 AM',
      '11:00 - 12:00 PM',
      '12:00 - 01:00 PM',
      '01:00 - 02:00 PM',
      '02:00 - 03:00 PM',
      '03:00 - 04:00 PM',
      '04:00 - 05:00 PM',
    ];

    DateTime selectedDate = _tryParseDate(order.date) ?? DateTime.now();
    if (selectedDate.isBefore(DateTime.now())) {
      selectedDate = DateTime.now().add(const Duration(days: 1));
    }
    String? selectedSlot = order.slot;
    List<String> availableSlots = fallbackSlots;
    var loadingSlots = false;

    Future<void> loadSlots(StateSetter setModalState) async {
      setModalState(() {
        loadingSlots = true;
      });

      try {
        final doctorId = portal.doctors.isNotEmpty ? portal.doctors.first.id : null;
        if (doctorId == null) {
          setModalState(() {
            availableSlots = fallbackSlots;
            loadingSlots = false;
          });
          return;
        }

        final slots = await portal.getDoctorAvailableSlots(
          doctorId: doctorId,
          date: DateFormat('yyyy-MM-dd').format(selectedDate),
        );

        setModalState(() {
          availableSlots = slots.isNotEmpty ? slots : fallbackSlots;
          selectedSlot = availableSlots.contains(selectedSlot)
              ? selectedSlot
              : (availableSlots.isNotEmpty ? availableSlots.first : null);
        });
      } catch (_) {
        setModalState(() {
          availableSlots = fallbackSlots;
        });
      } finally {
        setModalState(() {
          loadingSlots = false;
        });
      }
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                MediaQuery.of(context).viewInsets.bottom + 100,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: AppShadows.high(dark: theme.brightness == Brightness.dark),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reschedule Package',
                        style: GoogleFonts.manrope(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order: ${order.packageName}',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Date Selection Card
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                        initialDate: selectedDate,
                      );
                      if (picked == null) return;
                      setModalState(() {
                        selectedDate = picked;
                      });
                      await loadSlots(setModalState);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF8B5CF6), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Date',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  DateFormat('EEEE, dd MMM yyyy').format(selectedDate),
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_calendar_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Available Intervals',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (loadingSlots)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.6,
                      ),
                      itemCount: availableSlots.length,
                      itemBuilder: (context, index) {
                        final slot = availableSlots[index];
                        final isSelected = selectedSlot == slot;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              if (selectedSlot == slot) {
                                selectedSlot = null;
                              } else {
                                selectedSlot = slot;
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF8B5CF6) : theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              slot,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  CustomButton(
                    onPressed: () async {
                      if (selectedSlot == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a time slot.')),
                        );
                        return;
                      }

                      try {
                        await portal.rescheduleLabPackageOrder(
                          orderId: order.id,
                          date: DateFormat('yyyy-MM-dd').format(selectedDate),
                          slot: selectedSlot!.trim(),
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Package rescheduled successfully.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    text: 'Confirm Reschedule',
                    color: const Color(0xFF5A88F1),
                    isLoading: portal.isCreatingLabOrder,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
