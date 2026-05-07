part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

extension _BookingsTabSheetActions on _BookingsTab {


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
