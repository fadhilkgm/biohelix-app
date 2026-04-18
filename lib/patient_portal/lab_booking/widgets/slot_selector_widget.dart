import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import 'category_chip_widget.dart';

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
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: slots
          .map(
            (slot) => CategoryChipWidget(
              label: slot,
              selected: selectedSlot == slot,
              onTap: () => onSelect(slot),
            ),
          )
          .toList(),
    );
  }
}
