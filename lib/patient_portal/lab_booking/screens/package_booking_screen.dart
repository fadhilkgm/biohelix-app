import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/patient_models.dart';
import '../../core/providers/patient_portal_provider.dart';
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
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlot;
  String _collectionType = 'home';
  String _address = '';
  List<String> _slots = [];
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
    final portal = context.read<PatientPortalProvider>();
    _address = portal.dashboard?.patient.address ?? '';
  }

  Future<void> _loadSlots() async {
    final portal = context.read<PatientPortalProvider>();
    final doctorId = portal.doctors.isNotEmpty ? portal.doctors.first.id : null;
    
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

    if (doctorId == null) {
      if (mounted) {
        setState(() {
          _slots = fallbackSlots;
          if (_selectedSlot == null || !_slots.contains(_selectedSlot)) {
            _selectedSlot = _slots.isNotEmpty ? _slots.first : null;
          }
          _isLoadingSlots = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingSlots = true;
    });

    try {
      final result = await portal.getDoctorAvailableSlots(
        doctorId: doctorId,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      );
      if (!mounted) return;
      setState(() {
        _slots = result.isNotEmpty ? result : fallbackSlots;
        if (_selectedSlot == null || !_slots.contains(_selectedSlot)) {
          _selectedSlot = _slots.isNotEmpty ? _slots.first : null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _slots = fallbackSlots;
          if (_selectedSlot == null || !_slots.contains(_selectedSlot)) {
            _selectedSlot = _slots.isNotEmpty ? _slots.first : null;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSlots = false;
        });
      }
    }
  }

  Future<void> _handleBooking() async {
    final portal = context.read<PatientPortalProvider>();
    final doctorId = portal.doctors.isNotEmpty ? portal.doctors.first.id : null;

    if (_selectedSlot == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await portal.createLabPackageOrder(
        labPackageId: widget.package.id,
        doctorId: doctorId,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        slot: _selectedSlot,
        collectionType: _collectionType,
        address: _collectionType == 'home' ? (_address.isEmpty ? null : _address) : null,
        amount: (widget.package.discountedPrice ?? widget.package.basePrice).toDouble(),
        paymentStatus: 'pending',
      );

      if (!mounted) return;
      
      // Show success and pop
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${widget.package.name} booked successfully.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF108E3E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
