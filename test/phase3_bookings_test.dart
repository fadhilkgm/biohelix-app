import 'dart:convert';
import 'dart:typed_data';

import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('doctor booking posts mobile payload to /bookings', () async {
    final adapter = _BookingAdapter({'success': true, 'bookingId': 42});
    final repository = _repository(adapter);

    final confirmation = await repository.createBooking(
      doctorId: 1,
      bookingDate: '2026-06-25',
      timeslot: '09:00-09:15',
      notes: 'First consultation.',
    );

    expect(adapter.lastPath, '/bookings');
    expect(adapter.lastData, {
      'doctorId': 1,
      'bookingDate': '2026-06-25',
      'timeslot': '09:00-09:15',
      'notes': 'First consultation.',
    });
    expect(confirmation.reference, 'BKG-42');
    expect(confirmation.id, 42);
  });

  test('doctor booking omits notes when empty', () async {
    final adapter = _BookingAdapter({'success': true, 'bookingId': 43});
    final repository = _repository(adapter);

    await repository.createBooking(
      doctorId: 2,
      bookingDate: '2026-06-26',
      timeslot: '10:00-10:15',
    );

    expect(adapter.lastData, {
      'doctorId': 2,
      'bookingDate': '2026-06-26',
      'timeslot': '10:00-10:15',
    });
  });

  test('lab order posts camelCase payload to /patient/lab-orders', () async {
    final adapter = _BookingAdapter({
      'success': true,
      'batchId': '4a7b53cc-cd21-4f11-8e9a-4122d2ee5bb2',
    });
    final repository = _repository(adapter);

    final confirmation = await repository.createLabOrder(
      labTestIds: [1, 2],
      date: '2026-06-25',
      slot: '08:30',
      notes: 'Fasting sample.',
    );

    expect(adapter.lastPath, '/patient/lab-orders');
    expect(adapter.lastData, {
      'labTestIds': [1, 2],
      'date': '2026-06-25',
      'slot': '08:30',
      'paymentStatus': 'pending',
      'collectionType': 'home',
      'urgency': 'routine',
      'notes': 'Fasting sample.',
    });
    expect(confirmation.reference, '4a7b53cc-cd21-4f11-8e9a-4122d2ee5bb2');
    expect(confirmation.batchId, '4a7b53cc-cd21-4f11-8e9a-4122d2ee5bb2');
  });

  test('lab order with single test id sends correct payload', () async {
    final adapter = _BookingAdapter({
      'success': true,
      'batchId': 'aaa-bbb-ccc',
    });
    final repository = _repository(adapter);

    await repository.createLabOrder(
      labTestId: 5,
      date: '2026-06-25',
      slot: '09:00',
    );

    expect(adapter.lastData, {
      'labTestIds': [5],
      'date': '2026-06-25',
      'slot': '09:00',
      'paymentStatus': 'pending',
      'collectionType': 'home',
      'urgency': 'routine',
    });
  });

  test('lab order omits slot when not provided', () async {
    final adapter = _BookingAdapter({'success': true, 'batchId': 'x-y-z'});
    final repository = _repository(adapter);

    await repository.createLabOrder(
      labTestIds: [3],
      date: '2026-06-25',
    );

    expect((adapter.lastData as Map).containsKey('slot'), isFalse);
  });

  test('lab package order posts camelCase payload to /patient/lab-package-orders',
      () async {
    final adapter = _BookingAdapter({'success': true, 'bookingId': 60});
    final repository = _repository(adapter);

    final confirmation = await repository.createLabPackageOrder(
      labPackageId: 1,
      date: '2026-06-25',
      slot: '08:30',
      notes: 'Morning preferred.',
    );

    expect(adapter.lastPath, '/patient/lab-package-orders');
    expect(adapter.lastData, {
      'packageId': 1,
      'date': '2026-06-25',
      'slot': '08:30',
      'paymentStatus': 'pending',
      'collectionType': 'home',
      'urgency': 'routine',
      'notes': 'Morning preferred.',
    });
    expect(confirmation.reference, 'BKG-60');
    expect(confirmation.id, 60);
  });

  test('cancel booking calls correct PATCH path', () async {
    final adapter = _BookingAdapter({'success': true});
    final repository = _repository(adapter);

    await repository.cancelBooking(7);

    expect(adapter.lastPath, '/patients/bookings/7/cancel');
    expect(adapter.lastMethod, 'PATCH');
  });

  test('cancel lab order sends status=cancelled to /patient/lab-orders/{id}',
      () async {
    final adapter = _BookingAdapter({'success': true});
    final repository = _repository(adapter);

    await repository.cancelLabOrder(3);

    expect(adapter.lastPath, '/patient/lab-orders/3');
    expect(adapter.lastMethod, 'PATCH');
    expect(adapter.lastData, {'status': 'cancelled'});
  });

  test(
      'cancel lab package order sends status=cancelled to /patient/lab-package-orders/{id}',
      () async {
    final adapter = _BookingAdapter({'success': true});
    final repository = _repository(adapter);

    await repository.cancelLabPackageOrder(8);

    expect(adapter.lastPath, '/patient/lab-package-orders/8');
    expect(adapter.lastMethod, 'PATCH');
    expect(adapter.lastData, {'status': 'cancelled'});
  });

  test('reschedule booking calls /patients/bookings/{id}/reschedule', () async {
    final adapter = _BookingAdapter({'success': true});
    final repository = _repository(adapter);

    await repository.rescheduleBooking(
      bookingId: 5,
      bookingDate: '2026-06-28',
      timeslot: '10:00-10:15',
    );

    expect(adapter.lastPath, '/patients/bookings/5/reschedule');
    expect(adapter.lastMethod, 'PATCH');
    expect(adapter.lastData, {
      'bookingDate': '2026-06-28',
      'timeslot': '10:00-10:15',
    });
  });

  test('reschedule lab order calls /patient/lab-orders/{id}', () async {
    final adapter = _BookingAdapter({'success': true});
    final repository = _repository(adapter);

    await repository.rescheduleLabOrder(
      orderId: 3,
      date: '2026-06-28',
      slot: '09:30',
    );

    expect(adapter.lastPath, '/patient/lab-orders/3');
    expect(adapter.lastMethod, 'PATCH');
    expect(adapter.lastData, {'date': '2026-06-28', 'slot': '09:30'});
  });

  test('get lab tests calls /patient/lab-tests', () async {
    final adapter = _BookingAdapter({
      'tests': [
        {
          'id': 5,
          'testName': '10% KOH MOUNT',
          'status': true,
          'basePrice': 0,
          'bodyPoints': [],
        }
      ]
    });
    final repository = _repository(adapter);

    final tests = await repository.getLabTests();

    expect(adapter.lastPath, '/patient/lab-tests');
    expect(adapter.lastMethod, 'GET');
    expect(tests.length, 1);
    expect(tests.first.testName, '10% KOH MOUNT');
  });

  test('get lab packages calls /patient/lab-packages', () async {
    final adapter = _BookingAdapter({
      'packages': [
        {
          'id': 1,
          'name': 'Basic Health Package',
          'slug': 'basic-health-package',
          'status': true,
          'basePrice': 1200,
          'totalTests': 2,
          'includedTests': [
            {'testName': 'CBC'}
          ],
        }
      ]
    });
    final repository = _repository(adapter);

    final packages = await repository.getLabPackages();

    expect(adapter.lastPath, '/patient/lab-packages');
    expect(adapter.lastMethod, 'GET');
    expect(packages.length, 1);
    expect(packages.first.name, 'Basic Health Package');
  });

  test('BookingConfirmation parses legacy booking_number response', () {
    final c = BookingConfirmation.fromBookingResponse({
      'id': 14,
      'booking_number': 'BKG-20260613-0044',
    });
    expect(c.reference, 'BKG-20260613-0044');
    expect(c.id, 14);
  });

  test('BookingConfirmation parses mobile bookingId response', () {
    final c = BookingConfirmation.fromBookingResponse({
      'success': true,
      'bookingId': 42,
    });
    expect(c.reference, 'BKG-42');
    expect(c.id, 42);
  });

  test('BookingConfirmation.fromTestBatchResponse parses mobile batchId', () {
    final c = BookingConfirmation.fromTestBatchResponse({
      'success': true,
      'batchId': '9d0dbd83-c4e2-49a1-b8bc-2e2b8bf49d88',
    });
    expect(c.reference, '9d0dbd83-c4e2-49a1-b8bc-2e2b8bf49d88');
    expect(c.batchId, '9d0dbd83-c4e2-49a1-b8bc-2e2b8bf49d88');
  });

  test('BookingConfirmation.fromTestBatchResponse parses legacy batch_id', () {
    final c = BookingConfirmation.fromTestBatchResponse({
      'batch_id': 'aaa-bbb-ccc',
      'bookings': [
        {'id': 52, 'booking_number': 'BKG-000052'},
      ],
    });
    expect(c.reference, 'aaa-bbb-ccc');
    expect(c.batchId, 'aaa-bbb-ccc');
    expect(c.id, 52);
  });

  test('BookingItem excludes lab test bookings from doctor appointments', () {
    final doctorBooking = BookingItem.fromJson({
      'id': 1,
      'bookingDate': '2026-06-22',
      'timeslot': '09:00-09:15',
      'status': 'pending',
      'type': 'doctor',
      'doctorId': 1,
      'doctorName': 'Dr. Sarah Paul',
      'doctorSpecialization': 'Cardiology',
    });
    final labBooking = BookingItem.fromJson({
      'id': 2,
      'bookingDate': '2026-06-22',
      'timeslot': '08:30',
      'status': 'pending',
      'type': 'test',
      'testName': 'Complete Blood Count',
      'doctorId': 1,
      'doctorName': 'Dr. Sarah Paul',
    });

    expect(doctorBooking.isDoctorAppointment, isTrue);
    expect(labBooking.isDoctorAppointment, isFalse);
  });

  test('SummaryRecord maps API title and createdAt fields', () {
    final summary = SummaryRecord.fromJson({
      'id': 3,
      'title': 'Cardiology follow-up',
      'createdAt': '2026-06-20',
      'summary': 'Stable condition.',
    });

    expect(summary.type, 'Cardiology follow-up');
    expect(summary.date, '2026-06-20');
  });

  test('MyClubSummary parses flat pointsBalance response', () {
    final club = MyClubSummary.fromJson({
      'membership': {'tier': 'Gold'},
      'pointsBalance': 420,
      'plans': [],
    });

    expect(club.points, 420);
    expect(club.tier, 'Gold');
  });

  test('HealthSnapshot parses snake_case payload', () {
    final snapshot = HealthSnapshot.fromJson({
      'health_score': 82,
      'risk_score': 18,
      'bmi': 24.2,
      'ai_summary': 'Looking good.',
      'generated_at': '2026-06-30T10:00:00Z',
    });

    expect(snapshot.healthScore, 82);
    expect(snapshot.riskScore, 18);
    expect(snapshot.bmi, closeTo(24.2, 0.01));
  });

  test(
    'HealthSnapshot parses full documented payload incl. manual fields and '
    'combined-bp latest_vitals',
    () {
      final snapshot = HealthSnapshot.fromJson({
        'success': true,
        'snapshot': {
          'snapshot_date': '2026-07-02',
          'bmi': 24.3,
          'blood_sugar': 110.0,
          'cholesterol': 205.0,
          'risk_score': 45.0,
          'health_score': 55.0,
          'latest_vitals': {
            'bp': '128/82',
            'heart_rate': null,
            'temperature': 37.1,
            'weight': 74.5,
            'height': 172,
            'bmi': 24.3,
            'oxygen_saturation': 98,
            'recorded_at': '2026-07-01T09:00:00+00:00',
          },
          'latest_results': null,
          'other_conditions': 'Mild fever since yesterday, sore throat',
          'ai_summary': 'Health score: 55/100. Key findings: ...',
          'generated_at': '2026-07-02T10:20:00+00:00',
        },
      });

      expect(snapshot.snapshotDate, '2026-07-02');
      expect(snapshot.healthScore, 55.0);
      expect(snapshot.riskScore, 45.0);
      expect(snapshot.bloodSugar, 110.0);
      expect(snapshot.cholesterol, 205.0);
      expect(
        snapshot.otherConditions,
        'Mild fever since yesterday, sore throat',
      );
      expect(snapshot.latestResults, isNull);
      expect(snapshot.isEmpty, isFalse);

      final vitals = snapshot.latestVitals;
      expect(vitals, isNotNull);
      expect(vitals!.bloodPressureSystolic, 128);
      expect(vitals.bloodPressureDiastolic, 82);
      expect(vitals.bodyTemperature, closeTo(37.1, 0.01));
      expect(vitals.oxygenSaturation, 98);
      expect(vitals.weight, closeTo(74.5, 0.01));
      expect(vitals.heartRate, isNull);
    },
  );

  test('HealthSnapshot.isEmpty is true when no data has been recorded', () {
    const snapshot = HealthSnapshot();
    expect(snapshot.isEmpty, isTrue);
  });

  test('HealthSnapshotHistoryPage parses snapshots list and meta', () {
    final page = HealthSnapshotHistoryPage.fromJson({
      'success': true,
      'snapshots': [
        {'snapshot_date': '2026-07-02', 'health_score': 55.0},
        {'snapshot_date': '2026-07-01', 'health_score': 70.0},
      ],
      'meta': {'current_page': 1, 'last_page': 3, 'total': 62},
    });

    expect(page.items, hasLength(2));
    expect(page.items.first.snapshotDate, '2026-07-02');
    expect(page.items.first.healthScore, 55.0);
    expect(page.currentPage, 1);
    expect(page.lastPage, 3);
    expect(page.total, 62);
    expect(page.hasMore, isTrue);
  });

  test(
    'submitHealthSnapshot posts camelCase body to /patients/me/health-snapshot',
    () async {
      final adapter = _BookingAdapter({
        'success': true,
        'snapshot': {
          'snapshot_date': '2026-07-02',
          'health_score': 60.0,
          'risk_score': 40.0,
          'other_conditions': 'Sore throat',
        },
        'message': 'Health snapshot recorded.',
      });
      final repository = _repository(adapter);

      final snapshot = await repository.submitHealthSnapshot(
        const HealthSnapshotInput(
          bloodPressureSystolic: 128,
          bloodPressureDiastolic: 82,
          bloodSugar: 110,
          cholesterol: 205,
          weight: 74.5,
          otherConditions: 'Sore throat',
        ),
      );

      expect(adapter.lastPath, '/patients/me/health-snapshot');
      expect(adapter.lastMethod, 'POST');
      expect(adapter.lastData, {
        'bloodPressureSystolic': 128,
        'bloodPressureDiastolic': 82,
        'bloodSugar': 110.0,
        'cholesterol': 205.0,
        'weight': 74.5,
        'otherConditions': 'Sore throat',
      });
      expect(snapshot.healthScore, 60.0);
      expect(snapshot.otherConditions, 'Sore throat');
    },
  );

  test('HealthSnapshotInput.toJson omits null fields', () {
    const input = HealthSnapshotInput(otherConditions: 'Mild fever');
    expect(input.toJson(), {'otherConditions': 'Mild fever'});
  });

  test(
    'getHealthSnapshotHistory requests the given page and parses the response',
    () async {
      final adapter = _BookingAdapter({
        'success': true,
        'snapshots': [
          {'snapshot_date': '2026-06-20', 'health_score': 65.0},
        ],
        'meta': {'current_page': 2, 'last_page': 2, 'total': 21},
      });
      final repository = _repository(adapter);

      final page = await repository.getHealthSnapshotHistory(page: 2);

      expect(adapter.lastPath, '/patients/me/health-snapshot/history');
      expect(page.items, hasLength(1));
      expect(page.currentPage, 2);
      expect(page.hasMore, isFalse);
    },
  );

  test('AiSuggestionItem parses recommendation payload', () {
    final item = AiSuggestionItem.fromJson({
      'id': 9,
      'recommendation_type': 'preventive_screening',
      'reason': 'Based on your profile',
      'score': 0.91,
      'is_accepted': false,
      'item': {
        'type': 'lab_test',
        'id': 12,
        'test_name': 'Lipid Profile',
      },
    });

    expect(item.isLabTest, isTrue);
    expect(item.itemName, 'Lipid Profile');
    expect(item.labTestId, 12);
  });
}

PatientRepository _repository(_BookingAdapter adapter) {
  final client = ApiClient(
    config: AppConfig(
      appName: 'BioHelix Test',
      apiBaseUrl: 'http://localhost:8000/api/v1',
      healthEndpoint: '/health',
      showDevOtp: false,
    ),
    httpClientAdapter: adapter,
  );
  return PatientRepository(apiClient: client);
}

class _BookingAdapter implements HttpClientAdapter {
  _BookingAdapter(this.response);

  final Map<String, dynamic> response;
  String? lastPath;
  String? lastMethod;
  Object? lastData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastMethod = options.method;
    lastData = options.data;
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
