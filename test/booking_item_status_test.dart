import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:flutter_test/flutter_test.dart';

BookingItem _booking({
  String date = '2026-08-02',
  String timeslot = '10:00-10:15',
  String status = 'confirmed',
}) {
  return BookingItem(
    id: 1,
    bookingDate: date,
    timeslot: timeslot,
    status: status,
    doctorId: 1,
    doctorName: 'Dr Test',
  );
}

void main() {
  group('BookingItem effectiveStatus', () {
    test('keeps an appointment upcoming until its slot ends', () {
      final booking = _booking();

      expect(
        booking.effectiveStatus(now: DateTime(2026, 8, 2, 10, 14)),
        'confirmed',
      );
    });

    test('marks an open appointment missed when its slot ends', () {
      final booking = _booking();

      expect(
        booking.effectiveStatus(now: DateTime(2026, 8, 2, 10, 15)),
        'missed',
      );
    });

    test('supports twelve-hour appointment ranges', () {
      final booking = _booking(timeslot: '09:00 AM - 09:30 AM');

      expect(
        booking.effectiveStatus(now: DateTime(2026, 8, 2, 9, 31)),
        'missed',
      );
    });

    test('uses a fifteen-minute duration for a single start time', () {
      final booking = _booking(timeslot: '10:30 AM');

      expect(
        booking.effectiveStatus(now: DateTime(2026, 8, 2, 10, 44)),
        'confirmed',
      );
      expect(
        booking.effectiveStatus(now: DateTime(2026, 8, 2, 10, 45)),
        'missed',
      );
    });

    test('does not override completed or cancelled statuses', () {
      expect(
        _booking(
          status: 'completed',
        ).effectiveStatus(now: DateTime(2026, 8, 3)),
        'completed',
      );
      expect(
        _booking(
          status: 'cancelled',
        ).effectiveStatus(now: DateTime(2026, 8, 3)),
        'cancelled',
      );
    });

    test('normalizes the backend no-show status for display', () {
      expect(_booking(status: 'no_show').effectiveStatus(), 'missed');
    });
  });

  group('DoctorSlotAvailability', () {
    test('keeps a slot enabled while one of two places remains', () {
      final slot = DoctorSlotAvailability.fromJson({
        'slot': '09:00-09:15',
        'bookedCount': 1,
        'capacity': 2,
        'remainingCapacity': 1,
        'isAvailable': true,
      });

      expect(slot.isAvailable, isTrue);
      expect(slot.remainingCapacity, 1);
    });

    test('disables a slot after both places are booked', () {
      final slot = DoctorSlotAvailability.fromJson({
        'slot': '09:00-09:15',
        'bookedCount': 2,
        'capacity': 2,
        'remainingCapacity': 0,
        'isAvailable': false,
      });

      expect(slot.isAvailable, isFalse);
      expect(slot.remainingCapacity, 0);
    });
  });
}
