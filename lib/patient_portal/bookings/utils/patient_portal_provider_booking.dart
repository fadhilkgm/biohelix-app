part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalBookingMixin on PatientPortalProvider {
  Future<void> createBooking({
    required int doctorId,
    required String bookingDate,
    required String timeslot,
  }) async {
    final patient = _sessionProvider.patient;
    if (patient == null) {
      throw StateError('Patient session is missing.');
    }

    _isCreatingBooking = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.createBooking(
        patient: patient,
        doctorId: doctorId,
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

  Future<void> createLabOrder({
    required int labTestId,
    required int doctorId,
    required String date,
    String? slot,
    String collectionType = 'home',
    String? address,
    double? amount,
    String paymentStatus = 'pending',
    String? patientNameSnapshot,
    int? patientAgeSnapshot,
    String? patientGenderSnapshot,
    String? bookingRef,
    String urgency = 'routine',
    String? notes,
  }) async {
    _isCreatingLabOrder = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.createLabOrder(
        labTestId: labTestId,
        doctorId: doctorId,
        date: date,
        slot: slot,
        collectionType: collectionType,
        address: address,
        amount: amount,
        paymentStatus: paymentStatus,
        patientNameSnapshot: patientNameSnapshot,
        patientAgeSnapshot: patientAgeSnapshot,
        patientGenderSnapshot: patientGenderSnapshot,
        bookingRef: bookingRef,
        urgency: urgency,
        notes: notes,
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

  Future<void> createLabPackageOrder({
    required int labPackageId,
    required int doctorId,
    required String date,
    String? slot,
    String collectionType = 'home',
    String? address,
    double? amount,
    String paymentStatus = 'pending',
    String? patientNameSnapshot,
    int? patientAgeSnapshot,
    String? patientGenderSnapshot,
    String? bookingRef,
    String urgency = 'routine',
    String? notes,
  }) async {
    _isCreatingLabOrder = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.createLabPackageOrder(
        labPackageId: labPackageId,
        doctorId: doctorId,
        date: date,
        slot: slot,
        collectionType: collectionType,
        address: address,
        amount: amount,
        paymentStatus: paymentStatus,
        patientNameSnapshot: patientNameSnapshot,
        patientAgeSnapshot: patientAgeSnapshot,
        patientGenderSnapshot: patientGenderSnapshot,
        bookingRef: bookingRef,
        urgency: urgency,
        notes: notes,
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
  }) {
    return _repository.getDoctorAvailableSlots(doctorId: doctorId, date: date);
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
}
