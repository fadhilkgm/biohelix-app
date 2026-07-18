import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'voice_protocol.dart';

class VoiceSessionTicket {
  const VoiceSessionTicket({
    required this.sessionId,
    required this.gatewayUrl,
    required this.ticket,
    this.expiresAt,
    this.limits = const {},
  });

  final String sessionId;
  final String gatewayUrl;
  final String ticket;
  final DateTime? expiresAt;
  final Map<String, dynamic> limits;

  factory VoiceSessionTicket.fromJson(Map<String, dynamic> json) {
    final expiresAt = DateTime.tryParse(
      (json['expires_at'] ?? json['expiresAt'] ?? '').toString(),
    );
    return VoiceSessionTicket(
      sessionId: (json['session_id'] ?? json['sessionId'] ?? '').toString(),
      gatewayUrl: (json['gateway_url'] ?? json['gatewayUrl'] ?? '').toString(),
      ticket: (json['ticket'] ?? '').toString(),
      expiresAt: expiresAt,
      limits: json['limits'] is Map
          ? Map<String, dynamic>.from(json['limits'] as Map)
          : const {},
    );
  }
}

class VoiceGatewayEvent {
  const VoiceGatewayEvent({
    required this.type,
    required this.payload,
    this.audio,
  });

  final String type;
  final Map<String, dynamic> payload;
  final Uint8List? audio;

  String? get sessionId => payload['session_id']?.toString();
  String? get turnId => payload['turn_id']?.toString();
  int? get generation => (payload['generation'] as num?)?.toInt();
  String get text =>
      (payload['text'] ?? payload['transcript'] ?? '').toString();
}

class VoiceGatewayClient {
  VoiceGatewayClient();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _events = StreamController<VoiceGatewayEvent>.broadcast();

  Stream<VoiceGatewayEvent> get events => _events.stream;
  bool get isConnected => _channel != null;

  Future<void> connect(VoiceSessionTicket session) async {
    await disconnect();
    final uri = Uri.tryParse(session.gatewayUrl);
    if (uri == null || !uri.hasScheme || session.sessionId.isEmpty) {
      throw const FormatException('Invalid voice gateway session.');
    }

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    await channel.ready;
    _subscription = channel.stream.listen(
      _handleIncoming,
      onError: (Object error, StackTrace stack) {
        _events.addError(error, stack);
      },
      onDone: () {
        _channel = null;
      },
      cancelOnError: false,
    );

    sendControl(
      VoiceProtocol.control(
        type: VoiceClientEventType.hello,
        sessionId: session.sessionId,
        ticket: session.ticket,
      ),
    );
  }

  void sendControl(Map<String, dynamic> event) {
    final channel = _channel;
    if (channel == null) {
      throw StateError('Voice gateway is not connected.');
    }
    channel.sink.add(jsonEncode(event));
  }

  void sendAudio({
    required String sessionId,
    required String turnId,
    required int sequence,
    required Uint8List pcm16,
  }) {
    final header = jsonEncode({
      'v': VoiceProtocol.version,
      'type': 'audio',
      'session_id': sessionId,
      'turn_id': turnId,
      'sequence': sequence,
      'encoding': 'pcm_s16le',
      'sample_rate': 16000,
      'channels': 1,
      'payload_length': pcm16.length,
    });
    final headerBytes = Uint8List.fromList(utf8.encode(header));
    final frame = Uint8List(4 + headerBytes.length + pcm16.length);
    final view = ByteData.sublistView(frame);
    view.setUint32(0, headerBytes.length);
    frame.setRange(4, 4 + headerBytes.length, headerBytes);
    frame.setRange(4 + headerBytes.length, frame.length, pcm16);
    _channel?.sink.add(frame);
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }

  void _handleIncoming(dynamic value) {
    if (value is Uint8List || value is List<int>) {
      _events.add(
        VoiceGatewayEvent(
          type: 'audio',
          payload: const {},
          audio: Uint8List.fromList(List<int>.from(value as List<int>)),
        ),
      );
      return;
    }

    final payload = VoiceProtocol.decode(value);
    if (payload == null) return;
    final type = payload['type']?.toString() ?? 'unknown';
    final audio = VoiceProtocol.decodeBase64Audio(
      payload['audio'] ??
          payload['audio_base64'] ??
          (payload['data'] is Map
              ? (payload['data'] as Map)['audio']
              : payload['data']),
    );
    _events.add(
      VoiceGatewayEvent(
        type: type,
        payload: payload,
        audio: audio.isEmpty ? null : audio,
      ),
    );
  }
}
