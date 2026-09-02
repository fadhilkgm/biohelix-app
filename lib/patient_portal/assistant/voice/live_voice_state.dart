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
  });

  final LiveVoicePhase phase;
  final String? sessionId;
  final String? turnId;
  final String partialTranscript;
  final String finalTranscript;
  final String responseText;
  final String? errorMessage;

  /// Kept for compatibility. Live microphone/speaker levels are published on
  /// [LiveVoiceController.soundLevel] so 5-8Hz updates never rebuild the tab.
  final double soundLevel;

  bool get isActive =>
      phase != LiveVoicePhase.idle &&
      phase != LiveVoicePhase.closed &&
      phase != LiveVoicePhase.error;

  bool get isListening =>
      phase == LiveVoicePhase.listening || phase == LiveVoicePhase.transcribing;

  bool get isSpeaking => phase == LiveVoicePhase.speaking;

  LiveVoiceState copyWith({
    LiveVoicePhase? phase,
    String? sessionId,
    String? turnId,
    String? partialTranscript,
    String? finalTranscript,
    String? responseText,
    String? errorMessage,
    double? soundLevel,
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
        other.soundLevel == soundLevel;
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
  );
}
