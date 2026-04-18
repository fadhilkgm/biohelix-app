import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../state/lab_booking_controller.dart';
import '../widgets/address_card_widget.dart';
import 'payment_screen.dart';

class AddressScreen extends StatelessWidget {
  const AddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LabBookingController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Select Address')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ...c.addresses.map(
            (a) => AddressCardWidget(
              address: a,
              selected: c.selectedAddressId == a.id,
              onTap: () => c.setAddress(a.id),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showAddAddressDialog(context, c),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add New Address'),
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
          onPressed: () => _push(context, const PaymentScreen()),
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Proceed to Payment'),
        ),
      ),
    );
  }

  Future<void> _showAddAddressDialog(
    BuildContext context,
    LabBookingController c,
  ) async {
    final label = TextEditingController();
    final address = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Full address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (label.text.trim().isNotEmpty &&
                  address.text.trim().isNotEmpty) {
                c.addAddress(
                  label: label.text.trim(),
                  fullAddress: address.text.trim(),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
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
}
