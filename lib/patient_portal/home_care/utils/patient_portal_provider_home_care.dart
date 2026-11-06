part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalHomeCareMixin on PatientPortalProvider {
  Future<void> refreshFamilyMembers() async {
    final scope = _patientScopeRevision;
    try {
      final members = await _repository.getFamilyMembers();
      if (!_isCurrentScope(scope)) return;
      _familyMembers = members;
      _errorMessage = null;
      _notify();
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      _notify();
      rethrow;
    }
  }

  Future<FamilyMember> addLinkedFamilyMember({
    required String firstName,
    required String relationship,
    String? lastName,
    String? phone,
    String? gender,
    String? dateOfBirth,
    String? bloodGroup,
    String? email,
  }) async {
    final scope = _patientScopeRevision;
    try {
      final member = await _repository.addFamilyMember(
        firstName: firstName,
        relationship: relationship,
        lastName: lastName,
        phone: phone,
        gender: gender,
        dateOfBirth: dateOfBirth,
        bloodGroup: bloodGroup,
        email: email,
      );
      if (!_isCurrentScope(scope)) return member;
      _familyMembers = [
        member,
        ..._familyMembers.where((item) => item.linkId != member.linkId),
      ];
      _errorMessage = null;
      _notify();
      return member;
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      _notify();
      rethrow;
    }
  }

  Future<void> refreshHomeCare({int? patientId}) async {
    final scope = _patientScopeRevision;
    try {
      final results = await Future.wait<dynamic>([
        _repository.getHomeCareServices(),
        _repository.getHomeCareBookings(patientId: patientId),
      ]);
      if (!_isCurrentScope(scope)) return;
      _homeCareServices = results[0] as List<HomeCareServiceItem>? ?? const [];
      _homeCareBookings = results[1] as List<HomeCareBookingItem>? ?? const [];
      _errorMessage = null;
      _notify();
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      _notify();
      rethrow;
    }
  }

  Future<HomeCareBookingItem> createHomeCareBooking(
    HomeCareBookingInput input,
  ) async {
    final scope = _patientScopeRevision;
    _isCreatingHomeCareBooking = true;
    _errorMessage = null;
    _notify();

    try {
      final booking = await _repository.createHomeCareBooking(input);
      if (!_isCurrentScope(scope)) return booking;
      _homeCareBookings = [booking, ..._homeCareBookings];
      return booking;
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isCreatingHomeCareBooking = false;
        _notify();
      }
    }
  }

  Future<void> cancelHomeCareBooking(int bookingId, {int? patientId}) async {
    final scope = _patientScopeRevision;
    try {
      await _repository.cancelHomeCareBooking(bookingId, patientId: patientId);
      if (!_isCurrentScope(scope)) return;
      _homeCareBookings = _homeCareBookings
          .map(
            (booking) => booking.id == bookingId
                ? HomeCareBookingItem(
                    id: booking.id,
                    bookingNumber: booking.bookingNumber,
                    serviceName: booking.serviceName,
                    preferredDate: booking.preferredDate,
                    status: 'cancelled',
                    timeSlot: booking.timeSlot,
                    notes: booking.notes,
                    paymentStatus: booking.paymentStatus,
                    createdAt: booking.createdAt,
                  )
                : booking,
          )
          .toList();
      _notify();
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      _notify();
      rethrow;
    }
  }
}
