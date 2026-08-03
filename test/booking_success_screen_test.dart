import 'package:biohelix_app/patient_portal/core/widgets/booking_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the back action visible on a compact phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: BookingSuccessScreen(
          bookingId: 'BKG-42',
          showMedicalSuccessIcon: true,
          title: 'Appointment Booked!',
          subtitle:
              'Your session has been successfully scheduled. You can track your upcoming sessions in the bookings tab.',
          doctorName: 'Dr. Test',
          doctorSpecialization: 'General Medicine',
          bookingDate: 'Sun, 2 Aug 2026',
          bookingTime: '09:00 AM',
        ),
      ),
    );
    await tester.pump();

    final backButton = find.widgetWithText(ElevatedButton, 'Back');
    final successIcon = find.byIcon(Icons.medical_services_outlined);

    expect(backButton, findsOneWidget);
    expect(backButton.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(backButton).dy, lessThanOrEqualTo(655));
    expect(tester.getTopLeft(successIcon).dy, lessThan(100));
  });
}
