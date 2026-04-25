import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

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
      backgroundColor: const Color(0xFFF8F9FB),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            snap: false,
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Lab Tests',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF192233),
              ),
            ),
            actions: [
              Stack(
                children: [
                  IconButton(
                    onPressed: () => _push(context, const CartScreen()),
                    icon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF192233)),
                  ),
                  if (c.cartCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF5A88F1),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${c.cartCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    onChanged: c.setQuery,
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF5A88F1)),
                      hintText: 'Search tests or biomarkers',
                      hintStyle: GoogleFonts.manrope(
                        color: const Color(0xFF192233).withOpacity(0.4),
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F7FF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: c.categories.map((category) {
                        final isSelected = c.category == category;
                        return GestureDetector(
                          onTap: () => c.setCategory(category),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF5A88F1) : const Color(0xFFF4F7FF),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF5A88F1) : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              category,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : const Color(0xFF192233).withOpacity(0.6),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (c.filteredTests.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('No tests found for the selected filters.'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final t = c.filteredTests[index];
                    return TestCardWidget(
                      test: t,
                      onAdd: () => _handleAddToCart(context, c, t),
                      onOpen: () => _push(context, TestDetailScreen(test: t)),
                    );
                  },
                  childCount: c.filteredTests.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        backgroundColor: added ? const Color(0xFF4CAF50) : const Color(0xFF192233),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
