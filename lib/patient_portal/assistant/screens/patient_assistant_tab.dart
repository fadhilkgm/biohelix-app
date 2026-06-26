// ignore_for_file: unnecessary_getters_setters

part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _AssistantTab extends StatefulWidget {
  const _AssistantTab();

  @override
  State<_AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<_AssistantTab> {
  final _inputController = TextEditingController();
  final _messagesController = ScrollController();
  late final VoiceManager _voiceManager;
  int _lastAutoScrolledMessageCount = 0;
  String? _lastAutoScrolledThreadId;
  bool _showMobileSidebar = false;
  bool _speechReady = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isLiveVoiceMode = false;
  bool _isLiveTurnInFlight = false;
  bool _isTapRecording = false;
  Timer? _liveAutoSendDebounce;
  String _lastLiveSentText = '';
  String? _lastLiveSpokenReply;
  String? _configuredTtsLanguage;
  final List<ChatAttachment> _pendingAttachments = <ChatAttachment>[];
  bool _isAttachmentUploadInFlight = false;
  String? _uploadingAttachmentName;
  double _soundLevel = 0.0;

  TextEditingController get inputController => _inputController;
  ScrollController get messagesController => _messagesController;
  SpeechToText get speechToText => _voiceManager.nativeStt;
  FlutterTts get tts => _voiceManager.nativeTts;
  VoiceManager get voiceManager => _voiceManager;

  bool get speechReady => _speechReady;
  set speechReady(bool value) {
    _updateAssistantState(() {
      _speechReady = value;
    });
  }

  bool get isListening => _isListening;
  set isListening(bool value) {
    _updateAssistantState(() {
      _isListening = value;
    });
  }

  bool get isSpeaking => _isSpeaking;
  set isSpeaking(bool value) {
    _updateAssistantState(() {
      _isSpeaking = value;
    });
  }

  bool get isLiveVoiceMode => _isLiveVoiceMode;
  set isLiveVoiceMode(bool value) {
    _updateAssistantState(() {
      _isLiveVoiceMode = value;
    });
  }

  bool get isLiveTurnInFlight => _isLiveTurnInFlight;
  set isLiveTurnInFlight(bool value) {
    _updateAssistantState(() {
      _isLiveTurnInFlight = value;
    });
  }

  String? get lastLiveSpokenReply => _lastLiveSpokenReply;
  set lastLiveSpokenReply(String? value) {
    _updateAssistantState(() {
      _lastLiveSpokenReply = value;
    });
  }

  String? get configuredTtsLanguage => _configuredTtsLanguage;
  set configuredTtsLanguage(String? value) {
    _updateAssistantState(() {
      _configuredTtsLanguage = value;
    });
  }

  bool get isTapRecording => _isTapRecording;
  set isTapRecording(bool value) {
    _updateAssistantState(() {
      _isTapRecording = value;
    });
  }

  double get soundLevel => _soundLevel;
  set soundLevel(double value) {
    _updateAssistantState(() {
      _soundLevel = value;
    });
  }

  void _updateAssistantState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

  void updateAssistantState(VoidCallback update) =>
      _updateAssistantState(update);

  void _clearComposer() {
    _inputController.clear();
    _pendingAttachments.clear();
    _isAttachmentUploadInFlight = false;
    _uploadingAttachmentName = null;
    _isTapRecording = false;
  }

  @override
  void initState() {
    super.initState();
    _voiceManager = VoiceManager(
      sarvamApiKey: AppConfig.fromEnvironment().sarvamApiKey,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PatientPortalProvider>().initializeChatThreads();
    });
  }

  @override
  void dispose() {
    _isLiveVoiceMode = false;
    _liveAutoSendDebounce?.cancel();
    _voiceManager.stopListening();
    _voiceManager.stopSpeaking();
    _messagesController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeLanguage = context.watch<LanguageProvider>().language;
    final strings = AppStrings.of(activeLanguage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _configureTtsLanguage();
    });

    return Consumer<PatientPortalProvider>(
      builder: (context, portal, _) {
        final messages = portal.chatMessages;
        final activeThreadId = portal.activeChatThreadId;
        final busy = portal.isSendingMessage || portal.isUploadingDocument;
        final pendingAttachments = List<ChatAttachment>.unmodifiable(
          _pendingAttachments,
        );
        final uploadInProgress =
            _isAttachmentUploadInFlight || portal.isUploadingDocument;
        final uploadingLabel = _uploadingAttachmentName;

        if (_isLiveVoiceMode && !_isLiveTurnInFlight && messages.isNotEmpty) {
          final last = messages.last;
          final fingerprint =
              '${last.createdAt ?? ''}:${last.content.hashCode}';
          if (last.role != 'user' && _lastLiveSpokenReply != fingerprint) {
            _lastLiveSpokenReply = fingerprint;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_isLiveVoiceMode) return;
              _speakReplyThenResumeListening(last, portal);
            });
          }
        }

        if (activeThreadId != _lastAutoScrolledThreadId) {
          _lastAutoScrolledThreadId = activeThreadId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_messagesController.hasClients) return;
            final position = _messagesController.position;
            if (!position.hasContentDimensions) return;
            _messagesController.jumpTo(position.maxScrollExtent);
          });
        }

        if (messages.length != _lastAutoScrolledMessageCount || busy) {
          _lastAutoScrolledMessageCount = messages.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_messagesController.hasClients) return;
            final position = _messagesController.position;
            if (!position.hasContentDimensions) return;
            try {
              _messagesController.animateTo(
                position.maxScrollExtent,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            } catch (_) {
              // Ignore transient detach/layout races during route and keyboard changes.
            }
          });
        }

        return PopScope<void>(
          canPop: !_isLiveVoiceMode,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_isLiveVoiceMode) {
              _toggleLiveVoiceMode(portal);
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showDesktopSidebar = constraints.maxWidth >= 940;

              Widget messagePane() {
                final patientName =
                    (portal.dashboard?.patient.name.trim().isNotEmpty ?? false)
                    ? portal.dashboard!.patient.name.trim().split(' ').first
                    : 'there';

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: ChatHeaderWidget(
                        onBack: () {
                          if (_isLiveVoiceMode) {
                            _toggleLiveVoiceMode(portal);
                            return;
                          }
                          Navigator.of(context).maybePop();
                        },
                        onToggleThreads: () {
                          setState(() {
                            _showMobileSidebar = !_showMobileSidebar;
                          });
                        },
                        showToggleThreads: !showDesktopSidebar,
                        onNewChat: () async {
                          _updateAssistantState(_clearComposer);
                          await portal.createNewChatThread();
                        },
                        isLiveMode: _isLiveVoiceMode,
                        isListening: _isListening,
                        isSpeaking: _isSpeaking,
                        onInterruptAi: () =>
                            _interruptAiSpeechAndListen(portal),
                      ),
                    ),
                    Expanded(
                      child: _isLiveVoiceMode
                          ? _AssistantLiveStage(
                              patientName: patientName,
                              isListening: _isListening,
                              isSpeaking: _isSpeaking,
                              isBusy: portal.isSendingMessage,
                              latestAssistantText: _latestAssistantText(
                                messages,
                              ),
                              onInterrupt: () =>
                                  _interruptAiSpeechAndListen(portal),
                              onStopLive: () => _toggleLiveVoiceMode(portal),
                            )
                          : messages.isEmpty && !portal.isSendingMessage
                          ? _AssistantEmptyState(
                              prompts: strings.assistantStarterPrompts,
                              patientName: patientName,
                              onPromptTap: (prompt) {
                                _inputController.text = prompt;
                                _sendMessage(portal);
                              },
                            )
                          : ListView.separated(
                              controller: _messagesController,
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                              itemCount:
                                  messages.length +
                                  (portal.isSendingMessage ? 1 : 0),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.s14),
                              itemBuilder: (context, index) {
                                if (index >= messages.length) {
                                  return const TypingIndicatorWidget();
                                }

                                final message = messages[index];
                                final date = _messageDate(message, index);
                                final showDate =
                                    index == 0 ||
                                    _dateLabel(date) !=
                                        _dateLabel(
                                          _messageDate(
                                            messages[index - 1],
                                            index - 1,
                                          ),
                                        );
                                final attachments = _attachmentsFromMessage(
                                  context,
                                  message,
                                );

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (showDate)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: AppSpacing.s12,
                                        ),
                                        child: _DateSeparator(
                                          label: _dateLabel(date),
                                        ),
                                      ),
                                    _MessageBubbleWidget(
                                      message: message,
                                      timeLabel: _messageTimeLabel(
                                        message,
                                        index,
                                      ),
                                      attachments: attachments,
                                      onSpeakTap: () =>
                                          _toggleSpeechPlayback(message),
                                      isSpeaking:
                                          _isSpeaking &&
                                          message.role != 'user' &&
                                          index == messages.length - 1,
                                      onStopTap: () =>
                                          _interruptAiSpeechAndListen(portal),
                                      onAttachmentTap: (attachment) {
                                        _openAttachmentPreview(
                                          context,
                                          attachment,
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    if (pendingAttachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (
                                var i = 0;
                                i < pendingAttachments.length;
                                i++
                              )
                                Padding(
                                  padding: EdgeInsets.only(
                                    right: i == pendingAttachments.length - 1
                                        ? 0
                                        : AppSpacing.s8,
                                  ),
                                  child: InputChip(
                                    avatar: Icon(
                                      pendingAttachments[i].isImage
                                          ? Icons.image_outlined
                                          : Icons.attach_file_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      pendingAttachments[i].name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onPressed: () {
                                      final attachment = pendingAttachments[i];
                                      _openAttachmentPreview(
                                        context,
                                        _ChatAttachment(
                                          name: attachment.name,
                                          url: _resolveAttachmentUrl(
                                            context,
                                            attachment.url,
                                          ),
                                          sizeLabel: _formatBytes(
                                            attachment.sizeBytes,
                                          ),
                                          isImage: attachment.isImage,
                                        ),
                                      );
                                    },
                                    onDeleted: () {
                                      _updateAssistantState(() {
                                        _pendingAttachments.removeAt(i);
                                      });
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (uploadInProgress)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AiChatColors.bubbleAiSoft,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  uploadingLabel == null ||
                                          uploadingLabel.trim().isEmpty
                                      ? strings.assistantUploadingAttachment
                                      : strings
                                            .assistantUploadingNamedAttachment(
                                              uploadingLabel,
                                            ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.subtitle(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      child: _isLiveVoiceMode
                          ? const SizedBox.shrink()
                          : ChatInputWidget(
                              controller: _inputController,
                              isBusy: busy,
                              isListening: _isListening,
                              isLiveMode: _isLiveVoiceMode,
                              isSpeaking: _isSpeaking,
                              soundLevel: _soundLevel,
                              onAttach: () => _attachFile(portal),
                              onLiveTap: () => _toggleLiveVoiceMode(portal),
                              onVoiceTap: _toggleVoiceInput,
                              onInterrupt: () =>
                                  _interruptAiSpeechAndListen(portal),
                              onSend: () => _sendMessage(portal),
                            ),
                    ),
                  ],
                );
              }

              final sidebar = ChatSidebarWidget(
                threads: portal.chatThreads,
                activeThreadId: portal.activeChatThreadId,
                onThreadSelect: (threadId) {
                  _updateAssistantState(_clearComposer);
                  portal.switchChatThread(threadId);
                  if (!showDesktopSidebar) {
                    setState(() {
                      _showMobileSidebar = false;
                    });
                  }
                },
                onRenameThread: (threadId) => _renameThread(portal, threadId),
                onDeleteThread: (threadId) =>
                    _confirmDeleteThread(portal, threadId),
                onNewChat: () async {
                  _updateAssistantState(_clearComposer);
                  await portal.createNewChatThread();
                },
              );

              return SafeArea(
                top: true,
                bottom: false,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AiChatColors.background,
                        AiChatColors.background,
                        AiChatColors.surfaceTint,
                        AiChatColors.backgroundBlue,
                      ],
                      stops: [0.0, 0.58, 0.78, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          if (showDesktopSidebar)
                            SizedBox(
                              width: 300,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  8,
                                  12,
                                ),
                                child: sidebar,
                              ),
                            ),
                          Expanded(child: messagePane()),
                        ],
                      ),
                      if (!showDesktopSidebar && _showMobileSidebar)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showMobileSidebar = false;
                              });
                            },
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      if (!showDesktopSidebar && _showMobileSidebar)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: SizedBox(
                            width: 296,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                              child: sidebar,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

String? _latestAssistantText(List<ChatMessage> messages) {
  for (final message in messages.reversed) {
    if (message.role != 'user' && message.content.trim().isNotEmpty) {
      return message.content.trim();
    }
  }
  return null;
}

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState({
    required this.prompts,
    required this.patientName,
    required this.onPromptTap,
  });

  final List<String> prompts;
  final String patientName;
  final ValueChanged<String> onPromptTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 130, 24, 18),
      children: [
        const Center(child: _GeminiSparkle(size: 58)),
        const SizedBox(height: 38),
        Text(
          'Hi $patientName, how can I help?',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: AiChatColors.textPrimary,
            fontSize: 40,
            height: 1.1,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.8,
          ),
        ),
        const SizedBox(height: 96),
        for (final prompt in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextButton.icon(
              onPressed: () => onPromptTap(prompt),
              icon: const Icon(Icons.auto_awesome_rounded, size: 19),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(prompt, textAlign: TextAlign.left),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: AiChatColors.primary,
                textStyle: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: AiChatColors.border),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          strings.assistantDisclaimer,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: const Color(0xFF8E8E93),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _AssistantLiveStage extends StatefulWidget {
  const _AssistantLiveStage({
    required this.patientName,
    required this.isListening,
    required this.isSpeaking,
    required this.isBusy,
    required this.latestAssistantText,
    required this.onInterrupt,
    required this.onStopLive,
  });

  final String patientName;
  final bool isListening;
  final bool isSpeaking;
  final bool isBusy;
  final String? latestAssistantText;
  final VoidCallback onInterrupt;
  final VoidCallback onStopLive;

  @override
  State<_AssistantLiveStage> createState() => _AssistantLiveStageState();
}

class _AssistantLiveStageState extends State<_AssistantLiveStage> {
  final ScrollController _liveTextScrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _AssistantLiveStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking &&
        widget.latestAssistantText != oldWidget.latestAssistantText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_liveTextScrollController.hasClients) return;
        _liveTextScrollController.animateTo(
          _liveTextScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _liveTextScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSpeaking = widget.isSpeaking;
    final isListening = widget.isListening;
    final displayText =
        isSpeaking && (widget.latestAssistantText ?? '').isNotEmpty
        ? widget.latestAssistantText!
        : 'Hi ${widget.patientName}, how can I help?';

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 160, 26, 180),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LiveStatusOrb(
                  isListening: isListening,
                  isSpeaking: isSpeaking,
                  isBusy: widget.isBusy,
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _liveTextScrollController,
                    child: Text(
                      displayText,
                      textAlign: isSpeaking
                          ? TextAlign.start
                          : TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: AiChatColors.textPrimary,
                        fontSize: isSpeaking ? 32 : 40,
                        height: isSpeaking ? 1.18 : 1.1,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 28,
          child: _LiveControlsDock(
            isListening: isListening,
            isSpeaking: isSpeaking,
            onInterrupt: widget.onInterrupt,
            onStopLive: widget.onStopLive,
          ),
        ),
      ],
    );
  }
}

