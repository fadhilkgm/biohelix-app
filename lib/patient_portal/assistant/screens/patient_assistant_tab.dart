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
  StreamSubscription<dynamic>? _recordingAmplitudeSubscription;
  String _lastLiveSentText = '';
  String? _lastLiveSpokenReply;
  String _livePartialTranscript = '';
  String _liveSubmittedTranscript = '';
  String? _liveVoiceError;
  int _voiceRestartAttempts = 0;
  String? _configuredTtsLanguage;
  AppLanguage? _configuredLanguage;
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
  set speechReady(bool value) => _speechReady = value;

  bool get isListening => _isListening;
  set isListening(bool value) => _isListening = value;

  bool get isSpeaking => _isSpeaking;
  set isSpeaking(bool value) => _isSpeaking = value;

  bool get isLiveVoiceMode => _isLiveVoiceMode;
  set isLiveVoiceMode(bool value) => _isLiveVoiceMode = value;

  bool get isLiveTurnInFlight => _isLiveTurnInFlight;
  set isLiveTurnInFlight(bool value) => _isLiveTurnInFlight = value;

  String? get lastLiveSpokenReply => _lastLiveSpokenReply;
  set lastLiveSpokenReply(String? value) => _lastLiveSpokenReply = value;

  String? get configuredTtsLanguage => _configuredTtsLanguage;
  set configuredTtsLanguage(String? value) => _configuredTtsLanguage = value;

  bool get isTapRecording => _isTapRecording;
  set isTapRecording(bool value) => _isTapRecording = value;

  double get soundLevel => _soundLevel;
  set soundLevel(double value) => _soundLevel = value;

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
    _voiceManager = VoiceManager();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PatientPortalProvider>().initializeChatThreads();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = context.read<LanguageProvider>().language;
    if (_configuredLanguage == language) return;
    _configuredLanguage = language;
    unawaited(_configureTtsLanguage());
  }

  @override
  void dispose() {
    _isLiveVoiceMode = false;
    _liveAutoSendDebounce?.cancel();
    _recordingAmplitudeSubscription?.cancel();
    unawaited(_voiceManager.dispose());
    _messagesController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeLanguage = context.watch<LanguageProvider>().language;
    final strings = AppStrings.of(activeLanguage);

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
                              soundLevel: _soundLevel,
                              partialTranscript: _livePartialTranscript,
                              submittedTranscript: _liveSubmittedTranscript,
                              errorMessage: _liveVoiceError,
                              latestAssistantText: _latestAssistantText(
                                messages,
                              ),
                              onInterrupt: () =>
                                  _interruptAiSpeechAndListen(portal),
                              onStopLive: () => _toggleLiveVoiceMode(portal),
                              onRetry: () {
                                _updateAssistantState(() {
                                  _liveVoiceError = null;
                                  _voiceRestartAttempts = 0;
                                });
                                _startVoiceListening(portal);
                              },
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
                                    _dateLabel(_strings, date) !=
                                        _dateLabel(
                                          _strings,
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
                                          label: _dateLabel(_strings, date),
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
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 15),
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
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: EdgeInsets.fromLTRB(
          constraints.maxWidth > 700 ? 64 : 20,
          42,
          constraints.maxWidth > 700 ? 64 : 20,
          18,
        ),
        children: [
          const Center(child: _BioHelixMark(size: 46)),
          const SizedBox(height: 20),
          Text(
            '${strings.assistantTitle} — $patientName',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: AiChatColors.textPrimary,
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.assistantInputHint,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle(context),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final prompt in prompts.take(4))
                SizedBox(
                  width: constraints.maxWidth >= 560
                      ? (constraints.maxWidth -
                                (constraints.maxWidth > 700 ? 128 : 40) -
                                12) /
                            2
                      : double.infinity,
                  child: Semantics(
                    button: true,
                    child: InkWell(
                      onTap: () => onPromptTap(prompt),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 76),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: AiChatColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.north_east_rounded,
                              size: 19,
                              color: AiChatColors.accent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                prompt,
                                style: GoogleFonts.manrope(
                                  color: AiChatColors.primary,
                                  fontSize: 14,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 16,
                color: AiChatColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  strings.assistantDisclaimer,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    height: 1.4,
                    color: AiChatColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistantLiveStage extends StatefulWidget {
  const _AssistantLiveStage({
    required this.patientName,
    required this.isListening,
    required this.isSpeaking,
    required this.isBusy,
    required this.soundLevel,
    required this.partialTranscript,
    required this.submittedTranscript,
    required this.errorMessage,
    required this.latestAssistantText,
    required this.onInterrupt,
    required this.onStopLive,
    required this.onRetry,
  });

  final String patientName;
  final bool isListening;
  final bool isSpeaking;
  final bool isBusy;
  final double soundLevel;
  final String partialTranscript;
  final String submittedTranscript;
  final String? errorMessage;
  final String? latestAssistantText;
  final VoidCallback onInterrupt;
  final VoidCallback onStopLive;
  final VoidCallback onRetry;

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
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    final isSpeaking = widget.isSpeaking;
    final isListening = widget.isListening;
    final hasError = (widget.errorMessage ?? '').isNotEmpty;
    final phaseLabel = hasError
        ? strings.assistantVoiceUnavailable
        : isSpeaking
        ? strings.assistantSpeaking
        : widget.isBusy
        ? strings.assistantReady
        : isListening
        ? strings.assistantListening
        : strings.assistantReady;
    final supportLabel = hasError
        ? widget.errorMessage!
        : isSpeaking
        ? strings.assistantInterruptAi
        : widget.isBusy
        ? strings.assistantLiveModeActive
        : isListening
        ? strings.assistantLiveModeActive
        : strings.assistantLiveVoiceUnavailable;
    final displayText = isSpeaking
        ? widget.latestAssistantText ?? ''
        : widget.isBusy
        ? widget.submittedTranscript
        : widget.partialTranscript;

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 124),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _VoiceOrb(
                  isListening: isListening,
                  isSpeaking: isSpeaking,
                  isBusy: widget.isBusy,
                  soundLevel: widget.soundLevel,
                  hasError: hasError,
                ),
                const SizedBox(height: 28),
                Text(
                  phaseLabel,
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AiChatColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  supportLabel,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle(context),
                ),
                const SizedBox(height: 24),
                if (hasError) ...[
                  FilledButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(strings.assistantStartVoiceInput),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (displayText.trim().isNotEmpty)
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 620),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.84),
                        border: Border.all(color: AiChatColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: SingleChildScrollView(
                        controller: _liveTextScrollController,
                        child: Text(
                          displayText,
                          textAlign: TextAlign.left,
                          style: GoogleFonts.manrope(
                            color: AiChatColors.textPrimary,
                            fontSize: 15,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                          ),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundLiveButton(
          icon: Icons.stop_rounded,
          onTap: isSpeaking ? onInterrupt : null,
          highlighted: isSpeaking,
          label: AppStrings.of(
            context.read<LanguageProvider>().language,
          ).assistantInterruptAi,
        ),
        const SizedBox(width: 18),
        _RoundLiveButton(
          icon: Icons.call_end_rounded,
          onTap: onStopLive,
          label: AppStrings.of(
            context.read<LanguageProvider>().language,
          ).assistantStop,
          destructive: true,
        ),
      ],
    );
  }
}

class _RoundLiveButton extends StatelessWidget {
  const _RoundLiveButton({
    required this.icon,
    required this.onTap,
    required this.label,
    this.highlighted = false,
    this.destructive = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  final bool highlighted;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFC43D4B) : AiChatColors.primary;
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: label,
            child: IconButton.filled(
              onPressed: onTap,
              style: IconButton.styleFrom(
                minimumSize: const Size(56, 56),
                backgroundColor: highlighted || destructive
                    ? color
                    : Colors.white,
                foregroundColor: highlighted || destructive
                    ? Colors.white
                    : color,
                side: BorderSide(
                  color: highlighted || destructive
                      ? color
                      : AiChatColors.border,
                ),
              ),
              icon: Icon(icon, size: 27),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AiChatColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceOrb extends StatefulWidget {
  const _VoiceOrb({
    required this.isListening,
    required this.isSpeaking,
    required this.isBusy,
    required this.soundLevel,
    required this.hasError,
  });
  final bool isListening;
  final bool isSpeaking;
  final bool isBusy;
  final double soundLevel;
  final bool hasError;

  @override
  State<_VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<_VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => SizedBox.square(
          dimension: 190,
          child: CustomPaint(
            painter: _VoiceOrbPainter(
              phase: _controller.value,
              level: widget.soundLevel,
              listening: widget.isListening,
              speaking: widget.isSpeaking,
              thinking: widget.isBusy,
              error: widget.hasError,
            ),
            child: Icon(
              widget.isSpeaking
                  ? Icons.volume_up_rounded
                  : widget.isListening
                  ? Icons.mic_rounded
                  : Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
      ),
    );
  }
}

class _BioHelixMark extends StatelessWidget {
  const _BioHelixMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _BioHelixPainter());
  }
}

class _BioHelixPainter extends CustomPainter {
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

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .11
      ..strokeCap = StrokeCap.round;
    final strandA = Path()
      ..moveTo(size.width * .28, size.height * .08)
      ..cubicTo(
        size.width * .82,
        size.height * .28,
        size.width * .18,
        size.height * .72,
        size.width * .72,
        size.height * .92,
      );
    final strandB = Path()
      ..moveTo(size.width * .72, size.height * .08)
      ..cubicTo(
        size.width * .18,
        size.height * .28,
        size.width * .82,
        size.height * .72,
        size.width * .28,
        size.height * .92,
      );
    canvas.drawPath(strandA, paint);
    canvas.drawPath(strandB, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VoiceOrbPainter extends CustomPainter {
  const _VoiceOrbPainter({
    required this.phase,
    required this.level,
    required this.listening,
    required this.speaking,
    required this.thinking,
    required this.error,
  });

  final double phase;
  final double level;
  final bool listening;
  final bool speaking;
  final bool thinking;
  final bool error;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final activity = listening
        ? level.clamp(0.08, 1.0)
        : speaking
        ? 0.52
        : thinking
        ? 0.24
        : 0.1;
    final baseColor = error
        ? const Color(0xFFC43D4B)
        : speaking
        ? const Color(0xFF163F34)
        : thinking
        ? const Color(0xFF2B7864)
        : const Color(0xFF1B4D3E);
    final accent = error ? const Color(0xFFF29AA3) : const Color(0xFF4CC9A2);

    canvas.drawCircle(
      center,
      68 + math.sin(phase * math.pi * 2) * (3 + activity * 7),
      Paint()
        ..color = accent.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    for (var layer = 2; layer >= 0; layer--) {
      final path = Path();
      const points = 72;
      for (var i = 0; i <= points; i++) {
        final angle = i / points * math.pi * 2;
        final wobble = math.sin(
          angle * (3 + layer) + phase * math.pi * 2 * (layer.isEven ? 1 : -1),
        );
        final radius = 55.0 + layer * 8 + wobble * (3 + activity * 10);
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
        i == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accent.withValues(alpha: 0.76 - layer * 0.12),
              baseColor.withValues(alpha: 0.94 - layer * 0.14),
            ],
          ).createShader(Offset.zero & size),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceOrbPainter oldDelegate) =>
      phase != oldDelegate.phase ||
      level != oldDelegate.level ||
      listening != oldDelegate.listening ||
      speaking != oldDelegate.speaking ||
      thinking != oldDelegate.thinking ||
      error != oldDelegate.error;
}
