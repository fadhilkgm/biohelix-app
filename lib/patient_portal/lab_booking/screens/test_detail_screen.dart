import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';
import '../models/lab_booking_models.dart';
import '../state/lab_booking_controller.dart';
import 'cart_screen.dart';

class TestDetailScreen extends StatelessWidget {
  const TestDetailScreen({super.key, required this.test});

  final BookableLabTest test;

  @override
  Widget build(BuildContext context) {
    final c = context.read<LabBookingController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(test.name),
        actions: [
          IconButton(
            onPressed: () => _push(context, const CartScreen()),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            test.category.toUpperCase(),
            style: AppTextStyles.body(
              context,
            ).copyWith(letterSpacing: 1, color: AppColors.accent),
          ),
          const SizedBox(height: 6),
          Text(test.name, style: AppTextStyles.title(context)),
          const SizedBox(height: AppSpacing.md),
          Text(test.description, style: AppTextStyles.body(context)),
          const SizedBox(height: AppSpacing.md),
          const SizedBox(height: AppSpacing.md),
          Text('Price Breakdown', style: AppTextStyles.section(context)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Test price'),
            trailing: Text('Rs ${test.price.toStringAsFixed(0)}'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Sample handling'),
            trailing: Text('Included'),
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
          onPressed: () {
            final added = c.addToCart(test);
            final message = added
                ? 'Added to cart'
                : 'This test is already in your cart';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Add'),
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
