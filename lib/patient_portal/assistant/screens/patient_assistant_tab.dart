part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class _AssistantTab extends StatefulWidget {
  const _AssistantTab();

  @override
  State<_AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<_AssistantTab> {
  final _inputController = TextEditingController();
  final _messagesController = ScrollController();
  final _speechToText = SpeechToText();
  final _tts = FlutterTts();
  int _lastAutoScrolledMessageCount = 0;
  bool _showMobileSidebar = false;
  bool _speechReady = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isLiveVoiceMode = false;
  bool _isLiveTurnInFlight = false;
  String? _lastLiveSpokenReply;
  final List<ChatAttachment> _pendingAttachments = <ChatAttachment>[];
  bool _isAttachmentUploadInFlight = false;
  String? _uploadingAttachmentName;

  TextEditingController get inputController => _inputController;
  ScrollController get messagesController => _messagesController;
  SpeechToText get speechToText => _speechToText;
  FlutterTts get tts => _tts;
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
  }

  @override
  void initState() {
    super.initState();
    _initializeVoiceFeatures();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PatientPortalProvider>().initializeChatThreads();
    });
  }

  @override
  void dispose() {
    _isLiveVoiceMode = false;
    _speechToText.stop();
    _tts.stop();
    _messagesController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final showDesktopSidebar = constraints.maxWidth >= 940;

            Widget messagePane() {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                    child: ChatHeaderWidget(
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
                      onInterruptAi: () => _interruptAiSpeechAndListen(portal),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: _messagesController,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                      itemCount:
                          messages.length + (portal.isSendingMessage ? 1 : 0),
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
                                  _messageDate(messages[index - 1], index - 1),
                                );
                        final attachments = _attachmentsFromMessage(
                          context,
                          message,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDate)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.s12,
                                ),
                                child: _DateSeparator(label: _dateLabel(date)),
                              ),
                            MessageBubbleWidget(
                              message: message,
                              timeLabel: _messageTimeLabel(message, index),
                              attachments: attachments,
                              onSpeakTap: () => _toggleSpeechPlayback(message),
                              isSpeaking:
                                  _isSpeaking &&
                                  message.role != 'user' &&
                                  index == messages.length - 1,
                              onStopTap: () =>
                                  _interruptAiSpeechAndListen(portal),
                              onAttachmentTap: (attachment) {
                                _openAttachmentPreview(context, attachment);
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
                                    ? 'Uploading attachment...'
                                    : 'Uploading $uploadingLabel...',
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
                    child: ChatInputWidget(
                      controller: _inputController,
                      isBusy: busy,
                      isListening: _isListening,
                      isLiveMode: _isLiveVoiceMode,
                      onAttach: () => _attachFile(portal),
                      onLiveTap: () => _toggleLiveVoiceMode(portal),
                      onVoiceTap: _toggleVoiceInput,
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
                color: AiChatColors.background,
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
}
