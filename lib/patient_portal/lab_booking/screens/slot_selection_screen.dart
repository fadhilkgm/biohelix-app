import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../design/app_colors.dart';
import '../models/lab_booking_models.dart';
import '../design/app_spacing.dart';
import '../state/lab_booking_controller.dart';
import '../widgets/slot_selector_widget.dart';
import 'address_screen.dart';
import 'payment_screen.dart';

class SlotSelectionScreen extends StatelessWidget {
  const SlotSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LabBookingController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Slot')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => c.setCollectionType(CollectionType.home),
                      child: Container(
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: c.collectionType == CollectionType.home
                              ? AppColors.primary
                              : Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (c.collectionType == CollectionType.home) ...[
                              const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              'Home Collection',
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 0.1,
                                fontWeight: FontWeight.bold,
                                color: c.collectionType == CollectionType.home
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => c.setCollectionType(CollectionType.lab),
                      child: Container(
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: c.collectionType == CollectionType.lab
                              ? AppColors.primary
                              : Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (c.collectionType == CollectionType.lab) ...[
                              const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              'Visit Lab',
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 0.1,
                                fontWeight: FontWeight.bold,
                                color: c.collectionType == CollectionType.lab
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            title: const Text('Preferred Date'),
            subtitle: Text(DateFormat('EEE, dd MMM yyyy').format(c.date)),
            trailing: const Icon(Icons.calendar_month_rounded),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                initialDate: c.date,
              );
              if (d != null) c.setDate(d);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SlotSelectorWidget(
            slots: c.slots,
            selectedSlot: c.slot,
            onSelect: c.setSlot,
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
          onPressed: () => _push(
            context,
            c.collectionType == CollectionType.home
                ? const AddressScreen()
                : const PaymentScreen(),
          ),
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Continue'),
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
