import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/premium_home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home doctor card fits a two-line name without overflow', (
    tester,
  ) async {
    const doctor = DoctorListing(
      id: 8,
      name: 'Muhammed Shamsudheen',
      specialization: 'Pediatrics',
      departmentName: 'Pediatrics',
      availableTime: '2:00 PM - 6:00 PM',
      consultationFee: 500,
      imageUrl: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 278,
              height: 392,
              child: HomeDoctorCard(
                doc: doctor,
                onTap: _doNothing,
                resolvedImageUrl: '',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Muhammed Shamsudheen'), findsOneWidget);
    expect(find.text('Book Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _doNothing() {}
