part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalProfileMixin on PatientPortalProvider {
  Future<void> saveProfile(PatientIdentity patient) async {
    _isSavingProfile = true;
    _errorMessage = null;
    _notify();

    try {
      final updatedPatient = await _repository.updatePatientProfile(patient);
      _sessionProvider.updatePatient(updatedPatient);
      if (_dashboard != null) {
        _dashboard = PatientDashboard(
          patient: updatedPatient,
          metrics: _dashboard!.metrics,
          recentBookings: _dashboard!.recentBookings,
          recentPrescriptions: _dashboard!.recentPrescriptions,
          recentDocuments: _dashboard!.recentDocuments,
          recentSummaries: _dashboard!.recentSummaries,
          idCard: _dashboard!.idCard,
          myClub: _dashboard!.myClub,
          emergencyContacts: _dashboard!.emergencyContacts,
          latestVitals: _dashboard!.latestVitals,
        );
      }
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isSavingProfile = false;
      _notify();
    }
  }

  Future<void> saveVitals(VitalInput input) async {
    _isSavingVitals = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.saveVitals(input);
      await loadPortal();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isSavingVitals = false;
      _notify();
    }
  }
}
