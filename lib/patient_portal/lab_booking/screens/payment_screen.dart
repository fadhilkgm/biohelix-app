// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../core/providers/patient_portal_provider.dart';
import '../../core/widgets/booking_success_screen.dart';
import '../models/lab_booking_models.dart';
import '../state/lab_booking_controller.dart';
import '../widgets/price_summary_widget.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _placing = false;

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
          'Payment',
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
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Choose Payment Method',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: const Color(0xFF2D3142),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _PaymentOption(
                      title: 'Online Payment',
                      subtitle: 'Credit Card, UPI, Wallets',
                      icon: Icons.payments_outlined,
                      selected: c.paymentMethod == PaymentMethod.online,
                      onTap: () => c.setPaymentMethod(PaymentMethod.online),
                    ),
                    const Divider(height: 1, indent: 64),
                    _PaymentOption(
                      title: 'Pay at Collection',
                      subtitle: 'Pay when technician arrives',
                      icon: Icons.handshake_outlined,
                      selected: c.paymentMethod == PaymentMethod.atLab,
                      onTap: () => c.setPaymentMethod(PaymentMethod.atLab),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Final Summary',
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
              child: PriceSummaryWidget(
                subtotal: c.subtotal,
                discount: c.discount,
                collectionFee: c.collectionFee,
                total: c.total,
              ),
            ),
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
          onPressed: _placing ? null : () => _confirm(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5A88F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _placing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Confirm Order',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_outline_rounded, size: 20),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    setState(() => _placing = true);
    final c = context.read<LabBookingController>();
    final portal = context.read<PatientPortalProvider>();
    final config = context.read<AppConfig>();
    final bookedCart = c.cart.toList(growable: false);
    final firstTest = bookedCart.isNotEmpty ? bookedCart.first.test : null;
    final totalTestCount = bookedCart.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final summaryTitle = _labSummaryTitle(bookedCart);
    final summarySubtitle =
        '$totalTestCount ${totalTestCount == 1 ? 'test' : 'tests'} • ${_collectionLabel(c.collectionType)}';
    final summaryImageUrl = _resolveBookingImageUrl(
      firstTest?.imageUrl,
      config.apiBaseUrl.replaceAll('/api', ''),
    );
    final bookingDate = DateFormat('EEE, d MMM yyyy').format(c.date);
    final bookingTime = c.slot ?? 'To be confirmed';
    final selectedPatient = c.selectedPatient;
    final selectedAddress = c.selectedAddress?.fullAddress;
    final total = c.total;

    try {
      final bookingId = await c.placeOrder(portal);
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            bookingId: bookingId,
            title: 'Tests Booked!',
            subtitle:
                'Your lab tests have been successfully scheduled. You can track the status in the bookings tab.',
            imagePath: 'assets/images/lab-test-booking.png',
            summaryTitle: summaryTitle,
            summarySubtitle: summarySubtitle,
            summaryImageUrl: summaryImageUrl,
            summaryImageAsset: 'assets/images/lab-test-booking.png',
            details: [
              BookingSuccessDetail(
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                value: bookingDate,
              ),
              BookingSuccessDetail(
                icon: Icons.access_time_rounded,
                label: 'Time',
                value: bookingTime,
              ),
              BookingSuccessDetail(
                icon: Icons.person_rounded,
                label: 'Patient',
                value: selectedPatient.name,
              ),
              BookingSuccessDetail(
                icon: Icons.place_rounded,
                label: 'Collection',
                value: _collectionLabel(c.collectionType),
              ),
              BookingSuccessDetail(
                icon: Icons.payments_rounded,
                label: 'Amount',
                value: '₹${total.toStringAsFixed(0)}',
              ),
              if ((selectedAddress ?? '').trim().isNotEmpty)
                BookingSuccessDetail(
                  icon: Icons.home_rounded,
                  label: 'Address',
                  value: selectedAddress!.trim(),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _placing = false);
    }
  }

  String _labSummaryTitle(List<CartItem> cart) {
    if (cart.isEmpty) return 'Lab tests';
    final firstName = cart.first.test.name;
    final remaining = cart.fold<int>(0, (sum, item) => sum + item.quantity) - 1;
    if (remaining <= 0) return firstName;
    return '$firstName + $remaining more';
  }

  String _collectionLabel(CollectionType type) {
    return type == CollectionType.home ? 'Home collection' : 'Lab visit';
  }

  String _resolveBookingImageUrl(String? url, String apiBase) {
    if (url == null || url.trim().isEmpty) return '';
    final cleanValue = url.trim();
    if (cleanValue.startsWith('http')) return cleanValue;
    final cleanUrl = cleanValue.startsWith('/')
        ? cleanValue.substring(1)
        : cleanValue;
    return '$apiBase/$cleanUrl';
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF5A88F1)
                    : const Color(0xFFF4F7FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF5A88F1),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF2D3142),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: selected,
              activeColor: const Color(0xFF5A88F1),
              onChanged: (_) => onTap(),
            ),
          ],
        ),
      ),
    );
  }
}
