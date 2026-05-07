import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/patient_models.dart';
import '../../core/providers/patient_portal_provider.dart';
import '../../core/widgets/booking_success_screen.dart';
import '../../../features/session/providers/session_provider.dart';
import '../models/lab_booking_models.dart';
import '../widgets/slot_selector_widget.dart';

class PackageBookingScreen extends StatefulWidget {
  const PackageBookingScreen({
    super.key,
    required this.package,
  });

  final LabPackageItem package;

  @override
  State<PackageBookingScreen> createState() => _PackageBookingScreenState();
}

class _PackageBookingScreenState extends State<PackageBookingScreen> {
  PatientProfile? _selectedPatient;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlot;
  String _collectionType = 'home';
  String _address = '';
  List<String> _slots = [];
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;
  bool _showTests = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
    final portal = context.read<PatientPortalProvider>();
    _address = portal.dashboard?.patient.address ?? '';
    
    final session = context.read<SessionProvider>();
    if (session.patient != null) {
      _selectedPatient = PatientProfile(
        id: session.patient!.uuid,
        name: session.patient!.name,
        age: session.patient!.age ?? 29,
        gender: session.patient!.gender ?? 'Male',
      );
    }
  }

  void _showAddPatientDialog() {
    final name = TextEditingController();
    final age = TextEditingController();
    String gender = 'Male';

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Patient',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: age,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: gender,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
                setState(() {
                  _selectedPatient = PatientProfile(
                    id: 'new-${DateTime.now().millisecondsSinceEpoch}',
                    name: name.text.trim(),
                    age: parsed,
                    gender: gender,
                  );
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSwitchUserSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer<SessionProvider>(
          builder: (sheetContext, session, _) {
            final profiles = session.familyProfiles;
            final activePatientId = _selectedPatient?.id;
            final theme = Theme.of(sheetContext);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F8),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF5A88F1), Color(0xFF759BF1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Switch User',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Select a family member to book this package for.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.82),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withOpacity(0.14),
                              ),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (profiles.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Text(
                                  'No saved family members yet.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              )
                            else
                              ...profiles.map((profile) {
                                final isActive = profile.patient.uuid == activePatientId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(22),
                                      onTap: isActive
                                          ? null
                                          : () {
                                              Navigator.of(sheetContext).pop();
                                              setState(() {
                                                _selectedPatient = PatientProfile(
                                                  id: profile.patient.uuid,
                                                  name: profile.patient.name,
                                                  age: profile.patient.age ?? 29,
                                                  gender: profile.patient.gender ?? 'Male',
                                                );
                                              });
                                            },
                                      child: Ink(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(
                                            color: isActive
                                                ? const Color(0xFF5A88F1)
                                                : const Color(0xFFE5E9F0),
                                            width: isActive ? 1.6 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFF5A88F1),
                                                    Color(0xFF759BF1),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.all(Radius.circular(16)),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                profile.patient.name.isEmpty
                                                    ? 'P'
                                                    : profile.patient.name.characters.first.toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    profile.patient.name,
                                                    style: theme.textTheme.titleSmall?.copyWith(
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    profile.patient.registrationNumber,
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                      color: const Color(0xFF5A88F1),
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    profile.patient.phone,
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                      color: const Color(0xFF7E8BA0),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isActive)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF4F7FF),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: const Text(
                                                  'Active',
                                                  style: TextStyle(
                                                    color: Color(0xFF5A88F1),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              )
                                            else
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                color: Color(0xFF8DA0BA),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  _showAddPatientDialog();
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF5A88F1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: const Icon(Icons.person_add_alt_1_rounded),
                                label: const Text(
                                  'Add New Patient',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadSlots() async {
    final fallbackSlots = [
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

    if (mounted) {
      setState(() {
        _slots = fallbackSlots;
        if (_selectedSlot == null || !_slots.contains(_selectedSlot)) {
          _selectedSlot = _slots.isNotEmpty ? _slots.first : null;
        }
        _isLoadingSlots = false;
      });
    }
  }

  Future<void> _handleBooking() async {
    final portal = context.read<PatientPortalProvider>();

    if (_selectedSlot == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await portal.createLabPackageOrder(
        labPackageId: widget.package.id,
        doctorId: null,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        slot: _selectedSlot,
        collectionType: _collectionType,
        address: _collectionType == 'home' ? (_address.isEmpty ? null : _address) : null,
        amount: (widget.package.discountedPrice ?? widget.package.basePrice).toDouble(),
        paymentStatus: 'pending',
        patientNameSnapshot: _selectedPatient?.name,
        patientAgeSnapshot: _selectedPatient?.age,
        patientGenderSnapshot: _selectedPatient?.gender,
      );

      if (!mounted) return;
      
      final bookingId = 'PKG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            bookingId: bookingId,
            title: 'Package Booked!',
            subtitle: 'Your health package has been successfully scheduled. Our team will contact you for confirmation.',
            imagePath: 'assets/images/lab-test-booking.png',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTests = widget.package.includedTests.isNotEmpty;
    final hasDescription = widget.package.description != null && widget.package.description!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'Complete Booking',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Package Summary Header
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.package.name,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF192233),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Package Price',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF192233).withOpacity(0.5),
                        ),
                      ),
                      Text(
                        '₹${widget.package.discountedPrice ?? widget.package.basePrice}',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF5A88F1),
                        ),
                      ),
                    ],
                  ),
                  // Tests Included Collapsible Section
                  if (hasTests || hasDescription) ...[
                    const Divider(height: 32),
                    InkWell(
                      onTap: () => setState(() => _showTests = !_showTests),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tests Included ${hasTests ? "(${widget.package.includedTests.length})" : ""}',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF192233),
                              ),
                            ),
                            Icon(
                              _showTests ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: const Color(0xFF5A88F1),
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          if (hasTests) ...[
                            ...widget.package.includedTests.map((test) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF5A88F1).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Color(0xFF5A88F1),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          test,
                                          style: GoogleFonts.manrope(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF192233).withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ] else if (hasDescription) ...[
                            Text(
                              widget.package.description!,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: const Color(0xFF192233).withOpacity(0.6),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                      crossFadeState: _showTests ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Collection Type
            Text(
              'Sample Collection Mode',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF192233),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEBEDF2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _CollectionTab(
                    label: 'Home Visit',
                    icon: Icons.home_rounded,
                    selected: _collectionType == 'home',
                    onTap: () => setState(() => _collectionType = 'home'),
                  ),
                  _CollectionTab(
                    label: 'At Lab',
                    icon: Icons.biotech_rounded,
                    selected: _collectionType == 'lab',
                    onTap: () => setState(() => _collectionType = 'lab'),
                  ),
                ],
              ),
            ),
            
            if (_collectionType == 'home') ...[
              const SizedBox(height: 24),
              Text(
                'Collection Address',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF192233),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _address,
                onChanged: (v) => _address = v,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter complete address for sample collection',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 32),

            // Patient
            Text(
              'Patient Details',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF192233),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF5A88F1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPatient?.name ?? 'Select Patient',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF192233),
                          ),
                        ),
                        if (_selectedPatient != null)
                          Text(
                            '${_selectedPatient!.age} yrs \u2022 ${_selectedPatient!.gender}',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: const Color(0xFF192233).withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showSwitchUserSheet,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: Text(
                      'Switch User',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF5A88F1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Date Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Date',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF192233),
                  ),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedDate),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5A88F1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _HorizontalDatePicker(
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
                _loadSlots();
              },
            ),
            
            const SizedBox(height: 32),
            
            // Slot Selection
            Text(
              'Available Slots',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF192233),
              ),
            ),
            const SizedBox(height: 16),
            Consumer<PatientPortalProvider>(
              builder: (context, portal, _) {
                if (_isLoadingSlots) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_slots.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E9F0)),
                    ),
                    child: Text(
                      'No slots available for this date. Please choose another date.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF192233).withOpacity(0.5),
                      ),
                    ),
                  );
                }

                return SlotSelectorWidget(
                  slots: _slots,
                  selectedSlot: _selectedSlot ?? '',
                  onSelect: (slot) => setState(() => _selectedSlot = slot),
                );
              },
            ),
            
            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_selectedSlot == null || _isSubmitting) ? null : _handleBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A88F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Confirm & Book',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CollectionTab extends StatelessWidget {
  const _CollectionTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? const Color(0xFF5A88F1) : const Color(0xFF192233).withOpacity(0.4),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? const Color(0xFF5A88F1) : const Color(0xFF192233).withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalDatePicker extends StatelessWidget {
  const _HorizontalDatePicker({
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dates = List.generate(30, (index) => now.add(Duration(days: index + 1)));

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = DateUtils.isSameDay(date, selectedDate);
          
          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF5A88F1) : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white.withOpacity(0.7) : const Color(0xFF192233).withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : const Color(0xFF192233),
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
