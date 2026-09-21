part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _AssistantTab extends StatefulWidget {
  const _AssistantTab();

  @override
  State<_AssistantTab> createState() => _AssistantTabState();
}

/// How close to the bottom the patient must already be for a new message to
/// pull the view down.
const double _stickToBottomThreshold = 120;

/// How far up the patient must scroll before the jump-to-latest button appears.
const double _scrollToBottomThreshold = 300;

class _AssistantTabState extends State<_AssistantTab> {
  final _inputController = TextEditingController();
  final _messagesController = ScrollController();
  late final InworldSignalingApi _signalingApi;
  late final LiveVoiceController _liveVoiceController;
  Timer? _voicePrewarmTimer;
  PatientPortalProvider? _portal;
  int _lastMessageCount = 0;
  String? _lastScrolledThreadId;
  double _lastKeyboardInset = 0;
  bool _showScrollToBottom = false;
  bool _forceStickToBottomOnNextMessage = false;
  bool _showMobileSidebar = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isLiveVoiceMode = false;
  bool _isEndingLiveVoice = false;
  bool _isMicMuted = false;
  String _liveUserPartial = '';
  String _liveUserFinal = '';
  String _liveResponseText = '';
  String? _liveVoiceError;
  String? _liveConversationId;
  final List<ChatAttachment> _pendingAttachments = <ChatAttachment>[];
  bool _isAttachmentUploadInFlight = false;
  bool _isAttachmentAnalysisInFlight = false;
  String? _uploadingAttachmentName;
  double _soundLevel = 0.0;

