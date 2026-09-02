part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalHealthMixin on PatientPortalProvider {
  Future<void> refreshHealthSnapshot() async {
    final generation = _loadGeneration;
    final patientId = _sessionProvider.patient?.id;
    try {
      final snapshot = await _repository.refreshHealthSnapshot();
      if (!_isCurrentLoad(generation, patientId)) return;
      _healthSnapshot = snapshot;
      _errorMessage = null;
    } catch (error) {
      if (!_isCurrentLoad(generation, patientId)) return;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentLoad(generation, patientId)) _notify();
    }
  }

  /// Manual entry ("add/update today's readings"). Updates local state with
  /// the upserted snapshot returned by the API.
  Future<void> submitHealthSnapshot(HealthSnapshotInput input) async {
    final generation = _loadGeneration;
    final patientId = _sessionProvider.patient?.id;
    _isSubmittingHealthSnapshot = true;
    _errorMessage = null;
    _notify();

    try {
      final snapshot = await _repository.submitHealthSnapshot(input);
      if (!_isCurrentLoad(generation, patientId)) return;
      _healthSnapshot = snapshot;
    } catch (error) {
      if (!_isCurrentLoad(generation, patientId)) return;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentLoad(generation, patientId)) {
        _isSubmittingHealthSnapshot = false;
        _notify();
      }
    }
  }

  /// Loads the first page of health-snapshot history, replacing any
  /// previously loaded pages.
  Future<void> loadHealthSnapshotHistory() async {
    final generation = _loadGeneration;
    final patientId = _sessionProvider.patient?.id;
    _isLoadingHealthSnapshotHistory = true;
    _errorMessage = null;
    _notify();

    try {
      final page = await _repository.getHealthSnapshotHistory(page: 1);
      if (!_isCurrentLoad(generation, patientId)) return;
      _healthSnapshotHistory = page.items;
      _healthSnapshotHistoryPage = page.currentPage;
      _healthSnapshotHistoryLastPage = page.lastPage;
    } catch (error) {
      if (!_isCurrentLoad(generation, patientId)) return;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentLoad(generation, patientId)) {
        _isLoadingHealthSnapshotHistory = false;
        _notify();
      }
    }
  }

  /// Fetches the next page and appends it, for infinite-scroll history lists.
  Future<void> loadMoreHealthSnapshotHistory() async {
    if (_isLoadingMoreHealthSnapshotHistory || !hasMoreHealthSnapshotHistory) {
      return;
    }
    final generation = _loadGeneration;
    final patientId = _sessionProvider.patient?.id;
    _isLoadingMoreHealthSnapshotHistory = true;
    _notify();

    try {
      final nextPage = await _repository.getHealthSnapshotHistory(
        page: _healthSnapshotHistoryPage + 1,
      );
      if (!_isCurrentLoad(generation, patientId)) return;
      _healthSnapshotHistory = [..._healthSnapshotHistory, ...nextPage.items];
      _healthSnapshotHistoryPage = nextPage.currentPage;
      _healthSnapshotHistoryLastPage = nextPage.lastPage;
    } catch (error) {
      if (!_isCurrentLoad(generation, patientId)) return;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentLoad(generation, patientId)) {
        _isLoadingMoreHealthSnapshotHistory = false;
        _notify();
      }
    }
  }

  Future<void> acceptAiSuggestion(int suggestionId) async {
    final generation = _loadGeneration;
    final patientId = _sessionProvider.patient?.id;
    try {
      final updated = await _repository.acceptAiSuggestion(suggestionId);
      if (!_isCurrentLoad(generation, patientId)) return;
      _aiSuggestions = _aiSuggestions
          .map(
            (item) => item.id == suggestionId
                ? updated
                : item.copyWithAccepted(updated.isAccepted),
          )
          .toList();
      _errorMessage = null;
    } catch (error) {
      if (!_isCurrentLoad(generation, patientId)) return;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentLoad(generation, patientId)) _notify();
    }
  }
}

extension _AiSuggestionCopy on AiSuggestionItem {
  AiSuggestionItem copyWithAccepted(bool accepted) {
    return AiSuggestionItem(
      id: id,
      recommendationType: recommendationType,
      reason: reason,
      score: score,
      isAccepted: accepted,
      itemType: itemType,
      itemName: itemName,
      labTestId: labTestId,
      packageId: packageId,
    );
  }
}
