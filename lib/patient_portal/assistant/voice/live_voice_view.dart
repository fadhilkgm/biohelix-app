import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import 'live_voice_controller.dart';
import 'live_voice_state.dart';

/// Full-screen, hands-free voice conversation in the spirit of ChatGPT voice
/// mode and Gemini Live: one living orb, live captions, and big thumb-reach
/// controls. The patient just talks; the assistant listens, answers, and can
/// be interrupted by speaking or by tapping the orb.
class LiveVoiceView extends StatefulWidget {
  const LiveVoiceView({
    super.key,
    required this.controller,
    required this.onEnd,
    required this.onRetry,
  });

  final LiveVoiceController controller;

  /// Ends the call and returns to the chat.
  final VoidCallback onEnd;

  /// Starts a new call after an error.
  final VoidCallback onRetry;

  @override
  State<LiveVoiceView> createState() => _LiveVoiceViewState();
}

class _LiveVoiceViewState extends State<LiveVoiceView> {
  bool _showCaptions = true;
  LiveVoicePhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    _lastPhase = widget.controller.state.phase;
    widget.controller.addListener(_onVoiceChanged);
  }

  @override
  void didUpdateWidget(covariant LiveVoiceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onVoiceChanged);
      widget.controller.addListener(_onVoiceChanged);
      _lastPhase = widget.controller.state.phase;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVoiceChanged);
    super.dispose();
  }

  /// Haptics mark the moments a patient would otherwise have to look for:
  /// the line is open, or it failed.
  void _onVoiceChanged() {
    final phase = widget.controller.state.phase;
    final previous = _lastPhase;
    _lastPhase = phase;
    if (previous == phase) return;
    final wasConnecting =
        previous == LiveVoicePhase.connecting ||
        previous == LiveVoicePhase.reconnecting ||
        previous == LiveVoicePhase.ready;
    if (wasConnecting && phase == LiveVoicePhase.listening) {
      unawaited(HapticFeedback.lightImpact());
    } else if (phase == LiveVoicePhase.error) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _toggleMute() {
    unawaited(HapticFeedback.selectionClick());
    unawaited(widget.controller.toggleMute());
  }

  void _interrupt() {
    unawaited(HapticFeedback.mediumImpact());
    unawaited(widget.controller.interrupt());
  }

  void _end() {
    unawaited(HapticFeedback.mediumImpact());
    widget.onEnd();
  }

  void _onOrbTap(LiveVoiceState state) {
    if (state.isSpeaking) {
      _interrupt();
    } else if (state.isMuted && state.isListening) {
      _toggleMute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context.watch<LanguageProvider>().language);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _VoicePalette.backgroundBottom,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Material(
        color: _VoicePalette.backgroundBottom,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _VoicePalette.backgroundTop,
                _VoicePalette.backgroundMiddle,
                _VoicePalette.backgroundBottom,
              ],
              stops: [0, 0.55, 1],
            ),
          ),
          child: SafeArea(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final state = widget.controller.state;
                final showCaptions =
                    _showCaptions && state.phase != LiveVoicePhase.error;
                return Column(
                  children: [
                    _TopBar(
                      state: state,
                      strings: strings,
                      showCaptions: _showCaptions,
                      onToggleCaptions: () =>
                          setState(() => _showCaptions = !_showCaptions),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, stage) {
                          // Captions take a bounded share; the orb scales to
                          // what is left, so small phones, landscape and
                          // large text all fit without overflowing.
                          final captionsHeight = showCaptions
                              ? (stage.maxHeight * 0.34).clamp(0.0, 240.0)
                              : 0.0;
                          final upperHeight = stage.maxHeight - captionsHeight;
                          final orbSize = math.max(
                            96.0,
                            math.min(
                              math.min(stage.maxWidth * 0.62, 280.0),
                              upperHeight * 0.55,
                            ),
                          );
                          return Column(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, area) =>
                                      SingleChildScrollView(
                                        physics: const ClampingScrollPhysics(),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight: area.maxHeight,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              _OrbButton(
                                                state: state,
                                                size: orbSize,
                                                level: widget
                                                    .controller
                                                    .soundLevel,
                                                semanticsLabel: _statusTitle(
                                                  state,
                                                  strings,
                                                ),
                                                semanticsHint: _statusHint(
                                                  state,
                                                  strings,
                                                ),
                                                onTap: () => _onOrbTap(state),
                                              ),
                                              const SizedBox(height: 24),
                                              _StatusText(
                                                title: _statusTitle(
                                                  state,
                                                  strings,
                                                ),
                                                hint: _statusHint(
                                                  state,
                                                  strings,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                              if (showCaptions)
                                SizedBox(
                                  height: captionsHeight,
                                  child: _Captions(
                                    entries: state.transcript,
                                    emptyPrompt:
                                        state.isActive && !state.isConnecting
                                        ? strings.voiceEmptyPrompt
                                        : '',
                                    youLabel: strings.voiceYou,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    state.phase == LiveVoicePhase.error
                        ? _ErrorControls(
                            strings: strings,
                            onRetry: widget.onRetry,
                            onEnd: _end,
                          )
                        : _CallControls(
                            strings: strings,
                            state: state,
                            onToggleMute: state.isActive ? _toggleMute : null,
                            onInterrupt: _interrupt,
                            onEnd: _end,
                          ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _statusTitle(LiveVoiceState state, LocalizedStrings strings) {
    return switch (state.phase) {
      LiveVoicePhase.error => strings.voiceUnavailableTitle,
      LiveVoicePhase.reconnecting => strings.voiceReconnecting,
      LiveVoicePhase.idle ||
      LiveVoicePhase.connecting ||
      LiveVoicePhase.ready => strings.voiceConnecting,
      LiveVoicePhase.closing || LiveVoicePhase.closed => strings.voiceEnding,
      LiveVoicePhase.speaking => strings.voiceSpeaking,
      LiveVoicePhase.thinking ||
      LiveVoicePhase.transcribing => strings.voiceThinking,
      LiveVoicePhase.listening || LiveVoicePhase.degraded =>
        state.isMuted ? strings.voiceMicOff : strings.voiceListening,
    };
  }

  String _statusHint(LiveVoiceState state, LocalizedStrings strings) {
    return switch (state.phase) {
      LiveVoicePhase.error =>
        (state.errorMessage ?? '').trim().isEmpty
            ? strings.assistantLiveVoiceUnavailable
            : state.errorMessage!.trim(),
      LiveVoicePhase.reconnecting => strings.voiceReconnectingHint,
      LiveVoicePhase.idle ||
      LiveVoicePhase.connecting ||
      LiveVoicePhase.ready => strings.voiceConnectingHint,
      LiveVoicePhase.speaking => strings.voiceSpeakingHint,
      LiveVoicePhase.listening || LiveVoicePhase.degraded =>
        state.isMuted
            ? strings.voiceMicOffHint
            : state.isUserSpeaking
            ? ''
            : strings.voiceListeningHint,
      _ => '',
    };
  }
}

// -----------------------------------------------------------------------------
// Palette
// -----------------------------------------------------------------------------

abstract final class _VoicePalette {
  static const backgroundTop = Color(0xFF0A1C1D);
  static const backgroundMiddle = Color(0xFF0B2426);
  static const backgroundBottom = Color(0xFF071517);
  static const textPrimary = Color(0xFFF2FBF8);
  static const textSecondary = Color(0xB3DCEFEA);
  static const textTertiary = Color(0x80C9E2DC);
  static const controlFill = Color(0x1FFFFFFF);
  static const controlBorder = Color(0x33FFFFFF);
  static const endCall = Color(0xFFE5484D);
  static const live = Color(0xFF3DDC97);
}

// -----------------------------------------------------------------------------
// Top bar: live indicator, call timer, captions toggle
// -----------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.strings,
    required this.showCaptions,
    required this.onToggleCaptions,
  });

  final LiveVoiceState state;
  final LocalizedStrings strings;
  final bool showCaptions;
  final VoidCallback onToggleCaptions;

  @override
  Widget build(BuildContext context) {
    final live = state.isActive && !state.isConnecting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          if (state.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _VoicePalette.controlFill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _VoicePalette.controlBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: live
                          ? _VoicePalette.live
                          : _VoicePalette.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(strings.assistantLive, style: _VoiceText.chip),
                  if (state.connectedAt != null) ...[
                    Text(' · ', style: _VoiceText.chip),
                    _CallTimer(startedAt: state.connectedAt!),
                  ],
                ],
              ),
            ),
          const Spacer(),
          IconButton(
            key: const ValueKey('live_voice_captions_toggle'),
            tooltip: showCaptions
                ? strings.voiceCaptionsOff
                : strings.voiceCaptionsOn,
            onPressed: onToggleCaptions,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: _VoicePalette.textPrimary,
            ),
            icon: Icon(
              showCaptions
                  ? Icons.closed_caption_rounded
                  : Icons.closed_caption_off_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _CallTimer extends StatefulWidget {
  const _CallTimer({required this.startedAt});

  final DateTime startedAt;

  @override
  State<_CallTimer> createState() => _CallTimerState();
}

class _CallTimerState extends State<_CallTimer> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final seconds = elapsed.inSeconds.clamp(0, 359999);
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    String two(int value) => value.toString().padLeft(2, '0');
    final label = hours > 0
        ? '$hours:${two(minutes)}:${two(remainder)}'
        : '${two(minutes)}:${two(remainder)}';
    return Text(
      label,
      style: _VoiceText.chip.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Status
// -----------------------------------------------------------------------------

class _StatusText extends StatelessWidget {
  const _StatusText({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                title,
                key: ValueKey('voice-title-$title'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _VoiceText.title,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: SizedBox(
                key: ValueKey('voice-hint-$hint'),
                width: double.infinity,
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _VoiceText.hint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Captions
// -----------------------------------------------------------------------------

class _Captions extends StatelessWidget {
  const _Captions({
    required this.entries,
    required this.emptyPrompt,
    required this.youLabel,
  });

  final List<LiveVoiceTranscriptEntry> entries;
  final String emptyPrompt;
  final String youLabel;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedOpacity(
            opacity: emptyPrompt.isEmpty ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: Text(
              emptyPrompt,
              textAlign: TextAlign.center,
              style: _VoiceText.hint.copyWith(
                color: _VoicePalette.textTertiary,
              ),
            ),
          ),
        ),
      );
    }
    final visible = entries.length > 8
        ? entries.sublist(entries.length - 8)
        : entries;
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white],
        stops: [0, 0.22],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        key: const ValueKey('live_voice_captions'),
        reverse: true,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final entry = visible[visible.length - 1 - index];
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _CaptionLine(entry: entry, youLabel: youLabel),
          );
        },
      ),
    );
  }
}

class _CaptionLine extends StatelessWidget {
  const _CaptionLine({required this.entry, required this.youLabel});

  final LiveVoiceTranscriptEntry entry;
  final String youLabel;

  @override
  Widget build(BuildContext context) {
    final text = entry.interrupted ? '${entry.text} …' : entry.text;
    if (entry.isPatient && !entry.isFinal && entry.text.isEmpty) {
      // Still speaking or being transcribed: only the final words are shown.
      return Semantics(
        label: '$youLabel: …',
        excludeSemantics: true,
        child: const Align(
          alignment: Alignment.centerRight,
          child: _TypingDots(key: ValueKey('live_voice_patient_typing')),
        ),
      );
    }
    if (entry.isPatient) {
      return Semantics(
        label: '$youLabel: ${entry.text}',
        excludeSemantics: true,
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: _VoiceText.patientCaption.copyWith(
                fontStyle: entry.isFinal ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Text(
          text,
          style: _VoiceText.assistantCaption.copyWith(
            color: entry.interrupted
                ? _VoicePalette.textSecondary
                : _VoicePalette.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Three softly pulsing dots in place of the patient's caption while their
/// words are still being recognised.
class _TypingDots extends StatefulWidget {
  const _TypingDots({super.key});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              child: Opacity(
                // Each dot peaks a third of a cycle after the previous one.
                opacity:
                    0.3 +
                    0.7 *
                        (0.5 +
                            0.5 *
                                math.sin(2 * math.pi * (_pulse.value - i / 3))),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _VoicePalette.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Controls
// -----------------------------------------------------------------------------

class _CallControls extends StatelessWidget {
  const _CallControls({
    required this.strings,
    required this.state,
    required this.onToggleMute,
    required this.onInterrupt,
    required this.onEnd,
  });

  final LocalizedStrings strings;
  final LiveVoiceState state;
  final VoidCallback? onToggleMute;
  final VoidCallback onInterrupt;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final muted = state.isMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = _VoiceControlButton.slotWidth(constraints.maxWidth);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _VoiceControlButton(
                key: const ValueKey('live_voice_mute'),
                width: slot,
                icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: muted ? strings.voiceUnmute : strings.voiceMute,
                highlighted: muted,
                onTap: onToggleMute,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: state.isSpeaking
                    ? _VoiceControlButton(
                        key: const ValueKey('live_voice_interrupt'),
                        width: slot,
                        icon: Icons.stop_rounded,
                        label: strings.voiceStopReply,
                        onTap: onInterrupt,
                      )
                    : SizedBox(
                        key: const ValueKey('live_voice_interrupt_placeholder'),
                        width: slot,
                      ),
              ),
              _VoiceControlButton(
                key: const ValueKey('live_voice_end'),
                width: slot,
                icon: Icons.close_rounded,
                label: strings.voiceEnd,
                destructive: true,
                onTap: onEnd,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorControls extends StatelessWidget {
  const _ErrorControls({
    required this.strings,
    required this.onRetry,
    required this.onEnd,
  });

  final LocalizedStrings strings;
  final VoidCallback onRetry;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = _VoiceControlButton.slotWidth(constraints.maxWidth);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _VoiceControlButton(
                key: const ValueKey('live_voice_retry'),
                width: slot,
                icon: Icons.refresh_rounded,
                label: strings.voiceTryAgain,
                highlighted: true,
                onTap: onRetry,
              ),
              _VoiceControlButton(
                key: const ValueKey('live_voice_close'),
                width: slot,
                icon: Icons.close_rounded,
                label: strings.voiceEnd,
                destructive: true,
                onTap: onEnd,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VoiceControlButton extends StatelessWidget {
  const _VoiceControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.width = 100,
    this.highlighted = false,
    this.destructive = false,
  });

  /// Three controls share the row; wider slots keep long labels (Malayalam)
  /// at full size on normal phones.
  static double slotWidth(double rowWidth) =>
      (rowWidth / 3).clamp(84.0, 124.0).toDouble();

  final double width;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final background = destructive
        ? _VoicePalette.endCall
        : highlighted
        ? _VoicePalette.textPrimary
        : _VoicePalette.controlFill;
    final foreground = destructive
        ? Colors.white
        : highlighted
        ? _VoicePalette.backgroundBottom
        : _VoicePalette.textPrimary;
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: background,
              shape: CircleBorder(
                side: destructive || highlighted
                    ? BorderSide.none
                    : const BorderSide(color: _VoicePalette.controlBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: SizedBox.square(
                  dimension: 64,
                  child: Icon(
                    icon,
                    size: 30,
                    color: onTap == null
                        ? foreground.withValues(alpha: 0.4)
                        : foreground,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Long labels (Malayalam "End" is one long word) shrink to fit
            // rather than being cut off.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: _VoiceText.controlLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Orb
// -----------------------------------------------------------------------------

class _OrbButton extends StatelessWidget {
  const _OrbButton({
    required this.state,
    required this.size,
    required this.level,
    required this.semanticsLabel,
    required this.semanticsHint,
    required this.onTap,
  });

  final LiveVoiceState state;
  final double size;
  final ValueListenable<double> level;
  final String semanticsLabel;
  final String semanticsHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tappable = state.isSpeaking || (state.isMuted && state.isListening);
    return Semantics(
      button: tappable,
      label: semanticsLabel,
      hint: semanticsHint.isEmpty ? null : semanticsHint,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('live_voice_orb'),
        behavior: HitTestBehavior.opaque,
        onTap: tappable ? onTap : null,
        child: LiveVoiceOrb(
          mood: LiveVoiceOrb.moodFor(state),
          level: level,
          size: size,
        ),
      ),
    );
  }
}

enum LiveVoiceOrbMood {
  connecting,
  listening,
  userSpeaking,
  thinking,
  speaking,
  muted,
  error,
}

/// The animated "presence" of the assistant. It breathes while idle, follows
/// the patient's voice while listening, swirls while thinking and pulses with
/// the assistant's own voice while speaking.
class LiveVoiceOrb extends StatefulWidget {
  const LiveVoiceOrb({
    super.key,
    required this.mood,
    required this.level,
    required this.size,
  });

  final LiveVoiceOrbMood mood;
  final ValueListenable<double> level;
  final double size;

  static LiveVoiceOrbMood moodFor(LiveVoiceState state) {
    return switch (state.phase) {
      LiveVoicePhase.error => LiveVoiceOrbMood.error,
      LiveVoicePhase.idle ||
      LiveVoicePhase.connecting ||
      LiveVoicePhase.ready ||
      LiveVoicePhase.reconnecting ||
      LiveVoicePhase.closing ||
      LiveVoicePhase.closed => LiveVoiceOrbMood.connecting,
      LiveVoicePhase.speaking => LiveVoiceOrbMood.speaking,
      LiveVoicePhase.thinking ||
      LiveVoicePhase.transcribing => LiveVoiceOrbMood.thinking,
      LiveVoicePhase.listening || LiveVoicePhase.degraded =>
        state.isMuted
            ? LiveVoiceOrbMood.muted
            : state.isUserSpeaking
            ? LiveVoiceOrbMood.userSpeaking
            : LiveVoiceOrbMood.listening,
    };
  }

  @override
  State<LiveVoiceOrb> createState() => _LiveVoiceOrbState();
}

class _LiveVoiceOrbState extends State<LiveVoiceOrb>
    with TickerProviderStateMixin {
  late final _OrbModel _model = _OrbModel(_OrbStyle.forMood(widget.mood));
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _model.target = _OrbStyle.forMood(widget.mood);
    widget.level.addListener(_onLevel);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion == _reduceMotion && _ticker != null) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _ticker?.dispose();
      _ticker = null;
      _model.snapToTarget(level: widget.level.value);
    } else {
      _ticker ??= createTicker(_tick)..start();
    }
  }

  @override
  void didUpdateWidget(covariant LiveVoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.level, widget.level)) {
      oldWidget.level.removeListener(_onLevel);
      widget.level.addListener(_onLevel);
    }
    if (oldWidget.mood != widget.mood) {
      _model.target = _OrbStyle.forMood(widget.mood);
      if (_reduceMotion) _model.snapToTarget(level: widget.level.value);
    }
  }

  @override
  void dispose() {
    widget.level.removeListener(_onLevel);
    _ticker?.dispose();
    _model.dispose();
    super.dispose();
  }

  void _onLevel() {
    if (_reduceMotion) _model.snapToTarget(level: widget.level.value);
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = elapsed;
    _model.advance(
      seconds: elapsed.inMicroseconds / 1e6,
      dt: dt,
      level: widget.level.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: _OrbPainter(_model)),
      ),
    );
  }
}

/// Visual targets for each mood; the model eases between them.
@immutable
class _OrbStyle {
  const _OrbStyle({
    required this.core,
    required this.mid,
    required this.edge,
    required this.glow,
    required this.baseAmplitude,
    required this.levelAmplitude,
    required this.breathing,
    required this.ripples,
    required this.shimmer,
    required this.reactsToLevel,
  });

  final Color core;
  final Color mid;
  final Color edge;
  final Color glow;
  final double baseAmplitude;
  final double levelAmplitude;
  final double breathing;
  final double ripples;
  final double shimmer;
  final bool reactsToLevel;

  static _OrbStyle forMood(LiveVoiceOrbMood mood) {
    return switch (mood) {
      LiveVoiceOrbMood.connecting => const _OrbStyle(
        core: Color(0xFFCFE4F2),
        mid: Color(0xFF7EA7C4),
        edge: Color(0xFF2D4C66),
        glow: Color(0xFF5E8FB8),
        baseAmplitude: 0.025,
        levelAmplitude: 0,
        breathing: 0.045,
        ripples: 0,
        shimmer: 0.35,
        reactsToLevel: false,
      ),
      LiveVoiceOrbMood.listening => const _OrbStyle(
        core: Color(0xFFE2FFF6),
        mid: Color(0xFF63E0C2),
        edge: Color(0xFF12806E),
        glow: Color(0xFF2FD1AA),
        baseAmplitude: 0.03,
        levelAmplitude: 0.11,
        breathing: 0.02,
        ripples: 0,
        shimmer: 0,
        reactsToLevel: true,
      ),
      LiveVoiceOrbMood.userSpeaking => const _OrbStyle(
        core: Color(0xFFF0FFFA),
        mid: Color(0xFF72F0D0),
        edge: Color(0xFF0F8C74),
        glow: Color(0xFF45EBC2),
        baseAmplitude: 0.04,
        levelAmplitude: 0.14,
        breathing: 0.01,
        ripples: 0,
        shimmer: 0,
        reactsToLevel: true,
      ),
      LiveVoiceOrbMood.thinking => const _OrbStyle(
        core: Color(0xFFE8F0FF),
        mid: Color(0xFF86ABFF),
        edge: Color(0xFF3553C8),
        glow: Color(0xFF6F8DFF),
        baseAmplitude: 0.035,
        levelAmplitude: 0,
        breathing: 0.03,
        ripples: 0,
        shimmer: 1,
        reactsToLevel: false,
      ),
      LiveVoiceOrbMood.speaking => const _OrbStyle(
        core: Color(0xFFFFFFFF),
        mid: Color(0xFF8CF3DA),
        edge: Color(0xFF1AA38A),
        glow: Color(0xFF7FF5D8),
        baseAmplitude: 0.035,
        levelAmplitude: 0.15,
        breathing: 0.015,
        ripples: 1,
        shimmer: 0,
        reactsToLevel: true,
      ),
      LiveVoiceOrbMood.muted => const _OrbStyle(
        core: Color(0xFFD9DEE3),
        mid: Color(0xFF8E99A5),
        edge: Color(0xFF48535E),
        glow: Color(0xFF6B7785),
        baseAmplitude: 0.012,
        levelAmplitude: 0,
        breathing: 0.012,
        ripples: 0,
        shimmer: 0,
        reactsToLevel: false,
      ),
      LiveVoiceOrbMood.error => const _OrbStyle(
        core: Color(0xFFFFE0E0),
        mid: Color(0xFFFF8C8C),
        edge: Color(0xFFB3303D),
        glow: Color(0xFFFF6B6B),
        baseAmplitude: 0.008,
        levelAmplitude: 0,
        breathing: 0.008,
        ripples: 0,
        shimmer: 0,
        reactsToLevel: false,
      ),
    };
  }
}

/// Per-frame orb state. Eases colours and motion between moods so state
/// changes read as one continuous creature rather than a slideshow.
class _OrbModel extends ChangeNotifier {
  _OrbModel(_OrbStyle initial)
    : target = initial,
      core = initial.core,
      mid = initial.mid,
      edge = initial.edge,
      glow = initial.glow,
      amplitude = initial.baseAmplitude,
      breathing = initial.breathing,
      ripples = initial.ripples,
      shimmer = initial.shimmer;

  _OrbStyle target;
  double time = 0;
  double level = 0;
  Color core;
  Color mid;
  Color edge;
  Color glow;
  double amplitude;
  double breathing;
  double ripples;
  double shimmer;

  void advance({
    required double seconds,
    required double dt,
    required double level,
  }) {
    time = seconds;
    final input = target.reactsToLevel ? level.clamp(0.0, 1.0) : 0.0;
    // Fast attack, slow release: syllables pop, silences settle gently.
    final rate = input > this.level ? 22.0 : 6.0;
    this.level += (input - this.level) * (1 - math.exp(-dt * rate));
    final ease = 1 - math.exp(-dt * 5.5);
    core = Color.lerp(core, target.core, ease)!;
    mid = Color.lerp(mid, target.mid, ease)!;
    edge = Color.lerp(edge, target.edge, ease)!;
    glow = Color.lerp(glow, target.glow, ease)!;
    final wantedAmplitude =
        target.baseAmplitude + target.levelAmplitude * this.level;
    amplitude += (wantedAmplitude - amplitude) * (1 - math.exp(-dt * 10));
    breathing += (target.breathing - breathing) * ease;
    ripples += (target.ripples - ripples) * ease;
    shimmer += (target.shimmer - shimmer) * ease;
    notifyListeners();
  }

  /// Reduced-motion rendering: jump straight to the target, no animation.
  void snapToTarget({required double level}) {
    this.level = target.reactsToLevel ? level.clamp(0.0, 1.0) : 0.0;
    core = target.core;
    mid = target.mid;
    edge = target.edge;
    glow = target.glow;
    amplitude = 0;
    breathing = 0;
    ripples = 0;
    shimmer = 0;
    notifyListeners();
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.model) : super(repaint: model);

  final _OrbModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.34;
    final t = model.time;
    final breath = 1 + math.sin(t * 1.7) * model.breathing;
    final scale = breath + model.level * 0.12;
    final body = radius * scale;

    // Soft glow halo.
    final glowRadius = body * (1.5 + model.level * 0.3);
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            model.glow.withValues(alpha: 0.42),
            model.glow.withValues(alpha: 0.12),
            model.glow.withValues(alpha: 0),
          ],
          stops: const [0.3, 0.62, 1],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    // Voice ripples while the assistant is speaking.
    if (model.ripples > 0.02) {
      for (var i = 0; i < 3; i++) {
        final phase = (t * 0.55 + i / 3) % 1.0;
        final rippleRadius = body * (1.04 + phase * 0.62);
        final alpha =
            (1 - phase) * 0.32 * model.ripples * (0.55 + model.level * 0.9);
        canvas.drawCircle(
          center,
          rippleRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 + model.level * 2
            ..color = model.glow.withValues(alpha: alpha.clamp(0.0, 1.0)),
        );
      }
    }

    // Three drifting blob layers, outermost (most translucent) first.
    for (var layer = 0; layer < 3; layer++) {
      final layerRadius = body * (1.0 - layer * 0.09);
      final path = _blob(
        center,
        layerRadius,
        model.amplitude * (1 - layer * 0.22),
        t,
        layer,
      );
      final opacity = const [0.45, 0.7, 1.0][layer];
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.28, -0.34),
            radius: 1.05,
            colors: [
              model.core.withValues(alpha: opacity),
              model.mid.withValues(alpha: opacity),
              model.edge.withValues(alpha: opacity),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(Rect.fromCircle(center: center, radius: layerRadius)),
      );
    }

    // Thinking shimmer: a light sweeping around the rim.
    if (model.shimmer > 0.02) {
      final rect = Rect.fromCircle(center: center, radius: body * 0.94);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(t * 2.6);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawCircle(
        center,
        body * 0.94,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = body * 0.09
          ..shader = SweepGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.75 * model.shimmer),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.5, 0.85, 1],
          ).createShader(rect),
      );
      canvas.restore();
    }

    // Glassy highlight.
    final highlightCenter = center + Offset(-body * 0.26, -body * 0.3);
    final highlightRadius = body * 0.45;
    canvas.drawCircle(
      highlightCenter,
      highlightRadius,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.32),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: highlightCenter, radius: highlightRadius),
            ),
    );
  }

  Path _blob(
    Offset center,
    double radius,
    double amplitude,
    double t,
    int seed,
  ) {
    const points = 96;
    final path = Path();
    for (var i = 0; i <= points; i++) {
      final angle = i / points * math.pi * 2;
      final wobble =
          0.55 * math.sin(angle * 3 + t * 1.25 + seed * 1.7) +
          0.3 * math.sin(angle * 5 - t * 1.85 + seed * 0.9) +
          0.15 * math.sin(angle * 7 + t * 2.6 + seed * 2.3);
      final r = radius * (1 + amplitude * wobble);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      !identical(oldDelegate.model, model);
}

// -----------------------------------------------------------------------------
// Typography
// -----------------------------------------------------------------------------

abstract final class _VoiceText {
  static const _family = 'Manrope';
  static const _fallback = ['AnekMalayalam'];

  static const chip = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: _VoicePalette.textPrimary,
    letterSpacing: 0.2,
  );

  static const title = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: _VoicePalette.textPrimary,
    letterSpacing: -0.4,
  );

  static const hint = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: _VoicePalette.textSecondary,
  );

  static const patientCaption = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: _VoicePalette.textSecondary,
  );

  static const assistantCaption = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 18,
    height: 1.45,
    fontWeight: FontWeight.w600,
    color: _VoicePalette.textPrimary,
  );

  static const controlLabel = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: _VoicePalette.textSecondary,
  );
}
