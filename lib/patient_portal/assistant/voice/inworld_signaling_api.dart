import '../../../core/network/api_client.dart';

class InworldIceServer {
  const InworldIceServer({required this.urls, this.username, this.credential});

  final List<String> urls;
  final String? username;
  final String? credential;

  factory InworldIceServer.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['urls'];
    final urls = rawUrls is List
        ? rawUrls.map((value) => value.toString()).toList()
        : <String>[if (rawUrls != null) rawUrls.toString()];
    return InworldIceServer(
      urls: urls,
      username: json['username']?.toString(),
      credential: json['credential']?.toString(),
    );
  }

  Map<String, dynamic> toWebRtcJson() => {
    'urls': urls,
    if ((username ?? '').isNotEmpty) 'username': username,
    if ((credential ?? '').isNotEmpty) 'credential': credential,
  };
}

class InworldSessionBootstrap {
  const InworldSessionBootstrap({
    required this.iceServers,
    required this.sessionUpdate,
  });

  final List<InworldIceServer> iceServers;
  final Map<String, dynamic> sessionUpdate;
}

class InworldSignalingApi {
  const InworldSignalingApi(this._client);

  final ApiClient _client;

  Future<InworldSessionBootstrap> bootstrap() async {
    final responses = await Future.wait([
      _client.getJson('/realtime/ice'),
      _client.getJson('/realtime/session-config'),
    ]);
    final rawIce = responses[0]['ice_servers'] as List<dynamic>? ?? const [];
    final sessionUpdate = Map<String, dynamic>.from(responses[1]);
    if (sessionUpdate['type'] != 'session.update' ||
        sessionUpdate['session'] is! Map) {
      throw const FormatException('Realtime session configuration is invalid.');
    }
    return InworldSessionBootstrap(
      iceServers: rawIce
          .whereType<Map>()
          .map(
            (value) =>
                InworldIceServer.fromJson(Map<String, dynamic>.from(value)),
          )
          .where((server) => server.urls.isNotEmpty)
          .toList(),
      sessionUpdate: sessionUpdate,
    );
  }

  Future<String> createCall(String offerSdp) async {
    final answer = await _client.postSdp('/realtime/calls', sdp: offerSdp);
    if (!answer.trimLeft().startsWith('v=0')) {
      throw const FormatException('Realtime server returned an invalid SDP.');
    }
    return answer;
  }

  Future<void> persistTurn({
    required String conversationId,
    required String transcript,
    required String response,
    required String idempotencyKey,
  }) async {
    await _client.postJson(
      '/realtime/turns',
      data: {
        'conversation_id': conversationId,
        'transcript': transcript,
        'response': response,
        'idempotency_key': idempotencyKey,
      },
    );
  }
}
