import 'package:flutter/foundation.dart';

enum LiveVoicePhase {
  idle,
  connecting,
  ready,
  listening,
  transcribing,
  thinking,
  speaking,
  reconnecting,
  closing,
  closed,
  degraded,
  error,
}

enum LiveVoiceSpeaker { patient, assistant }

/// One caption line of the running voice conversation.
@immutable
class LiveVoiceTranscriptEntry {
  const LiveVoiceTranscriptEntry({
    required this.id,
    required this.speaker,
    required this.text,
    this.isFinal = false,
    this.interrupted = false,
  });

  final String id;
  final LiveVoiceSpeaker speaker;
  final String text;

  /// False while the words are still streaming in.
  final bool isFinal;

  /// The patient talked over (or tapped to stop) this assistant reply.
  final bool interrupted;

  bool get isPatient => speaker == LiveVoiceSpeaker.patient;

  LiveVoiceTranscriptEntry copyWith({
    String? text,
    bool? isFinal,
    bool? interrupted,
  }) {
    return LiveVoiceTranscriptEntry(
      id: id,
      speaker: speaker,
      text: text ?? this.text,
      isFinal: isFinal ?? this.isFinal,
      interrupted: interrupted ?? this.interrupted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiveVoiceTranscriptEntry &&
        other.id == id &&
        other.speaker == speaker &&
        other.text == text &&
        other.isFinal == isFinal &&
        other.interrupted == interrupted;
  }

  @override
  int get hashCode => Object.hash(id, speaker, text, isFinal, interrupted);
}

class LiveVoiceState {
  const LiveVoiceState({
    this.phase = LiveVoicePhase.idle,
    this.sessionId,
    this.turnId,
    this.partialTranscript = '',
    this.finalTranscript = '',
    this.responseText = '',
    this.errorMessage,
    this.soundLevel = 0,
    this.isMuted = false,
    this.isUserSpeaking = false,
    this.connectedAt,
    this.transcript = const [],
  });

  final LiveVoicePhase phase;
  final String? sessionId;
  final String? turnId;
  final String partialTranscript;
  final String finalTranscript;
  final String responseText;
  final String? errorMessage;

  /// Kept for compatibility. Live microphone/speaker levels are published on
  /// [LiveVoiceController.soundLevel] so 5-10Hz updates never rebuild a tab.
  final double soundLevel;

  final bool isMuted;

  /// Voice activity is currently detected on the patient's microphone.
  final bool isUserSpeaking;

  /// When the call first became ready to listen; drives the call timer.
  final DateTime? connectedAt;

  /// Captions for this call only, oldest first.
  final List<LiveVoiceTranscriptEntry> transcript;

  bool get isActive =>
      phase != LiveVoicePhase.idle &&
      phase != LiveVoicePhase.closed &&
      phase != LiveVoicePhase.error;

  bool get isListening =>
      phase == LiveVoicePhase.listening || phase == LiveVoicePhase.transcribing;

  bool get isSpeaking => phase == LiveVoicePhase.speaking;

  bool get isThinking => phase == LiveVoicePhase.thinking;

  bool get isConnecting =>
      phase == LiveVoicePhase.connecting ||
      phase == LiveVoicePhase.reconnecting ||
      phase == LiveVoicePhase.ready;

  LiveVoiceState copyWith({
    LiveVoicePhase? phase,
    String? sessionId,
    String? turnId,
    String? partialTranscript,
    String? finalTranscript,
    String? responseText,
    String? errorMessage,
    double? soundLevel,
    bool? isMuted,
    bool? isUserSpeaking,
    DateTime? connectedAt,
    List<LiveVoiceTranscriptEntry>? transcript,
    bool clearError = false,
    bool clearSession = false,
    bool clearTurn = false,
  }) {
    return LiveVoiceState(
      phase: phase ?? this.phase,
      sessionId: clearSession ? null : sessionId ?? this.sessionId,
      turnId: clearTurn ? null : turnId ?? this.turnId,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      finalTranscript: finalTranscript ?? this.finalTranscript,
      responseText: responseText ?? this.responseText,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      soundLevel: soundLevel ?? this.soundLevel,
      isMuted: isMuted ?? this.isMuted,
      isUserSpeaking: isUserSpeaking ?? this.isUserSpeaking,
      connectedAt: clearSession ? null : connectedAt ?? this.connectedAt,
      transcript: transcript ?? this.transcript,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiveVoiceState &&
        other.phase == phase &&
        other.sessionId == sessionId &&
        other.turnId == turnId &&
        other.partialTranscript == partialTranscript &&
        other.finalTranscript == finalTranscript &&
        other.responseText == responseText &&
        other.errorMessage == errorMessage &&
        other.soundLevel == soundLevel &&
        other.isMuted == isMuted &&
        other.isUserSpeaking == isUserSpeaking &&
        other.connectedAt == connectedAt &&
        listEquals(other.transcript, transcript);
  }

  @override
  int get hashCode => Object.hash(
    phase,
    sessionId,
    turnId,
    partialTranscript,
    finalTranscript,
    responseText,
    errorMessage,
    soundLevel,
    isMuted,
    isUserSpeaking,
    connectedAt,
    Object.hashAll(transcript),
  );
}
