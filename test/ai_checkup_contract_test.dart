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
}
