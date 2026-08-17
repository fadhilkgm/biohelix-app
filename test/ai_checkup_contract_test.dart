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

  test('parses a confirmed voice booking signal', () {
    final decision = VoiceAssessmentTurnDecision.fromJson(const {
      'accepted_transcript': 'Yes',
      'spoken_response': 'Your appointment is booked.',
      'response_instructions': 'Speak exactly.',
      'completed': false,
      'turn_count': 2,
      'max_turns': 10,
      'state': 'collecting',
      'booking_created': true,
      'booking_id': 42,
    });

    expect(decision.bookingCreated, isTrue);
    expect(decision.bookingId, 42);
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

  test('parses a server-priced custom package draft', () {
    final result = AssessmentResults.fromJson(const {
      'intent': 'custom_package',
      'custom_package': {
        'id': 9,
        'draft_token': 'draft-token',
        'name': 'AI Personal Health Panel',
        'reason': 'Tailored for the reported concern.',
        'subtotal': '600.00',
        'discount': '0.00',
        'price': '600.00',
        'status': 'draft',
        'valid_until': '2026-08-17T12:00:00Z',
        'tests': [
          {'id': 11, 'test_name': 'CBC', 'price': '250.00'},
          {'id': 12, 'test_name': 'TSH', 'price': '350.00'},
        ],
      },
    });

    expect(result.customPackage?.id, 9);
    expect(result.customPackage?.status, 'draft');
    expect(result.customPackage?.price, '600.00');
    expect(result.customPackage?.tests.map((test) => test.id), [11, 12]);
  });
}
