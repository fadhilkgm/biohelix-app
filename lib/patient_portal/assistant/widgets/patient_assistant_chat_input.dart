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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    // strings is LocalizedStrings
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Main input bar ──
        Container(
          decoration: BoxDecoration(
            color: AiChatColors.inputSurface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            boxShadow: AiChatColors.softShadow,
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top action row: Centered Live button + Left-aligned Attach ──
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildAttachButton(),
                  ),
                  _buildLiveButton(strings),
                ],
              ),
              const SizedBox(height: 6),
              // ── Bottom row: Mic + TextField + Send ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildMicButton(strings),
                  const SizedBox(width: 6),
                  Expanded(
                    child: widget.isListening
                        ? _AudioWaveform(soundLevel: widget.soundLevel)
                        : TextField(
                            controller: widget.controller,
                            minLines: 1,
                            maxLines: 5,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AiChatColors.textPrimary,
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => widget.onSend(),
                            decoration: InputDecoration(
                              hintText: strings.assistantInputHint,
                              hintStyle: AppTextStyles.inputHint(context),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 4,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  _buildSendButton(),
                ],
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  Live Button — prominent gradient pill with breathing glow
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLiveButton(LocalizedStrings strings) {
    final isLive = widget.isLiveMode;

    return AnimatedBuilder(
      animation: _liveGlowCtrl,
      builder: (context, child) {
        final glowOpacity = isLive ? 0.2 + (_liveGlowCtrl.value * 0.25) : 0.0;

        return GestureDetector(
          onTap: widget.isBusy && !isLive ? null : widget.onLiveTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: isLive
                  ? const LinearGradient(
                      colors: [Color(0xFFE11D48), Color(0xFFFF6B8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF2B79FF), Color(0xFF16B5A4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: isLive
                      ? Color.fromRGBO(225, 29, 72, glowOpacity)
                      : const Color(0x202B79FF),
                  blurRadius: isLive ? 16 : 10,
                  spreadRadius: isLive ? 2 : 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLive && widget.isListening)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    isLive ? Icons.call_end_rounded : Icons.graphic_eq_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                const SizedBox(width: 6),
                Text(
                  isLive ? strings.assistantStop : strings.assistantLive,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Attach Button — frosted circle
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAttachButton() {
    return SizedBox(
      width: 56,
      height: 56,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF1F4F8),
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
                    Icons.attach_file_rounded,
                    size: 22,
                    color: Color(0xFF475569),
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
            width: 56,
            height: 56,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // ── 3 concentric red sound-wave rings ──
                if (isRecording)
                  for (int i = 0; i < 3; i++)
                    _buildWaveRing(i),

                // ── Background circle ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  width: 42,
                  height: 42,
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
                                colors: [Color(0xFF2B79FF), Color(0xFF5A9BFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                    color: (isRecording || isSpeaking)
                        ? null
                        : const Color(0xFFF1F4F8),
                    boxShadow: [
                      BoxShadow(
                        color: isRecording
                            ? const Color(0x40E11D48)
                            : isSpeaking
                                ? const Color(0x302B79FF)
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
                      : const Color(0xFF475569),
                  size: 22,
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
        width: 42,
        height: 42,
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
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        gradient: AiChatColors.userBubbleGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x302B79FF),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: widget.isBusy ? null : widget.onSend,
        icon: widget.isBusy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
      ),
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
      height: 48,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
              final double height = 6.0 + (sineVal * 28.0 * envelope * (0.15 + 0.85 * widget.soundLevel));

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
