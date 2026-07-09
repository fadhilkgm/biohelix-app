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
    this.soundLevel = 0.0,
    this.onInterrupt,
    super.key,
  });

  final TextEditingController controller;
  final bool isBusy;
  final bool isListening;
  final bool isLiveMode;
  final bool isSpeaking;
  final double soundLevel;
  final VoidCallback onAttach;
  final VoidCallback onLiveTap;
  final VoidCallback onVoiceTap;
  final VoidCallback onSend;
  final VoidCallback? onInterrupt;

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _liveGlowCtrl;
  final FocusNode _inputFocus = FocusNode();
  bool _isFolded = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _liveGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    if (widget.isListening && !widget.isLiveMode) {
      _pulseCtrl.repeat();
    }
    if (widget.isLiveMode) {
      _liveGlowCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ChatInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recording pulse (disabled in live mode to keep the mic button quiet/idle)
    final bool shouldPulse = widget.isListening && !widget.isLiveMode;
    if (shouldPulse && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat();
    } else if (!shouldPulse && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }

    // Live mode breathing glow
    if (widget.isLiveMode && !_liveGlowCtrl.isAnimating) {
      _liveGlowCtrl.repeat(reverse: true);
    } else if (!widget.isLiveMode && _liveGlowCtrl.isAnimating) {
      _liveGlowCtrl.stop();
      _liveGlowCtrl.reset();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _liveGlowCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _toggleFold() {
    setState(() => _isFolded = !_isFolded);
    if (_isFolded) {
      _inputFocus.unfocus();
    } else {
      // Re-open the keyboard when the composer is expanded again.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _inputFocus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: child,
            ),
          ),
          child: (_isFolded && !widget.isListening)
              ? _buildFoldedBar(strings)
              : _buildComposer(strings),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Folded Bar — collapsed pill that reopens the composer on tap
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFoldedBar(LocalizedStrings strings) {
    return GestureDetector(
      key: const ValueKey('folded'),
      onTap: _toggleFold,
      onVerticalDragEnd: (details) {
        // Swipe up to expand the composer again.
        if ((details.primaryVelocity ?? 0) < -60) _toggleFold();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AiChatColors.inputSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AiChatColors.border),
        ),
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAttachButton(),
            const SizedBox(width: 5),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                child: Text(
                  strings.assistantInputHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.inputHint(context),
                ),
              ),
            ),
            _buildMicButton(strings),
            const SizedBox(width: 5),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Composer — full input row
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildComposer(LocalizedStrings strings) {
    return GestureDetector(
      key: const ValueKey('composer'),
      onVerticalDragEnd: widget.isListening
          ? null
          : (details) {
              // Swipe down to fold/minimize the composer.
              if ((details.primaryVelocity ?? 0) > 60) _toggleFold();
            },
      child: Container(
        decoration: BoxDecoration(
          color: AiChatColors.inputSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AiChatColors.border),
        ),
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAttachButton(),
          const SizedBox(width: 5),
          Expanded(
            child: widget.isListening
                ? _AudioWaveform(soundLevel: widget.soundLevel)
                : TextField(
                        focusNode: _inputFocus,
                        controller: widget.controller,
                        minLines: 1,
                        maxLines: 4,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AiChatColors.textPrimary,
                        ),
                        cursorColor: AiChatColors.primary,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => widget.onSend(),
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
            _buildMicButton(strings),
            const SizedBox(width: 5),
            _buildSendButton(),
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
      width: 38,
      height: 38,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          width: 36,
          height: 36,
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
  //  Mic Button — 52×52 with expanding sound-wave ring animation
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMicButton(LocalizedStrings strings) {
    return GestureDetector(
      onTap: widget.isBusy
          ? null
          : (widget.isSpeaking && widget.onInterrupt != null)
          ? widget.onInterrupt
          : widget.onVoiceTap,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          // Bypassed during Live Mode to keep standard mic button quiet/idle,
          // only standard Tap-to-Record mode utilizes active red gradient & expanding rings.
          final bool isRecording = widget.isListening && !widget.isLiveMode;
          final bool isSpeaking = widget.isSpeaking && !widget.isLiveMode;

          return SizedBox(
            width: 36,
            height: 38,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // ── 3 concentric red sound-wave rings ──
                if (isRecording)
                  for (int i = 0; i < 3; i++) _buildWaveRing(i),

                // ── Background circle ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isRecording
                        ? const LinearGradient(
                            colors: [Color(0xFFE11D48), Color(0xFFFF6B8A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : isSpeaking
                        ? const LinearGradient(
                            colors: [AiChatColors.primary, AiChatColors.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: (isRecording || isSpeaking)
                        ? null
                        : Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: isRecording
                            ? const Color(0x40E11D48)
                            : isSpeaking
                            ? const Color(0x301B4D3E)
                            : const Color(0x00000000),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),

                // ── Mic icon ──
                Icon(
                  isRecording || isSpeaking
                      ? Icons.mic_rounded
                      : Icons.mic_none_rounded,
                  color: isRecording || isSpeaking
                      ? Colors.white
                      : AiChatColors.primary,
                  size: 25,
                ),

                // ── REC badge ──
                if (isRecording)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE11D48), Color(0xFFFF4068)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40E11D48),
                            blurRadius: 4,
                            offset: Offset(0, 1.5),
                          ),
                        ],
                      ),
                      child: Text(
                        strings.assistantRecording,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaveRing(int index) {
    final double offset = index * 0.33;
    final double t = (_pulseCtrl.value + offset) % 1.0;
    final double scale = 1.0 + (t * 0.65);
    final double opacity = (1.0 - t) * 0.55;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Color.fromRGBO(225, 29, 72, opacity),
            width: 2.0,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Send Button — gradient circle with soft shadow
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSendButton() {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final hasText = widget.controller.text.trim().isNotEmpty;
        return Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            gradient: AiChatColors.userBubbleGradient,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: widget.isBusy
                ? null
                : hasText
                ? widget.onSend
                : widget.onLiveTap,
            icon: widget.isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    hasText
                        ? Icons.arrow_upward_rounded
                        : Icons.graphic_eq_rounded,
                    color: Colors.white,
                    size: 24,
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
