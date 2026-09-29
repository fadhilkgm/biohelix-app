/// Per-turn directive used when Laravel returns record context for a turn.
/// The controller prepends the session instructions, because a
/// `response.create` instruction replaces the session prompt for that reply.
const String kLiveVoiceTurnInstructions =
    "Answer the patient's last message now in one to three short, natural "
    'spoken sentences. Use the verified health-record context below only when '
    'it is relevant, and never say that you read records.';

/// Sent as the `response.create` instruction when the per-turn context lookup
/// is slower than the live latency budget, or fails outright. The controller
/// prepends the session instructions (persona, safety rules, language and the
/// patient's health background), so the reply stays grounded.
const String kLiveVoiceFallbackTurnInstructions =
    "Answer the patient's last message now using the health background above. "
    'Keep it to one to three short spoken sentences.';

/// Cap on each text-chat message replayed into a new voice session.
const int kLiveVoiceHistoryCharacterLimit = 600;

/// How many recent text-chat messages a new voice session starts with.
const int kLiveVoiceHistoryMessageLimit = 6;

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
    'thank you bye',
    'thanks bye',
    'ബൈ',
    'ബൈ ബൈ',
    'വിട',
    'പിന്നെ കാണാം',
  };

  return exactPhrases.contains(phrase);
}

String liveVoiceFarewellInstructions(String locale) {
  if (locale.toLowerCase().startsWith('ml')) {
    return 'Say exactly this in Malayalam and nothing else: '
        '"നന്ദി. ശ്രദ്ധിക്കൂ. വീണ്ടും കാണാം." '
        'The patient is ending the live conversation, so do not ask another '
        'question.';
  }

  return 'Say exactly this and nothing else: '
      '"You’re welcome. Take care, and goodbye." '
      'The patient is ending the live conversation, so do not ask another '
      'question.';
}

/// True when [instructions] demand a verbatim reply. Those are sent on their
/// own; anything else is composed on top of the session prompt.
bool isExactLiveVoiceInstruction(String instructions) {
  final lower = instructions.trimLeft().toLowerCase();
  return lower.startsWith('speak exactly') ||
      lower.startsWith('say exactly') ||
      lower.contains('speak exactly this text') ||
      lower.contains('speak exactly the following');
}

/// Strips chat markdown so replayed messages read like speech.
String plainLiveVoiceText(
  String value, {
  int limit = kLiveVoiceHistoryCharacterLimit,
}) {
  var text = value
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]*\)'),
        (match) => match.group(1) ?? '',
      )
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'[*_`>|]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.length > limit) {
    text = '${text.substring(0, limit - 1).trimRight()}…';
  }
  return text;
}
