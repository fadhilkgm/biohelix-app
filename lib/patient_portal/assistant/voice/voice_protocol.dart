import 'dart:convert';
import 'dart:typed_data';

enum VoiceClientEventType {
  hello,
  audioStart,
  audioCommit,
  responseCancel,
  sessionEnd,
  ping,
}

class VoiceProtocol {
  const VoiceProtocol._();

  static const version = 'bh-voice.v1';

  static Map<String, dynamic> control({
    required VoiceClientEventType type,
    required String sessionId,
    String? ticket,
    String? turnId,
    int? generation,
    Map<String, dynamic> data = const {},
  }) {
    final event = switch (type) {
      VoiceClientEventType.hello => 'hello',
      VoiceClientEventType.audioStart => 'audio.start',
      VoiceClientEventType.audioCommit => 'audio.commit',
      VoiceClientEventType.responseCancel => 'response.cancel',
      VoiceClientEventType.sessionEnd => 'session.end',
      VoiceClientEventType.ping => 'ping',
    };

    return {
      'v': version,
      'type': event,
      'session_id': sessionId,
      if (ticket != null) 'ticket': ticket,
      if (turnId != null) 'turn_id': turnId,
      if (generation != null) 'generation': generation,
      ...data,
    };
  }

  static String encode(Map<String, dynamic> event) => jsonEncode(event);

  static Map<String, dynamic>? decode(Object? value) {
    if (value is! String) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  static Uint8List decodeBase64Audio(dynamic value) {
    if (value is! String || value.isEmpty) return Uint8List(0);
    try {
      return Uint8List.fromList(base64Decode(value));
    } catch (_) {
      return Uint8List(0);
    }
  }
}
