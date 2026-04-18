import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';
import '../models/lab_booking_models.dart';

class TestCardWidget extends StatelessWidget {
  const TestCardWidget({
    super.key,
    required this.test,
    required this.onAdd,
    required this.onOpen,
  });

  final BookableLabTest test;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.cardGradient),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D2A3C),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            test.category.toUpperCase(),
            style: AppTextStyles.body(context).copyWith(
              fontSize: 11,
              letterSpacing: 1,
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(test.name, style: AppTextStyles.cardTitle(context)),
          const SizedBox(height: 6),
          Text(
            test.description,
            style: AppTextStyles.body(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                'Rs ${test.price.toStringAsFixed(0)}',
                style: AppTextStyles.section(context),
              ),
              const Spacer(),
              TextButton(onPressed: onOpen, child: const Text('Details')),
              FilledButton(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
