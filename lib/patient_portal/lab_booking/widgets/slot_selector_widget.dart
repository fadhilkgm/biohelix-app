import 'package:flutter/material.dart';

class SlotSelectorWidget extends StatelessWidget {
  const SlotSelectorWidget({
    super.key,
    required this.slots,
    required this.selectedSlot,
    required this.onSelect,
  });

  final List<String> slots;
  final String? selectedSlot;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.8,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = selectedSlot == slot;

        return GestureDetector(
          onTap: () => onSelect(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF06489B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF06489B)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFF06489B).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    slot.replaceAll(' - ', ' to '),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF2D3142),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