class _LiveControlsDock extends StatelessWidget {
  const _LiveControlsDock({
    required this.isListening,
    required this.isSpeaking,
    required this.onInterrupt,
    required this.onStopLive,
  });

  final bool isListening;
  final bool isSpeaking;
  final VoidCallback onInterrupt;
  final VoidCallback onStopLive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _LiveOrb(isListening: isListening, isSpeaking: isSpeaking),
        _RoundLiveButton(
          icon: Icons.stop_rounded,
          onTap: isSpeaking ? onInterrupt : () {},
          highlighted: isSpeaking,
        ),
        _RoundLiveButton(icon: Icons.close_rounded, onTap: onStopLive),
      ],
    );
  }
}

class _LiveStatusOrb extends StatelessWidget {
  const _LiveStatusOrb({
    required this.isListening,
    required this.isSpeaking,
    required this.isBusy,
  });

  final bool isListening;
  final bool isSpeaking;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colors = isSpeaking
        ? const [Color(0xFF1B4D3E), Color(0xFF35D399), Color(0xFF9EF3D1)]
        : isListening
        ? const [Color(0xFF0F3A7A), Color(0xFF5A88F1), Color(0xFFAFC7FF)]
        : isBusy
        ? const [Color(0xFF6B4E16), Color(0xFFF0B429), Color(0xFFFFE4A3)]
        : const [Color(0xFF2E8B57), Color(0xFF35D399), Color(0xFF1B4D3E)];

    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[1].withValues(alpha: 0.42),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.graphic_eq_rounded,
        color: Colors.white,
        size: 38,
      ),
    );
  }
}

