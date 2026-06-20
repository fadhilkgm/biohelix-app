part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalBookingMixin on PatientPortalProvider {
  Future<BookingConfirmation> createBooking({
    required int doctorId,
    required String bookingDate,
    required String timeslot,
    String? notes,
  }) async {
    if (_sessionProvider.patient == null) {
      throw StateError('Patient session is missing.');
    }

    _isCreatingBooking = true;
    _errorMessage = null;
    _notify();

    try {
      final confirmation = await _repository.createBooking(
        doctorId: doctorId,
        bookingDate: bookingDate,
        timeslot: timeslot,
        notes: notes,
      );
      await loadPortal();
      return confirmation;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isCreatingBooking = false;
      _notify();
    }
  }

  Future<BookingConfirmation> createLabOrder({
    int? labTestId,
    List<int>? labTestIds,
    int? doctorId,
    required String date,
    String? slot,
    String collectionType = 'home',
    String? address,
    double? amount,
    String paymentStatus = 'pending',
    String? patientNameSnapshot,
    int? patientAgeSnapshot,
    String? patientGenderSnapshot,
    String? patientPhoneSnapshot,
    String? bookingRef,
    String urgency = 'routine',
    String? notes,
  }) async {
    _isCreatingLabOrder = true;
    _errorMessage = null;
    _notify();

    try {
      final confirmation = await _repository.createLabOrder(
        labTestId: labTestId,
        labTestIds: labTestIds,
        doctorId: null, // Keep null as requested
        date: date,
        slot: slot,
        collectionType: collectionType,
        address: address,
        amount: amount,
        paymentStatus: paymentStatus,
        patientNameSnapshot: patientNameSnapshot,
        patientAgeSnapshot: patientAgeSnapshot,
        patientGenderSnapshot: patientGenderSnapshot,
        patientPhoneSnapshot: patientPhoneSnapshot,
        bookingRef: bookingRef,
        urgency: urgency,
        notes: notes,
      );
      await loadPortal();
      return confirmation;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isCreatingLabOrder = false;
      _notify();
    }
  }

  Future<void> cancelLabOrder(int orderId) async {
    _isCreatingLabOrder = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.cancelLabOrder(orderId);
      await loadPortal();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isCreatingLabOrder = false;
      _notify();
    }
  }

  Future<BookingConfirmation> createLabPackageOrder({
    required int labPackageId,
    int? doctorId,
    required String date,
    String? slot,
    String collectionType = 'home',
    String? address,
    double? amount,
    String paymentStatus = 'pending',
    String? patientNameSnapshot,
    int? patientAgeSnapshot,
    String? patientGenderSnapshot,
    String? patientPhoneSnapshot,
    String? bookingRef,
    String urgency = 'routine',
    String? notes,
  }) async {
    _isCreatingLabOrder = true;
    _errorMessage = null;
    _notify();

    try {
      final confirmation = await _repository.createLabPackageOrder(
        labPackageId: labPackageId,
        doctorId: null, // Keep null as requested
        date: date,
        slot: slot,
        collectionType: collectionType,
        address: address,
        amount: amount,
        paymentStatus: paymentStatus,
        patientNameSnapshot: patientNameSnapshot,
        patientAgeSnapshot: patientAgeSnapshot,
        patientGenderSnapshot: patientGenderSnapshot,
        patientPhoneSnapshot: patientPhoneSnapshot,
        bookingRef: bookingRef,
        urgency: urgency,
        notes: notes,
      );
      await loadPortal();
      return confirmation;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isCreatingLabOrder = false;
      _notify();
    }
  }

  Future<void> cancelLabPackageOrder(int orderId) async {
    _isCreatingLabOrder = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.cancelLabPackageOrder(orderId);
      await loadPortal();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isCreatingLabOrder = false;
      _notify();
    }
  }

  Future<List<String>> getDoctorAvailableSlots({
    required int doctorId,
    required String date,
  }) async {
    final doctor = _doctorById(doctorId);
    try {
      final slots = await _repository.getDoctorAvailableSlots(
        doctorId: doctorId,
        date: date,
      );
      if (slots.isNotEmpty) {
        return doctor == null
            ? slots
            : _filterSlotsForDoctorDate(doctor, date, slots);
      }
    } catch (_) {
      // The v1 API documents schedule templates on doctor listings, not slots.
    }

    if (doctor == null) return const [];

    final parsedDate = DateTime.tryParse(date);
    final day = parsedDate == null
        ? ''
        : DateFormat('EEEE').format(parsedDate).toLowerCase();
    final schedules = doctor.schedules
        .where((schedule) => schedule.dayOfWeek.toLowerCase() == day)
        .toList();

    return schedules
        .expand(
          (schedule) => _slotsForSchedule(
            schedule,
            intervalMinutes: doctor.slotDurationMinutes ?? 30,
          ),
        )
        .toList();
  }

  DoctorListing? _doctorById(int doctorId) {
    for (final item in _doctors) {
      if (item.id == doctorId) return item;
    }
    return null;
  }

  List<String> _filterSlotsForDoctorDate(
    DoctorListing doctor,
    String date,
    List<String> slots,
  ) {
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null || doctor.schedules.isEmpty) return slots;
    final day = DateFormat('EEEE').format(parsedDate).toLowerCase();
    final schedules = doctor.schedules
        .where((schedule) => schedule.dayOfWeek.toLowerCase() == day)
        .toList();
    if (schedules.isEmpty) return const [];

    return slots.where((slot) {
      final slotMinutes = _minutesFromTime(slot);
      if (slotMinutes == null) return false;
      for (final schedule in schedules) {
        final start = _minutesFromTime(schedule.startTime);
        final end = _minutesFromTime(schedule.endTime);
        if (start == null || end == null) continue;
        if (slotMinutes >= start && slotMinutes < end) return true;
      }
      return false;
    }).toList();
  }

  List<String> _slotsForSchedule(
    DoctorSchedule schedule, {
    required int intervalMinutes,
  }) {
    final start = _minutesFromTime(schedule.startTime);
    final end = _minutesFromTime(schedule.endTime);
    if (start == null || end == null || end <= start) return const [];

    final step = intervalMinutes > 0 ? intervalMinutes : 30;
    final slots = <String>[];
    for (var minute = start; minute < end; minute += step) {
      slots.add(_timeFromMinutes(minute));
    }
    return slots;
  }

  int? _minutesFromTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  String _timeFromMinutes(int value) {
    final hour = value ~/ 60;
    final minute = value % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> cancelBooking(int bookingId) async {
    _isCreatingBooking = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.cancelBooking(bookingId);
      await loadPortal();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isCreatingBooking = false;
      _notify();
    }
  }

  Future<void> checkInBooking(int bookingId) async {
    _isCreatingBooking = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.checkInBooking(bookingId);
      await loadPortal();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isCreatingBooking = false;
      _notify();
    }
  }

  Future<void> rescheduleBooking({
    required int bookingId,
    required String bookingDate,
    required String timeslot,
  }) async {
    _isCreatingBooking = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.rescheduleBooking(
        bookingId: bookingId,
        bookingDate: bookingDate,
        timeslot: timeslot,
      );
      await loadPortal();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isCreatingBooking = false;
      _notify();
    }
  }

  Future<void> rescheduleLabOrder({
    required int orderId,
    required String date,
    String? slot,
  }) async {
    _isCreatingLabOrder = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.rescheduleLabOrder(
        orderId: orderId,
        date: date,
        slot: slot,
      );
      await loadPortal();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isCreatingLabOrder = false;
      _notify();
    }
  }

  Future<void> rescheduleLabPackageOrder({
    required int orderId,
    required String date,
    String? slot,
  }) async {
    _isCreatingLabOrder = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.rescheduleLabPackageOrder(
        orderId: orderId,
        date: date,
        slot: slot,
      );
      await loadPortal();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isCreatingLabOrder = false;
      _notify();
    }
  }
}
