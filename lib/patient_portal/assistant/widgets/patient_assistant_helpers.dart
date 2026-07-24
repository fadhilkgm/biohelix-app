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
  AppLanguage get _assistantLanguage =>
      context.read<LanguageProvider>().language;

  LocalizedStrings get _strings => AppStrings.of(_assistantLanguage);

  String get _assistantLanguageCode =>
      _assistantLanguage == AppLanguage.ml ? 'ml' : 'en';

  String get _ttsLanguageCode =>
      _assistantLanguage == AppLanguage.ml ? 'ml-IN' : 'en-IN';

  Future<void> _sendMessage(PatientPortalProvider portal) async {
    final message = inputController.text.trim();
    final attachments = List<ChatAttachment>.from(_pendingAttachments);
    if (message.isEmpty && attachments.isEmpty) return;

    inputController.clear();
    updateAssistantState(() {
      _pendingAttachments.clear();
    });

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
        const SnackBar(
          content: Text('Message not sent. Check your connection and retry.'),
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
        _analyzingAttachmentName = fileName;
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
            _analyzingAttachmentName = null;
          });
          final result = analysis;
          if (result != null && result.summary.trim().isNotEmpty) {
            _showDocumentAnalysisResult(fileName, result);
          } else if (result?.status == 'processing' ||
              result?.status == 'queued') {
            await _showAttachmentMessage(
              'Your report is queued for analysis. We will show the summary when it is ready.',
            );
          }
          if (result?.summary.trim().isNotEmpty == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_strings.assistantSummaryReady(fileName))),
            );
          }
        } catch (_) {
          if (!mounted) return;
          updateAssistantState(() {
            _isAttachmentAnalysisInFlight = false;
            _analyzingAttachmentName = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_strings.assistantUploadPending(fileName))),
          );
        }
      }());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_strings.assistantUploadedReady(fileName))),
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
      _analyzingAttachmentName = null;
    });
    if (!mounted) return;
    final message = _friendlyAttachmentError(error);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyGalleryImageName(String originalName, String path) {
    final source = originalName.trim().isNotEmpty ? originalName : path;
    final extensionMatch = RegExp(r'\.([a-zA-Z0-9]{2,5})$').firstMatch(source);
    final extension = extensionMatch?.group(1)?.toLowerCase() ?? 'jpg';
    return 'Gallery image.$extension';
  }

  Future<void> _showDocumentAnalysisResult(
    String fileName,
    DocumentAnalysisResult analysis,
  ) {
    final riskReason = (analysis.riskReason ?? '').trim();
    final findings = analysis.findings.take(4).toList();
    final recommendations =
        (analysis.recommendations.isNotEmpty
                ? analysis.recommendations
                : analysis.texts)
            .map(_cleanAnalysisLine)
            .where((item) => item.isNotEmpty)
            .take(3)
            .toList();
    final riskLevel = (analysis.riskLevel ?? '').trim();

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.32,
        maxChildSize: 0.86,
        builder: (context, controller) => SafeArea(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      _displayAttachmentName(fileName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title(sheetContext),
                    ),
                  ),
                  if (riskLevel.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.s8),
                    _AnalysisRiskPill(level: riskLevel),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                _cleanAnalysisSummary(analysis.summary),
                style: AppTextStyles.bubbleAi(sheetContext),
              ),
              if (riskReason.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s12),
                _AnalysisSection(
                  title: 'Why it matters',
                  lines: [_cleanAnalysisLine(riskReason)],
                ),
              ],
              if (findings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s12),
                _AnalysisSection(title: 'Key findings', lines: findings),
              ],
              if (recommendations.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s12),
                _AnalysisSection(title: 'Next steps', lines: recommendations),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _displayAttachmentName(String fileName) {
    if (fileName.startsWith('image_picker_')) return 'Gallery image';
    return fileName;
  }

  String _cleanAnalysisSummary(String value) {
    final cleaned = _cleanAnalysisLine(value);
    if (cleaned.startsWith('{') ||
        cleaned.contains('"document_type"') ||
        cleaned.contains('"summary"')) {
      return 'The report was analyzed, but the AI response needs a cleaner structured summary. Please review the highlighted values with your doctor.';
    }
    return cleaned.isNotEmpty
        ? cleaned
        : 'The report was analyzed. Please review the findings with your doctor.';
  }

  String _cleanAnalysisLine(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('Review the raw AI output manually.', '')
        .trim();
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('{') || cleaned.contains('"risk_level"')) return '';
    return cleaned;
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

  Future<void> _toggleLiveVoiceMode(PatientPortalProvider portal) async {
    if (isLiveVoiceMode) {
      await liveVoiceController.stop();
      if (!mounted) return;
      updateAssistantState(() {
        _isLiveVoiceMode = false;
        _isListening = false;
        _isSpeaking = false;
        _isLiveTurnInFlight = false;
        _soundLevel = 0;
        _livePartialTranscript = '';
        _liveSubmittedTranscript = '';
        _liveVoiceError = null;
        _liveConversationId = null;
      });
      return;
    }

    if ((portal.activeChatThreadId ?? '').isEmpty) {
      await portal.createNewChatThread();
    }
    if (!mounted || (portal.activeChatThreadId ?? '').isEmpty) return;

    updateAssistantState(() {
      _isLiveVoiceMode = true;
      _liveConversationId = portal.activeChatThreadId;
      _livePartialTranscript = '';
      _liveSubmittedTranscript = '';
      _liveVoiceError = null;
    });
    await liveVoiceController.start(locale: _ttsLanguageCode);
  }

  Future<void> _interruptAiSpeechAndListen(PatientPortalProvider portal) async {
    if (!isLiveVoiceMode) return;
    await liveVoiceController.interrupt();
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

class _AnalysisRiskPill extends StatelessWidget {
  const _AnalysisRiskPill({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final normalized = level.toLowerCase();
    final color = switch (normalized) {
      'critical' => const Color(0xFFB3261E),
      'high' => const Color(0xFFD04718),
      'moderate' => const Color(0xFFB26A00),
      _ => const Color(0xFF137A52),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          '${level[0].toUpperCase()}${level.substring(1).toLowerCase()} risk',
          style: AppTextStyles.subtitle(
            context,
          ).copyWith(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _AnalysisSection extends StatelessWidget {
  const _AnalysisSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final visibleLines = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (visibleLines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.subtitle(context).copyWith(
            fontWeight: FontWeight.w800,
            color: AiChatColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        ...visibleLines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, size: 6),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(line, style: AppTextStyles.subtitle(context)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
