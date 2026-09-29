part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _ChatAttachment {
  const _ChatAttachment({
    required this.name,
    required this.url,
    required this.sizeLabel,
    required this.isImage,
  });

  final String name;
  final String url;
  final String sizeLabel;
  final bool isImage;
}

enum _AttachmentSource { galleryImage, file }

String _dateLabel(LocalizedStrings strings, DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return strings.today;
  if (diff == 1) return strings.yesterday;
  return DateFormat('dd MMM yyyy').format(date);
}

/// Per-message fallback timestamps, so a message without `createdAt` keeps one
/// stable time instead of drifting on every rebuild.
final Expando<DateTime> _messageFallbackDates = Expando<DateTime>(
  'assistantMessageFallbackDate',
);

DateTime _messageDate(ChatMessage message) {
  final parsed = DateTime.tryParse(message.createdAt ?? '');
  if (parsed != null) return parsed;
  final cached = _messageFallbackDates[message];
  if (cached != null) return cached;
  final now = DateTime.now();
  _messageFallbackDates[message] = now;
  return now;
}

String _messageTimeLabel(ChatMessage message) {
  return DateFormat('hh:mm a').format(_messageDate(message));
}

String _resolveAttachmentUrl(BuildContext context, String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  final config = Provider.of<AppConfig>(context, listen: false);
  final base = config.apiBaseUrl;
  final origin = Uri.parse(base).resolve('/').toString();
  final path = value.startsWith('/') ? value.substring(1) : value;
  return Uri.parse(origin).resolve(path).toString();
}

/// The quoted string only counts as a legacy attachment if it actually looks
/// like an uploadable file name.
final RegExp _legacyAttachmentNamePattern = RegExp(
  r'\.(pdf|png|jpe?g|webp|heic)$',
  caseSensitive: false,
);

List<_ChatAttachment> _attachmentsFromMessage(
  BuildContext context,
  ChatMessage message,
) {
  if (message.attachments.isNotEmpty) {
    return message.attachments
        .map(
          (attachment) => _ChatAttachment(
            name: attachment.name,
            url: _resolveAttachmentUrl(context, attachment.url),
            sizeLabel: _formatBytes(attachment.sizeBytes),
            isImage: attachment.isImage,
          ),
        )
        .toList();
  }

  // Backward compatibility for legacy *patient* messages that embedded file
  // names in text. Assistant replies quote ordinary prose constantly, so
  // applying this to them invents phantom attachments.
  if (message.role != 'user') return const [];

  final content = message.content;
  final quoted = RegExp(r'"([^"]+)"').firstMatch(content);
  if (quoted == null) return const [];
  final name = quoted.group(1) ?? '';
  if (name.isEmpty) return const [];
  if (!_legacyAttachmentNamePattern.hasMatch(name)) return const [];
  final lower = name.toLowerCase();
  final isImage = !lower.endsWith('.pdf');
  return [
    _ChatAttachment(
      name: name,
      url: '',
      sizeLabel: isImage ? 'Image attachment' : 'Document attachment',
      isImage: isImage,
    ),
  ];
}

String _formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return 'Attachment';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

extension _AssistantActions on _AssistantTabState {
  AppLanguage get _assistantLanguage =>
      context.read<LanguageProvider>().language;

  LocalizedStrings get _strings => AppStrings.of(_assistantLanguage);

  String get _assistantLanguageCode =>
      _assistantLanguage == AppLanguage.ml ? 'ml' : 'en';

  String get _ttsLanguageCode =>
      _assistantLanguage == AppLanguage.ml ? 'ml-IN' : 'en-IN';

