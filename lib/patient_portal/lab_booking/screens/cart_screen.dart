import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/lab_booking_controller.dart';
import '../widgets/cart_item_widget.dart';
import '../widgets/price_summary_widget.dart';
import 'checkout_details_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LabBookingController>();
    final theme = Theme.of(context);
    final couponController = TextEditingController(text: c.coupon);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              'My Cart',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF2D3142),
              ),
            ),
            actions: [
              if (c.cart.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      '${c.cartCount} Items',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF5A88F1),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (c.cart.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_basket_outlined,
                      size: 64,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your cart is empty',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = c.cart[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CartItemWidget(
                        item: item,
                        onRemove: () => c.updateQty(item.test.id, 0),
                      ),
                    );
                  },
                  childCount: c.cart.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Coupon',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF2D3142),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
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
                      child: TextField(
                        controller: couponController,
                        decoration: InputDecoration(
                          hintText: 'Try HEALTH10',
                          hintStyle: const TextStyle(fontSize: 14),
                          suffixIcon: TextButton(
                            onPressed: () => c.applyCoupon(couponController.text),
                            child: const Text(
                              'Apply',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        onSubmitted: c.applyCoupon,
                      ),
                    ),
                    const SizedBox(height: 32),
                    PriceSummaryWidget(
                      subtotal: c.subtotal,
                      discount: c.discount,
                      collectionFee: c.collectionFee,
                      total: c.total,
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: c.cart.isEmpty
          ? null
          : Container(
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
                onPressed: () => _push(context, const CheckoutDetailsScreen()),
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
                      'Address & Patient Details',
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

  void _push(BuildContext context, Widget child) {
    final c = context.read<LabBookingController>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(value: c, child: child),
      ),
    );
  }
}
