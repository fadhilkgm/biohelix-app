import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('doctor listing parses v1 catalogue fields', () {
    final doctor = DoctorListing.fromJson({
      'id': 1,
      'doctor_code': 'DOC-000001',
      'name': 'Dr Ali',
      'specialization': 'Skin',
      'qualification': 'MBBS, MD',
      'consultation_fee': '100.00',
      'profile_photo_url': 'https://example.test/doctor.png',
      'schedules': [
        {
          'id': 7,
          'day_of_week': 'monday',
          'session_name': 'morning',
          'start_time': '10:00:00',
          'end_time': '12:00:00',
        },
      ],
    });

    expect(doctor.id, 1);
    expect(doctor.qualifications, 'MBBS, MD');
    expect(doctor.consultationFee, 100);
    expect(doctor.imageUrl, 'https://example.test/doctor.png');
    expect(doctor.schedules.single.id, 7);
    expect(doctor.availabilityWindowLabel, '10:00 AM - 12:00 PM');
  });

  test('lab test listing parses v1 catalogue fields', () {
    final test = LabTestItem.fromJson({
      'id': 5,
      'test_code': '293',
      'test_name': '10% KOH MOUNT',
      'category': 'Microbiology',
      'price': '20.00',
      'description': 'Sample description',
      'status': 'active',
    });

    expect(test.id, 5);
    expect(test.testName, '10% KOH MOUNT');
    expect(test.categoryName, 'Microbiology');
    expect(test.basePrice, 20);
    expect(test.instructions, 'Sample description');
    expect(test.status, isTrue);
  });

  test('package listing parses v1 catalogue fields and decimal prices', () {
    final package = LabPackageItem.fromJson({
      'id': 1,
      'package_code': 'PKG-000001',
      'package_name': 'Executive Package',
      'description': 'Complete checkup',
      'price': '2000.00',
      'discounted_price': '1988.00',
      'status': 'active',
      'image_url': 'https://example.test/package.png',
      'tests': [
        {'id': 6, 'test_code': '306', 'test_name': '17-OH- PROGESTERONE'},
      ],
      'test_count': 1,
    });

    expect(package.id, 1);
    expect(package.slug, 'PKG-000001');
    expect(package.name, 'Executive Package');
    expect(package.basePrice, 2000);
    expect(package.discountedPrice, 1988);
    expect(package.imageUrl, 'https://example.test/package.png');
    expect(package.includedTests, ['17-OH- PROGESTERONE']);
    expect(package.totalTests, 1);
    expect(package.status, isTrue);
  });
}
