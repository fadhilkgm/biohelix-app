part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

extension _BookingsTabSheetActions on _BookingsTab {
  Future<void> _showBookingSheet(
    BuildContext context,
    PatientPortalProvider portal,
  ) async {
    DoctorListing? selectedDoctor;
    DateTime? selectedDate;
    String? timeslot;
    List<String> availableSlots = const [];
    var loadingSlots = false;

    Future<void> loadSlots(StateSetter setModalState) async {
      final doctor = selectedDoctor;
      final date = selectedDate;
      if (doctor == null || date == null) {
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

    try {
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
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book an appointment',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<DoctorListing>(
                        initialValue: selectedDoctor,
                        decoration: const InputDecoration(labelText: 'Doctor'),
                        items: portal.doctors
                            .map(
                              (doctor) => DropdownMenuItem<DoctorListing>(
                                value: doctor,
                                child: Text(
                                  '${doctor.name} • ${doctor.specialization}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedDoctor = value;
                            if (value != null) {
                              selectedDate = _nextWorkingDateForDoctor(
                                value,
                                selectedDate ?? DateTime.now(),
                              );
                            }
                          });
                          loadSlots(setState);
                        },
                      ),
                      const SizedBox(height: 12),
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
                            lastDate: DateTime.now().add(
                              const Duration(days: 180),
                            ),
                            initialDate: () {
                              final doctor = selectedDoctor;
                              if (doctor == null) {
                                return selectedDate ?? DateTime.now();
                              }

                              final fallback = _nextWorkingDateForDoctor(
                                doctor,
                                selectedDate ?? DateTime.now(),
                              );

                              return _isDoctorWorkingOnDate(
                                    doctor,
                                    selectedDate ?? fallback,
                                  )
                                  ? (selectedDate ?? fallback)
                                  : fallback;
                            }(),
                            selectableDayPredicate: (day) {
                              final doctor = selectedDoctor;
                              if (doctor == null) return true;
                              return _isDoctorWorkingOnDate(doctor, day);
                            },
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
                            selectedDoctor == null
                                ? 'Select doctor and date to see available slots.'
                                : 'No slots are available for this date.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 20),
                      CustomButton(
                        onPressed: () async {
                          final doctor = selectedDoctor;
                          final date = selectedDate;
                          final chosenSlot = timeslot;
                          if (doctor == null || date == null || chosenSlot == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please select doctor, date and an available slot.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          try {
                            await portal.createBooking(
                              doctorId: doctor.id,
                              bookingDate: DateFormat(
                                'yyyy-MM-dd',
                              ).format(date),
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
                                  backgroundColor: const Color(0xFF108E3E),
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
    } finally {}
  }

  Future<void> _showLabOrderSheet(
    BuildContext context,
    PatientPortalProvider portal, {
    LabTestItem? initialTest,
  }) async {
    LabTestItem? selectedTest =
        initialTest ??
        (portal.labTests.isNotEmpty ? portal.labTests.first : null);
    DoctorListing? selectedDoctor = portal.doctors.isNotEmpty
        ? portal.doctors.first
        : null;
    DateTime? selectedDate = DateTime.now();
    var urgency = 'routine';
    var notes = '';

    try {
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
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order a lab test',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (initialTest != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${initialTest.testName} • ${initialTest.categoryName}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        DropdownButtonFormField<LabTestItem>(
                          initialValue: selectedTest,
                          decoration: const InputDecoration(
                            labelText: 'Lab test',
                          ),
                          items: portal.labTests
                              .map(
                                (test) => DropdownMenuItem<LabTestItem>(
                                  value: test,
                                  child: Text(
                                    '${test.testName} • ${test.categoryName}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedTest = value;
                            });
                          },
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<DoctorListing>(
                        initialValue: selectedDoctor,
                        decoration: const InputDecoration(labelText: 'Doctor'),
                        items: portal.doctors
                            .map(
                              (doctor) => DropdownMenuItem<DoctorListing>(
                                value: doctor,
                                child: Text(
                                  '${doctor.name} • ${doctor.specialization}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedDoctor = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Preferred date'),
                        subtitle: Text(
                          DateFormat(
                            'dd MMM yyyy',
                          ).format(selectedDate ?? DateTime.now()),
                        ),
                        trailing: const Icon(Icons.calendar_today_rounded),
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 180),
                            ),
                            initialDate: selectedDate ?? DateTime.now(),
                          );
                          if (selected != null) {
                            setState(() {
                              selectedDate = selected;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'routine',
                            label: Text('Routine'),
                          ),
                          ButtonSegment(value: 'urgent', label: Text('Urgent')),
                        ],
                        selected: {urgency},
                        onSelectionChanged: (value) {
                          setState(() {
                            urgency = value.first;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: notes,
                        minLines: 2,
                        maxLines: 4,
                        onChanged: (value) => notes = value,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText:
                              'Symptoms, preparation notes, or referral context',
                        ),
                      ),
                      const SizedBox(height: 20),
                      CustomButton(
                        onPressed: () async {
                          final test = selectedTest;
                          final doctor = selectedDoctor;
                          final date = selectedDate;
                          if (test == null || doctor == null || date == null) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Select a lab test, doctor, and preferred date before confirming.',
                                ),
                              ),
                            );
                            return;
                          }
                          try {
                            await portal.createLabOrder(
                              labTestId: test.id,
                              doctorId: doctor.id,
                              date: DateFormat('yyyy-MM-dd').format(date),
                              urgency: urgency,
                              notes: notes,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: const [
                                    Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Lab test ordered successfully.',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF108E3E),
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
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        },
                        text: 'Confirm lab order',
                        isLoading: portal.isCreatingLabOrder,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    } finally {}
  }
}
