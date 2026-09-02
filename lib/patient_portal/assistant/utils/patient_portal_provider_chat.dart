part of 'package:biohelix_app/patient_portal/core/providers/patient_portal_provider.dart';

/// A user-safe failure the assistant reported inside the reply stream.
class AssistantStreamException implements Exception {
  const AssistantStreamException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension PatientPortalChatMixin on PatientPortalProvider {
  Future<void> initializeChatThreads({bool force = false}) async {
    if (_chatThreads.isNotEmpty && !force) {
      return;
    }

    final pending = _chatInitialization;
    if (pending != null && !force) {
      await pending;
      return;
    }

    final initialization = _loadInitialChatThreads();
    _chatInitialization = initialization;
    try {
      await initialization;
    } finally {
      if (identical(_chatInitialization, initialization)) {
        _chatInitialization = null;
      }
    }
  }

  Future<void> _loadInitialChatThreads() async {
    _errorMessage = null;
    _chatHistoryError = null;
    _chatHistoryErrorThreadId = null;

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
      // No thread is addressable yet, so the failure is not thread-scoped.
      _chatHistoryError = error.toString();
      _chatHistoryErrorThreadId = null;
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

    _loadingChatHistoryThreadId = threadId;
    if (_chatHistoryErrorThreadId == threadId || _chatHistoryErrorThreadId == null) {
      _chatHistoryError = null;
      _chatHistoryErrorThreadId = null;
    }
    _notify();

    try {
      final history = await _repository.getGlobalChatHistory(threadId);
      _chatHistories[threadId] = history;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
      _chatHistoryError = error.toString();
      _chatHistoryErrorThreadId = threadId;
    } finally {
      if (_loadingChatHistoryThreadId == threadId) {
        _loadingChatHistoryThreadId = null;
      }
      _notify();
    }
  }

  /// Retries whatever failed: the thread bootstrap, or the active thread's
  /// history.
  Future<void> retryChatHistory() async {
    final threadId = _activeChatThreadId;
    if ((threadId ?? '').isEmpty) {
      await initializeChatThreads(force: true);
      return;
    }
    await loadChatHistory(threadId!);
  }

  Future<void> sendChatMessage(
    String message, {
    List<ChatAttachment> attachments = const [],
    String? language,
    String? mode,
  }) async {
    // Re-entrancy guard: one send at a time across every thread. A second send
    // would race the placeholder bookkeeping of the first.
    if (_sendingThreadId != null) return;

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
    final nowIso = DateTime.now().toIso8601String();
    final userMessage = ChatMessage(
      role: 'user',
      content: trimmed,
      attachments: attachments,
      createdAt: nowIso,
    );
    // The placeholder is what the tab renders as a typing indicator, then as
    // growing text; it is replaced wholesale by the authoritative `done` reply.
    final placeholder = ChatMessage(
      role: 'ai',
      content: '',
      createdAt: nowIso,
    );
    _chatHistories[currentThreadId] = [...existing, userMessage, placeholder];

    final preview = trimmed.isNotEmpty
        ? trimmed
        : attachments.isNotEmpty
        ? 'Sent ${attachments.first.isImage ? 'an image' : 'an attachment'}'
        : '';

    final idempotencyKey =
        '$currentThreadId-${DateTime.now().microsecondsSinceEpoch}';
    final cancelToken = CancelToken();
    _replyCancelToken = cancelToken;
    _sendingThreadId = currentThreadId;
    _streamingThreadId = currentThreadId;
    _errorMessage = null;
    _touchThread(currentThreadId, preview);
    _notify();

    final wireMessage = userMessage.toWireContent();
    final buffer = StringBuffer();
    var sawDelta = false;
    var completed = false;
    var lastNotify = DateTime.now();

    try {
      await for (final event in _repository.streamGlobalChatMessage(
        threadId: currentThreadId,
        message: wireMessage,
        language: language,
        mode: mode,
        idempotencyKey: idempotencyKey,
        cancelToken: cancelToken,
      )) {
        if (event.type == ChatStreamEventType.delta) {
          sawDelta = true;
          buffer.write(event.text);
          _replaceStreamingReply(
            currentThreadId,
            ChatMessage(
              role: 'ai',
              content: buffer.toString(),
              createdAt: nowIso,
            ),
          );
          // Throttle: a notify per delta would rebuild the whole list at token
          // rate.
          final now = DateTime.now();
          if (now.difference(lastNotify).inMilliseconds >= 50) {
            lastNotify = now;
            _notify();
          }
        } else if (event.type == ChatStreamEventType.done) {
          final reply = event.message!;
          _replaceStreamingReply(currentThreadId, reply);
          _touchThread(currentThreadId, reply.content);
          completed = true;
          break;
        } else {
          throw AssistantStreamException(event.text);
        }
      }

      if (!completed) {
        if (cancelToken.isCancelled) {
          // Stop-generation: keep whatever arrived as the assistant turn.
          _touchThread(currentThreadId, buffer.toString());
        } else if (!sawDelta) {
          // The stream ended without producing anything usable.
          await _sendChatMessageNonStreaming(
            threadId: currentThreadId,
            message: wireMessage,
            language: language,
            mode: mode,
            idempotencyKey: idempotencyKey,
          );
        } else {
          _touchThread(currentThreadId, buffer.toString());
        }
      }
    } catch (error) {
      if (cancelToken.isCancelled) {
        // Cancellation is not a failure: keep the partial text.
        _touchThread(currentThreadId, buffer.toString());
      } else if (!sawDelta && _isTransportFailure(error)) {
        // The streaming endpoint may not be deployed (404) or may be rate
        // limited; the non-streaming endpoint remains the contract.
        try {
          await _sendChatMessageNonStreaming(
            threadId: currentThreadId,
            message: wireMessage,
            language: language,
            mode: mode,
            idempotencyKey: idempotencyKey,
          );
        } catch (fallbackError) {
          _errorMessage = fallbackError.toString();
          _chatHistories[currentThreadId] = existing;
          rethrow;
        }
      } else {
        _errorMessage = error.toString();
        // Roll back the optimistic turn (user message and placeholder). A
        // transport failure is UI state, not an assistant-authored message,
        // and callers need the error to offer retry.
        _chatHistories[currentThreadId] = existing;
        rethrow;
      }
    } finally {
      if (identical(_replyCancelToken, cancelToken)) {
        _replyCancelToken = null;
      }
      if (_sendingThreadId == currentThreadId) _sendingThreadId = null;
      if (_streamingThreadId == currentThreadId) _streamingThreadId = null;
      _notify();
    }
  }

  Future<void> _sendChatMessageNonStreaming({
    required String threadId,
    required String message,
    required String? language,
    required String? mode,
    required String idempotencyKey,
  }) async {
    final reply = await _repository.sendGlobalChatMessage(
      threadId: threadId,
      message: message,
      language: language,
      mode: mode,
      idempotencyKey: idempotencyKey,
    );
    _replaceStreamingReply(threadId, reply);
    _touchThread(threadId, reply.content);
  }

  /// Swaps the trailing assistant placeholder for [reply]. No-op if the tail is
  /// no longer the placeholder (thread reloaded mid-flight).
  void _replaceStreamingReply(String threadId, ChatMessage reply) {
    final history = _chatHistories[threadId];
    if (history == null || history.isEmpty) return;
    if (history.last.role == 'user') return;
    _chatHistories[threadId] = [
      ...history.sublist(0, history.length - 1),
      reply,
    ];
  }

  /// A server-authored `error` frame is an application failure, not a transport
  /// one, so it must not trigger the non-streaming fallback.
  bool _isTransportFailure(Object error) {
    if (error is AssistantStreamException) return false;
    return error is ApiException || error is TimeoutException;
  }

  /// Stops an in-flight reply. Whatever text already streamed stays as the
  /// assistant message.
  void cancelReply() {
    final token = _replyCancelToken;
    if (token == null || token.isCancelled) return;
    token.cancel('stopped-by-user');
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
