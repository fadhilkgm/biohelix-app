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

class LiveVoiceUsageUpdate {
  const LiveVoiceUsageUpdate({
    required this.sessionId,
    required this.verifiedSeconds,
    required this.awardedPoints,
    required this.heartbeatIntervalSeconds,
  });

  final String sessionId;
  final int verifiedSeconds;
  final int awardedPoints;
  final int heartbeatIntervalSeconds;

  factory LiveVoiceUsageUpdate.fromJson(Map<String, dynamic> json) {
    return LiveVoiceUsageUpdate(
      sessionId: json['session_id']?.toString() ?? '',
      verifiedSeconds: (json['verified_seconds'] as num?)?.toInt() ?? 0,
      awardedPoints: (json['awarded_points'] as num?)?.toInt() ?? 0,
      heartbeatIntervalSeconds:
          (json['heartbeat_interval_seconds'] as num?)?.toInt() ?? 30,
    );
  }
}

class InworldSignalingApi {
  InworldSignalingApi(this._client);

  final ApiClient _client;
  InworldSessionBootstrap? _cachedBootstrap;
  DateTime? _cachedAt;
  String? _cachedLanguage;
  Future<InworldSessionBootstrap>? _bootstrapInFlight;

  static const _bootstrapCacheTtl = Duration(seconds: 45);

  Future<InworldSessionBootstrap> bootstrap({required String locale}) async {
    final language = locale.toLowerCase().startsWith('ml') ? 'ml' : 'en';
    final cached = _cachedBootstrap;
    final cachedAt = _cachedAt;
    if (cached != null &&
        cachedAt != null &&
        _cachedLanguage == language &&
        DateTime.now().difference(cachedAt) < _bootstrapCacheTtl) {
      return cached;
    }
    final inFlight = _bootstrapInFlight;
    if (inFlight != null) return inFlight;

    final request = _fetchBootstrap(language);
    _bootstrapInFlight = request;
    try {
      final bootstrap = await request;
      _cachedBootstrap = bootstrap;
      _cachedAt = DateTime.now();
      _cachedLanguage = language;
      return bootstrap;
    } finally {
      _bootstrapInFlight = null;
    }
  }

  void invalidateBootstrap() {
    _cachedBootstrap = null;
    _cachedAt = null;
    _cachedLanguage = null;
  }

  Future<InworldSessionBootstrap> _fetchBootstrap(String language) async {
    final responses = await Future.wait([
      _client.getJson('/realtime/ice'),
      _client.getJson(
        '/realtime/session-config',
        queryParameters: {'language': language},
      ),
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

  /// Laravel selects only completed, patient-owned report summaries for this
  /// transcript. Inworld never receives a document tool or raw report file.
  Future<String> responseInstructions({
    required String conversationId,
    required String transcript,
  }) async {
    final response = await _client.postJson(
      '/realtime/context',
      data: {
        'conversation_id': int.tryParse(conversationId) ?? conversationId,
        'transcript': transcript,
      },
    );
    final instructions = response['instructions']?.toString().trim() ?? '';
    if (instructions.isEmpty) {
      throw const FormatException('Voice context response is invalid.');
    }
    return instructions;
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

  Future<LiveVoiceUsageUpdate> startUsage({
    required String conversationId,
  }) async {
    final response = await _client.postJson(
      '/realtime/usage',
      data: {'conversation_id': int.tryParse(conversationId) ?? conversationId},
    );
    final update = LiveVoiceUsageUpdate.fromJson(response);
    if (update.sessionId.isEmpty) {
      throw const FormatException('Voice usage session response is invalid.');
    }
    return update;
  }

  Future<LiveVoiceUsageUpdate> heartbeatUsage(String sessionId) async {
    final response = await _client.postJson(
      '/realtime/usage/$sessionId/heartbeat',
    );
    return LiveVoiceUsageUpdate.fromJson(response);
  }

  Future<LiveVoiceUsageUpdate> finishUsage(String sessionId) async {
    final response = await _client.postJson(
      '/realtime/usage/$sessionId/finish',
    );
    return LiveVoiceUsageUpdate.fromJson(response);
  }
}
