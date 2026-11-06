part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalBookingMixin on PatientPortalProvider {
  Future<LabOrderQuote> quoteLabOrder({
    required List<int> labTestIds,
    required String collectionType,
  }) {
    return _repository.quoteLabOrder(
      labTestIds: labTestIds,
      collectionType: collectionType,
    );
  }

  Future<BookingConfirmation> createBooking({
    required int doctorId,
    required String bookingDate,
    required String timeslot,
    int? patientId,
    String? notes,
    String? sourceAssessmentToken,
    String? idempotencyKey,
  }) async {
    if (_sessionProvider.patient == null) {
      throw StateError('Patient session is missing.');
    }

    final scope = _patientScopeRevision;
    _isCreatingBooking = true;
    _errorMessage = null;
    _notify();

    try {
      final confirmation = await _repository.createBooking(
        doctorId: doctorId,
        bookingDate: bookingDate,
        timeslot: timeslot,
        patientId: patientId,
        notes: notes,
        sourceAssessmentToken: sourceAssessmentToken,
        idempotencyKey: idempotencyKey,
      );
      if (_isCurrentScope(scope)) await _refreshDoctorBookings();
      return confirmation;
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isCreatingBooking = false;
        _notify();
      }
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
    String? sourceAssessmentToken,
    String? idempotencyKey,
  }) async {
    final scope = _patientScopeRevision;
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
        sourceAssessmentToken: sourceAssessmentToken,
        idempotencyKey: idempotencyKey,
      );
      if (_isCurrentScope(scope)) await _refreshLabOrders();
      return confirmation;
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isCreatingLabOrder = false;
        _notify();
      }
    }
  }

  Future<void> cancelLabOrder(int orderId) async {
    final scope = _patientScopeRevision;
    _isCreatingLabOrder = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.cancelLabOrder(orderId);
      if (_isCurrentScope(scope)) await _refreshLabOrders();
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isCreatingLabOrder = false;
        _notify();
      }
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
    final scope = _patientScopeRevision;
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
      if (_isCurrentScope(scope)) await _refreshLabPackageOrders();
      return confirmation;
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isCreatingLabOrder = false;
        _notify();
      }
    }
  }

  Future<void> cancelLabPackageOrder(int orderId) async {
    final scope = _patientScopeRevision;
    _isCreatingLabOrder = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.cancelLabPackageOrder(orderId);
      if (_isCurrentScope(scope)) await _refreshLabPackageOrders();
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isCreatingLabOrder = false;
        _notify();
      }
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
      return doctor == null
          ? slots
          : _filterSlotsForDoctorDate(doctor, date, slots);
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
            intervalMinutes: doctor.slotDurationMinutes ?? 15,
          ),
        )
        .toList();
  }

  Future<List<DoctorSlotAvailability>> getDoctorSlotAvailability({
    required int doctorId,
    required String date,
  }) async {
    final doctor = _doctorById(doctorId);
    try {
      final availability = await _repository.getDoctorSlotAvailability(
        doctorId: doctorId,
        date: date,
      );
      if (doctor == null) return availability;
      final allowedSlots = _filterSlotsForDoctorDate(
        doctor,
        date,
        availability.map((item) => item.slot).toList(),
      ).toSet();
      return availability
          .where((item) => allowedSlots.contains(item.slot))
          .toList();
    } catch (_) {
      // Fall back to schedule templates when the availability API is offline.
    }

    final slots = await getDoctorAvailableSlots(doctorId: doctorId, date: date);
    return slots.map((slot) => DoctorSlotAvailability.available(slot)).toList();
  }

  Future<List<BookingItem>> getBookingsForPatient(int? patientId) {
    if (patientId == null) return Future.value(bookings);
    return _repository.getBookings(patientId: patientId);
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

    final step = intervalMinutes > 0 ? intervalMinutes : 15;
    final slots = <String>[];
    for (var minute = start; minute < end; minute += step) {
      slots.add(_timeFromMinutes(minute));
    }
    return slots;
  }

  int? _minutesFromTime(String value) {
    final match = RegExp(
      r'^\s*(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period =
        (match.group(3) ??
                (value.contains('-')
                    ? RegExp(
                        r'(AM|PM)\s*$',
                        caseSensitive: false,
                      ).firstMatch(value)?.group(1)
                    : null))
            ?.toUpperCase();
    if (minute > 59 || hour > 23) return null;
    if (period != null) {
      if (hour < 1 || hour > 12) return null;
      hour = hour % 12 + (period == 'PM' ? 12 : 0);
    }
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
    final scope = _patientScopeRevision;
    _isCreatingBooking = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.cancelBooking(bookingId);
      if (_isCurrentScope(scope)) await _refreshDoctorBookings();
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isCreatingBooking = false;
        _notify();
      }
    }
  }

  Future<void> checkInBooking(int bookingId) async {
    final scope = _patientScopeRevision;
    _isCreatingBooking = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.checkInBooking(bookingId);
      if (_isCurrentScope(scope)) await _refreshDoctorBookings();
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isCreatingBooking = false;
        _notify();
      }
    }
  }

  Future<void> rescheduleBooking({
    required int bookingId,
    required String bookingDate,
    required String timeslot,
  }) async {
    final scope = _patientScopeRevision;
    _isCreatingBooking = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.rescheduleBooking(
        bookingId: bookingId,
        bookingDate: bookingDate,
        timeslot: timeslot,
      );
      if (_isCurrentScope(scope)) await _refreshDoctorBookings();
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isCreatingBooking = false;
        _notify();
      }
    }
  }

  Future<void> rescheduleLabOrder({
    required int orderId,
    required String date,
    String? slot,
  }) async {
    final scope = _patientScopeRevision;
    _isCreatingLabOrder = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.rescheduleLabOrder(
        orderId: orderId,
        date: date,
        slot: slot,
      );
      if (_isCurrentScope(scope)) await _refreshLabOrders();
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isCreatingLabOrder = false;
        _notify();
      }
    }
  }

  Future<void> rescheduleLabPackageOrder({
    required int orderId,
    required String date,
    String? slot,
  }) async {
    final scope = _patientScopeRevision;
    _isCreatingLabOrder = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.rescheduleLabPackageOrder(
        orderId: orderId,
        date: date,
        slot: slot,
      );
      if (_isCurrentScope(scope)) await _refreshLabPackageOrders();
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isCreatingLabOrder = false;
        _notify();
      }
    }
  }
}
