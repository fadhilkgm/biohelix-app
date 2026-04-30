import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/lab_booking_models.dart';
import '../state/lab_booking_controller.dart';
import '../widgets/address_card_widget.dart';
import 'slot_selection_screen.dart';

class CheckoutDetailsScreen extends StatelessWidget {
  const CheckoutDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LabBookingController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Booking Details',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF2D3142),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Patient',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: const Color(0xFF2D3142),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddPatientDialog(context, c),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add New'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 90,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: c.patients.length,
                itemBuilder: (context, index) {
                  final p = c.patients[index];
                  final isSelected = c.selectedPatientId == p.id;
                  return GestureDetector(
                    onTap: () => c.setPatient(p.id),
                    child: Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF5A88F1) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF5A88F1) : Colors.black.withValues(alpha: 0.05),
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: const Color(0xFF5A88F1).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF4F7FF),
                            child: Text(
                              p.name.characters.first.toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF5A88F1),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFF2D3142),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${p.age} yrs • ${p.gender.characters.first}',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // Collection Type Toggle (Airy design)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Collection Type',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: const Color(0xFF2D3142),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                   _CollectionOption(
                      title: 'Home Collection',
                      subtitle: '99 fee applies',
                      icon: Icons.home_rounded,
                      selected: c.collectionType == CollectionType.home,
                      onTap: () => c.setCollectionType(CollectionType.home),
                   ),
                   const SizedBox(width: 12),
                   _CollectionOption(
                      title: 'Visit Lab',
                      subtitle: 'Free collection',
                      icon: Icons.local_hospital_rounded,
                      selected: c.collectionType == CollectionType.lab,
                      onTap: () => c.setCollectionType(CollectionType.lab),
                   ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Address Section (Conditional)
            if (c.collectionType == CollectionType.home) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Collection Address',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: const Color(0xFF2D3142),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddAddressDialog(context, c),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add New'),
                    ),
                  ],
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: c.addresses.length,
                itemBuilder: (context, index) {
                  final a = c.addresses[index];
                  final isSelected = c.selectedAddressId == a.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AddressCardWidget(
                      address: a,
                      selected: isSelected,
                      onTap: () => c.setAddress(a.id),
                    ),
                  );
                },
              ),
            ],
            
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _push(context, const SlotSelectionScreen()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A88F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Choose Time Slot',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _showAddPatientDialog(BuildContext context, LabBookingController c) async {
    final name = TextEditingController();
    final age = TextEditingController();
    String gender = 'Male';
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add New Patient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(labelText: 'Gender'),
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
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(age.text) ?? 0;
              if (name.text.trim().isNotEmpty && parsed > 0) {
                c.addPatient(name: name.text.trim(), age: parsed, gender: gender);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAddressDialog(BuildContext context, LabBookingController c) async {
    final label = TextEditingController();
    final address = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Label (e.g., Home, Office)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Full Address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (label.text.trim().isNotEmpty && address.text.trim().isNotEmpty) {
                c.addAddress(label: label.text.trim(), fullAddress: address.text.trim());
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

class _CollectionOption extends StatelessWidget {
  const _CollectionOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? const Color(0xFF5A88F1) : Colors.black.withValues(alpha: 0.05),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFF5A88F1) : Colors.grey,
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? const Color(0xFF5A88F1) : const Color(0xFF2D3142),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? const Color(0xFF5A88F1).withValues(alpha: 0.7) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
