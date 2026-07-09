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

  String get _speechLocaleId =>
      _assistantLanguage == AppLanguage.ml ? 'ml_IN' : 'en_IN';

  String get _ttsLanguageCode =>
      _assistantLanguage == AppLanguage.ml ? 'ml-IN' : 'en-IN';

  Future<void> _configureTtsLanguage() async {
    final target = _ttsLanguageCode;
    if (configuredTtsLanguage == target) return;
    await tts.setLanguage(target);
    await tts.setSpeechRate(_assistantLanguage == AppLanguage.ml ? 0.42 : 0.45);
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
      // Speak the AI reply aloud automatically once it arrives.
      _pendingAutoSpeak = true;
    });

    await portal.sendChatMessage(
      message,
      attachments: attachments,
      language: _assistantLanguageCode,
      mode: 'text',
    );
  }

  /// Speaks a freshly-arrived AI reply aloud (text mode). Manages `isSpeaking`
  /// directly so it works whether or not the live-voice TTS handlers are set.
  Future<void> _autoSpeakReply(ChatMessage message) async {
    if (isLiveVoiceMode) return;
    final toSpeak = _sanitizeSpeechText(message.content);
    if (toSpeak.isEmpty) return;

    // Flip `isSpeaking` first so the reply's word-by-word reveal starts right
    // away, before any TTS setup latency.
    updateAssistantState(() {
      isSpeaking = true;
    });
    await _configureTtsLanguage();
    await voiceManager.awaitSpeakCompletion(true);
    if (!mounted) return;
    try {
      await voiceManager.speak(toSpeak, _ttsLanguageCode);
    } catch (_) {
    } finally {
      if (mounted) {
        updateAssistantState(() {
          isSpeaking = false;
        });
      }
    }
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

  Future<void> _initializeVoiceFeatures() async {
    try {
      final available = await speechToText.initialize(
        onStatus: (status) async {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            // Auto-resume listening in Live Voice Mode only
            final shouldAutoResume =
                (isLiveVoiceMode && !isSpeaking && !isLiveTurnInFlight);
            if (shouldAutoResume) {
              await Future<void>.delayed(const Duration(milliseconds: 300));
              if (mounted && isLiveVoiceMode) {
                final portal = context.read<PatientPortalProvider>();
                await _startVoiceListening(portal);
              }
            } else {
              if (isListening || isTapRecording) {
                updateAssistantState(() {
                  _isListening = false;
                  _isTapRecording = false;
                  _soundLevel = 0.0;
                });
                Future.delayed(Duration.zero, () async {
                  try {
                    await speechToText.cancel();
                  } catch (_) {}
                });
              }
            }
          }
        },
        onError: (errorNotification) async {
          if (!mounted) return;
          // Auto-resume on transient errors in Live Voice Mode only
          final shouldAutoResume =
              (isLiveVoiceMode && !isSpeaking && !isLiveTurnInFlight);
          if (shouldAutoResume) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            if (mounted && isLiveVoiceMode) {
              final portal = context.read<PatientPortalProvider>();
              await _startVoiceListening(portal);
            }
          } else {
            if (isListening || isTapRecording) {
              updateAssistantState(() {
                _isListening = false;
                _isTapRecording = false;
                _soundLevel = 0.0;
              });
              Future.delayed(Duration.zero, () async {
                try {
                  await speechToText.cancel();
                } catch (_) {}
              });
            }
          }
        },
      ).timeout(const Duration(seconds: 8), onTimeout: () => false);

      await _configureTtsLanguage();
      await voiceManager.awaitSpeakCompletion(true);
      voiceManager.setTtsStartHandler(() {
        if (!mounted) return;
        updateAssistantState(() {
          isSpeaking = true;
        });
      });
      voiceManager.setTtsCompletionHandler(() async {
        if (!mounted) return;
        updateAssistantState(() {
          isSpeaking = false;
        });

        // Re-activate mic listening ONLY after the voice output has finished playing,
        // preventing the microphone from capturing the AI's own spoken output.
        if (isLiveVoiceMode && !isLiveTurnInFlight && !isListening) {
          final portal = context.read<PatientPortalProvider>();
          await _startVoiceListening(portal);
        }
      });
      voiceManager.setTtsCancelHandler(() {
        if (!mounted) return;
        updateAssistantState(() {
          isSpeaking = false;
        });
      });

      if (!mounted) return;
      updateAssistantState(() {
        speechReady = available;
      });
    } catch (e) {
      // ignore: avoid_print
      print("🎙️ [VoiceAssistant] SpeechToText initialization failed: $e");
      if (!mounted) return;
      updateAssistantState(() {
        speechReady = false;
      });
    }
  }

  /// Push-to-talk: tap once to start recording, tap again to stop and send.
  /// The recorded clip is uploaded to the server-side voice endpoint, which
  /// transcribes it, generates a reply, and (when configured) returns spoken
  /// audio that we play back. See `Health_AI_Chat_Voice_API.md` §5.
  Future<void> _toggleVoiceInput() async {
    final portal = context.read<PatientPortalProvider>();

    if (isLiveVoiceMode) {
      await _toggleLiveVoiceMode(portal);
    }

    // Currently recording — stop, upload and let the server handle STT/TTS.
    if (isTapRecording) {
      String? audioPath;
      try {
        audioPath = await voiceManager.stopRecording();
      } catch (_) {}
      updateAssistantState(() {
        _isTapRecording = false;
        _isListening = false;
        _soundLevel = 0.0;
      });
      if ((audioPath ?? '').isEmpty) return;
      await _sendVoiceTurn(portal, audioPath!);
      return;
    }

    // Not recording — begin capturing a clip.
    try {
      final path = await voiceManager.startRecording();
      if (path == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_strings.assistantLiveVoiceUnavailable)),
        );
        return;
      }
      updateAssistantState(() {
        _isTapRecording = true;
        _isListening = true;
      });
    } catch (error) {
      if (!mounted) return;
      updateAssistantState(() {
        _isTapRecording = false;
        _isListening = false;
        _soundLevel = 0.0;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${_strings.assistantUnableToListen}: $error')));
    }
  }

  /// Uploads a recorded push-to-talk clip and plays back the spoken reply if
  /// the server returned one.
  Future<void> _sendVoiceTurn(
    PatientPortalProvider portal,
    String audioPath,
  ) async {
    // Voice turns play the server's spoken audio directly; don't also auto-speak.
    updateAssistantState(() {
      _pendingAutoSpeak = false;
    });
    final voiceReply = await portal.sendChatVoiceMessage(
      audioPath,
      language: _assistantLanguageCode,
    );

    // Clean up the temporary recording once uploaded.
    unawaited(voiceManager.deleteRecording(audioPath));

    if (!mounted || voiceReply == null) return;

    final audioUrl = voiceReply.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) return;

    // Server returned spoken audio — play it back.
    updateAssistantState(() {
      isSpeaking = true;
    });
    try {
      await voiceManager.playRemoteAudio(audioUrl);
    } catch (_) {
    } finally {
      if (mounted) {
        updateAssistantState(() {
          isSpeaking = false;
        });
      }
    }
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
      await voiceManager.stopListening();
      await voiceManager.stopSpeaking();
      if (!mounted) return;
      updateAssistantState(() {
        _isLiveVoiceMode = false;
        _isListening = false;
        _isSpeaking = false;
        _isLiveTurnInFlight = false;
        _isTapRecording = false;
        _soundLevel = 0.0;
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
        await voiceManager.stopSpeaking();
      }

      updateAssistantState(() {
        _isListening = true;
      });
      await _configureTtsLanguage();

      try {
        await speechToText.listen(
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: true,
            localeId: _speechLocaleId,
            listenFor: const Duration(seconds: 60),
            pauseFor: isLiveVoiceMode
                ? const Duration(seconds: 3)
                : const Duration(seconds: 6),
          ),
          onResult: (result) {
            if (!mounted) return;
            final words = result.recognizedWords.trim();
            if (isLiveVoiceMode) {
              if (words.isEmpty || isLiveTurnInFlight) return;

              // In live mode, don't write transcript into the text composer.
              // Auto-send after a brief pause, or immediately on final result.
              _liveAutoSendDebounce?.cancel();
              if (result.finalResult) {
                if (_sanitizeSpeechText(words) != _lastLiveSentText) {
                  _lastLiveSentText = _sanitizeSpeechText(words);
                  _sendLiveVoiceTurn(portal, words);
                }
                return;
              }

              _liveAutoSendDebounce = Timer(
                const Duration(milliseconds: 1200),
                () {
                  if (!mounted || !isLiveVoiceMode || isLiveTurnInFlight) {
                    return;
                  }
                  final sanitized = _sanitizeSpeechText(words);
                  if (sanitized.isEmpty || sanitized == _lastLiveSentText) {
                    return;
                  }
                  _lastLiveSentText = sanitized;
                  _sendLiveVoiceTurn(portal, sanitized);
                },
              );
            } else if (!isLiveVoiceMode && result.finalResult) {
              inputController.value = TextEditingValue(
                text: words,
                selection: TextSelection.collapsed(offset: words.length),
              );
              speechToText.stop();
              updateAssistantState(() {
                _isListening = false;
                _isTapRecording = false;
                _soundLevel = 0.0;
              });
              if (words.isNotEmpty) {
                _sendMessage(portal);
              }
            }
          },
          onSoundLevelChange: (level) {
            if (!mounted) return;
            double norm = 0.0;
            if (level < 0) {
              norm = (level + 160) / 160.0;
            } else {
              norm = (level + 2) / 14.0;
            }
            updateAssistantState(() {
              _soundLevel = norm.clamp(0.0, 1.0);
            });
          },
        );
      } catch (e) {
        // Fallback for emulators/devices where STT fails to start, allowing visual testing of premium animations.
        // ignore: avoid_print
        print(
          "🎙️ [VoiceAssistant] Speech recognition failed to start: $e. Falling back to simulated animation mode.",
        );
      }

      if (!mounted) return;
      updateAssistantState(() {
        _isListening = true;
      });
    } catch (error) {
      if (!mounted) return;
      updateAssistantState(() {
        if (_isTapRecording || _isLiveVoiceMode) {
          _isListening = true;
        } else {
          _isListening = false;
          _isTapRecording = false;
        }
        _soundLevel = 0.0;
      });

      // If we are in live voice mode, retry listening after a short delay to let
      // the device finish transitioning its audio session from playback to recording.
      if (isLiveVoiceMode && !isSpeaking && !isLiveTurnInFlight) {
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        if (mounted &&
            isLiveVoiceMode &&
            !isListening &&
            !isSpeaking &&
            !isLiveTurnInFlight) {
          await _startVoiceListening(portal);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_strings.assistantUnableToListen}: $error'),
          ),
        );
      }
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
      _isListening = false;
      _isLiveTurnInFlight = true;
      _soundLevel = 0.0;
    });

    bool success = false;
    try {
      inputController.clear();
      await portal.sendChatMessage(
        message,
        language: _assistantLanguageCode,
        mode: 'voice',
      );
      success = true;
    } catch (e) {
      // ignore: avoid_print
      print("Error sending live voice chat message: $e");
    } finally {
      if (mounted) {
        updateAssistantState(() {
          isLiveTurnInFlight = false;
        });
        // Only restart the mic here if the message FAILED to send.
        // If it succeeded, the UI will trigger _speakReplyThenResumeListening,
        // and the TTS completion handler will restart the mic AFTER the AI finishes talking!
        if (!success && isLiveVoiceMode && !isListening && !isSpeaking) {
          await _startVoiceListening(portal);
        }
      }
    }
  }

  Future<void> _speakReplyThenResumeListening(
    ChatMessage message,
    PatientPortalProvider portal,
  ) async {
    if (!isLiveVoiceMode || isSpeaking) return;

    final toSpeak = _sanitizeSpeechText(message.content);
    if (toSpeak.isEmpty) return;

    await _configureTtsLanguage();
    updateAssistantState(() {
      isSpeaking = true;
    });

    await voiceManager.speak(toSpeak, _ttsLanguageCode);
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
      await voiceManager.stopSpeaking();
      if (!mounted) return;
      updateAssistantState(() {
        isSpeaking = false;
      });

      // If the user stops the AI speech directly from the chat bubble,
      // we must resume the microphone immediately so the Live Voice loop doesn't break!
      if (isLiveVoiceMode && !isListening && !isLiveTurnInFlight) {
        final portal = context.read<PatientPortalProvider>();
        await _startVoiceListening(portal);
      }
      return;
    }

    final toSpeak = _sanitizeSpeechText(message.content);
    if (toSpeak.isEmpty) return;

    await _configureTtsLanguage();
    await voiceManager.speak(toSpeak, _ttsLanguageCode);
    if (!mounted) return;
  }

  Future<void> _interruptAiSpeechAndListen(PatientPortalProvider portal) async {
    if (!isSpeaking) return;
    await voiceManager.stopSpeaking();
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
