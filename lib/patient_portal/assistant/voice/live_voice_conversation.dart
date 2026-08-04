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

  const exactPhrases = {
    'bye',
    'bye bye',
    'goodbye',
    'good bye',
    'see you',
    'see you later',
    'thank you',
    'thank you so much',
    'thank you very much',
    'thanks',
    'thanks a lot',
    'thanks for your help',
    'thanks for explaining',
    'that is all',
    'that s all',
    'no more questions',
    'ok bye',
    'okay bye',
    'ok thank you',
    'okay thank you',
    'alright thank you',
    'നന്ദി',
    'വളരെ നന്ദി',
    'ബൈ',
    'ബൈ ബൈ',
    'വിട',
    'പിന്നെ കാണാം',
    'മതി നന്ദി',
    'ശരി നന്ദി',
    'nanni',
    'valare nanni',
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
