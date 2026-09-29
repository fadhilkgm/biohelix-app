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
  bool _isLiveVoiceMode = false;

  /// True once the patient chose to end the call, so the "voice chat ended"
  /// notice is only shown when a call ends on its own.
  bool _isEndingLiveVoice = false;
  String? _liveConversationId;

  /// Resolves to the chat thread the live call belongs to. The call starts
  /// before the thread exists (a first-time patient has none yet), so turn
  /// context and persistence wait on this instead of blocking the connect.
  Future<String?>? _liveConversationReady;
  final List<ChatAttachment> _pendingAttachments = <ChatAttachment>[];
  bool _isAttachmentUploadInFlight = false;
  bool _isAttachmentAnalysisInFlight = false;
  String? _uploadingAttachmentName;

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
        if (transcript.trim().isEmpty || response.trim().isEmpty) return;
        if (isLiveConversationEndingPhrase(transcript) && _isLiveVoiceMode) {
          // Hang up only once the goodbye has been heard in full.
          unawaited(_liveVoiceController.stopAfterSpeaking());
        }
        final conversationId = await _awaitLiveConversationId();
        if (conversationId.isEmpty) return;
        await _persistLiveTurn(conversationId, transcript, response);
      },
      onTurnContext: (transcript) async {
        if (isLiveConversationEndingPhrase(transcript)) {
          return liveVoiceFarewellInstructions(_ttsLanguageCode);
        }
        final conversationId = await _awaitLiveConversationId();
        if (conversationId.isEmpty) {
          throw StateError('A chat conversation is required for live voice.');
        }
        return _signalingApi.responseInstructions(
          conversationId: conversationId,
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
    _liveConversationReady = null;
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
    return PopScope<void>(
      canPop: !_isLiveVoiceMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isLiveVoiceMode) {
          unawaited(_endLiveVoice(context.read<PatientPortalProvider>()));
        }
      },
      child: Stack(
        children: [
          // The chat stays mounted under the call so its scroll position,
          // draft and attachments are exactly as the patient left them.
          Positioned.fill(
            child: ExcludeSemantics(
              excluding: _isLiveVoiceMode,
              child: IgnorePointer(
                ignoring: _isLiveVoiceMode,
                child: TickerMode(
                  enabled: !_isLiveVoiceMode,
                  child: _buildChat(context),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              reverseDuration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.04, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: _isLiveVoiceMode
                  ? LiveVoiceView(
                      key: const ValueKey('assistant_live_voice'),
                      controller: _liveVoiceController,
                      onEnd: () => unawaited(
                        _endLiveVoice(context.read<PatientPortalProvider>()),
                      ),
                      onRetry: () => unawaited(
                        _retryLiveVoice(context.read<PatientPortalProvider>()),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('assistant_no_voice')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat(BuildContext context) {
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
        return LayoutBuilder(
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
                      onBack: () => Navigator.of(context).maybePop(),
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
                    ),
                  ),
                  Expanded(
                    child: messages.isEmpty && portal.isLoadingChatHistory
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
                            onVoiceTap: () =>
                                unawaited(_startLiveVoice(portal)),
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
                                  final isLast = index == messages.length - 1;

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
                                              label: _dateLabel(_strings, date),
                                            ),
                                          ),
                                        _MessageBubbleWidget(
                                          message: message,
                                          timeLabel: _messageTimeLabel(message),
                                          attachments: attachments,
                                          isStreaming:
                                              portal.isStreamingReply &&
                                              isLast &&
                                              message.role != 'user',
                                          isSpeaking: false,
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
                            for (var i = 0; i < pendingAttachments.length; i++)
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Text(
                                uploadingLabel == null ||
                                        uploadingLabel.trim().isEmpty
                                    ? strings.assistantUploadingAttachment
                                    : strings.assistantUploadingNamedAttachment(
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
                    child: ChatInputWidget(
                      controller: _inputController,
                      isBusy: busy,
                      isListening: false,
                      isLiveMode: _isLiveVoiceMode,
                      isStreaming: portal.isStreamingReply,
                      onAttach: () => _attachFile(portal),
                      onLiveTap: () => unawaited(_startLiveVoice(portal)),
                      onVoiceTap: () => unawaited(_startLiveVoice(portal)),
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
                              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
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
        );
      },
    );
  }

  /// The voice view listens to the controller itself; the tab only reacts to
  /// a call that ended on its own (goodbye, app backgrounded) so it can return
  /// to the chat. Errors stay on the voice screen, which offers a retry.
  void _handleLiveVoiceControllerChanged() {
    if (!mounted) return;
    if (_liveVoiceController.state.phase != LiveVoicePhase.closed) return;
    if (!_isLiveVoiceMode) return;
    final endedByPatient = _isEndingLiveVoice;
    updateAssistantState(() {
      _isLiveVoiceMode = false;
      _isEndingLiveVoice = false;
      _liveConversationId = null;
      _liveConversationReady = null;
    });
    unawaited(_portal?.refreshMyClub());
    if (!endedByPatient) {
      AppToast.show(
        context,
        message: _liveVoiceController.lastStopReason == 'idle'
            ? _strings.voiceEndedIdle
            : _strings.voiceEnded,
      );
    }
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
    this.onVoiceTap,
  });

  final List<String> prompts;
  final String patientName;
  final ValueChanged<String> onPromptTap;

  /// Starts a hands-free voice chat, offered up front like Gemini Live.
  final VoidCallback? onVoiceTap;

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
                if (onVoiceTap != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('assistant_empty_voice_button'),
                    onPressed: onVoiceTap,
                    icon: const Icon(Icons.graphic_eq_rounded, size: 20),
                    label: Text(strings.voiceChat),
                    style: FilledButton.styleFrom(
                      backgroundColor: AiChatColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(160, 48),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontFamily: 'Manrope',
                        fontFamilyFallback: ['AnekMalayalam'],
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
