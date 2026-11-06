part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalDocumentMixin on PatientPortalProvider {
  Future<DocumentRecord> uploadDocument(
    String filePath, {
    String? fileName,
    String? documentType,
    List<int>? fileBytes,
  }) async {
    final scope = _patientScopeRevision;
    _isUploadingDocument = true;
    _errorMessage = null;
    _notify();

    try {
      final uploaded = await _repository.uploadDocument(
        filePath,
        fileName: fileName,
        documentType: documentType,
        fileBytes: fileBytes,
      );
      if (_isCurrentScope(scope)) await loadPortal();
      return uploaded;
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope)) {
        _isUploadingDocument = false;
        _notify();
      }
    }
  }

  Future<DocumentAnalysisResult?> analyzeDocument(
    int documentId, {
    String language = 'en',
  }) async {
    final scope = _patientScopeRevision;
    _analyzingDocumentId = documentId;
    _lastAnalysisResult = null;
    _errorMessage = null;
    _notify();

    try {
      final result = await _repository.analyzeDocument(
        documentId,
        language: language,
      );
      if (!_isCurrentScope(scope)) return null;
      _lastAnalysisResult = result;
      if (_lastAnalysisResult != null) {
        _documentAnalyses[documentId] = _lastAnalysisResult!;
      }
      await loadPortal();
      return _isCurrentScope(scope) ? result : null;
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope) && _analyzingDocumentId == documentId) {
        _analyzingDocumentId = null;
        _notify();
      }
    }
  }

  Future<void> deleteDocument(int documentId) async {
    final scope = _patientScopeRevision;
    _errorMessage = null;
    _notify();

    try {
      await _repository.deleteDocument(documentId);
      if (!_isCurrentScope(scope)) return;
      _documentAnalyses.remove(documentId);
      _documentChats.remove(documentId);
      if (_lastAnalysisResult != null &&
          _analyzingDocumentId != null &&
          _analyzingDocumentId == documentId) {
        _lastAnalysisResult = null;
      }
      await loadPortal();
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<void> loadDocumentConversation(int documentId) async {
    final scope = _patientScopeRevision;
    _loadingDocumentChatId = documentId;
    _errorMessage = null;
    _notify();

    try {
      final history = await _repository.getDocumentChatHistory(documentId);
      if (!_isCurrentScope(scope)) return;
      _documentChats[documentId] = history;
    } catch (error) {
      if (!_isCurrentScope(scope)) rethrow;
      _errorMessage = error.toString();
      rethrow;
    } finally {
      if (_isCurrentScope(scope) && _loadingDocumentChatId == documentId) {
        _loadingDocumentChatId = null;
        _notify();
      }
    }
  }

  Future<void> sendDocumentChatMessage({
    required int documentId,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _sendingDocumentChatId != null) return;
    final scope = _patientScopeRevision;

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
      if (!_isCurrentScope(scope)) return;
      _documentChats[documentId] = [...?_documentChats[documentId], reply];
    } catch (error) {
      if (!_isCurrentScope(scope)) return;
      _errorMessage = error.toString();
      _documentChats[documentId] = [
        ...?_documentChats[documentId],
        const ChatMessage(
          role: 'ai',
          content:
              'I could not reach the report assistant right now. Please try again later or discuss the report with your doctor.',
        ),
      ];
    } finally {
      if (_isCurrentScope(scope)) {
        _sendingDocumentChatId = null;
        _notify();
      }
    }
  }
}
