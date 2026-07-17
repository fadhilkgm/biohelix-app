part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalHomeCareMixin on PatientPortalProvider {
  Future<void> refreshFamilyMembers() async {
    try {
      _familyMembers = await _repository.getFamilyMembers();
      _errorMessage = null;
      _notify();
    } catch (error) {
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
      _familyMembers = [
        member,
        ..._familyMembers.where((item) => item.linkId != member.linkId),
      ];
      _errorMessage = null;
      _notify();
      return member;
    } catch (error) {
      _errorMessage = error.toString();
      _notify();
      rethrow;
    }
  }

  Future<void> refreshHomeCare({int? patientId}) async {
    try {
      final results = await Future.wait<dynamic>([
        _repository.getHomeCareServices(),
        _repository.getHomeCareBookings(patientId: patientId),
      ]);
      _homeCareServices = results[0] as List<HomeCareServiceItem>? ?? const [];
      _homeCareBookings = results[1] as List<HomeCareBookingItem>? ?? const [];
      _errorMessage = null;
      _notify();
    } catch (error) {
      _errorMessage = error.toString();
      _notify();
      rethrow;
    }
  }

  Future<HomeCareBookingItem> createHomeCareBooking(
    HomeCareBookingInput input,
  ) async {
    _isCreatingHomeCareBooking = true;
    _errorMessage = null;
    _notify();

    try {
      final booking = await _repository.createHomeCareBooking(input);
      _homeCareBookings = [booking, ..._homeCareBookings];
      return booking;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isCreatingHomeCareBooking = false;
      _notify();
    }
  }

  Future<void> cancelHomeCareBooking(int bookingId, {int? patientId}) async {
    try {
      await _repository.cancelHomeCareBooking(bookingId, patientId: patientId);
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
      _errorMessage = error.toString();
      _notify();
      rethrow;
    }
  }
}
