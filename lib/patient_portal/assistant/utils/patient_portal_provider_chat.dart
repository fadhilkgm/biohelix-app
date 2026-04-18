part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

extension PatientPortalChatMixin on PatientPortalProvider {
  Future<void> initializeChatThreads({bool force = false}) async {
    if (_chatThreads.isNotEmpty && !force) {
      return;
    }

    _errorMessage = null;

    try {
      final threads = await _repository.getGlobalChatThreads();
      _chatThreads = threads;
      if (_chatThreads.isEmpty) {
        final created = await _repository.createGlobalChatThread();
        _chatThreads = [created];
      }

      _activeChatThreadId ??= _chatThreads.first.id;
      await loadChatHistory(_activeChatThreadId!);
      _notify();
    } catch (error) {
      _errorMessage = error.toString();
      _notify();
    }
  }

  Future<void> createNewChatThread({String? title}) async {
    try {
      final created = await _repository.createGlobalChatThread(title: title);
      _chatThreads = [created, ..._chatThreads];
      _activeChatThreadId = created.id;
      _chatHistories[created.id] = const [];
      _notify();
    } catch (error) {
      _errorMessage = error.toString();
      _notify();
    }
  }

  Future<void> renameChatThread({
    required String threadId,
    required String title,
  }) async {
    final trimmedTitle = title.trim();
    if (threadId.isEmpty || trimmedTitle.isEmpty) return;

    try {
      final updatedThread = await _repository.renameGlobalChatThread(
        threadId: threadId,
        title: trimmedTitle,
      );
      _chatThreads = _chatThreads.map((thread) {
        if (thread.id != threadId) return thread;
        return ChatThreadSummary(
          id: thread.id,
          title: updatedThread.title,
          messageCount: thread.messageCount,
          lastMessagePreview: thread.lastMessagePreview,
          lastMessageAt: thread.lastMessageAt,
          createdAt: thread.createdAt,
          updatedAt: updatedThread.updatedAt ?? thread.updatedAt,
        );
      }).toList();
      _errorMessage = null;
      _notify();
    } catch (error) {
      _errorMessage = error.toString();
      _notify();
    }
  }

  Future<void> deleteChatThread(String threadId) async {
    if (threadId.isEmpty) return;

    try {
      await _repository.deleteGlobalChatThread(threadId);
      _chatHistories.remove(threadId);
      _chatThreads = _chatThreads
          .where((thread) => thread.id != threadId)
          .toList();

      if (_chatThreads.isEmpty) {
        final created = await _repository.createGlobalChatThread();
        _chatThreads = [created];
      }

      if (_activeChatThreadId == threadId ||
          _chatThreads.every((thread) => thread.id != _activeChatThreadId)) {
        _activeChatThreadId = _chatThreads.first.id;
      }

      await loadChatHistory(_activeChatThreadId!);
      _errorMessage = null;
      _notify();
    } catch (error) {
      _errorMessage = error.toString();
      _notify();
    }
  }

  Future<void> switchChatThread(String threadId) async {
    if (threadId.isEmpty) return;
    _activeChatThreadId = threadId;
    _notify();
    await loadChatHistory(threadId);
  }

  Future<void> loadChatHistory(String threadId) async {
    if (threadId.isEmpty) return;

    try {
      final history = await _repository.getGlobalChatHistory(threadId);
      _chatHistories[threadId] = history;
      _errorMessage = null;
      _notify();
    } catch (error) {
      _errorMessage = error.toString();
      _notify();
    }
  }

  Future<void> sendChatMessage(
    String message, {
    List<ChatAttachment> attachments = const [],
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty && attachments.isEmpty) return;

    var threadId = _activeChatThreadId;
    if ((threadId ?? '').isEmpty) {
      await createNewChatThread();
      threadId = _activeChatThreadId;
      if ((threadId ?? '').isEmpty) {
        return;
      }
    }

    final currentThreadId = threadId!;
    final existing = _chatHistories[currentThreadId] ?? const <ChatMessage>[];
    final userMessage = ChatMessage(
      role: 'user',
      content: trimmed,
      attachments: attachments,
    );
    _chatHistories[currentThreadId] = [...existing, userMessage];

    final preview = trimmed.isNotEmpty
      ? trimmed
      : attachments.isNotEmpty
      ? 'Sent ${attachments.first.isImage ? 'an image' : 'an attachment'}'
      : '';

    _isSendingMessage = true;
    _errorMessage = null;
    _touchThread(currentThreadId, preview);
    _notify();

    try {
      final wireMessage = userMessage.toWireContent();
      final reply = await _repository.sendGlobalChatMessage(
        threadId: currentThreadId,
        message: wireMessage,
      );
      final updated = _chatHistories[currentThreadId] ?? const <ChatMessage>[];
      _chatHistories[currentThreadId] = [...updated, reply];
      _touchThread(currentThreadId, reply.content);
    } catch (error) {
      _errorMessage = error.toString();
      final updated = _chatHistories[currentThreadId] ?? const <ChatMessage>[];
      _chatHistories[currentThreadId] = [
        ...updated,
        const ChatMessage(
          role: 'ai',
          content:
              'I could not reach the BHRC assistant right now. Please try again later or contact the hospital directly.',
        ),
      ];
    } finally {
      _isSendingMessage = false;
      _notify();
    }
  }

  void _touchThread(String threadId, String preview) {
    final nowIso = DateTime.now().toIso8601String();
    _chatThreads =
        _chatThreads.map((thread) {
          if (thread.id != threadId) return thread;
          return ChatThreadSummary(
            id: thread.id,
            title: thread.title,
            messageCount: thread.messageCount + 1,
            lastMessagePreview: preview,
            lastMessageAt: nowIso,
            createdAt: thread.createdAt,
            updatedAt: nowIso,
          );
        }).toList()..sort((a, b) {
          final aTime = DateTime.tryParse(a.updatedAt ?? '') ?? DateTime(1970);
          final bTime = DateTime.tryParse(b.updatedAt ?? '') ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });
  }
}
