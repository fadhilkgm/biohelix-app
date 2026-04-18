import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../state/lab_booking_controller.dart';
import '../widgets/patient_card_widget.dart';
import 'slot_selection_screen.dart';

class PatientSelectionScreen extends StatelessWidget {
  const PatientSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LabBookingController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Select Patient')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ...c.patients.map(
            (p) => PatientCardWidget(
              patient: p,
              selected: c.selectedPatientId == p.id,
              onTap: () => c.setPatient(p.id),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showAddPatientDialog(context, c),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add Family Member'),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          8,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: FilledButton(
          onPressed: () => _push(context, const SlotSelectionScreen()),
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Select Slot'),
        ),
      ),
    );
  }

  Future<void> _showAddPatientDialog(
    BuildContext context,
    LabBookingController c,
  ) async {
    final name = TextEditingController();
    final age = TextEditingController();
    String gender = 'Male';
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Patient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
            ),
            DropdownButtonFormField<String>(
              initialValue: gender,
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => gender = v ?? 'Male',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(age.text) ?? 0;
              if (name.text.trim().isNotEmpty && parsed > 0) {
                c.addPatient(
                  name: name.text.trim(),
                  age: parsed,
                  gender: gender,
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget child) {
    final c = context.read<LabBookingController>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(value: c, child: child),
      ),
    );
  }
}