class _RoundLiveButton extends StatelessWidget {
  const _RoundLiveButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: highlighted ? AiChatColors.primary : Colors.white,
          border: Border.all(color: AiChatColors.border),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: highlighted ? Colors.white : AiChatColors.primary,
          size: 31,
        ),
      ),
    );
  }
}

class _LiveOrb extends StatelessWidget {
  const _LiveOrb({required this.isListening, required this.isSpeaking});

  final bool isListening;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    final colors = isSpeaking
        ? const [Color(0xFF0D2A22), Color(0xFF1B4D3E), Color(0xFF35D399)]
        : isListening
        ? const [Color(0xFF102A52), Color(0xFF2C5DB6), Color(0xFF5A88F1)]
        : const [Color(0xFF0D2A22), Color(0xFF1B4D3E), Color(0xFF35D399)];
    final icon = isSpeaking
        ? Icons.volume_up_rounded
        : isListening
        ? Icons.hearing_rounded
        : Icons.graphic_eq_rounded;

    return Container(
      width: 118,
      height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.5),
            blurRadius: 34,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(painter: _OrbPainter()),
          Icon(icon, color: Colors.white, size: 32),
        ],
      ),
    );
  }
}

class _GeminiSparkle extends StatelessWidget {
  const _GeminiSparkle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _SparklePainter());
  }
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF2E8B57),
          Color(0xFF35D399),
          Color(0xFF1B4D3E),
          Color(0xFF26A89A),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomRight,
      ).createShader(rect);

    final path = Path();
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    path
      ..moveTo(c.dx, c.dy - r)
      ..cubicTo(
        c.dx + r * 0.10,
        c.dy - r * 0.28,
        c.dx + r * 0.28,
        c.dy - r * 0.10,
        c.dx + r,
        c.dy,
      )
      ..cubicTo(
        c.dx + r * 0.28,
        c.dy + r * 0.10,
        c.dx + r * 0.10,
        c.dy + r * 0.28,
        c.dx,
        c.dy + r,
      )
      ..cubicTo(
        c.dx - r * 0.10,
        c.dy + r * 0.28,
        c.dx - r * 0.28,
        c.dy + r * 0.10,
        c.dx - r,
        c.dy,
      )
      ..cubicTo(
        c.dx - r * 0.28,
        c.dy - r * 0.10,
        c.dx - r * 0.10,
        c.dy - r * 0.28,
        c.dx,
        c.dy - r,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEAFBF3), Color(0x00EAFBF3)],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final path = Path()
      ..moveTo(0, size.height * 0.58)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.28,
        size.width * 0.45,
        size.height * 0.62,
        size.width * 0.7,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.9,
        size.height * 0.28,
        size.width,
        size.height * 0.5,
        size.width,
        size.height * 0.5,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
