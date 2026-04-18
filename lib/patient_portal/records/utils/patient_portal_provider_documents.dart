part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalDocumentMixin on PatientPortalProvider {
  Future<DocumentRecord> uploadDocument(String filePath) async {
    _isUploadingDocument = true;
    _errorMessage = null;
    _notify();

    try {
      final uploaded = await _repository.uploadDocument(filePath);
      await loadPortal();
      return uploaded;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isUploadingDocument = false;
      _notify();
    }
  }

  Future<void> analyzeDocument(int documentId) async {
    _analyzingDocumentId = documentId;
    _lastAnalysisResult = null;
    _errorMessage = null;
    _notify();

    try {
      _lastAnalysisResult = await _repository.analyzeDocument(documentId);
      if (_lastAnalysisResult != null) {
        _documentAnalyses[documentId] = _lastAnalysisResult!;
      }
      await loadPortal();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _analyzingDocumentId = null;
      _notify();
    }
  }

  Future<void> deleteDocument(int documentId) async {
    _errorMessage = null;
    _notify();

    try {
      await _repository.deleteDocument(documentId);
      _documentAnalyses.remove(documentId);
      _documentChats.remove(documentId);
      if (_lastAnalysisResult != null &&
          _analyzingDocumentId != null &&
          _analyzingDocumentId == documentId) {
        _lastAnalysisResult = null;
      }
      await loadPortal();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<void> loadDocumentConversation(int documentId) async {
    _loadingDocumentChatId = documentId;
    _errorMessage = null;
    _notify();

    try {
      _documentChats[documentId] = await _repository.getDocumentChatHistory(
        documentId,
      );
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _loadingDocumentChatId = null;
      _notify();
    }
  }

  Future<void> sendDocumentChatMessage({
    required int documentId,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final history = _documentChats[documentId] ?? const [];
    _documentChats[documentId] = [
      ...history,
      ChatMessage(role: 'user', content: trimmed),
    ];
    _sendingDocumentChatId = documentId;
    _errorMessage = null;
    _notify();

    try {
      final reply = await _repository.sendDocumentChatMessage(
        documentId: documentId,
        message: trimmed,
      );
      _documentChats[documentId] = [..._documentChats[documentId]!, reply];
    } catch (error) {
      _errorMessage = error.toString();
      _documentChats[documentId] = [
        ..._documentChats[documentId]!,
        const ChatMessage(
          role: 'ai',
          content:
              'I could not reach the report assistant right now. Please try again later or discuss the report with your doctor.',
        ),
      ];
    } finally {
      _sendingDocumentChatId = null;
      _notify();
    }
  }
}
