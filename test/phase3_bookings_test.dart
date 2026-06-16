import 'dart:convert';
import 'dart:typed_data';

import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/patient_portal/core/data/patient_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('doctor booking posts v1 payload and returns booking number', () async {
    final adapter = _BookingAdapter({
      'id': 14,
      'booking_number': 'BKG-20260613-0044',
    });
    final repository = _repository(adapter);

    final confirmation = await repository.createBooking(
      doctorId: 1,
      scheduleId: 7,
      bookingDate: '2026-06-15',
      timeslot: '10:30',
      notes: 'First consultation.',
    );

    expect(adapter.lastPath, '/bookings/doctors');
    expect(adapter.lastData, {
      'doctor_id': 1,
      'schedule_id': 7,
      'booking_date': '2026-06-15',
      'booking_time': '10:30',
      'notes': 'First consultation.',
    });
    expect(confirmation.reference, 'BKG-20260613-0044');
  });

  test('doctor booking accepts 12-hour AM PM labels', () async {
    final adapter = _BookingAdapter({
      'id': 15,
      'booking_number': 'BKG-20260613-0045',
    });
    final repository = _repository(adapter);

    await repository.createBooking(
      doctorId: 1,
      scheduleId: 7,
      bookingDate: '2026-06-15',
      timeslot: '1:30 PM',
    );

    expect(adapter.lastData, {
      'doctor_id': 1,
      'schedule_id': 7,
      'booking_date': '2026-06-15',
      'booking_time': '13:30',
    });
  });

  test(
    'test batch booking posts multiple test ids with normalized slot',
    () async {
      final adapter = _BookingAdapter({
        'batch_id': '4a7b53cc-cd21-4f11-8e9a-4122d2ee5bb2',
        'bookings': [
          {'id': 13, 'booking_number': 'BKG-20260613-0043'},
        ],
      });
      final repository = _repository(adapter);

      final confirmation = await repository.createLabOrder(
        labTestIds: [1, 2],
        date: '2026-06-15',
        slot: '08:00 - 09:00 AM',
        notes: 'Fasting sample.',
      );

      expect(adapter.lastPath, '/bookings/tests');
      expect(adapter.lastData, {
        'test_ids': [1, 2],
        'booking_date': '2026-06-15',
        'booking_time': '08:00',
        'notes': 'Fasting sample.',
      });
      expect(confirmation.reference, '4a7b53cc-cd21-4f11-8e9a-4122d2ee5bb2');
    },
  );

  test(
    'package booking posts v1 payload with normalized afternoon slot',
    () async {
      final adapter = _BookingAdapter({
        'id': 12,
        'booking_number': 'BKG-20260613-0042',
      });
      final repository = _repository(adapter);

      final confirmation = await repository.createLabPackageOrder(
        labPackageId: 1,
        date: '2026-06-15',
        slot: '01:00 - 02:00 PM',
        notes: 'Morning slot preferred.',
      );

      expect(adapter.lastPath, '/bookings/packages');
      expect(adapter.lastData, {
        'package_id': 1,
        'booking_date': '2026-06-15',
        'booking_time': '13:00',
        'notes': 'Morning slot preferred.',
      });
      expect(confirmation.reference, 'BKG-20260613-0042');
    },
  );
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
  Object? lastData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastData = options.data;
    return ResponseBody.fromString(
      jsonEncode(response),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
