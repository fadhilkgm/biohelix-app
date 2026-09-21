import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/lab_booking/models/lab_booking_models.dart';
import 'package:biohelix_app/patient_portal/lab_booking/state/lab_booking_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _bareTest = LabTestItem(
  id: 21,
  testName: 'CBC',
  categoryId: 1,
  categoryName: 'Hematology',
  status: true,
  basePrice: 400,
);

void main() {
  group('BookableLabTest.fromLabTest', () {
    test('carries real catalogue fields and invents nothing', () {
      const item = LabTestItem(
        id: 22,
        testName: 'Fasting Blood Sugar',
        categoryId: 3,
        categoryName: 'Diabetes',
        status: true,
        basePrice: 300,
        discountedPrice: 240,
        instructions: 'Fast for 10 hours.',
        resultEta: 'Same day',
      );

      final bookable = BookableLabTest.fromLabTest(item);

      expect(bookable.preparation, 'Fast for 10 hours.');
      expect(bookable.resultEta, 'Same day');
      expect(bookable.categoryName, 'Diabetes');
      expect(bookable.price, 240);
      expect(bookable.basePrice, 300);
      expect(bookable.isDiscounted, isTrue);
    });

    test('leaves clinical fields null when the API supplies none', () {
      final bookable = BookableLabTest.fromLabTest(_bareTest);

      // Guessed preparation advice and placeholder marker lists must never be
      // shown to a patient, so absent data stays absent.
      expect(bookable.preparation, isNull);
      expect(bookable.resultEta, isNull);
      expect(bookable.price, 400);
      expect(bookable.isDiscounted, isFalse);
    });
  });

  group('LabBookingController patient and address seeding', () {
    test('keeps demographics empty rather than guessing an age or gender', () {
      final controller = LabBookingController(
        patientName: 'Asha',
        tests: const [_bareTest],
        bodyPoints: const [],
      );

      final patient = controller.selectedPatient;
      expect(patient.age, isNull);
      expect(patient.gender, isNull);
      expect(patient.demographicsLabel, isNull);
      expect(controller.addresses, isEmpty);
      expect(controller.selectedAddress, isNull);
    });

    test(
      'seeds only the registered address and formats known demographics',
      () {
        final controller = LabBookingController(
          patientName: 'Asha',
          patientAge: 42,
          patientGender: 'Female',
          patientAddress: '12 Beach Road, Ponnani',
          tests: const [_bareTest],
          bodyPoints: const [],
        );

        expect(controller.selectedPatient.demographicsLabel, '42 yrs • Female');
        expect(controller.addresses, hasLength(1));
        expect(
          controller.selectedAddress?.fullAddress,
          '12 Beach Road, Ponnani',
        );
      },
    );
  });
}
