import 'package:biohelix_app/core/utils/phone_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizePatientPhone adds India country code for 10-digit numbers', () {
    expect(normalizePatientPhone('9876543210'), '+919876543210');
  });

  test('normalizePatientPhone keeps full international numbers', () {
    expect(normalizePatientPhone('+919876543210'), '+919876543210');
    expect(normalizePatientPhone('919876543210'), '+919876543210');
  });

  test('whatsAppPhoneDigits matches Meta API format', () {
    expect(
      whatsAppPhoneDigits(normalizePatientPhone('9876543210')),
      '919876543210',
    );
  });

  test('maskPatientPhone hides middle digits', () {
    expect(maskPatientPhone('+919876543210'), '+91 XXXXXX3210');
  });
}
