import 'package:biohelix_app/patient_portal/core/models/patient_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses doctor booking action and source assessment', () {
    final message = ChatMessage.fromJson(const {
      'role': 'ai',
      'content': 'Please confirm the appointment.',
      'action': {
        'intent': 'doctor_booking',
        'state': 'awaiting_confirmation',
        'urgency': 'routine',
        'outcome': 'consultation_only',
        'source_session_token': 'chat-session',
        'recommended_doctors': [
          {
            'id': 7,
            'name': 'Dr Active',
            'specialization': 'General Medicine',
            'reason': 'First clinical review',
          },
        ],
      },
    });

    expect(message.action?.intent, 'doctor_booking');
    expect(message.action?.state, 'awaiting_confirmation');
    expect(message.action?.sourceSessionToken, 'chat-session');
    expect(message.action?.recommendedDoctors.single.id, 7);
  });

  test('parses emergency and confirmed booking actions', () {
    final emergency = ChatAssistantAction.fromJson(const {
      'intent': 'advice',
      'state': 'completed',
      'urgency': 'emergency',
      'outcome': 'emergency_escalation',
    });
    final booking = ChatAssistantAction.fromJson(const {
      'intent': 'doctor_booking',
      'state': 'completed',
      'urgency': 'routine',
      'booking_created': true,
      'booking_id': 42,
      'booking_number': 'BKG-42',
    });

    expect(emergency.isAdviceOnly, isFalse);
    expect(booking.bookingCreated, isTrue);
    expect(booking.bookingId, 42);
    expect(booking.bookingNumber, 'BKG-42');
  });

  test('parses a server-priced editable custom package', () {
    final action = ChatAssistantAction.fromJson(const {
      'intent': 'custom_package',
      'state': 'completed',
      'urgency': 'routine',
      'source_session_token': 'custom-session',
      'custom_package': {
        'id': 9,
        'draft_token': 'draft-token',
        'name': 'Personal panel',
        'price': '525.00',
        'status': 'draft',
        'valid_until': '2026-08-27T12:00:00Z',
        'tests': [
          {'id': 11, 'test_name': 'CBC'},
          {'id': 12, 'test_name': 'TSH'},
        ],
      },
    });

    expect(action.customPackage?.id, 9);
    expect(action.customPackage?.price, '525.00');
    expect(action.customPackage?.testIds, [11, 12]);
    expect(action.sourceSessionToken, 'custom-session');
  });
}
