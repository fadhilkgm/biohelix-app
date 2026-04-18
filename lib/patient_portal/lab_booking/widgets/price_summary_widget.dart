import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';

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
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.body(context)),
            const Spacer(),
            Text(
              value,
              style:
                  (strong
                          ? AppTextStyles.section(context)
                          : AppTextStyles.body(context))
                      .copyWith(color: color),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          row('Subtotal', 'Rs ${subtotal.toStringAsFixed(0)}'),
          row(
            'Discount',
            '- Rs ${discount.toStringAsFixed(0)}',
            color: AppColors.success,
          ),
          row('Collection Fee', 'Rs ${collectionFee.toStringAsFixed(0)}'),
          const Divider(),
          row('Total', 'Rs ${total.toStringAsFixed(0)}', strong: true),
        ],
      ),
    );
  }
}
