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

String _dateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('dd MMM yyyy').format(date);
}

DateTime _messageDate(ChatMessage message, int index) {
  final parsed = DateTime.tryParse(message.createdAt ?? '');
  return parsed ?? DateTime.now().subtract(Duration(minutes: index));
}

String _messageTimeLabel(ChatMessage message, int index) {
  return DateFormat('hh:mm a').format(_messageDate(message, index));
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

  // Backward compatibility for legacy messages that embedded file names in text.
  final content = message.content;
  final quoted = RegExp(r'"([^"]+)"').firstMatch(content);
  if (quoted == null) return const [];
  final name = quoted.group(1) ?? '';
  if (name.isEmpty) return const [];
  final lower = name.toLowerCase();
  final isImage =
      lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp');
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
  Future<bool> _ensureVoiceReady() async {
    if (speechReady) return true;
    await _initializeVoiceFeatures();
    return speechReady;
  }

  Future<void> _sendMessage(PatientPortalProvider portal) async {
    final message = inputController.text.trim();
    final attachments = List<ChatAttachment>.from(_pendingAttachments);
    if (message.isEmpty && attachments.isEmpty) return;

    inputController.clear();
    updateAssistantState(() {
      _pendingAttachments.clear();
    });

    await portal.sendChatMessage(message, attachments: attachments);
  }

  Future<void> _attachFile(PatientPortalProvider portal) async {
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

      updateAssistantState(() {
        _isAttachmentUploadInFlight = true;
        _uploadingAttachmentName = fileName;
      });

      final uploaded = await portal.uploadDocument(path!);
      final attachment = ChatAttachment(
        name: fileName,
        url: uploaded.documentPath,
        mimeType: uploaded.documentType,
        sizeBytes: result.files.single.size,
      );

      updateAssistantState(() {
        _pendingAttachments.add(attachment);
        _isAttachmentUploadInFlight = false;
        _uploadingAttachmentName = null;
      });

      unawaited(() async {
        try {
          await portal.analyzeDocument(uploaded.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Summary ready for $fileName in Reports.')),
          );
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Uploaded $fileName, but summary generation is still pending.',
              ),
            ),
          );
        }
      }());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded $fileName. You can tap it to preview, then send your message.',
          ),
        ),
      );
    } catch (error) {
      updateAssistantState(() {
        _isAttachmentUploadInFlight = false;
        _uploadingAttachmentName = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _confirmDeleteThread(
    PatientPortalProvider portal,
    String threadId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete chat'),
          content: const Text(
            'This removes the chat from your current list. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
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
          title: const Text('Rename chat'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(hintText: 'Enter chat title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Save'),
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

  Future<void> _initializeVoiceFeatures() async {
    final available = await speechToText.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          updateAssistantState(() {
            isListening = false;
          });
        }
      },
      onError: (_) {
        if (!mounted) return;
        updateAssistantState(() {
          isListening = false;
        });
      },
    );

    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.45);
    await tts.setPitch(1.0);
    await tts.awaitSpeakCompletion(true);
    tts.setStartHandler(() {
      if (!mounted) return;
      updateAssistantState(() {
        isSpeaking = true;
      });
    });
    tts.setCompletionHandler(() {
      if (!mounted) return;
      updateAssistantState(() {
        isSpeaking = false;
      });
    });
    tts.setCancelHandler(() {
      if (!mounted) return;
      updateAssistantState(() {
        isSpeaking = false;
      });
    });

    if (!mounted) return;
    updateAssistantState(() {
      speechReady = available;
    });
  }

  Future<void> _toggleVoiceInput() async {
    final portal = context.read<PatientPortalProvider>();

    if (isLiveVoiceMode) {
      await _toggleLiveVoiceMode(portal);
    }

    if (!await _ensureVoiceReady()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice input unavailable. Please allow microphone permission and enable a speech recognition service (Google app / Voice Typing).',
          ),
        ),
      );
      return;
    }

    if (isListening) {
      await speechToText.stop();
      if (!mounted) return;
      updateAssistantState(() {
        isListening = false;
      });
      return;
    }

    await _startVoiceListening(portal);
  }

  Future<void> _toggleLiveVoiceMode(PatientPortalProvider portal) async {
    if (!await _ensureVoiceReady()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Live voice unavailable. Please allow microphone permission and enable a speech recognition service (Google app / Voice Typing).',
          ),
        ),
      );
      return;
    }

    if (isLiveVoiceMode) {
      await speechToText.stop();
      await tts.stop();
      if (!mounted) return;
      updateAssistantState(() {
        isLiveVoiceMode = false;
        isListening = false;
        isSpeaking = false;
        isLiveTurnInFlight = false;
      });
      return;
    }

    final latest = portal.chatMessages.isNotEmpty
        ? portal.chatMessages.last
        : null;
    String? lastFingerprint;
    if (latest != null && latest.role != 'user') {
      lastFingerprint = '${latest.createdAt ?? ''}:${latest.content.hashCode}';
    }

    updateAssistantState(() {
      isLiveVoiceMode = true;
      lastLiveSpokenReply = lastFingerprint;
    });
    await _startVoiceListening(portal);
  }

  Future<void> _startVoiceListening(PatientPortalProvider portal) async {
    try {
      if (isSpeaking) {
        await tts.stop();
      }

      updateAssistantState(() {
        isListening = true;
      });

      final started = await speechToText.listen(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(partialResults: true),
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords.trim();
          inputController.value = TextEditingValue(
            text: words,
            selection: TextSelection.collapsed(offset: words.length),
          );

          if (isLiveVoiceMode && result.finalResult && !isLiveTurnInFlight) {
            _sendLiveVoiceTurn(portal, words);
          }
        },
      );

      if (!mounted) return;
      updateAssistantState(() {
        isListening = started == true;
      });
    } catch (error) {
      if (!mounted) return;
      updateAssistantState(() {
        isListening = false;
        isLiveVoiceMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start voice listening: $error')),
      );
    }
  }

  Future<void> _sendLiveVoiceTurn(
    PatientPortalProvider portal,
    String recognizedText,
  ) async {
    final message = _sanitizeSpeechText(recognizedText);
    if (message.isEmpty) return;

    await speechToText.stop();
    if (!mounted) return;
    updateAssistantState(() {
      isListening = false;
      isLiveTurnInFlight = true;
    });

    inputController.clear();
    await portal.sendChatMessage(message);

    if (!mounted) return;
    updateAssistantState(() {
      isLiveTurnInFlight = false;
    });
  }

  Future<void> _speakReplyThenResumeListening(
    ChatMessage message,
    PatientPortalProvider portal,
  ) async {
    if (!isLiveVoiceMode || isSpeaking) return;

    final toSpeak = _sanitizeSpeechText(message.content);
    if (toSpeak.isEmpty) return;

    updateAssistantState(() {
      isSpeaking = true;
    });

    final status = await tts.speak(toSpeak);
    if (!mounted) return;
    if (status != 1) {
      updateAssistantState(() {
        isSpeaking = false;
      });
    }

    if (!isLiveVoiceMode || !mounted) return;
    await _startVoiceListening(portal);
  }

  String _sanitizeSpeechText(String value) {
    return value
        .replaceAll(RegExp(r'[`*_>#\-|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _toggleSpeechPlayback(ChatMessage message) async {
    if (message.role == 'user') return;

    if (isSpeaking) {
      await tts.stop();
      if (!mounted) return;
      updateAssistantState(() {
        isSpeaking = false;
      });
      return;
    }

    final toSpeak = _sanitizeSpeechText(message.content);
    if (toSpeak.isEmpty) return;

    final status = await tts.speak(toSpeak);
    if (!mounted) return;
    if (status != 1) {
      updateAssistantState(() {
        isSpeaking = false;
      });
    }
  }

  Future<void> _interruptAiSpeechAndListen(PatientPortalProvider portal) async {
    if (!isSpeaking) return;
    await tts.stop();
    if (!mounted) return;
    updateAssistantState(() {
      isSpeaking = false;
    });
    if (isLiveVoiceMode) {
      await _startVoiceListening(portal);
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
