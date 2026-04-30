import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/lab_booking_models.dart';
import '../state/lab_booking_controller.dart';
import 'test_booking_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LabBookingController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'Your Cart',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: c.cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: const Color(0xFF192233).withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your cart is empty',
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF192233),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add tests to continue booking',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: const Color(0xFF192233).withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Cart items
                ...c.cart.map((item) => _CartItemCard(
                      item: item,
                      onRemove: () => c.updateQty(item.test.id, 0),
                    )),
                const SizedBox(height: 20),
                // Price summary
                Container(
                  padding: const EdgeInsets.all(20),
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
                    children: [
                      _SummaryRow(
                        label: 'Subtotal',
                        value: '\u20B9${c.subtotal.toStringAsFixed(0)}',
                      ),
                      _SummaryRow(
                        label: 'Discount',
                        value: '- \u20B9${c.discount.toStringAsFixed(0)}',
                        valueColor: const Color(0xFF1F9A6D),
                      ),
                      _SummaryRow(
                        label: 'Collection Fee',
                        value: '\u20B9${c.collectionFee.toStringAsFixed(0)}',
                      ),
                      const Divider(height: 24),
                      _SummaryRow(
                        label: 'Total',
                        value: '\u20B9${c.total.toStringAsFixed(0)}',
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
      bottomSheet: c.cart.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _pushCheckout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A88F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Proceed to Checkout',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${c.cart.length}',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  void _pushCheckout(BuildContext context) {
    final c = context.read<LabBookingController>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: c,
          child: const TestBookingScreen(),
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;

  const _CartItemCard({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.biotech_outlined,
              color: Color(0xFF5A88F1),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.test.name,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF192233),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.test.category,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: const Color(0xFF192233).withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\u20B9${item.test.price.toStringAsFixed(0)}',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF5A88F1),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFFF5C5C),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: const Color(0xFF192233).withValues(alpha: isBold ? 1 : 0.6),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ??
                  (isBold
                      ? const Color(0xFF192233)
                      : const Color(0xFF192233).withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }
}
