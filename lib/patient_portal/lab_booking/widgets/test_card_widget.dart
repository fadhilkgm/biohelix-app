import 'package:flutter/material.dart';
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (test.bodyPoints.isNotEmpty
                              ? test.bodyPoints.first.name
                              : 'Lab test')
                          .toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontFamilyFallback: const ['AnekMalayalam'],
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF06489B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.history_toggle_off_rounded,
                    size: 14,
                    color: Color(0xFF06489B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    test.originalItem?.resultEta ?? '24 hrs',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontFamilyFallback: const ['AnekMalayalam'],
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF06489B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                test.name,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontFamilyFallback: const ['AnekMalayalam'],
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF192233),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Price and actions. At larger system font sizes the horizontal row cannot
  /// hold both buttons, so the layout stacks and the buttons go full width —
  /// which also gives older patients a much bigger target.
  Widget _buildActions(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 17;
    final price = _buildPrice();

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: price),
          const SizedBox(height: 10),
          _bookButton(),
          const SizedBox(height: 8),
          _addButton(),
        ],
      );
    }

    return Row(
      children: [
        price,
        const Spacer(),
        _bookButton(),
        const SizedBox(width: 8),
        _addButton(),
      ],
    );
  }

  Widget _buildPrice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (test.basePrice > test.price)
          Text(
            '\u20B9${test.basePrice.toStringAsFixed(0)}',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontFamilyFallback: ['AnekMalayalam'],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        Text(
          '\u20B9${test.price.toStringAsFixed(0)}',
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontFamilyFallback: ['AnekMalayalam'],
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF06489B),
          ),
        ),
      ],
    );
  }

  Widget _bookButton() {
    return TextButton(
      onPressed: onOpen,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF06489B),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 48),
      ),
      child: const Text(
        'Book Now',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontFamilyFallback: ['AnekMalayalam'],
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _addButton() {
    return ElevatedButton(
      onPressed: onAdd,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF06489B),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // 48dp keeps the tap target reachable for older patients.
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text(
        'Add',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontFamilyFallback: ['AnekMalayalam'],
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}
