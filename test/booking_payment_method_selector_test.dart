import 'package:biohelix_app/patient_portal/bookings/models/booking_payment_method.dart';
import 'package:biohelix_app/patient_portal/bookings/widgets/booking_payment_method_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking payment methods map to shared API statuses', () {
    expect(BookingPaymentMethod.online.paymentStatus, 'paid');
    expect(
      BookingPaymentMethod.payOnArrival.paymentStatus,
      'pay_at_collection',
    );
  });

  testWidgets('shared payment selector updates package and test choices', (
    tester,
  ) async {
    var selected = BookingPaymentMethod.online;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: BookingPaymentMethodSelector(
              value: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Online Payment'), findsOneWidget);
    expect(find.text('Pay at Collection'), findsOneWidget);

    await tester.tap(find.text('Pay at Collection'));
    await tester.pump();

    expect(selected, BookingPaymentMethod.payOnArrival);
  });
}
