import 'package:biohelix_app/patient_portal/assistant/voice/inworld_signaling_api.dart';
import 'package:biohelix_app/patient_portal/assistant/voice/live_voice_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ICE server accepts both URL list and single URL', () {
    final turn = InworldIceServer.fromJson({
      'urls': ['turn:one', 'turn:two'],
      'username': 'user',
      'credential': 'secret',
    });
    final stun = InworldIceServer.fromJson({'urls': 'stun:one'});

    expect(turn.urls, ['turn:one', 'turn:two']);
    expect(turn.toWebRtcJson(), {
      'urls': ['turn:one', 'turn:two'],
      'username': 'user',
      'credential': 'secret',
    });
    expect(stun.urls, ['stun:one']);
  });

  test('live state exposes legal UI activity flags', () {
    expect(
      const LiveVoiceState(phase: LiveVoicePhase.listening).isListening,
      isTrue,
    );
    expect(
      const LiveVoiceState(phase: LiveVoicePhase.transcribing).isListening,
      isTrue,
    );
    expect(
      const LiveVoiceState(phase: LiveVoicePhase.speaking).isSpeaking,
      isTrue,
    );
    expect(
      const LiveVoiceState(phase: LiveVoicePhase.closed).isActive,
      isFalse,
    );
  });
}
