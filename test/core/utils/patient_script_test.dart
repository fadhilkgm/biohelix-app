import 'package:biohelix_app/core/utils/patient_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leaves English, Malayalam and mixed text untouched', () {
    for (final text in [
      'I have fever for 2 days.',
      'എനിക്ക് പനി ഉണ്ട്.',
      'Sugar 140 ആണ്, BP normal 😊',
    ]) {
      expect(hasForeignScript(text), isFalse);
      expect(toPatientScript(text), text);
    }
  });

  test('turns Hindi letters into Malayalam letters', () {
    // "എനിക്ക് പനി" spoken in Malayalam but written in Devanagari.
    expect(hasForeignScript('एनिक्क् पनि।'), isTrue);
    expect(toPatientScript('एनिक्क् पनि।'), 'എനിക്ക് പനി.');
    expect(toPatientScript('फ़ीवर'), 'ഫീവര');
  });

  test('removes scripts that cannot be transliterated', () {
    final clean = toPatientScript('Hello Привет مرحبا 你好 നമസ്കാരം');
    expect(clean, 'Hello നമസ്കാരം');
    expect(hasForeignScript(clean), isFalse);
  });
}
