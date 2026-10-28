import 'dart:async';

import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/inworld_signaling_api.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/live_voice_controller.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/live_voice_conversation.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/live_voice_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = 'BASE SESSION PROMPT';

/// Captures what the controller would send over the realtime data channel.
class _RecordingController extends LiveVoiceController {
  _RecordingController({
    required super.onTurnCompleted,
    required super.onTurnContext,
  }) : super(
         signalingApi: InworldSignalingApi(
           ApiClient(
             config: AppConfig(
               appName: 'Test',
               apiBaseUrl: 'https://example.test/api',
               healthEndpoint: '/health',
               showDevOtp: false,
             ),
           ),
         ),
       );

  final List<Map<String, dynamic>> sent = [];

  @override
  Future<void> sendRealtimeEvent(Map<String, dynamic> event) async {
    sent.add(event);
  }

  List<Map<String, dynamic>> sentOfType(String type) =>
      sent.where((event) => event['type'] == type).toList();

  String lastInstructions() {
    final creates = sentOfType('response.create');
    final response = creates.last['response'] as Map<String, dynamic>;
    return response['instructions'] as String;
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<(String, String)> completedTurns;
  late Future<String> Function(String transcript) turnContext;
  late _RecordingController voice;

  setUp(() {
    completedTurns = [];
    turnContext = (_) async => 'Answer now.\n\nRecords: haemoglobin 13.1';
    voice = _RecordingController(
      onTurnCompleted: (transcript, response) {
        completedTurns.add((transcript, response));
      },
      onTurnContext: (transcript) => turnContext(transcript),
    );
  });

  tearDown(() {
    voice.dispose();
  });

  /// One patient utterance, transcribed as [text].
  Future<void> patientSays(String itemId, String text) async {
    voice.debugHandleEvent({
      'type': 'input_audio_buffer.speech_started',
      'item_id': itemId,
    });
    voice.debugHandleEvent({
      'type': 'input_audio_buffer.speech_stopped',
      'item_id': itemId,
    });
    voice.debugHandleEvent({
      'type': 'conversation.item.input_audio_transcription.completed',
      'item_id': itemId,
      'transcript': text,
    });
    await _settle();
  }

  /// The assistant's reply [responseId] streams [text] and finishes
  /// generating (the audio may still be playing).
  void assistantReplies(String responseId, String text) {
    voice.debugHandleEvent({
      'type': 'response.created',
      'response': {'id': responseId},
    });
    voice.debugHandleEvent({'type': 'output_audio_buffer.started'});
    voice.debugHandleEvent({
      'type': 'response.output_audio_transcript.delta',
      'response_id': responseId,
      'delta': text,
    });
    voice.debugHandleEvent({
      'type': 'response.done',
      'response': {'id': responseId, 'status': 'completed'},
    });
  }

  group('session start', () {
    test(
      'a session configured with the call listens as soon as the channel opens',
      () {
        voice.debugStartSimulatedSession(baseInstructions: _base);

        expect(voice.state.phase, LiveVoicePhase.listening);
        expect(voice.state.connectedAt, isNotNull);
        expect(voice.sentOfType('session.update'), isEmpty);
        // No greeting to sit through: the assistant waits for the patient.
        expect(voice.sentOfType('response.create'), isEmpty);
      },
    );

    test('an unconfigured session sends session.update and waits for it', () {
      voice.debugStartSimulatedSession(sessionPreconfigured: false);

      expect(voice.state.phase, LiveVoicePhase.connecting);
      expect(voice.sentOfType('session.update'), hasLength(1));

      voice.debugHandleEvent({
        'type': 'session.updated',
        'session': {'id': 'sess_1'},
      });

      expect(voice.state.phase, LiveVoicePhase.listening);
      expect(voice.state.sessionId, 'sess_1');
    });

    test('replays recent chat messages so the call continues the thread', () {
      voice.debugStartSimulatedSession(
        history: const [
          LiveVoiceHistoryItem(fromPatient: true, text: 'Is my **sugar** ok?'),
          LiveVoiceHistoryItem(fromPatient: false, text: 'Your HbA1c is 5.4%.'),
        ],
      );

      final items = voice.sentOfType('conversation.item.create');
      expect(items, hasLength(2));
      final first = items[0]['item'] as Map<String, dynamic>;
      final second = items[1]['item'] as Map<String, dynamic>;
      expect(first['role'], 'user');
      expect((first['content'] as List).single, {
        'type': 'input_text',
        'text': 'Is my sugar ok?',
      });
      expect(second['role'], 'assistant');
      expect(
        ((second['content'] as List).single as Map)['type'],
        'output_text',
      );
    });
  });

  group('unrequested replies', () {
    test('a reply the provider starts on its own is cancelled unheard', () {
      voice.debugStartSimulatedSession(baseInstructions: _base);

      voice.debugHandleEvent({
        'type': 'response.created',
        'response': {'id': 'auto_1'},
      });
      voice.debugHandleEvent({
        'type': 'response.output_audio_transcript.delta',
        'response_id': 'auto_1',
        'delta': 'नमस्ते',
      });

      expect(voice.sentOfType('response.cancel'), hasLength(1));
      expect(voice.sentOfType('output_audio_buffer.clear'), hasLength(1));
      expect(voice.state.transcript, isEmpty);
      expect(voice.state.phase, LiveVoicePhase.listening);
    });

    test('the requested reply still plays after an unrequested one', () async {
      voice.debugStartSimulatedSession(baseInstructions: _base);

      // Inworld auto-answers the raw transcript before the app's request.
      voice.debugHandleEvent({
        'type': 'input_audio_buffer.speech_started',
        'item_id': 'item_1',
      });
      voice.debugHandleEvent({
        'type': 'input_audio_buffer.speech_stopped',
        'item_id': 'item_1',
      });
      voice.debugHandleEvent({
        'type': 'response.created',
        'response': {'id': 'auto_1'},
      });
      voice.debugHandleEvent({
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'item_1',
        'transcript': 'എനിക്ക് മുട്ടുവേദന ഉണ്ട്',
      });
      await _settle();
      expect(voice.sentOfType('response.create'), hasLength(1));

      assistantReplies('reply_1', 'എത്ര ദിവസമായി?');
      voice.debugHandleEvent({
        'type': 'response.done',
        'response': {'id': 'auto_1', 'status': 'cancelled'},
      });
      voice.debugHandleEvent({'type': 'output_audio_buffer.stopped'});

      expect(voice.sentOfType('response.cancel'), hasLength(1));
      expect(completedTurns, [('എനിക്ക് മുട്ടുവേദന ഉണ്ട്', 'എത്ര ദിവസമായി?')]);
      expect(voice.state.phase, LiveVoicePhase.listening);
    });
  });

  group('turn instructions', () {
    test('turn context is layered on top of the session prompt', () async {
      voice.debugStartSimulatedSession(baseInstructions: _base);

      await patientSays('item_1', 'What is my haemoglobin?');

      expect(voice.state.phase, LiveVoicePhase.thinking);
      expect(
        voice.lastInstructions(),
        '$_base\n\nAnswer now.\n\nRecords: haemoglobin 13.1',
      );
    });

    test('verbatim server replies are sent without the session prompt', () async {
      turnContext = (_) async =>
          'Speak exactly this text with no introduction or extra words: "Booked."';
      voice.debugStartSimulatedSession(baseInstructions: _base);

      await patientSays('item_1', 'Yes, book it');

      expect(
        voice.lastInstructions(),
        'Speak exactly this text with no introduction or extra words: "Booked."',
      );
    });

    test(
      'a failed context lookup still answers with the full session prompt',
      () async {
        turnContext = (_) async => throw StateError('offline');
        voice.debugStartSimulatedSession(baseInstructions: _base);

        await patientSays('item_1', 'I have a headache');

        final instructions = voice.lastInstructions();
        expect(instructions, startsWith(_base));
        expect(instructions, endsWith(kLiveVoiceFallbackTurnInstructions));
      },
    );

    test('an empty transcript keeps listening without replying', () async {
      voice.debugStartSimulatedSession(baseInstructions: _base);

      await patientSays('item_1', '   ');

      expect(voice.state.phase, LiveVoicePhase.listening);
      expect(voice.sentOfType('response.create'), isEmpty);
      expect(voice.state.transcript, isEmpty);
    });

    test(
      'a late context result for a superseded utterance is dropped',
      () async {
        final slow = Completer<String>();
        turnContext = (transcript) => transcript == 'first'
            ? slow.future
            : Future.value('Second answer.');
        voice.debugStartSimulatedSession(baseInstructions: _base);

        await patientSays('item_1', 'first');
        voice.debugHandleEvent({
          'type': 'input_audio_buffer.speech_started',
          'item_id': 'item_2',
        });
        slow.complete('First answer.');
        await _settle();

        expect(voice.sentOfType('response.create'), isEmpty);
      },
    );
  });

  test(
    'a transcript for an utterance the patient has kept talking past gets no reply',
    () async {
      voice.debugStartSimulatedSession(baseInstructions: _base);
      voice.debugHandleEvent({
        'type': 'input_audio_buffer.speech_started',
        'item_id': 'item_1',
      });
      voice.debugHandleEvent({'type': 'input_audio_buffer.speech_stopped'});
      // The patient carries on before the first transcript lands.
      voice.debugHandleEvent({
        'type': 'input_audio_buffer.speech_started',
        'item_id': 'item_2',
      });
      voice.debugHandleEvent({
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'item_1',
        'transcript': 'I have had a fever',
      });
      await _settle();

      expect(voice.sentOfType('response.create'), isEmpty);
      expect(voice.state.phase, LiveVoicePhase.listening);
      expect(voice.state.isUserSpeaking, isTrue);
      expect(voice.state.transcript.single.text, 'I have had a fever');

      voice.debugHandleEvent({'type': 'input_audio_buffer.speech_stopped'});
      voice.debugHandleEvent({
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'item_2',
        'transcript': 'for three days',
      });
      await _settle();

      expect(voice.sentOfType('response.create'), hasLength(1));
      expect(voice.state.phase, LiveVoicePhase.thinking);
    },
  );

  group('speaking and turn-taking', () {
    test(
      'stays speaking until the audio buffer drains, then saves the turn',
      () async {
        voice.debugStartSimulatedSession(baseInstructions: _base);
        await patientSays('item_1', 'What is my haemoglobin?');

        assistantReplies('resp_1', 'It is 13.1, which is normal.');

        // Generation finished, but the patient is still hearing the reply.
        expect(voice.state.phase, LiveVoicePhase.speaking);
        expect(completedTurns, [
          ('What is my haemoglobin?', 'It is 13.1, which is normal.'),
        ]);

        voice.debugHandleEvent({'type': 'output_audio_buffer.stopped'});

        expect(voice.state.phase, LiveVoicePhase.listening);
        final captions = voice.state.transcript;
        expect(captions.map((entry) => entry.text), [
          'What is my haemoglobin?',
          'It is 13.1, which is normal.',
        ]);
        expect(captions.every((entry) => entry.isFinal), isTrue);
      },
    );

    test(
      'talking over the assistant interrupts it without saving the turn',
      () async {
        voice.debugStartSimulatedSession(baseInstructions: _base);
        await patientSays('item_1', 'Tell me about diabetes');
        voice.debugHandleEvent({
          'type': 'response.created',
          'response': {'id': 'resp_1'},
        });
        voice.debugHandleEvent({'type': 'output_audio_buffer.started'});
        voice.debugHandleEvent({
          'type': 'response.output_audio_transcript.delta',
          'response_id': 'resp_1',
          'delta': 'Diabetes is a condition where',
        });
        expect(voice.state.phase, LiveVoicePhase.speaking);

        voice.debugHandleEvent({
          'type': 'input_audio_buffer.speech_started',
          'item_id': 'item_2',
        });

        expect(voice.state.phase, LiveVoicePhase.listening);
        expect(voice.state.isUserSpeaking, isTrue);
        expect(voice.sentOfType('response.cancel'), hasLength(1));
        expect(voice.sentOfType('output_audio_buffer.clear'), hasLength(1));
        final interrupted = voice.state.transcript.last;
        expect(interrupted.speaker, LiveVoiceSpeaker.assistant);
        expect(interrupted.interrupted, isTrue);

        voice.debugHandleEvent({
          'type': 'response.done',
          'response': {'id': 'resp_1', 'status': 'cancelled'},
        });

        expect(completedTurns, isEmpty);
        expect(voice.state.phase, LiveVoicePhase.listening);
      },
    );

    test('tapping stop interrupts the reply', () async {
      voice.debugStartSimulatedSession(baseInstructions: _base);
      await patientSays('item_1', 'Tell me about diabetes');
      voice.debugHandleEvent({
        'type': 'response.created',
        'response': {'id': 'resp_1'},
      });
      voice.debugHandleEvent({'type': 'output_audio_buffer.started'});

      await voice.interrupt();

      expect(voice.state.phase, LiveVoicePhase.listening);
      expect(voice.sentOfType('response.cancel'), hasLength(1));
      expect(voice.sentOfType('output_audio_buffer.clear'), hasLength(1));
    });

    test(
      'a reply the patient talked over before it started is cancelled',
      () async {
        voice.debugStartSimulatedSession(baseInstructions: _base);
        await patientSays('item_1', 'I have a cough');
        expect(voice.sentOfType('response.create'), hasLength(1));

        // The patient keeps talking before the reply is created.
        voice.debugHandleEvent({
          'type': 'input_audio_buffer.speech_started',
          'item_id': 'item_2',
        });
        voice.debugHandleEvent({
          'type': 'response.created',
          'response': {'id': 'resp_stale'},
        });
        voice.debugHandleEvent({
          'type': 'response.output_audio_transcript.delta',
          'response_id': 'resp_stale',
          'delta': 'A cough can',
        });

        expect(voice.sentOfType('response.cancel'), hasLength(1));
        expect(voice.state.phase, LiveVoicePhase.listening);
        expect(
          voice.state.transcript.where(
            (entry) => entry.speaker == LiveVoiceSpeaker.assistant,
          ),
          isEmpty,
        );
      },
    );

    test('stopAfterSpeaking lets a goodbye finish before hanging up', () async {
      voice.debugStartSimulatedSession(baseInstructions: _base);
      await patientSays('item_1', 'bye');
      assistantReplies('resp_1', 'Take care, and goodbye.');

      final stopping = voice.stopAfterSpeaking();
      await _settle();
      expect(voice.state.isActive, isTrue);

      voice.debugHandleEvent({'type': 'output_audio_buffer.stopped'});
      await stopping;

      expect(voice.state.phase, LiveVoicePhase.closed);
      // Captions of the finished call stay available after it ends.
      expect(voice.state.transcript, isNotEmpty);
    });
  });

  group('resilience', () {
    test('provider errors never end the call', () async {
      voice.debugStartSimulatedSession(baseInstructions: _base);
      await patientSays('item_1', 'Hello');
      expect(voice.state.phase, LiveVoicePhase.thinking);

      voice.debugHandleEvent({
        'type': 'error',
        'error': {
          'type': 'invalid_request_error',
          'code': 'invalid_value',
          'message': 'Unsupported parameter',
        },
      });

      // The failed request goes back to listening instead of hanging.
      expect(voice.state.isActive, isTrue);
      expect(voice.state.phase, LiveVoicePhase.listening);
    });

    test('malformed provider events are ignored', () {
      voice.debugStartSimulatedSession(baseInstructions: _base);

      voice.debugHandleEvent({'type': 'rate_limits.updated'});
      voice.debugHandleEvent({'type': 'something.new'});
      voice.debugHandleEvent({'no_type': true});

      expect(voice.state.phase, LiveVoicePhase.listening);
    });

    test('muting is reflected in state', () async {
      voice.debugStartSimulatedSession(baseInstructions: _base);

      await voice.toggleMute();
      expect(voice.state.isMuted, isTrue);
      expect(voice.isMuted, isTrue);

      await voice.toggleMute();
      expect(voice.state.isMuted, isFalse);
    });
  });

  testWidgets('a call with nobody speaking ends itself after three minutes', (
    tester,
  ) async {
    voice.debugStartSimulatedSession(baseInstructions: _base);

    await tester.pump(const Duration(minutes: 2));
    // Any speech restarts the countdown.
    voice.debugHandleEvent({
      'type': 'input_audio_buffer.speech_started',
      'item_id': 'item_1',
    });
    voice.debugHandleEvent({'type': 'input_audio_buffer.speech_stopped'});
    await tester.pump(const Duration(minutes: 2));
    expect(voice.state.isActive, isTrue);

    await tester.pump(const Duration(minutes: 1, seconds: 5));
    expect(voice.state.phase, LiveVoicePhase.closed);
    expect(voice.lastStopReason, 'idle');
    voice.dispose();
  });

  testWidgets(
    'without audio buffer events, playback end is estimated from the reply',
    (tester) async {
      voice.debugStartSimulatedSession(baseInstructions: _base);
      voice.debugHandleEvent({
        'type': 'input_audio_buffer.speech_started',
        'item_id': 'item_1',
      });
      voice.debugHandleEvent({
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'item_1',
        'transcript': 'Hi',
      });
      await tester.pump();
      voice.debugHandleEvent({
        'type': 'response.created',
        'response': {'id': 'resp_1'},
      });
      voice.debugHandleEvent({
        'type': 'response.output_audio_transcript.delta',
        'response_id': 'resp_1',
        'delta': 'Hello! How can I help you today?',
      });
      voice.debugHandleEvent({
        'type': 'response.done',
        'response': {'id': 'resp_1', 'status': 'completed'},
      });

      expect(voice.state.phase, LiveVoicePhase.speaking);
      await tester.pump(const Duration(seconds: 3));
      expect(voice.state.phase, LiveVoicePhase.listening);
      // Releases the idle countdown before the fake clock is checked.
      voice.dispose();
    },
  );
}