  TextEditingController get inputController => _inputController;
  ScrollController get messagesController => _messagesController;
  LiveVoiceController get liveVoiceController => _liveVoiceController;

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
    _isAttachmentAnalysisInFlight = false;
    _uploadingAttachmentName = null;
  }

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    // One signaling client for the tab: it owns the bootstrap cache, so a new
    // instance per turn would throw away every prewarm.
    _signalingApi = InworldSignalingApi(apiClient);
    _liveVoiceController = LiveVoiceController(
      signalingApi: _signalingApi,
      onTurnCompleted: (transcript, response) async {
        if (!mounted) return;
        final portal = context.read<PatientPortalProvider>();
        if (transcript.trim().isEmpty || response.trim().isEmpty) return;
        final shouldEndLiveVoice = isLiveConversationEndingPhrase(transcript);
        final conversationId = _liveConversationId;
        if ((conversationId ?? '').isNotEmpty) {
          try {
            await _signalingApi.persistTurn(
              conversationId: conversationId!,
              transcript: transcript,
              response: response,
              idempotencyKey:
                  '$conversationId-${DateTime.now().microsecondsSinceEpoch}',
            );
          } catch (error) {
            if (!mounted) return;
            updateAssistantState(() {
              _liveVoiceError = 'The voice turn could not be saved: $error';
            });
          }
        }
        if (shouldEndLiveVoice && mounted && !_isEndingLiveVoice) {
          updateAssistantState(() => _isEndingLiveVoice = true);
          await Future<void>.delayed(const Duration(milliseconds: 1600));
          if (!mounted || !_isLiveVoiceMode) return;
          await _toggleLiveVoiceMode(portal);
        }
      },
      onTurnContext: (transcript) async {
        if (isLiveConversationEndingPhrase(transcript)) {
          return liveVoiceFarewellInstructions(_ttsLanguageCode);
        }
        final conversationId = _liveConversationId;
        if ((conversationId ?? '').isEmpty) {
          throw StateError('A chat conversation is required for live voice.');
        }
        return _signalingApi.responseInstructions(
          conversationId: conversationId!,
          transcript: transcript,
        );
      },
    );
    _liveVoiceController.addListener(_handleLiveVoiceControllerChanged);
    _messagesController.addListener(_handleMessagesScrolled);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PatientPortalProvider>().initializeChatThreads();
      _prewarmLiveVoice();
      // The bootstrap cache is short lived, so keep it warm while the patient
      // reads the thread. This is network-only: the microphone stays off until
      // live voice is explicitly started.
      _voicePrewarmTimer?.cancel();
      _voicePrewarmTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _prewarmLiveVoice(),
      );
    });
  }

  void _prewarmLiveVoice() {
    if (!mounted || _isLiveVoiceMode) return;
    final language = context.read<LanguageProvider>().language;
    unawaited(
      _liveVoiceController.prewarm(
        locale: language == AppLanguage.ml ? 'ml-IN' : 'en-IN',
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final portal = context.read<PatientPortalProvider>();
    if (!identical(portal, _portal)) {
      _portal?.removeListener(_handlePortalChanged);
      _portal = portal;
      portal.addListener(_handlePortalChanged);
      _lastScrolledThreadId = portal.activeChatThreadId;
      _lastMessageCount = portal.chatMessages.length;
      _maybeStickToBottom(force: true, jump: true);
    }

    // Depending on the inset here also means the keyboard opening/closing
    // re-runs this callback.
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if ((inset - _lastKeyboardInset).abs() > 1) {
      final opening = inset > _lastKeyboardInset;
      _lastKeyboardInset = inset;
      _maybeStickToBottom(force: opening, jump: true);
    }
  }

  /// Scrolls to the newest message only when the patient is already reading the
  /// tail (or when [force] — they just sent something, or the thread changed).
  /// Scrolling someone back down while they read history is worse than not
  /// scrolling at all.
  void _maybeStickToBottom({bool force = false, bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesController.hasClients) return;
      final position = _messagesController.position;
      if (!position.hasContentDimensions) return;
      final distance = position.maxScrollExtent - position.pixels;
      if (!force && distance > _stickToBottomThreshold) return;
      if (distance.abs() < 1) return;
      try {
        if (jump) {
          _messagesController.jumpTo(position.maxScrollExtent);
        } else {
          _messagesController.animateTo(
            position.maxScrollExtent,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        }
      } catch (_) {
        // Ignore transient detach/layout races during route and keyboard changes.
      }
    });
  }

  void _handlePortalChanged() {
    if (!mounted) return;
    final portal = _portal;
    if (portal == null) return;

    final threadId = portal.activeChatThreadId;
    final count = portal.chatMessages.length;

    if (threadId != _lastScrolledThreadId) {
      _lastScrolledThreadId = threadId;
      _lastMessageCount = count;
      _maybeStickToBottom(force: true, jump: true);
      return;
    }

    if (count != _lastMessageCount) {
      _lastMessageCount = count;
      final force = _forceStickToBottomOnNextMessage;
      _forceStickToBottomOnNextMessage = false;
      _maybeStickToBottom(force: force, jump: force);
      return;
    }

    if (portal.isStreamingReply) {
      // Deltas land every few tens of ms; an animation per delta would fight
      // itself, so follow the tail with a jump.
      _maybeStickToBottom(jump: true);
    }
  }

  void _handleMessagesScrolled() {
    if (!mounted || !_messagesController.hasClients) return;
    final position = _messagesController.position;
    if (!position.hasContentDimensions) return;
    final show =
        position.maxScrollExtent - position.pixels > _scrollToBottomThreshold;
    if (show == _showScrollToBottom) return;
    setState(() => _showScrollToBottom = show);
  }

  void _scrollToBottom() {
    if (!_messagesController.hasClients) return;
    _messagesController.animateTo(
      _messagesController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _isLiveVoiceMode = false;
    _isEndingLiveVoice = false;
    _portal?.removeListener(_handlePortalChanged);
    _portal = null;
    _messagesController.removeListener(_handleMessagesScrolled);
    _voicePrewarmTimer?.cancel();
    _voicePrewarmTimer = null;
    _liveVoiceController.removeListener(_handleLiveVoiceControllerChanged);
    _liveVoiceController.dispose();
    _liveConversationId = null;
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
        final busy = portal.isSendingMessage || portal.isUploadingDocument;
        final pendingAttachments = List<ChatAttachment>.unmodifiable(
          _pendingAttachments,
        );
        final uploadInProgress =
            _isAttachmentUploadInFlight || portal.isUploadingDocument;
        final uploadingLabel = _uploadingAttachmentName;
        final analysisInProgress =
            _isAttachmentAnalysisInFlight || portal.analyzingDocumentId != null;

        // Auto-scroll is driven by the provider listener and
        // didChangeDependencies; build() stays a pure function of state.
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
                              phase: _liveVoiceController.state.phase,
                              isListening: _isListening,
                              isSpeaking: _isSpeaking,
                              isBusy: portal.isSendingMessage,
                              soundLevel: _liveVoiceController.soundLevel,
                              isMuted: _isMicMuted,
                              partialTranscript: _liveUserPartial,
                              finalTranscript: _liveUserFinal,
                              responseText: _liveResponseText,
                              errorMessage: _liveVoiceError,
                              onInterrupt: () =>
                                  _interruptAiSpeechAndListen(portal),
                              onToggleMute: () =>
                                  unawaited(_liveVoiceController.toggleMute()),
                              onStopLive: () => _toggleLiveVoiceMode(portal),
                              onRetry: () {
                                _updateAssistantState(() {
                                  _liveVoiceError = null;
                                });
                                _toggleLiveVoiceMode(portal);
                              },
                            )
                          : messages.isEmpty && portal.isLoadingChatHistory
                          // A spinner, not the onboarding prompts: an empty
                          // state during a load reads as "you have no chats".
                          ? const Center(
                              key: ValueKey('assistant_history_loading'),
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              ),
                            )
                          : messages.isEmpty && portal.chatHistoryError != null
                          ? _AssistantHistoryError(
                              onRetry: () => portal.retryChatHistory(),
                            )
                          : messages.isEmpty
                          ? _AssistantEmptyState(
                              prompts: strings.assistantStarterPrompts,
                              patientName: patientName,
                              onPromptTap: (prompt) {
                                _inputController.text = prompt;
                                _sendMessage(portal);
                              },
                            )
                          : Stack(
                              children: [
                                ListView.separated(
                                  controller: _messagesController,
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    8,
                                    14,
                                    18,
                                  ),
                                  itemCount: messages.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: AppSpacing.s14),
                                  itemBuilder: (context, index) {
                                    final message = messages[index];
                                    final date = _messageDate(message);
                                    final showDate =
                                        index == 0 ||
                                        _dateLabel(_strings, date) !=
                                            _dateLabel(
                                              _strings,
                                              _messageDate(messages[index - 1]),
                                            );
                                    final attachments = _attachmentsFromMessage(
                                      context,
                                      message,
                                    );
                                    final isLast =
                                        index == messages.length - 1;

                                    return RepaintBoundary(
                                      key: ValueKey<Object>(
                                        message.id ?? 'index-$index',
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (showDate)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: AppSpacing.s12,
                                              ),
                                              child: _DateSeparator(
                                                label: _dateLabel(
                                                  _strings,
                                                  date,
                                                ),
                                              ),
                                            ),
                                          _MessageBubbleWidget(
                                            message: message,
                                            timeLabel: _messageTimeLabel(
                                              message,
                                            ),
                                            attachments: attachments,
                                            isStreaming:
                                                portal.isStreamingReply &&
                                                isLast &&
                                                message.role != 'user',
                                            isSpeaking:
                                                _isSpeaking &&
                                                message.role != 'user' &&
                                                isLast,
                                            onAttachmentTap: (attachment) {
                                              _openAttachmentPreview(
                                                context,
                                                attachment,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                if (_showScrollToBottom)
                                  Positioned(
                                    right: 14,
                                    bottom: 12,
                                    child: FloatingActionButton.small(
                                      key: const ValueKey(
                                        'assistant_scroll_to_bottom',
                                      ),
                                      heroTag: 'assistantScrollToBottom',
                                      onPressed: _scrollToBottom,
                                      backgroundColor: AiChatColors.bubbleAi,
                                      foregroundColor: AiChatColors.primary,
                                      child: const Icon(
                                        Icons.arrow_downward_rounded,
                                      ),
                                    ),
                                  ),
                              ],
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
                    if (analysisInProgress)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: DocumentAnalysisProgressCard(),
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
                              isStreaming: portal.isStreamingReply,
                              soundLevel: _soundLevel,
                              onAttach: () => _attachFile(portal),
                              onLiveTap: () => _toggleLiveVoiceMode(portal),
                              onVoiceTap: () => _toggleLiveVoiceMode(portal),
                              onInterrupt: () =>
                                  _interruptAiSpeechAndListen(portal),
                              onStop: portal.cancelReply,
                              onSend: () => _sendMessage(portal),
                            ),
                    ),
                  ],
                );
              }

              final sidebar = ChatSidebarWidget(
                threads: portal.chatThreads,
                activeThreadId: portal.activeChatThreadId,
                onThreadSelect: (threadId) async {
                  if (_isLiveVoiceMode) {
                    await _toggleLiveVoiceMode(portal);
                    if (!mounted) return;
                  }
                  _updateAssistantState(_clearComposer);
                  await portal.switchChatThread(threadId);
                  if (!mounted) return;
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

  void _handleLiveVoiceControllerChanged() {
    if (!mounted) return;
    final state = _liveVoiceController.state;
    updateAssistantState(() {
      if (state.phase == LiveVoicePhase.closed ||
          state.phase == LiveVoicePhase.error) {
        _isLiveVoiceMode = false;
        _isEndingLiveVoice = false;
        _liveConversationId = null;
      }
      _isListening = state.isListening;
      _isSpeaking = state.isSpeaking;
      _soundLevel = state.soundLevel;
      _isMicMuted = _liveVoiceController.isMuted;
      _liveUserPartial = state.partialTranscript;
      _liveUserFinal = state.finalTranscript;
      _liveResponseText = state.responseText;
      _liveVoiceError = state.errorMessage;
    });
  }
}

/// Shown when the thread history could not be loaded. Deliberately not the
/// empty state: "start a chat" would hide the fact that existing messages are
/// simply unreachable right now.
class _AssistantHistoryError extends StatelessWidget {
  const _AssistantHistoryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('assistant_history_error'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 20,
              color: AiChatColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s8),
            Flexible(
              child: Text(
                'This chat could not be loaded.',
                style: AppTextStyles.subtitle(context),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            TextButton(
              key: const ValueKey('assistant_history_retry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
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
          24,
          constraints.maxWidth > 700 ? 64 : 20,
          18,
        ),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFCFE0FA)),
            ),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFF356FD3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${strings.assistantTitle} — $patientName',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: const ['AnekMalayalam'],
                    color: const Color(0xFF173B63),
                    fontSize: 25,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.assistantInputHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: const ['AnekMalayalam'],
                    color: const Color(0xFF5B7190),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
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
                        constraints: const BoxConstraints(minHeight: 72),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFDCE6F3)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF356FD3,
                              ).withValues(alpha: 0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEAF2FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_outward_rounded,
                                size: 18,
                                color: Color(0xFF356FD3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                prompt,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontFamilyFallback: const ['AnekMalayalam'],
                                  color: const Color(0xFF173B63),
                                  fontSize: 14,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
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
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE6F3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3EDFB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.health_and_safety_outlined,
                    size: 19,
                    color: Color(0xFF356FD3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'For your safety',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontFamilyFallback: const ['AnekMalayalam'],
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF173B63),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        strings.assistantDisclaimer,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontFamilyFallback: const ['AnekMalayalam'],
                          fontSize: 11.5,
                          height: 1.4,
                          color: const Color(0xFF5B7190),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantLiveStage extends StatelessWidget {
  const _AssistantLiveStage({
    required this.patientName,
    required this.phase,
    required this.isListening,
    required this.isSpeaking,
    required this.isBusy,
    required this.soundLevel,
    required this.isMuted,
    required this.partialTranscript,
    required this.finalTranscript,
    required this.responseText,
    required this.errorMessage,
    required this.onInterrupt,
    required this.onToggleMute,
    required this.onStopLive,
    required this.onRetry,
  });

  final String patientName;
  final LiveVoicePhase phase;
  final bool isListening;
  final bool isSpeaking;
  final bool isBusy;

  /// Sampled 5x a second, so it is listened to in place instead of being
  /// rebuilt through the whole assistant tab.
  final ValueNotifier<double> soundLevel;
  final bool isMuted;
  final String partialTranscript;
  final String finalTranscript;
  final String responseText;
  final String? errorMessage;
  final VoidCallback onInterrupt;
  final VoidCallback onToggleMute;
  final VoidCallback onStopLive;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    final isSpeaking = this.isSpeaking;
    final isListening = this.isListening;
    final hasError = (errorMessage ?? '').isNotEmpty;
    final isConnecting =
        phase == LiveVoicePhase.connecting ||
        phase == LiveVoicePhase.reconnecting ||
        phase == LiveVoicePhase.ready;
    final phaseLabel = hasError
        ? strings.assistantVoiceUnavailable
        : isConnecting
        ? 'Connecting securely'
        : isSpeaking
        ? strings.assistantSpeaking
        : isBusy
        ? strings.assistantReady
        : isListening
        ? strings.assistantListening
        : strings.assistantReady;
    final supportLabel = hasError
        ? errorMessage!
        : isConnecting
        ? 'Preparing your private voice connection. Your microphone turns on when ready.'
        : isSpeaking
        ? strings.assistantInterruptAi
        : isBusy
        ? strings.assistantLiveModeActive
        : isListening
        ? strings.assistantLiveModeActive
        : strings.assistantLiveVoiceUnavailable;
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 124),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: soundLevel,
                  builder: (context, level, _) => _VoiceOrb(
                    isListening: isListening,
                    isSpeaking: isSpeaking,
                    isBusy: isBusy,
                    soundLevel: level,
                    hasError: hasError,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  phaseLabel,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: const ['AnekMalayalam'],
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
                if (isConnecting) ...[
                  const SizedBox(height: 18),
                  const SizedBox(
                    width: 156,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                      color: AiChatColors.primary,
                      backgroundColor: AiChatColors.bubbleAiSoft,
                    ),
                  ),
                ],
                if (!hasError) ...[
                  const SizedBox(height: 20),
                  _LiveCaption(
                    partialTranscript: partialTranscript,
                    finalTranscript: finalTranscript,
                    responseText: responseText,
                  ),
                ],
                const SizedBox(height: 24),
                if (hasError) ...[
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(strings.assistantStartVoiceInput),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
            isMuted: isMuted,
            onInterrupt: onInterrupt,
            onToggleMute: onToggleMute,
            onStopLive: onStopLive,
          ),
        ),
      ],
    );
  }
}

