import 'package:biohelix_app/patient_portal/assistant/voice/live_voice_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isLiveConversationEndingPhrase', () {
    test('recognizes short English and Malayalam endings', () {
      expect(isLiveConversationEndingPhrase('Bye!'), isTrue);
      expect(isLiveConversationEndingPhrase('Okay, bye.'), isTrue);
      expect(isLiveConversationEndingPhrase('That is all'), isTrue);
      expect(isLiveConversationEndingPhrase('ബൈ'), isTrue);
      expect(isLiveConversationEndingPhrase('പിന്നെ കാണാം!'), isTrue);
    });

    test('does not close while the patient is still asking for help', () {
      expect(
        isLiveConversationEndingPhrase(
          'Thank you, but what is my sugar level?',
        ),
        isFalse,
      );
      expect(
        isLiveConversationEndingPhrase('Can you explain this report?'),
        isFalse,
      );
    });

    test('gratitude alone keeps the call open', () {
      // Patients thank the assistant mid-consultation; hanging up there was
      // the single most reported live-voice complaint.
      expect(isLiveConversationEndingPhrase('Thank you'), isFalse);
      expect(isLiveConversationEndingPhrase('Thanks a lot'), isFalse);
      expect(isLiveConversationEndingPhrase('Okay, thank you.'), isFalse);
      expect(isLiveConversationEndingPhrase('നന്ദി'), isFalse);
    });
  });

  test('fallback turn instructions stay short and spoken', () {
    expect(kLiveVoiceFallbackTurnInstructions, contains('health background'));
    expect(kLiveVoiceFallbackTurnInstructions, contains('short spoken'));
  });

  test('farewell prompt does not invite another question', () {
    expect(
      liveVoiceFarewellInstructions('en-IN'),
      contains('Take care, and goodbye'),
    );
    expect(
      liveVoiceFarewellInstructions('ml-IN'),
      contains('നന്ദി. ശ്രദ്ധിക്കൂ. വീണ്ടും കാണാം.'),
    );
    // Farewells are verbatim, so they must never be merged into the session
    // prompt, which asks for two to four sentences.
    expect(
      isExactLiveVoiceInstruction(liveVoiceFarewellInstructions('en-IN')),
      isTrue,
    );
    expect(
      isExactLiveVoiceInstruction(liveVoiceFarewellInstructions('ml-IN')),
      isTrue,
    );
  });

  group('isExactLiveVoiceInstruction', () {
    test('recognises server-owned verbatim replies', () {
      expect(
        isExactLiveVoiceInstruction(
          'Speak exactly this text with no introduction or extra words: "Hi"',
        ),
        isTrue,
      );
      expect(
        isExactLiveVoiceInstruction(
          'Do not ask another question or give routine advice. Speak exactly '
          'this text with no introduction, labels, markdown, or additional '
          'words: "Call an ambulance"',
        ),
        isTrue,
      );
    });

    test('treats ordinary directives as composable', () {
      expect(isExactLiveVoiceInstruction(kLiveVoiceTurnInstructions), isFalse);
      expect(
        isExactLiveVoiceInstruction(
          "Continue as the patient's health checkup assistant. Ask one short "
          'next question, or if enough information is available say exactly: '
          'Thank you.',
        ),
        isFalse,
      );
    });
  });

  test('replayed chat text is stripped of markdown and capped', () {
    expect(
      plainLiveVoiceText('## Summary\n- **Haemoglobin** is [normal](http://x)'),
      'Summary Haemoglobin is normal',
    );
    final long = plainLiveVoiceText('a' * 900);
    expect(long.length, kLiveVoiceHistoryCharacterLimit);
    expect(long.endsWith('…'), isTrue);
  });
}