  Future<void> _sendMessage(PatientPortalProvider portal) async {
    // The provider also guards re-entrancy; bail here so the composer is not
    // cleared for a send that will be dropped.
    if (portal.isSendingMessage) return;

    final message = inputController.text.trim();
    final attachments = List<ChatAttachment>.from(_pendingAttachments);
    if (message.isEmpty && attachments.isEmpty) return;

    inputController.clear();
    updateAssistantState(() {
      _pendingAttachments.clear();
    });
    _forceStickToBottomOnNextMessage = true;

    try {
      await portal.sendChatMessage(
        message,
        attachments: attachments,
        language: _assistantLanguageCode,
        mode: 'text',
      );
    } catch (_) {
      if (!mounted) return;
      inputController.text = message;
      inputController.selection = TextSelection.collapsed(
        offset: inputController.text.length,
      );
      updateAssistantState(() {
        _pendingAttachments
          ..clear()
          ..addAll(attachments);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Message not sent. Check your connection and retry.',
          ),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              if (!mounted) return;
              unawaited(_sendMessage(portal));
            },
          ),
        ),
      );
    }
  }

  Future<void> _attachFile(PatientPortalProvider portal) async {
    final source = await showModalBottomSheet<_AttachmentSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Gallery image'),
                  onTap: () =>
                      Navigator.pop(context, _AttachmentSource.galleryImage),
                ),
                ListTile(
                  leading: const Icon(Icons.attach_file_rounded),
                  title: const Text('File or document'),
                  onTap: () => Navigator.pop(context, _AttachmentSource.file),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    if (source == _AttachmentSource.galleryImage) {
      await _attachGalleryImage(portal);
      return;
    }

    await _attachDocumentFile(portal);
  }

  Future<void> _attachGalleryImage(PatientPortalProvider portal) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;

      await _uploadChatAttachment(
        portal,
        path: picked.path,
        fileName: _friendlyGalleryImageName(picked.name, picked.path),
        sizeBytes: await picked.length(),
      );
    } catch (error) {
      if (_isImagePickerChannelError(error)) {
        await _showAttachmentMessage(
          'Gallery picker is not ready in this app build. Rebuild the app once, or choose the image as a file.',
        );
        if (mounted) {
          await _attachDocumentFile(portal);
        }
        return;
      }
      _handleAttachmentError(error);
    }
  }

  Future<void> _attachDocumentFile(PatientPortalProvider portal) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if ((path ?? '').isEmpty || !mounted) return;
      final fileName = result.files.single.name;

      await _uploadChatAttachment(
        portal,
        path: path!,
        fileName: fileName,
        sizeBytes: result.files.single.size,
      );
    } catch (error) {
      _handleAttachmentError(error);
    }
  }

  Future<void> _uploadChatAttachment(
    PatientPortalProvider portal, {
    required String path,
    required String fileName,
    required int sizeBytes,
  }) async {
    if (sizeBytes <= 0) {
      _handleAttachmentError(
        const FormatException('The selected report is empty.'),
      );
      return;
    }
    if (sizeBytes > 25 * 1024 * 1024) {
      _handleAttachmentError(
        const FormatException('Reports must be smaller than 25 MB.'),
      );
      return;
    }
    try {
      updateAssistantState(() {
        _isAttachmentUploadInFlight = true;
        _uploadingAttachmentName = fileName;
      });

      final uploaded = await portal.uploadDocument(path, fileName: fileName);
      final attachment = ChatAttachment(
        name: fileName,
        url: uploaded.documentPath,
        mimeType: uploaded.documentType,
        sizeBytes: sizeBytes,
      );

      updateAssistantState(() {
        _pendingAttachments.add(attachment);
        _isAttachmentUploadInFlight = false;
        _uploadingAttachmentName = null;
        _isAttachmentAnalysisInFlight = true;
      });

      unawaited(() async {
        try {
          final analysis = await portal.analyzeDocument(
            uploaded.id,
            language: _assistantLanguageCode,
          );
          if (!mounted) return;
          updateAssistantState(() {
            _isAttachmentAnalysisInFlight = false;
          });
          final result = analysis;
          if (result?.status == 'processing' || result?.status == 'queued') {
            await _showAttachmentMessage(
              'Your report is queued for analysis. You can ask questions once it is ready.',
            );
          }
          if (!mounted) return;
          if (result?.summary.trim().isNotEmpty == true) {
            AppToast.show(
              context,
              message: _strings.assistantSummaryReady(fileName),
              type: AppToastType.success,
            );
          }
        } catch (_) {
          if (!mounted) return;
          updateAssistantState(() {
            _isAttachmentAnalysisInFlight = false;
          });
          AppToast.show(
            context,
            message: _strings.assistantUploadPending(fileName),
            type: AppToastType.warning,
          );
        }
      }());

      if (!mounted) return;
      AppToast.show(
        context,
        message: _strings.assistantUploadedReady(fileName),
        type: AppToastType.success,
      );
    } catch (error) {
      _handleAttachmentError(error);
    }
  }

  void _handleAttachmentError(Object error) {
    updateAssistantState(() {
      _isAttachmentUploadInFlight = false;
      _isAttachmentAnalysisInFlight = false;
      _uploadingAttachmentName = null;
    });
    if (!mounted) return;
    final message = _friendlyAttachmentError(error);
    AppToast.show(context, message: message, type: AppToastType.error);
  }

  bool _isImagePickerChannelError(Object error) {
    return error is PlatformException &&
        error.code == 'channel-error' &&
        (error.message ?? '').contains('image_picker_ios');
  }

  String _friendlyAttachmentError(Object error) {
    if (_isImagePickerChannelError(error)) {
      return 'Gallery picker is not ready in this app build. Please rebuild the app and try again.';
    }
    if (error is PlatformException) {
      return error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Attachment picker failed. Please try again.';
    }
    if (error is FormatException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _showAttachmentMessage(String message) async {
    if (!mounted) return;
    AppToast.show(context, message: message);
  }

  String _friendlyGalleryImageName(String originalName, String path) {
    final source = originalName.trim().isNotEmpty ? originalName : path;
    final extensionMatch = RegExp(r'\.([a-zA-Z0-9]{2,5})$').firstMatch(source);
    final extension = extensionMatch?.group(1)?.toLowerCase() ?? 'jpg';
    return 'Gallery image.$extension';
  }

  Future<void> _confirmDeleteThread(
    PatientPortalProvider portal,
    String threadId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_strings.assistantDeleteChat),
          content: const Text(
            'This removes the chat from your current list. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_strings.delete),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    await portal.deleteChatThread(threadId);
  }

  Future<void> _renameThread(
    PatientPortalProvider portal,
    String threadId,
  ) async {
    ChatThreadSummary? thread;
    for (final candidate in portal.chatThreads) {
      if (candidate.id == threadId) {
        thread = candidate;
        break;
      }
    }
    if (thread == null) return;

    final controller = TextEditingController(text: thread.title);
    final renamed = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_strings.assistantRenameChat),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(hintText: 'Enter chat title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(_strings.save),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (!mounted || renamed == null) return;
    final title = renamed.trim();
    if (title.isEmpty || title == thread.title) return;
    await portal.renameChatThread(threadId: threadId, title: title);
  }

  /// Opens the voice screen at once and connects in the background, like
  /// ChatGPT voice mode: no greeting to sit through, the patient can talk as
  /// soon as the orb turns green.
  Future<void> _startLiveVoice(PatientPortalProvider portal) async {
    if (_isLiveVoiceMode) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final existingThread = portal.activeChatThreadId ?? '';
    updateAssistantState(() {
      _isLiveVoiceMode = true;
      _isEndingLiveVoice = false;
      _liveConversationId = existingThread.isEmpty ? null : existingThread;
    });

    // Voice turns belong to a real chat thread, but creating one must not
    // delay the connection: resolve it alongside the WebRTC handshake.
    final conversationReady = _ensureLiveConversation(portal);
    _liveConversationReady = conversationReady;
    unawaited(
      conversationReady.then((conversationId) {
        if (!mounted || !_isLiveVoiceMode || conversationId == null) return;
        if (!identical(_liveConversationReady, conversationReady)) return;
        _liveConversationId = conversationId;
        liveVoiceController.attachConversation(conversationId);
      }),
    );

    await liveVoiceController.start(
      locale: _ttsLanguageCode,
      conversationId: existingThread,
      history: existingThread.isEmpty
          ? const []
          : _liveVoiceHistory(portal.chatMessages),
    );
  }

  Future<void> _endLiveVoice(PatientPortalProvider portal) async {
    if (!_isLiveVoiceMode) return;
    updateAssistantState(() {
      _isLiveVoiceMode = false;
      _isEndingLiveVoice = true;
      _liveConversationId = null;
      _liveConversationReady = null;
    });
    await liveVoiceController.stop(reason: 'patient_ended');
    unawaited(portal.refreshMyClub());
  }

  Future<void> _retryLiveVoice(PatientPortalProvider portal) async {
    if (!_isLiveVoiceMode || liveVoiceController.state.isActive) return;
    final conversationId = await _awaitLiveConversationId();
    if (!mounted || !_isLiveVoiceMode) return;
    await liveVoiceController.start(
      locale: _ttsLanguageCode,
      conversationId: conversationId,
      history: _liveVoiceHistory(portal.chatMessages),
    );
  }

  Future<String?> _ensureLiveConversation(PatientPortalProvider portal) async {
    try {
      if ((portal.activeChatThreadId ?? '').isEmpty) {
        // The assistant can be opened before the background load finishes.
        await portal.initializeChatThreads(force: true);
      }
      if ((portal.activeChatThreadId ?? '').isEmpty) {
        await portal.createNewChatThread();
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[LiveVoice] chat thread unavailable: $error');
    }
    final conversationId = portal.activeChatThreadId ?? '';
    return conversationId.isEmpty ? null : conversationId;
  }

  /// The live call's chat thread, waiting for it to be created if needed.
  Future<String> _awaitLiveConversationId() async {
    final current = _liveConversationId ?? '';
    if (current.isNotEmpty) return current;
    final pending = _liveConversationReady;
    if (pending == null) return '';
    return await pending ?? '';
  }

  /// The last few text messages of the thread, so the voice assistant picks
  /// up the conversation instead of starting cold.
  List<LiveVoiceHistoryItem> _liveVoiceHistory(List<ChatMessage> messages) {
    final items = <LiveVoiceHistoryItem>[];
    for (final message in messages.reversed) {
      if (items.length >= kLiveVoiceHistoryMessageLimit) break;
      final role = message.role;
      if (role != 'user' && role != 'assistant') continue;
      final text = message.content.trim();
      if (text.isEmpty) continue;
      items.add(LiveVoiceHistoryItem(fromPatient: role == 'user', text: text));
    }
    return items.reversed.toList(growable: false);
  }

  /// Saves one voice exchange, retrying once. A failure never interrupts the
  /// call: the conversation matters more than its transcript.
  Future<void> _persistLiveTurn(
    String conversationId,
    String transcript,
    String response,
  ) async {
    final idempotencyKey =
        '$conversationId-${DateTime.now().microsecondsSinceEpoch}';
    final safeTranscript = transcript.length > 2000
        ? transcript.substring(0, 2000)
        : transcript;
    final safeResponse = response.length > 4000
        ? response.substring(0, 4000)
        : response;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        await _signalingApi.persistTurn(
          conversationId: conversationId,
          transcript: safeTranscript,
          response: safeResponse,
          idempotencyKey: idempotencyKey,
        );
        return;
      } catch (error) {
        if (attempt == 2) {
          if (kDebugMode) {
            debugPrint('[LiveVoice] voice turn could not be saved: $error');
          }
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }
}

Future<void> _openAttachmentPreview(
  BuildContext context,
  _ChatAttachment attachment,
) async {
  final resolvedUrl = _resolveAttachmentUrl(context, attachment.url);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attachment.name,
                style: AppTextStyles.title(sheetContext).copyWith(fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.s12),
              if (attachment.isImage && resolvedUrl.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.62,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.network(
                        resolvedUrl,
                        fit: BoxFit.contain,
                        headers: {
                          if (Provider.of<SessionProvider>(
                                context,
                                listen: false,
                              ).authToken !=
                              null)
                            'Authorization':
                                'Bearer ${Provider.of<SessionProvider>(context, listen: false).authToken}',
                        },
                        errorBuilder: (_, _, _) => Text(
                          'Image preview unavailable.',
                          style: AppTextStyles.subtitle(sheetContext),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    const Icon(Icons.insert_drive_file_rounded),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      attachment.sizeLabel,
                      style: AppTextStyles.subtitle(sheetContext),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}
