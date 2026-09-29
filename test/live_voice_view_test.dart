import 'package:biohelix_app/core/config/app_config.dart';
import 'package:biohelix_app/core/network/api_client.dart';
import 'package:biohelix_app/core/providers/language_provider.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/inworld_signaling_api.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/live_voice_controller.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/live_voice_state.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/live_voice_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _RecordingController extends LiveVoiceController {
  _RecordingController(ApiClient client)
    : super(
        signalingApi: InworldSignalingApi(client),
        onTurnCompleted: (_, _) {},
        onTurnContext: (_) async => 'Answer now.',
      );

  final List<Map<String, dynamic>> sent = [];

  @override
  Future<void> sendRealtimeEvent(Map<String, dynamic> event) async {
    sent.add(event);
  }
}

ApiClient _client() => ApiClient(
  config: AppConfig(
    appName: 'Test',
    apiBaseUrl: 'https://example.test/api',
    healthEndpoint: '/health',
    showDevOtp: false,
  ),
);

void main() {
  late _RecordingController voice;
  late int endCount;
  late int retryCount;

  Future<void> pumpView(WidgetTester tester) async {
    final client = _client();
    voice = _RecordingController(client);
    endCount = 0;
    retryCount = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(apiClient: client),
        child: MaterialApp(
          home: LiveVoiceView(
            controller: voice,
            onEnd: () => endCount++,
            onRetry: () => retryCount++,
          ),
        ),
      ),
    );
  }

  /// The orb and call timer animate forever, so tests pump fixed frames and
  /// dispose the tree before finishing.
  Future<void> tearDownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    voice.dispose();
  }

  testWidgets('connecting, then listening with a hint to start talking', (
    tester,
  ) async {
    await pumpView(tester);
    voice.debugStartSimulatedSession(sessionPreconfigured: false);
    await tester.pump();

    expect(find.text('Connecting…'), findsOneWidget);

    voice.debugHandleEvent({'type': 'session.updated', 'session': {}});
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Listening'), findsOneWidget);
    expect(find.text('Go ahead, I’m listening'), findsOneWidget);
    expect(find.byKey(const ValueKey('live_voice_interrupt')), findsNothing);

    await tearDownView(tester);
  });

  testWidgets('mute toggles the microphone and the status', (tester) async {
    await pumpView(tester);
    voice.debugStartSimulatedSession();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('live_voice_mute')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(voice.state.isMuted, isTrue);
    expect(find.text('Microphone off'), findsOneWidget);
    expect(find.text('Unmute'), findsOneWidget);

    await tearDownView(tester);
  });

  testWidgets('while speaking, captions stream and stop interrupts', (
    tester,
  ) async {
    await pumpView(tester);
    voice.debugStartSimulatedSession();
    voice.debugHandleEvent({
      'type': 'input_audio_buffer.speech_started',
      'item_id': 'item_1',
    });
    voice.debugHandleEvent({
      'type': 'conversation.item.input_audio_transcription.completed',
      'item_id': 'item_1',
      'transcript': 'Is my sugar normal?',
    });
    await tester.pump();
    voice.debugHandleEvent({
      'type': 'response.created',
      'response': {'id': 'resp_1'},
    });
    voice.debugHandleEvent({'type': 'output_audio_buffer.started'});
    voice.debugHandleEvent({
      'type': 'response.output_audio_transcript.delta',
      'response_id': 'resp_1',
      'delta': 'Your fasting sugar is in the normal range.',
    });
    // One frame starts the Stop button's entrance, the next finishes it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Speaking'), findsOneWidget);
    expect(find.text('Is my sugar normal?'), findsOneWidget);
    expect(
      find.text('Your fasting sugar is in the normal range.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('live_voice_interrupt')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(voice.state.phase, LiveVoicePhase.listening);
    expect(
      voice.sent.map((event) => event['type']),
      contains('response.cancel'),
    );

    await tearDownView(tester);
  });

  testWidgets('captions can be hidden', (tester) async {
    await pumpView(tester);
    voice.debugStartSimulatedSession();
    voice.debugHandleEvent({
      'type': 'conversation.item.input_audio_transcription.completed',
      'item_id': 'item_1',
      'transcript': 'Hello there',
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hello there'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('live_voice_captions_toggle')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hello there'), findsNothing);

    await tearDownView(tester);
  });

  testWidgets('end button ends the call', (tester) async {
    await pumpView(tester);
    voice.debugStartSimulatedSession();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('live_voice_end')));
    await tester.pump();

    expect(endCount, 1);

    await tearDownView(tester);
  });

  testWidgets('an error explains itself and offers a retry', (tester) async {
    await pumpView(tester);
    voice.debugStartSimulatedSession();
    await tester.pump();

    voice.debugFail('Could not reach the voice service.');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Voice chat unavailable'), findsOneWidget);
    expect(find.text('Could not reach the voice service.'), findsOneWidget);
    expect(find.byKey(const ValueKey('live_voice_mute')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('live_voice_retry')));
    await tester.pump();
    expect(retryCount, 1);

    await tester.tap(find.byKey(const ValueKey('live_voice_close')));
    await tester.pump();
    expect(endCount, 1);

    await tearDownView(tester);
  });
}
