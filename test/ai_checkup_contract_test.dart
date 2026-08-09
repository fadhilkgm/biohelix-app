import 'package:biohelix_app/patient_portal/ai_checkup/services/ai_checkup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the current AI Checkup contract', () {
    final result = AssessmentResults.fromJson(const {
      'intent': 'custom_package',
      'state': 'awaiting_confirmation',
      'urgency': 'soon',
      'outcome': 'test_package_only',
      'risk_level': 'moderate',
      'summary': 'Review the proposed panel.',
    });

    expect(result.intent, 'custom_package');
    expect(result.state, 'awaiting_confirmation');
    expect(result.urgency, 'soon');
  });

  test('maps legacy outcomes and rejects unknown contract values', () {
    final doctor = AssessmentResults.fromJson(const {
      'outcome': 'consultation_only',
      'urgency': 'unexpected',
    });
    final tests = AssessmentResults.fromJson(const {
      'outcome': 'test_package_only',
    });

    expect(doctor.intent, 'doctor_booking');
    expect(doctor.state, 'recommendation_ready');
    expect(doctor.urgency, 'routine');
    expect(tests.intent, 'test_booking');
  });

  test('parses voice lifecycle states', () {
    final session = VoiceAssessmentSession.fromJson(const {
      'session_token': 'session-1',
      'initial_instructions': 'Hello',
      'state': 'collecting',
    });
    final decision = VoiceAssessmentTurnDecision.fromJson(const {
      'completed': true,
      'state': 'completed',
      'result': {
        'intent': 'advice',
        'state': 'completed',
        'urgency': 'emergency',
      },
    });

    expect(session.state, 'collecting');
    expect(decision.state, 'completed');
    expect(decision.result?.urgency, 'emergency');
  });

  test('parses validated catalogue recommendations with reasons', () {
    final result = AssessmentResults.fromJson(const {
      'intent': 'doctor_booking',
      'state': 'recommendation_ready',
      'recommended_doctors': [
        {
          'id': 4,
          'name': 'Dr Active',
          'specialization': 'General Medicine',
          'consultation_fee': '500.00',
          'reason': 'Persistent headache review',
        },
      ],
      'recommended_tests': [
        {
          'id': 8,
          'test_name': 'CBC',
          'price': '250.00',
          'reason': 'Matched to the reported concern.',
        },
      ],
      'recommended_packages': [
        {
          'id': 12,
          'package_name': 'Wellness',
          'price': '1200.00',
          'reason': 'Routine screening match.',
        },
      ],
    });

    expect(result.recommendedDoctors.single.id, 4);
    expect(
      result.recommendedDoctors.single.reason,
      'Persistent headache review',
    );
    expect(result.recommendedTests.single.id, 8);
    expect(result.recommendedTests.single.reason, isNotEmpty);
    expect(result.recommendedPackages.single.id, 12);
    expect(
      result.recommendedPackages.single.reason,
      'Routine screening match.',
    );
  });
}
