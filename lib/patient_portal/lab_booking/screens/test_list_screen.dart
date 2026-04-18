import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';
import '../models/lab_booking_models.dart';
import '../state/lab_booking_controller.dart';
import '../widgets/test_card_widget.dart';
import 'cart_screen.dart';
import 'test_detail_screen.dart';

class TestListScreen extends StatelessWidget {
  const TestListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LabBookingController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Lab Tests'),
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
          TextField(
            onChanged: c.setQuery,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search tests or biomarkers',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: c.categories
                  .map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: c.category == category,
                        onSelected: (_) => c.setCategory(category),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Price Range (up to Rs ${c.maxPrice.toStringAsFixed(0)})',
            style: AppTextStyles.body(context),
          ),
          Slider(
            value: c.maxPrice,
            min: 300,
            max: 2500,
            divisions: 22,
            onChanged: c.setMaxPrice,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (c.filteredTests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No tests found for the selected filters.'),
              ),
            )
          else
            ...c.filteredTests.map(
              (t) => TestCardWidget(
                test: t,
                onAdd: () => _handleAddToCart(context, c, t),
                onOpen: () => _push(context, TestDetailScreen(test: t)),
              ),
            ),
        ],
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

  void _handleAddToCart(
    BuildContext context,
    LabBookingController controller,
    BookableLabTest test,
  ) {
    final added = controller.addToCart(test);
    final message = added
        ? 'Added to cart'
        : 'This test is already in your cart';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