/// Live captions under the orb: what the patient is saying, then what the
/// assistant answers as it streams in.
class _LiveCaption extends StatelessWidget {
  const _LiveCaption({
    required this.partialTranscript,
    required this.finalTranscript,
    required this.responseText,
  });

  final String partialTranscript;
  final String finalTranscript;
  final String responseText;

  @override
  Widget build(BuildContext context) {
    final answer = responseText.trim();
    final partial = partialTranscript.trim();
    final spoken = finalTranscript.trim();

    final String text;
    final bool isTentative;
    final bool isAssistant;
    if (answer.isNotEmpty) {
      text = answer;
      isTentative = false;
      isAssistant = true;
    } else if (partial.isNotEmpty) {
      text = partial;
      isTentative = true;
      isAssistant = false;
    } else {
      text = spoken;
      isTentative = false;
      isAssistant = false;
    }

    return SizedBox(
      height: 92,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: text.isEmpty
            ? const SizedBox.shrink(key: ValueKey('live-caption-empty'))
            : Align(
                key: ValueKey(
                  'live-caption-${isAssistant ? 'ai' : 'patient'}-$isTentative',
                ),
                alignment: Alignment.topCenter,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    height: 1.42,
                    fontWeight: isAssistant
                        ? FontWeight.w600
                        : FontWeight.w500,
                    fontStyle: isTentative
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: isTentative
                        ? AiChatColors.textSecondary.withValues(alpha: 0.7)
                        : isAssistant
                        ? AiChatColors.textPrimary
                        : AiChatColors.textSecondary,
                  ),
                ),
              ),
      ),
    );
  }
}

