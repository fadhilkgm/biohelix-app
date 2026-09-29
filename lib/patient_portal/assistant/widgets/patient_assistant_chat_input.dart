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
    this.isSpeaking = false,
    this.isStreaming = false,
    this.soundLevel = 0.0,
    this.onInterrupt,
    this.onStop,
    super.key,
  });

  final TextEditingController controller;
  final bool isBusy;
  final bool isListening;
  final bool isLiveMode;
  final bool isSpeaking;

  /// True while an assistant reply is streaming: the send button becomes Stop.
  final bool isStreaming;
  final double soundLevel;
  final VoidCallback onAttach;
  final VoidCallback onLiveTap;

  /// Starts the hands-free voice chat. The primary button turns into this
  /// whenever the composer is empty, the way ChatGPT and Gemini do it.
  final VoidCallback onVoiceTap;
  final VoidCallback onSend;
  final VoidCallback? onInterrupt;

  /// Invoked by the Stop button while [isStreaming].
  final VoidCallback? onStop;

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final FocusNode _inputFocus = FocusNode();
  double _downwardDragDistance = 0;

  @override
  void dispose() {
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    return _buildComposer(strings);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Composer — full input row
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildComposer(LocalizedStrings strings) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) => _downwardDragDistance = 0,
      onVerticalDragUpdate: (details) {
        _downwardDragDistance = math.max(
          0,
          _downwardDragDistance + details.delta.dy,
        );
        if (_downwardDragDistance >= 24 && _inputFocus.hasFocus) {
          _inputFocus.unfocus();
        }
      },
      onVerticalDragEnd: (_) => _downwardDragDistance = 0,
      onVerticalDragCancel: () => _downwardDragDistance = 0,
      child: Container(
        key: const ValueKey('composer'),
        decoration: BoxDecoration(
          color: AiChatColors.inputSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AiChatColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F163F34),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAttachButton(),
            const SizedBox(width: 5),
            Expanded(
              child: widget.isListening
                  ? _AudioWaveform(soundLevel: widget.soundLevel)
                  : TextField(
                      key: const ValueKey('assistant_message_input'),
                      focusNode: _inputFocus,
                      controller: widget.controller,
                      minLines: 1,
                      maxLines: 4,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontFamilyFallback: const ['AnekMalayalam'],
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AiChatColors.textPrimary,
                      ),
                      cursorColor: AiChatColors.primary,
                      textInputAction: TextInputAction.send,
                      // Enter must respect the same busy gate as the button,
                      // otherwise it queues a second send mid-reply.
                      onSubmitted: (_) {
                        if (widget.isBusy || widget.isStreaming) return;
                        widget.onSend();
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        hintText: strings.assistantInputHint,
                        hintStyle: AppTextStyles.inputHint(context),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 2,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 5),
            _buildPrimaryButton(strings),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Attach Button — frosted circle
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAttachButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          child: widget.isBusy
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF667085),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: widget.onAttach,
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 27,
                    color: AiChatColors.primary,
                  ),
                ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Primary Button — Send with text, Voice chat when empty, Stop while a
  //  reply streams. One button, like ChatGPT and Gemini.
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPrimaryButton(LocalizedStrings strings) {
    // While a reply streams the affordance is Stop, not a dead spinner: the
    // patient can always interrupt generation.
    if (widget.isStreaming) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          gradient: AiChatColors.userBubbleGradient,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          key: const ValueKey('assistant_stop_button'),
          tooltip: 'Stop',
          onPressed: widget.onStop,
          icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
        ),
      );
    }

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final hasText = widget.controller.text.trim().isNotEmpty;
        return Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            gradient: AiChatColors.userBubbleGradient,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            key: ValueKey(
              hasText ? 'assistant_send_button' : 'assistant_voice_button',
            ),
            tooltip: hasText ? null : strings.voiceChat,
            onPressed: widget.isBusy
                ? null
                : hasText
                ? widget.onSend
                : widget.onVoiceTap,
            icon: widget.isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      hasText
                          ? Icons.arrow_upward_rounded
                          : Icons.graphic_eq_rounded,
                      key: ValueKey(hasText ? 'send' : 'voice'),
                      color: Colors.white,
                      size: 24,
                      semanticLabel: hasText ? 'Send' : strings.voiceChat,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Animated Audio Waveform
// ═══════════════════════════════════════════════════════════════════════════
class _AudioWaveform extends StatefulWidget {
  const _AudioWaveform({required this.soundLevel});

  final double soundLevel;

  @override
  State<_AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<_AudioWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(22, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double t = _controller.value;
              // Stagger phase based on index to create a traveling wave effect
              final double phase = index * 0.35;
              final double angle = (t * 2 * math.pi) - phase;

              // Parabolic bell curve envelope (symmetric peaking in the middle)
              final double centerOffset = (index - 11).abs() / 11.0;
              final double envelope = 1.0 - (centerOffset * centerOffset);

              // Sine wave oscillation
              final double sineVal = math.sin(angle).abs();

              // Dynamic height calculations modulated by real-time voice decibel levels
              final double height =
                  6.0 +
                  (sineVal *
                      28.0 *
                      envelope *
                      (0.15 + 0.85 * widget.soundLevel));

              return Container(
                width: 3.5,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
