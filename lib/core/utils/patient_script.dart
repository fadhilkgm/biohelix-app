/// The assistant is used only in English and Malayalam, so chat text must
/// never show another script. Speech recognition and keyboard voice typing
/// have written Malayalam speech in Hindi (Devanagari) letters, and models
/// have answered in Hindi; this keeps that off the screen. It mirrors
/// `PatientLanguage` on the server.
library;

final RegExp _foreignScript = RegExp(
  r'[^\p{Script=Latin}\p{Script=Malayalam}\p{Script=Common}\p{Script=Inherited}]',
  unicode: true,
);
final RegExp _malayalamLetter = RegExp(
  r'^\p{Script=Malayalam}$',
  unicode: true,
);
final RegExp _repeatedSpaces = RegExp(r'[ \t]{2,}');

const int _malayalamBlock = 0x0D00;

/// Devanagari nukta letters (क़ ख़ ग़ ज़ ड़ ढ़ फ़ य़) map to their base letters.
const Map<int, int> _nuktaBase = {
  0x0958: 0x15,
  0x0959: 0x16,
  0x095A: 0x17,
  0x095B: 0x1C,
  0x095C: 0x21,
  0x095D: 0x22,
  0x095E: 0x2B,
  0x095F: 0x2F,
};

bool hasForeignScript(String text) => _foreignScript.hasMatch(text);

/// Returns [text] with only English and Malayalam letters. Indian scripts
/// share one letter layout, so Devanagari, Tamil, Kannada and the rest are
/// transliterated into Malayalam letters; any other script is removed.
String toPatientScript(String text) {
  if (!hasForeignScript(text)) return text;
  final out = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0x0900 && rune < 0x0D00) {
      out.write(_toMalayalam(rune));
    } else {
      out.writeCharCode(rune);
    }
  }
  return out
      .toString()
      .replaceAll(_foreignScript, '')
      .replaceAll(_repeatedSpaces, ' ');
}

String _toMalayalam(int rune) {
  if (rune == 0x0964 || rune == 0x0965) return '.'; // Danda: Hindi full stop.
  var offset = _nuktaBase[rune] ?? (rune & 0x7F);
  final devanagari = rune < 0x0980;
  if (offset == 0x3C) return ''; // Nukta has no Malayalam form.
  if (devanagari && const {0x0F, 0x13, 0x47, 0x4B}.contains(offset)) {
    // Hindi has no short e/o, so Malayalam's (far more common) short vowels
    // are written with the long Hindi ones.
    offset -= 1;
  } else if (offset == 0x45 || offset == 0x49) {
    offset += 1; // Candra e/o signs.
  }
  final malayalam = String.fromCharCode(_malayalamBlock + offset);
  return _malayalamLetter.hasMatch(malayalam) ? malayalam : '';
}
