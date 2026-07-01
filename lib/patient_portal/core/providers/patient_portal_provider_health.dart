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
