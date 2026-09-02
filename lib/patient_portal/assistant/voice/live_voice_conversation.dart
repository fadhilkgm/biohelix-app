/// Sent as the `response.create` instruction when the per-turn context lookup
/// is slower than the live latency budget, or fails outright. The call keeps
/// going on the session instructions already delivered in `session.update`.
const String kLiveVoiceFallbackTurnInstructions =
    "Answer the patient's last message now using the session instructions "
    'and any health background already provided. Keep it to one to three '
    'short spoken sentences.';

String normalizeLiveVoicePhrase(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool isLiveConversationEndingPhrase(String transcript) {
  final phrase = normalizeLiveVoicePhrase(transcript);
  if (phrase.isEmpty || phrase.length > 80) return false;

  // Gratitude on its own is not a farewell: patients routinely say "thanks"
  // in the middle of a consultation and the call must stay open.
  const exactPhrases = {
    'bye',
    'bye bye',
    'goodbye',
    'good bye',
    'see you',
    'see you later',
    'that is all',
    'that s all',
    'no more questions',
    'ok bye',
    'okay bye',
    'ബൈ',
    'ബൈ ബൈ',
    'വിട',
    'പിന്നെ കാണാം',
  };

  return exactPhrases.contains(phrase);
}

String liveVoiceFarewellInstructions(String locale) {
  if (locale.toLowerCase().startsWith('ml')) {
    return 'The patient is ending the live conversation. '
        'Say exactly this in Malayalam: "നന്ദി. ശ്രദ്ധിക്കൂ. വീണ്ടും കാണാം." '
        'Do not ask another question or add anything else.';
  }

  return 'The patient is ending the live conversation. '
      'Say exactly: "You’re welcome. Take care, and goodbye." '
      'Do not ask another question or add anything else.';
}
