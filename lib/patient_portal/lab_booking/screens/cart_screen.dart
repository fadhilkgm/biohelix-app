import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../state/lab_booking_controller.dart';
import '../widgets/cart_item_widget.dart';
import '../widgets/price_summary_widget.dart';
import 'patient_selection_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LabBookingController>();
    final couponController = TextEditingController(text: c.coupon);
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (c.cart.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(
                child: Text('Your cart is empty. Add tests to continue.'),
              ),
            )
          else
            ...c.cart.map(
              (item) => CartItemWidget(
                item: item,
                onRemove: () => c.updateQty(item.test.id, 0),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: couponController,
            decoration: const InputDecoration(
              labelText: 'Coupon code',
              hintText: 'Try HEALTH10',
            ),
            onSubmitted: c.applyCoupon,
          ),
          const SizedBox(height: AppSpacing.md),
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
          6,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: FilledButton(
          onPressed: c.cart.isEmpty
              ? null
              : () => _push(context, const PatientSelectionScreen()),
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Continue Booking'),
        ),
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
