import 'package:flutter/material.dart';

class PriceSummaryWidget extends StatelessWidget {
  const PriceSummaryWidget({
    super.key,
    required this.subtotal,
    required this.discount,
    required this.collectionFee,
    required this.total,
  });

  final double subtotal;
  final double discount;
  final double collectionFee;
  final double total;

  @override
  Widget build(BuildContext context) {
    Widget row(
      String label,
      String value, {
      bool strong = false,
      Color? color,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                color: strong ? const Color(0xFF2D3142) : Colors.grey[600],
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: strong ? 18 : 14,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
                color:
                    color ??
                    (strong
                        ? const Color(0xFF06489B)
                        : const Color(0xFF2D3142)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: const Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 20),
          row('Subtotal', '₹${subtotal.toStringAsFixed(0)}'),
          if (discount > 0)
            row(
              'Coupon Discount',
              '- ₹${discount.toStringAsFixed(0)}',
              color: const Color(0xFF4CAF50),
            ),
          row('Collection Fee', '₹${collectionFee.toStringAsFixed(0)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          row('Order Total', '₹${total.toStringAsFixed(0)}', strong: true),
        ],
      ),
    );
  }
}
