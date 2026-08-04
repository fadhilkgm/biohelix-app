import 'package:biohelix_app/patient_portal/fitness/providers/fitness_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HealthKit read failures do not expose platform error details', () {
    final error = PlatformException(
      code: 'healthkit_read',
      message: 'No data available for the specified predicate.',
    );

    final message = friendlyFitnessError(error);

    expect(
      message,
      'Apple Health could not refresh your walking activity. Please try again.',
    );
    expect(message, isNot(contains('healthkit_read')));
    expect(message, isNot(contains('predicate')));
  });
}
