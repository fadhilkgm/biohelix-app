part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalProfileMixin on PatientPortalProvider {
  Future<void> saveProfile(PatientIdentity patient) async {
    final scope = _patientScopeRevision;
    _isSavingProfile = true;
    _errorMessage = null;
    _notify();

    try {
      final updatedPatient = await _repository.updatePatientProfile(patient);
      if (!_isCurrentScope(scope)) return;
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
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isSavingProfile = false;
        _notify();
      }
    }
  }

  Future<void> saveVitals(VitalInput input) async {
    final scope = _patientScopeRevision;
    _isSavingVitals = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.saveVitals(input);
      if (!_isCurrentScope(scope)) return;
      await loadPortal();
      try {
        if (!_isCurrentScope(scope)) return;
        final snapshot = await _repository.refreshHealthSnapshot();
        if (_isCurrentScope(scope)) _healthSnapshot = snapshot;
      } catch (_) {
        // Snapshot refresh is best-effort after vitals save.
      }
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isSavingVitals = false;
        _notify();
      }
    }
  }
}
