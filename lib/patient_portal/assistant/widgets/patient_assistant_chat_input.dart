part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';

class ChatInputWidget extends StatefulWidget {
  const ChatInputWidget({
    required this.controller,
    required this.isBusy,
    required this.isListening,
    required this.isLiveMode,
    required this.onAttach,
    required this.onLiveTap,
    required this.onVoiceTap,
    required this.onSend,
    required this.soundLevel,
    super.key,
  });

  final TextEditingController controller;
  final bool isBusy;
  final bool isListening;
  final bool isLiveMode;
  final VoidCallback onAttach;
  final VoidCallback onLiveTap;
  final VoidCallback onVoiceTap;
  final VoidCallback onSend;
  final double soundLevel;

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isListening) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ChatInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isListening && oldWidget.isListening) {
      _pulseController.stop();
      _pulseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    final isBusy = widget.isBusy;
    final isListening = widget.isListening;
    final isLiveMode = widget.isLiveMode;
    final onAttach = widget.onAttach;
    final onLiveTap = widget.onLiveTap;
    final onVoiceTap = widget.onVoiceTap;
    final onSend = widget.onSend;
    final controller = widget.controller;
    final soundLevel = widget.soundLevel;

    // Map sound level (-2 to 10 typical) to a scale factor (1.0 to 2.2)
    final soundScale = 1.0 + (soundLevel.clamp(-2, 10) + 2) / 12 * 1.2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AiChatColors.inputSurface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            boxShadow: AiChatColors.softShadow,
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 28,
                    child: FilledButton.tonalIcon(
                      onPressed: isBusy && !isLiveMode ? null : onLiveTap,
                      icon: isLiveMode && isListening
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isLiveMode
                                  ? Icons.call_end_rounded
                                  : Icons.graphic_eq_rounded,
                              size: 14,
                            ),
                      label: Text(
                        isLiveMode
                            ? strings.assistantStop
                            : strings.assistantLive,
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: AppTextStyles.subtitle(
                          context,
                        ).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: isBusy ? null : onAttach,
                    icon: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file_rounded),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: isBusy ? null : onVoiceTap,
                tooltip: isListening
                    ? strings.assistantStopVoiceInput
                    : strings.assistantStartVoiceInput,
                iconSize: isListening ? 30 : 24,
                icon: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeInOutCubic,
                      width: isListening ? 48 : 38,
                      height: isListening ? 48 : 38,
                      decoration: BoxDecoration(
                        color: isListening
                            ? const Color(0xFFFFD2DB)
                            : const Color(0xFFE9EEF7),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isListening
                                ? const Color(0x50E11D48)
                                : const Color(0x00000000),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    if (isListening)
                      ScaleTransition(
                        scale: Tween(begin: 1.0, end: soundScale).animate(
                          CurvedAnimation(
                            parent: _pulseController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFBE123C).withValues(alpha: 0.4),
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    if (isListening)
                      FadeTransition(
                        opacity: Tween(begin: 0.2, end: 0.5).animate(
                          CurvedAnimation(
                            parent: _pulseController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 40 + (soundLevel.clamp(0, 10) * 2),
                          height: 40 + (soundLevel.clamp(0, 10) * 2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFBE123C),
                          ),
                        ),
                      ),
                    Icon(
                      isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: isListening
                          ? const Color(0xFFBE123C)
                          : const Color(0xFF475569),
                      size: isListening ? 28 : 22,
                    ),
                    if (isListening)
                      Positioned(
                        top: -8,
                        right: -10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBE123C),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            strings.assistantRecording,
                            style: AppTextStyles.subtitle(context).copyWith(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: strings.assistantInputHint,
                    hintStyle: AppTextStyles.inputHint(context),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  gradient: AiChatColors.userBubbleGradient,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: isBusy ? null : onSend,
                  icon: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.assistantDisclaimer,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
