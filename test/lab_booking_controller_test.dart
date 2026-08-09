import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:biohelix_app/patient_portal/lab_booking/state/lab_booking_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'preselects only active recommended tests and keeps the cart editable',
    () {
      final controller = LabBookingController(
        patientName: 'Patient',
        tests: const [
          LabTestItem(
            id: 11,
            testName: 'CBC',
            categoryId: 1,
            categoryName: 'Hematology',
            status: true,
            basePrice: 250,
          ),
          LabTestItem(
            id: 12,
            testName: 'Inactive Test',
            categoryId: 1,
            categoryName: 'Hematology',
            status: false,
            basePrice: 500,
          ),
          LabTestItem(
            id: 13,
            testName: 'TSH',
            categoryId: 2,
            categoryName: 'Thyroid',
            status: true,
            basePrice: 350,
          ),
        ],
        bodyPoints: const [],
        initialTestIds: const [11, 12, 999],
      );

      expect(controller.preselectedCount, 1);
      expect(controller.cart.map((item) => item.test.id), [11]);

      final tsh = controller.filteredTests.singleWhere((test) => test.id == 13);
      expect(controller.addToCart(tsh), isTrue);
      controller.updateQty(11, 0);

      expect(controller.cart.map((item) => item.test.id), [13]);
    },
  );
}
