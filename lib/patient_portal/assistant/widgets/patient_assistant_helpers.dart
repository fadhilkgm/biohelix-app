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
  AppLanguage get _assistantLanguage =>
      context.read<LanguageProvider>().language;

  LocalizedStrings get _strings => AppStrings.of(_assistantLanguage);

  String get _assistantLanguageCode => switch (_assistantLanguage) {
    AppLanguage.ml => 'ml',
    AppLanguage.hi => 'hi',
    _ => 'en',
  };

  String get _speechLocaleId => switch (_assistantLanguage) {
    AppLanguage.ml => 'ml-IN',
    AppLanguage.hi => 'hi-IN',
    _ => 'en-IN',
  };

  String get _ttsLanguageCode => switch (_assistantLanguage) {
    AppLanguage.ml => 'ml-IN',
    AppLanguage.hi => 'hi-IN',
    _ => 'en-IN',
  };

  Future<void> _configureTtsLanguage() async {
    final target = _ttsLanguageCode;
    if (configuredTtsLanguage == target) return;
    await tts.setLanguage(target);
    await tts.setSpeechRate(switch (_assistantLanguage) {
      AppLanguage.ml => 0.42,
      AppLanguage.hi => 0.45,
      _ => 0.45,
    });
    await tts.setPitch(1.0);
    configuredTtsLanguage = target;
  }

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

    await portal.sendChatMessage(
      message,
      attachments: attachments,
      language: _assistantLanguageCode,
      mode: 'text',
    );
  }

  Future<void> _attachFile(PatientPortalProvider portal) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      final bytes = result.files.single.bytes;
      if (((path ?? '').isEmpty && bytes == null) || !mounted) return;
      final fileName = result.files.single.name;

      updateAssistantState(() {
        _isAttachmentUploadInFlight = true;
        _uploadingAttachmentName = fileName;
      });

      final uploaded = await portal.uploadDocument(
        filePath: path,
        bytes: bytes,
        fileName: fileName,
      );
      final attachment = ChatAttachment(
        name: fileName,
        url: uploaded.documentPath,
        mimeType: uploaded.documentType,
        sizeBytes: result.files.single.size,
        documentId: uploaded.id,
      );

      updateAssistantState(() {
        _pendingAttachments.add(attachment);
        _isAttachmentUploadInFlight = false;
        _uploadingAttachmentName = null;
      });

      unawaited(() async {
        try {
          await portal.analyzeDocument(uploaded.id);
          final summary =
              portal.analysisFor(uploaded.id)?.summary.trim() ??
              uploaded.summary?.trim() ??
              '';
          if (summary.isNotEmpty && mounted) {
            updateAssistantState(() {
              final index = _pendingAttachments.indexWhere(
                (item) => item.documentId == uploaded.id,
              );
              if (index < 0) return;
              final current = _pendingAttachments[index];
              _pendingAttachments[index] = ChatAttachment(
                name: current.name,
                url: current.url,
                mimeType: current.mimeType,
                sizeBytes: current.sizeBytes,
                documentId: current.documentId,
                analysisSummary: summary,
              );
            });
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_strings.assistantSummaryReady(fileName))),
          );
        } catch (_) {
          if (!mounted) return;
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
    bool available = false;
    try {
      available = await speechToText.initialize(
        debugLogging: true,
        onStatus: (status) {
          if (!mounted) return;
          debugPrint('SpeechToText Status: $status');
          if (status == 'done' || status == 'notListening') {
            updateAssistantState(() {
              isListening = false;
              soundLevel = 0.0;
            });
          }
        },
        onError: (errorNotification) {
          if (!mounted) return;
          debugPrint('SpeechToText Error: ${errorNotification.errorMsg}');
          updateAssistantState(() {
            isListening = false;
            soundLevel = 0.0;
          });

          if (errorNotification.errorMsg == 'error_speech_timeout' || 
              errorNotification.errorMsg == 'error_no_match') {
            if (!isSpeaking &&
                !isLiveTurnInFlight &&
                (isLiveVoiceMode || isVoiceActiveManually)) {
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted && (isLiveVoiceMode || isVoiceActiveManually)) {
                  _startVoiceListening(context.read<PatientPortalProvider>());
                }
              });
            }
          }
        },
      );
    } catch (e) {
      debugPrint('SpeechToText Initialization Exception: $e');
      available = false;
    }

    try {
      await _configureTtsLanguage();
      await tts.awaitSpeakCompletion(true);
      tts.setStartHandler(() {
        if (!mounted) return;
        debugPrint('TTS: Started speaking');
        updateAssistantState(() {
          isSpeaking = true;
        });
      });
      tts.setCompletionHandler(() {
        if (!mounted) return;
        debugPrint('TTS: Completed speaking');
        updateAssistantState(() {
          isSpeaking = false;
        });
        if (isLiveVoiceMode && !isLiveTurnInFlight) {
          Future.delayed(const Duration(milliseconds: 250), () {
            if (!mounted || !isLiveVoiceMode || isListening || isSpeaking) {
              return;
            }
            _startVoiceListening(context.read<PatientPortalProvider>());
          });
        }
      });
      tts.setCancelHandler(() {
        if (!mounted) return;
        debugPrint('TTS: Cancelled');
        updateAssistantState(() {
          isSpeaking = false;
        });
      });
      tts.setErrorHandler((msg) {
        if (!mounted) return;
        debugPrint('TTS Error: $msg');
        updateAssistantState(() {
          isSpeaking = false;
        });
      });
    } catch (e) {
      debugPrint('TTS Initialization Error: $e');
    }

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
        SnackBar(content: Text(_strings.assistantVoiceUnavailable)),
      );
      return;
    }

    if (isVoiceActiveManually) {
      // User tapped to STOP manually
      await speechToText.stop();
      if (!mounted) return;
      updateAssistantState(() {
        isListening = false;
        isVoiceActiveManually = false;
        soundLevel = 0.0;
      });
      return;
    }

    // User tapped to START manually
    updateAssistantState(() {
      isVoiceActiveManually = true;
    });
    await _startVoiceListening(portal);
  }

  Future<void> _toggleLiveVoiceMode(PatientPortalProvider portal) async {
    if (!await _ensureVoiceReady()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_strings.assistantLiveVoiceUnavailable)),
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
        soundLevel = 0.0;
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
      isVoiceActiveManually = false;
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
        soundLevel = 0.0;
      });
      debugPrint('Voice listening requested...');
      await _configureTtsLanguage();

      var started = await speechToText.listen(
        localeId: _speechLocaleId,
        listenFor: const Duration(seconds: 180),
        pauseFor: const Duration(seconds: 10),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        onSoundLevelChange: (level) {
          if (!mounted) return;
          updateAssistantState(() {
            soundLevel = level;
          });
        },
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords.trim();
          debugPrint('Speech Result: "$words" (final: ${result.finalResult})');
          
          if (words.isNotEmpty) {
            // Check if current text already ends with these words to avoid duplication
            final current = inputController.text;
            if (result.finalResult) {
              // On final result, if we are restarting, we might need to append
              if (!current.endsWith(words)) {
                inputController.text = current.isEmpty ? words : '$current $words';
              }
            } else {
              // While partial, just update the end if possible or replace if short
              if (current.length < words.length || !current.contains(words.substring(0, words.length ~/ 2))) {
                 inputController.text = words; 
              }
            }
            
            inputController.selection = TextSelection.fromPosition(
              TextPosition(offset: inputController.text.length),
            );
          }

          if (isLiveVoiceMode && result.finalResult && !isLiveTurnInFlight) {
            _sendLiveVoiceTurn(portal, words);
          } else if (isVoiceActiveManually && result.finalResult) {
            _sendManualVoiceTurn(portal, words);
          }
        },
      );

      // Fallback: If preferred locale failed, try with default locale
      if (started != true) {
        debugPrint('Preferred locale failed, trying default locale...');
        started = await speechToText.listen(
          listenFor: const Duration(seconds: 180),
          pauseFor: const Duration(seconds: 10),
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: true,
            listenMode: ListenMode.dictation,
          ),
          onSoundLevelChange: (level) {
            if (!mounted) return;
            updateAssistantState(() {
              soundLevel = level;
            });
          },
          onResult: (result) {
            if (!mounted) return;
            final words = result.recognizedWords.trim();
            debugPrint('SpeechToText Fallback Result: "$words" (final: ${result.finalResult})');

            if (words.isNotEmpty) {
              inputController.text = words;
              inputController.selection = TextSelection.fromPosition(
                TextPosition(offset: words.length),
              );
            }

            if (isLiveVoiceMode && result.finalResult && !isLiveTurnInFlight) {
              _sendLiveVoiceTurn(portal, words);
            } else if (isVoiceActiveManually && result.finalResult) {
              _sendManualVoiceTurn(portal, words);
            }
          },
        );
      }

      if (!mounted) return;
      if (started != true) {
        updateAssistantState(() {
          isListening = false;
          if (isLiveVoiceMode) {
            isLiveVoiceMode = false;
          }
          if (isVoiceActiveManually) {
            isVoiceActiveManually = false;
          }
          soundLevel = 0.0;
        });
      } else {
        updateAssistantState(() {
          isListening = true;
        });
      }
    } catch (error) {
      if (!mounted) return;
      updateAssistantState(() {
        isListening = false;
        isLiveVoiceMode = false;
        isVoiceActiveManually = false;
        soundLevel = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_strings.assistantUnableToListen}: $error')),
      );
    }
  }

  Future<void> _sendManualVoiceTurn(
    PatientPortalProvider portal,
    String recognizedText,
  ) async {
    final message = _sanitizeSpeechText(recognizedText);
    if (message.isEmpty) return;

    await speechToText.stop();
    if (!mounted) return;
    updateAssistantState(() {
      isListening = false;
      isVoiceActiveManually = false;
      soundLevel = 0.0;
    });

    inputController.text = message;
    inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: message.length),
    );

    await portal.sendChatMessage(
      message,
      language: _assistantLanguageCode,
      mode: 'voice',
    );

    if (!mounted) return;
    final messages = portal.chatMessages;
    if (messages.isNotEmpty && messages.last.role == 'ai') {
      await _speakReply(messages.last);
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
      soundLevel = 0.0;
    });

    inputController.clear();
    await portal.sendChatMessage(
      message,
      language: _assistantLanguageCode,
      mode: 'voice',
    );

    if (!mounted) return;
    final messages = portal.chatMessages;
    if (messages.isNotEmpty && messages.last.role == 'ai') {
      final fingerprint =
          '${messages.last.createdAt ?? ''}:${messages.last.content.hashCode}';
      updateAssistantState(() {
        lastLiveSpokenReply = fingerprint;
      });
      await _speakReply(messages.last);
    }

    updateAssistantState(() {
      isLiveTurnInFlight = false;
    });
  }

  Future<void> _speakReply(ChatMessage message) async {
    if (isSpeaking) {
      debugPrint('TTS skipped: Already speaking');
      return;
    }

    final toSpeak = _sanitizeSpeechText(message.content);
    debugPrint('TTS: Attempting to speak: "$toSpeak"');
    if (toSpeak.isEmpty) {
      debugPrint('TTS skipped: Empty content');
      return;
    }

    await _configureTtsLanguage();
    updateAssistantState(() {
      isSpeaking = true;
    });

    final status = await tts.speak(toSpeak);
    debugPrint('TTS Speak call status: $status');
    if (!mounted) return;
    if (status != 1) {
      updateAssistantState(() {
        isSpeaking = false;
      });
    }
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

    await _configureTtsLanguage();
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