class _LiveControlsDock extends StatelessWidget {
  const _LiveControlsDock({
    required this.isListening,
    required this.isSpeaking,
    required this.isMuted,
    required this.onInterrupt,
    required this.onToggleMute,
    required this.onStopLive,
  });

  final bool isListening;
  final bool isSpeaking;
  final bool isMuted;
  final VoidCallback onInterrupt;
  final VoidCallback onToggleMute;
  final VoidCallback onStopLive;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.read<LanguageProvider>().language);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundLiveButton(
          icon: Icons.stop_rounded,
          onTap: isSpeaking ? onInterrupt : null,
          highlighted: isSpeaking,
          label: strings.assistantInterruptAi,
        ),
        const SizedBox(width: 18),
        _RoundLiveButton(
          icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          onTap: onToggleMute,
          highlighted: isMuted,
          label: isMuted ? 'Unmute' : 'Mute',
          semanticsLabel: isMuted
              ? 'Unmute microphone'
              : 'Mute microphone',
        ),
        const SizedBox(width: 18),
        _RoundLiveButton(
          icon: Icons.call_end_rounded,
          onTap: onStopLive,
          label: strings.assistantStop,
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
    this.semanticsLabel,
    this.highlighted = false,
    this.destructive = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  final String? semanticsLabel;
  final bool highlighted;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFC43D4B) : AiChatColors.primary;
    final accessibleLabel = semanticsLabel ?? label;
    return Semantics(
      button: true,
      label: accessibleLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: accessibleLabel,
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
          SizedBox(
            width: 92,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: const ['AnekMalayalam'],
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

class DocumentAnalysisProgressCard extends StatelessWidget {
  const DocumentAnalysisProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AiChatColors.bubbleAiSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AiChatColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: AppSpacing.s12),
          Text(
            'AI analysing…',
            style: AppTextStyles.subtitle(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
