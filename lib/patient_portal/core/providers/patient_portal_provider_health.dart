part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalHealthMixin on PatientPortalProvider {
  Future<void> refreshHealthSnapshot() async {
    try {
      _healthSnapshot = await _repository.refreshHealthSnapshot();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _notify();
    }
  }

  /// Manual entry ("add/update today's readings"). Updates local state with
  /// the upserted snapshot returned by the API.
  Future<void> submitHealthSnapshot(HealthSnapshotInput input) async {
    _isSubmittingHealthSnapshot = true;
    _errorMessage = null;
    _notify();

    try {
      _healthSnapshot = await _repository.submitHealthSnapshot(input);
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isSubmittingHealthSnapshot = false;
      _notify();
    }
  }

  /// Loads the first page of health-snapshot history, replacing any
  /// previously loaded pages.
  Future<void> loadHealthSnapshotHistory() async {
    _isLoadingHealthSnapshotHistory = true;
    _errorMessage = null;
    _notify();

    try {
      final page = await _repository.getHealthSnapshotHistory(page: 1);
      _healthSnapshotHistory = page.items;
      _healthSnapshotHistoryPage = page.currentPage;
      _healthSnapshotHistoryLastPage = page.lastPage;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isLoadingHealthSnapshotHistory = false;
      _notify();
    }
  }

  /// Fetches the next page and appends it, for infinite-scroll history lists.
  Future<void> loadMoreHealthSnapshotHistory() async {
    if (_isLoadingMoreHealthSnapshotHistory || !hasMoreHealthSnapshotHistory) {
      return;
    }
    _isLoadingMoreHealthSnapshotHistory = true;
    _notify();

    try {
      final nextPage = await _repository.getHealthSnapshotHistory(
        page: _healthSnapshotHistoryPage + 1,
      );
      _healthSnapshotHistory = [..._healthSnapshotHistory, ...nextPage.items];
      _healthSnapshotHistoryPage = nextPage.currentPage;
      _healthSnapshotHistoryLastPage = nextPage.lastPage;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isLoadingMoreHealthSnapshotHistory = false;
      _notify();
    }
  }

  Future<void> acceptAiSuggestion(int suggestionId) async {
    try {
      final updated = await _repository.acceptAiSuggestion(suggestionId);
      _aiSuggestions = _aiSuggestions
          .map(
            (item) => item.id == suggestionId
                ? updated
                : item.copyWithAccepted(updated.isAccepted),
          )
          .toList();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _notify();
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
