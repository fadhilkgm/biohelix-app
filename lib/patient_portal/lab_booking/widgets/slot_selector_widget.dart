import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../design/app_spacing.dart';

class SlotSelectorWidget extends StatelessWidget {
  const SlotSelectorWidget({
    super.key,
    required this.slots,
    required this.selectedSlot,
    required this.onSelect,
  });

  final List<String> slots;
  final String selectedSlot;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.2,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = selectedSlot == slot;
        
        return GestureDetector(
          onTap: () => onSelect(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF5A88F1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF5A88F1).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              slot.replaceAll(' - ', '\n'), // Stack times to save horizontal space
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 11,
                height: 1.2,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF192233),
              ),
            ),
          ),
        );
      },
    );
  }
}
