import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/patient_portal_provider.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';
import '../models/lab_booking_models.dart';
import '../state/lab_booking_controller.dart';
import '../widgets/price_summary_widget.dart';
import 'booking_success_screen.dart';

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
      appBar: AppBar(title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Payment Method', style: AppTextStyles.section(context)),
          const SizedBox(height: AppSpacing.sm),
          RadioListTile<PaymentMethod>(
            value: PaymentMethod.online,
            groupValue: c.paymentMethod,
            onChanged: (v) => c.setPaymentMethod(v!),
            title: const Text('Pay Online'),
          ),
          RadioListTile<PaymentMethod>(
            value: PaymentMethod.atLab,
            groupValue: c.paymentMethod,
            onChanged: (v) => c.setPaymentMethod(v!),
            title: const Text('Pay at Lab'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Order Summary', style: AppTextStyles.section(context)),
          const SizedBox(height: AppSpacing.sm),
          PriceSummaryWidget(
            subtotal: c.subtotal,
            discount: c.discount,
            collectionFee: c.collectionFee,
            total: c.total,
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
          onPressed: _placing ? null : () => _confirm(context),
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(52),
          ),
          child: _placing
              ? const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                )
              : const Text('Confirm Booking'),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    setState(() => _placing = true);
    final c = context.read<LabBookingController>();
    final portal = context.read<PatientPortalProvider>();
    try {
      final bookingId = await c.placeOrder(portal);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(bookingId: bookingId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _placing = false);
    }
  }
}
