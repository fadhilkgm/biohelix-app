import 'package:flutter/material.dart';

import '../models/booking_payment_method.dart';

class BookingPaymentMethodSelector extends StatelessWidget {
  const BookingPaymentMethodSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.payOnArrivalTitle = 'Pay at Collection',
    this.payOnArrivalSubtitle = 'Pay when the sample is collected',
  });

  final BookingPaymentMethod value;
  final ValueChanged<BookingPaymentMethod> onChanged;
  final String payOnArrivalTitle;
  final String payOnArrivalSubtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _BookingPaymentOption(
            title: 'Online Payment',
            subtitle: 'Credit Card, UPI, Wallets',
            icon: Icons.payments_outlined,
            selected: value == BookingPaymentMethod.online,
            onTap: () => onChanged(BookingPaymentMethod.online),
          ),
          const Divider(height: 1, indent: 64),
          _BookingPaymentOption(
            title: payOnArrivalTitle,
            subtitle: payOnArrivalSubtitle,
            icon: Icons.handshake_outlined,
            selected: value == BookingPaymentMethod.payOnArrival,
            onTap: () => onChanged(BookingPaymentMethod.payOnArrival),
          ),
        ],
      ),
    );
  }
}

class _BookingPaymentOption extends StatelessWidget {
  const _BookingPaymentOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF06489B)
                    : const Color(0xFFF4F7FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF06489B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? const Color(0xFF06489B)
                  : const Color(0xFF8A94A6),
            ),
          ],
        ),
      ),
    );
  }
}
