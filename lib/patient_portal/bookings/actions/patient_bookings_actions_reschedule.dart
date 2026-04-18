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
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reschedule appointment',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${selectedDoctor.name} • ${selectedDoctor.specialization}',
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date'),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy').format(selectedDate),
                    ),
                    trailing: const Icon(Icons.calendar_today_rounded),
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
                      setState(() {
                        selectedDate = picked;
                      });
                      await loadSlots(setState);
                    },
                  ),
                  const SizedBox(height: 8),
                  if (loadingSlots)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: LinearProgressIndicator(minHeight: 2.5),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedSlot,
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
                          selectedSlot = value;
                        });
                      },
                    ),
                  if (!loadingSlots && availableSlots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No slots are available for this date.'),
                    ),
                  const SizedBox(height: 16),
                  CustomButton(
                    onPressed: () async {
                      if (selectedSlot == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Select an available slot first.'),
                          ),
                        );
                        return;
                      }

                      try {
                        await portal.rescheduleBooking(
                          bookingId: booking.id,
                          bookingDate: DateFormat(
                            'yyyy-MM-dd',
                          ).format(selectedDate),
                          timeslot: selectedSlot!.trim(),
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Appointment rescheduled successfully.',
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    text: 'Save changes',
                    isLoading: portal.isCreatingBooking,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
