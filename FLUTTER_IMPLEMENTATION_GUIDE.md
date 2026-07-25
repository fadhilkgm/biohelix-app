# Flutter + Laravel Realtime Voice, Document Chat, and Random Chat Implementation Guide

## 1. Goal

Build a Flutter application with three conversation modes:

1. **Realtime voice AI** — continuous English or Malayalam speech-to-speech using Inworld WebRTC.
2. **Document chat** — upload PDFs/documents and ask grounded questions using retrieval-augmented generation (RAG).
3. **Random AI chat** — start a conversation with a randomly selected topic, personality, or scenario.

This guide uses the existing web application as the behavior reference. The existing Laravel application is the authoritative backend and PostgreSQL is the system of record. Cloudflare may remain in front of the Laravel API as DNS/CDN/WAF, but a Worker is not required for the application logic.

## 2. Recommended architecture

```text
Flutter app
├── Login and user interface
├── flutter_webrtc
│   ├── microphone audio ───────────────► Inworld Realtime API
│   ├── remote AI audio ◄─────────────── Inworld Realtime API
│   └── oai-events data channel ◄──────► Inworld Realtime API
├── REST API ───────────────────────────► Laravel API
│   ├── authentication and authorization
│   ├── Inworld ICE and SDP proxy
│   ├── document upload authorization
│   ├── document search/RAG
│   └── random session configuration
└── local secure storage
    └── user session token only; no provider secrets

Laravel backend
├── Sanctum/mobile authentication
├── Inworld signaling service
├── PostgreSQL: users, preferences, chats, documents, chunks, embeddings
├── pgvector: document similarity search
├── Laravel Storage: private local/S3-compatible document objects
├── Redis/database queue: extraction and indexing jobs
└── .env/server secret manager: provider credentials
```

Laravel participates only in WebRTC setup. Once connected, realtime audio normally travels directly between the phone and Inworld. This preserves low latency and avoids relaying every audio packet through the VPS.

## 3. Important security decision

### Do not encrypt a permanent API key and send it to Flutter

That design is not secure. If the Flutter application can decrypt a provider key, a user can inspect the application, hook the decryption method, inspect process memory, or capture the outgoing request and recover the key. Obfuscation or a key stored in Android Keystore/iOS Keychain does not make a shared provider credential safe.

Use this design instead:

- Store `INWORLD_API_KEY` only in Laravel's server environment or deployment secret manager.
- Authenticate the Flutter user with a short-lived application access token.
- Let the backend call Inworld's ICE and SDP endpoints.
- Return only ICE server configuration and the SDP answer to Flutter.
- If a provider later offers scoped, short-lived ephemeral client tokens, the backend may issue those instead. They should expire within minutes and be limited to one session.
- Store only the user's refresh/access tokens in Keychain or Keystore.
- Use HTTPS/TLS for all app-to-backend traffic. Do not invent custom payload encryption on top of TLS.

For production, inject the value into the Laravel process environment and cache configuration after deployment:

```sh
php artisan config:cache
```

## 4. Backend environment variables

Keep secrets out of source control.

```dotenv
INWORLD_API_KEY=base64_inworld_api_key
INWORLD_BASE_URL=https://api.inworld.ai
INWORLD_LLM_MODEL=google-ai-studio/gemini-2.5-flash-lite
INWORLD_ENGLISH_STT_MODEL=assemblyai/u3-rt-pro
INWORLD_MALAYALAM_STT_MODEL=soniox/stt-rt-v4
INWORLD_TTS_MODEL=inworld-tts-2
INWORLD_VOICE=Sarah
DOCUMENT_LLM_API_KEY=optional_server_only_key
QUEUE_CONNECTION=redis
FILESYSTEM_DISK=s3
AWS_ACCESS_KEY_ID=private_object_storage_key
AWS_SECRET_ACCESS_KEY=private_object_storage_secret
AWS_BUCKET=private_documents_bucket
```

Expose the settings through `config/services.php`, never with direct `env()` calls outside configuration files:

```php
'inworld' => [
    'key' => env('INWORLD_API_KEY'),
    'base_url' => env('INWORLD_BASE_URL', 'https://api.inworld.ai'),
    'llm' => env('INWORLD_LLM_MODEL', 'google-ai-studio/gemini-2.5-flash-lite'),
    'english_stt' => env('INWORLD_ENGLISH_STT_MODEL', 'assemblyai/u3-rt-pro'),
    'malayalam_stt' => env('INWORLD_MALAYALAM_STT_MODEL', 'soniox/stt-rt-v4'),
    'tts' => env('INWORLD_TTS_MODEL', 'inworld-tts-2'),
    'voice' => env('INWORLD_VOICE', 'Sarah'),
],
```

Do not return these secrets from a `/config` endpoint. Public model names and UI settings may be returned, but provider credentials must remain private.

## 5. Backend API contract

All endpoints except login/registration should use the existing Laravel authentication. For a first-party Flutter client, Sanctum API tokens are a straightforward option; send them as `Authorization: Bearer ...` and store them in platform secure storage. See [Laravel Sanctum mobile authentication](https://laravel.com/docs/10.x/sanctum#mobile-application-authentication).

### User language preference

```text
GET   /v1/me/preferences
PATCH /v1/me/preferences
```

```json
{
  "language": "en"
}
```

Accept only `en` or `ml`. Flutter should show this choice during onboarding and in Settings. A conversation captures the language when it starts; changing the preference affects new sessions, not an already connected WebRTC call.

### Realtime voice

```text
GET  /v1/realtime/ice
POST /v1/realtime/calls
GET  /v1/realtime/session-config
POST /v1/realtime/tool-results
```

`GET /v1/realtime/ice` returns:

```json
{
  "ice_servers": [
    { "urls": ["stun:example"] },
    {
      "urls": ["turn:example"],
      "username": "temporary-user",
      "credential": "temporary-credential"
    }
  ]
}
```

`POST /v1/realtime/calls` accepts `Content-Type: application/sdp` and the WebRTC offer as its body. Laravel forwards it to Inworld's `POST /v1/realtime/calls` using `Http::withToken(config('services.inworld.key'))`, then returns the SDP answer.

`GET /v1/realtime/session-config` reads the authenticated user's `preferred_language` and returns a safe, credential-free session configuration. Do not accept a client-provided model name. The user may change language through a validated preference endpoint, but Laravel maps `en` and `ml` to allow-listed prompts and STT models.

Apply per-user and per-IP rate limits to both endpoints. Validate the request size, SDP prefix, authentication, account state, plan limits, and allowed origin/app version.

Laravel route and controller sketch:

```php
Route::middleware(['auth:sanctum', 'throttle:realtime'])->group(function () {
    Route::get('/v1/realtime/ice', [RealtimeController::class, 'ice']);
    Route::post('/v1/realtime/calls', [RealtimeController::class, 'createCall']);
    Route::get('/v1/realtime/session-config', [RealtimeController::class, 'sessionConfig']);
});

final class RealtimeController
{
    public function ice()
    {
        $upstream = Http::withToken(config('services.inworld.key'))
            ->timeout(10)
            ->get(config('services.inworld.base_url').'/v1/realtime/ice-servers')
            ->throw();

        return response()->json($upstream->json());
    }

    public function createCall(Request $request)
    {
        abort_unless(str_starts_with((string) $request->header('Content-Type'), 'application/sdp'), 415);
        $sdp = $request->getContent();
        abort_unless(str_starts_with($sdp, 'v=0') && strlen($sdp) <= 100_000, 422);

        $upstream = Http::withToken(config('services.inworld.key'))
            ->withBody($sdp, 'application/sdp')
            ->timeout(15)
            ->post(config('services.inworld.base_url').'/v1/realtime/calls')
            ->throw();

        return response($upstream->body(), $upstream->status())
            ->header('Content-Type', 'application/sdp')
            ->header('Cache-Control', 'no-store');
    }
}
```

In production, return only a normalized error body to Flutter and never forward upstream headers or diagnostic bodies blindly. Adapt the response conversion to the Laravel version used by the existing backend.

### Documents

```text
POST   /v1/documents/upload-url
POST   /v1/documents/:id/complete
GET    /v1/documents
GET    /v1/documents/:id
DELETE /v1/documents/:id
POST   /v1/documents/search
POST   /v1/document-chat/messages
```

Suggested upload request:

```json
{
  "filename": "policy.pdf",
  "content_type": "application/pdf",
  "size": 248123
}
```

Suggested response:

```json
{
  "document_id": "doc_01...",
  "upload_url": "short-lived-private-storage-upload-url",
  "expires_at": "2026-07-22T12:05:00Z"
}
```

Laravel can generate a short-lived direct upload URL when the configured disk supports `Storage::temporaryUploadUrl()`. Otherwise, accept a normal authenticated multipart upload through Laravel. Treat temporary URLs as bearer tokens and validate file type, actual MIME, size, and ownership again during processing. See [Laravel temporary upload URLs](https://laravel.com/docs/10.x/filesystem#temporary-upload-urls).

### Random AI chat

```text
POST /v1/random-sessions
GET  /v1/random-sessions/:id
```

Request:

```json
{
  "language": "ml",
  "category": "any",
  "difficulty": "casual"
}
```

Response:

```json
{
  "session_id": "rnd_01...",
  "title": "ഒരു യാത്രാ സംഭാഷണം",
  "opening_prompt": "കേരളത്തിലെ ഒരു യാത്രയെക്കുറിച്ച് സൗഹൃദപരമായി സംസാരിക്കുക.",
  "voice": "Sarah"
}
```

`language` must be `en` or `ml`; default it from the user's saved preference. Select localized prompts on the backend from an allow-listed catalog. Do not allow arbitrary hidden system prompts from one user to affect another user's session.

## 6. Language preference and Inworld session configuration

Persist the user's default language in PostgreSQL:

```php
Schema::table('users', function (Blueprint $table) {
    $table->string('preferred_language', 2)->default('en');
});
```

Validate updates with `Rule::in(['en', 'ml'])`. Copy the selected language into each conversation so changing a profile preference does not alter old conversations.

Use this backend mapping:

| Preference | STT model | STT language | Assistant language |
| --- | --- | --- | --- |
| `en` | `assemblyai/u3-rt-pro` | `en` | English |
| `ml` | `soniox/stt-rt-v4` | `ml` | Malayalam |

Example Laravel service logic:

```php
public function sessionConfig(User $user): array
{
    $language = in_array($user->preferred_language, ['en', 'ml'], true)
        ? $user->preferred_language
        : 'en';

    $malayalam = $language === 'ml';

    return [
        'type' => 'session.update',
        'session' => [
            'type' => 'realtime',
            'model' => config('services.inworld.llm'),
            'instructions' => $malayalam
                ? "You are a helpful Malayalam conversational assistant. Understand the user's Malayalam speech and answer its meaning. Never repeat, transcribe, paraphrase, or translate what the user said. Reply in Malayalam using one short spoken line."
                : "You are a helpful English conversational assistant. Understand the user's speech and answer its meaning. Never repeat, transcribe, paraphrase, or translate what the user said. Reply in English using one short spoken line.",
            'output_modalities' => ['audio', 'text'],
            'max_output_tokens' => 100,
            'audio' => [
                'input' => [
                    'transcription' => [
                        'model' => $malayalam
                            ? config('services.inworld.malayalam_stt')
                            : config('services.inworld.english_stt'),
                        'language' => $language,
                    ],
                    'turn_detection' => [
                        'type' => 'semantic_vad',
                        'eagerness' => 'low',
                        'create_response' => true,
                        'interrupt_response' => true,
                    ],
                ],
                'output' => [
                    'model' => config('services.inworld.tts'),
                    'voice' => config('services.inworld.voice'),
                    'speed' => 1.0,
                ],
            ],
        ],
    ];
}
```

Flutter fetches this safe configuration before connecting. Create a data channel named `oai-events` and send the returned object after it opens. A Malayalam response resembles:

```json
{
  "type": "session.update",
  "session": {
    "type": "realtime",
    "model": "google-ai-studio/gemini-2.5-flash-lite",
    "instructions": "You are a helpful Malayalam conversational assistant. Understand the user's Malayalam speech and answer its meaning. Never repeat, transcribe, paraphrase, or translate what the user said. Reply in Malayalam using one short spoken line.",
    "output_modalities": ["audio", "text"],
    "max_output_tokens": 100,
    "audio": {
      "input": {
        "transcription": {
          "model": "soniox/stt-rt-v4",
          "language": "ml"
        },
        "turn_detection": {
          "type": "semantic_vad",
          "eagerness": "low",
          "create_response": true,
          "interrupt_response": true
        }
      },
      "output": {
        "model": "inworld-tts-2",
        "voice": "Sarah",
        "speed": 1.0
    }
  }
}
```

Inworld's WebRTC API uses `POST /v1/realtime/calls`, `GET /v1/realtime/ice-servers`, and an `oai-events` data channel. See the [Inworld WebRTC guide](https://dev.docs.inworld.ai/realtime/connect/webrtc). Soniox lists Malayalam (`ml`) as supported for realtime STT; see [Soniox supported languages](https://soniox.com/docs/stt/concepts/supported-languages).

## 7. Flutter project structure

```text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme.dart
├── core/
│   ├── auth/
│   ├── network/
│   ├── secure_storage/
│   └── errors/
├── features/
│   ├── voice_chat/
│   │   ├── data/inworld_signaling_api.dart
│   │   ├── domain/voice_event.dart
│   │   ├── domain/voice_session_state.dart
│   │   ├── presentation/voice_chat_page.dart
│   │   └── services/realtime_voice_session.dart
│   ├── document_chat/
│   │   ├── data/document_api.dart
│   │   ├── presentation/document_list_page.dart
│   │   ├── presentation/document_chat_page.dart
│   │   └── services/document_uploader.dart
│   └── random_chat/
│       ├── data/random_chat_api.dart
│       └── presentation/random_chat_page.dart
└── main.dart
```

Recommended packages:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_webrtc: any
  dio: any
  flutter_riverpod: any
  go_router: any
  flutter_secure_storage: any
  permission_handler: any
  freezed_annotation: any
  json_annotation: any
  uuid: any
```

Pin versions after testing rather than leaving `any`. `flutter_webrtc` supports audio tracks and data channels on iOS and Android; consult its current [package documentation](https://pub.dev/packages/flutter_webrtc) before pinning.

## 8. Flutter WebRTC implementation sketch

The method names below follow the common `flutter_webrtc` API but should be checked against the version pinned by the app.

```dart
class RealtimeVoiceSession {
  RTCPeerConnection? _peer;
  RTCDataChannel? _events;
  MediaStream? _microphone;

  Future<void> connect() async {
    final sessionUpdate = await signalingApi.getSessionConfig();
    final ice = await signalingApi.getIceServers();

    _peer = await createPeerConnection({
      'iceServers': ice.map((server) => server.toJson()).toList(),
      'sdpSemantics': 'unified-plan',
    });

    _microphone = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });

    for (final track in _microphone!.getAudioTracks()) {
      await _peer!.addTrack(track, _microphone!);
    }

    _peer!.onTrack = (event) {
      // Native WebRTC normally routes the received audio automatically.
      // Configure speaker/Bluetooth routing with flutter_webrtc helpers.
    };

    _events = await _peer!.createDataChannel(
      'oai-events',
      RTCDataChannelInit()..ordered = true,
    );
    _events!.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _events!.send(RTCDataChannelMessage(jsonEncode(sessionUpdate)));
      }
    };
    _events!.onMessage = (message) {
      final event = jsonDecode(message.text) as Map<String, dynamic>;
      eventController.add(VoiceEvent.fromJson(event));
    };

    final offer = await _peer!.createOffer({'offerToReceiveAudio': true});
    await _peer!.setLocalDescription(offer);
    await waitForIceGatheringToComplete(_peer!);

    final local = await _peer!.getLocalDescription();
    final answerSdp = await signalingApi.createCall(local!.sdp!);
    await _peer!.setRemoteDescription(
      RTCSessionDescription(answerSdp, 'answer'),
    );
  }

  Future<void> disconnect() async {
    await _events?.close();
    for (final track in _microphone?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    await _microphone?.dispose();
    await _peer?.close();
    _events = null;
    _microphone = null;
    _peer = null;
  }
}
```

Do not use `MediaRecorder`, manually split speech, or upload audio files for this mode. WebRTC continuously transports audio, while Inworld performs semantic turn detection.

## 9. Event handling and UI state

Map realtime events to one state machine:

```text
idle
  └── connect tapped → connecting
connecting
  ├── session.updated → listening
  └── failure → error
listening
  └── input_audio_buffer.speech_stopped → thinking
thinking
  └── response audio/transcript starts → speaking
speaking
  ├── user starts talking → listening (barge-in)
  └── response.done → listening
any state
  └── end call → idle
```

Handle at least these event families:

- `session.updated`
- `input_audio_buffer.speech_started`
- `input_audio_buffer.speech_stopped`
- `conversation.item.input_audio_transcription.delta`
- `conversation.item.input_audio_transcription.completed`
- `response.output_audio_transcript.delta`
- `response.output_text.delta`
- `response.done`
- `response.function_call_arguments.done`
- `error`

Keep partial transcript text separate from final transcript text. Key messages by item/response ID so deltas from different turns are not concatenated.

## 10. Mobile audio behavior

### Android

- Request `RECORD_AUDIO` permission at runtime.
- Declare microphone permission in `AndroidManifest.xml`.
- Configure audio focus for voice communication.
- Test Bluetooth headset, wired headset, speaker, and earpiece routes.
- Stop tracks when the app is backgrounded unless background-call behavior is intentionally supported.

### iOS

- Add `NSMicrophoneUsageDescription` to `Info.plist`.
- Configure `AVAudioSession` for play-and-record/voice chat through the WebRTC package.
- Test silent mode, interruptions, Bluetooth, incoming calls, and route changes.
- Enable background audio only if the product truly needs calls to continue in the background and the App Store use case permits it.

On both platforms, listen for lifecycle changes and network transitions. Reconnect with bounded exponential backoff, but create a new Inworld call after a failed peer connection rather than reusing a closed one.

## 11. Document chat pipeline

### Upload and indexing

1. Flutter requests a short-lived upload URL or starts an authenticated multipart upload.
2. The backend verifies account quota, MIME type, extension, and declared size.
3. Flutter uploads to a private Laravel Storage key such as `users/{userId}/documents/{documentId}/source.pdf`.
4. Flutter calls `/complete`.
5. Laravel dispatches an `IndexDocument` job after the database transaction commits.
6. A Laravel queue worker extracts text, scans/validates the file, and normalizes Unicode.
7. Split text into overlapping chunks, for example 500–900 tokens with 10–15% overlap.
8. Generate embeddings and write chunks plus vectors to PostgreSQL/pgvector with `user_id`, `document_id`, page, and chunk number.
9. Store document and processing status in PostgreSQL; keep original files private through Laravel Storage.
10. Mark the document `ready` or `failed`.

Never trust document IDs or metadata filters supplied by Flutter. Laravel policies/scopes must add the authenticated `user_id` constraint before every pgvector query.

### Text document chat

1. Save the user message.
2. Embed the question.
3. Retrieve top matching chunks filtered to authorized document IDs.
4. Optionally rerank results.
5. Ask the LLM to answer only from retrieved context.
6. Stream the response to Flutter using Server-Sent Events or a normal chunked HTTP response.
7. Return citations containing document ID, page number, and chunk ID.
8. Store the final answer and citations.

### Voice questions about documents

Add a realtime function tool named `search_documents` to the Inworld session. When the model emits `response.function_call_arguments.done`:

1. Flutter sends the query and selected document IDs to the authenticated backend.
2. The backend validates ownership and performs vector search.
3. Flutter returns the backend result through `conversation.item.create` as a function-call output.
4. Flutter sends `response.create` so the voice agent speaks the grounded answer.

Do not download all document text into the mobile application or place an entire document in the system prompt.

Use Laravel queued jobs for extraction and embedding so HTTP requests stay short; see [Laravel queues](https://laravel.com/docs/12.x/queues). PostgreSQL's [pgvector extension](https://github.com/pgvector/pgvector) supports cosine distance and approximate HNSW/IVFFlat indexes while keeping authorization metadata and vectors in the same database.

## 12. Suggested data model

```sql
CREATE TABLE users (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  preferred_language VARCHAR(2) NOT NULL DEFAULT 'en'
);

CREATE TABLE conversations (
  id UUID PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mode VARCHAR(20) NOT NULL, -- voice, document, random
  language VARCHAR(2) NOT NULL,
  title TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE messages (
  id UUID PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL,
  content TEXT NOT NULL,
  citations_json JSONB,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE documents (
  id UUID PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  filename TEXT NOT NULL,
  content_type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  storage_disk VARCHAR(50) NOT NULL,
  storage_path TEXT NOT NULL,
  status VARCHAR(20) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE document_chunks (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  page_number INTEGER,
  chunk_index INTEGER NOT NULL,
  content TEXT NOT NULL,
  embedding VECTOR(EMBEDDING_DIMENSIONS) NOT NULL
);

CREATE INDEX idx_conversations_user ON conversations(user_id, updated_at);
CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at);
CREATE INDEX idx_documents_user ON documents(user_id, created_at);
CREATE INDEX idx_chunks_document ON document_chunks(document_id, chunk_index);
```

Replace `EMBEDDING_DIMENSIONS` with the exact output dimension of the selected embedding model and never change that model silently. Add an HNSW cosine index after representative data-volume testing. Use Laravel migrations for the real schema and policies/queries for every ownership check.

## 13. Random chat design

Maintain a server-side catalog:

```php
$scenarios = [
    [
        'id' => 'travel-friend-ml',
        'language' => 'ml',
        'title' => 'യാത്രാസുഹൃത്ത്',
        'instructions' => 'Discuss travel naturally in Malayalam and ask one relevant follow-up question.',
    ],
    [
        'id' => 'travel-friend-en',
        'language' => 'en',
        'title' => 'Travel companion',
        'instructions' => 'Discuss travel naturally in English and ask one relevant follow-up question.',
    ],
];
```

Laravel filters scenarios by the user's chosen language, randomly selects an eligible scenario, records its ID, and returns the public title plus session instructions. Add category filters, repetition avoidance, safety rules, age restrictions, and analytics without exposing secrets.

### If “random chat” means matching two human strangers

That is a separate product feature. Use:

- Redis atomic operations/locks plus Laravel broadcasting for matchmaking queues and presence.
- A managed WebRTC SFU such as LiveKit, Cloudflare RealtimeKit, or another provider for human audio rooms.
- Blocking, reporting, moderation, age gates, abuse detection, and rapid disconnect controls.
- No Inworld provider key in the peer clients.

Do not use the AI signaling endpoints to connect two human users. Human-to-human random matching has substantially greater safety, moderation, privacy, and legal requirements.

## 14. Authentication and abuse prevention

- Use short-lived access tokens and rotating refresh tokens.
- Bind refresh tokens to a device record and support revocation.
- Store mobile tokens with `flutter_secure_storage`.
- Apply per-user concurrent-call limits.
- Rate-limit call setup, document uploads, vector searches, and LLM requests.
- Enforce file count, page count, byte, token, and daily-cost quotas.
- Use idempotency keys for session creation and upload completion.
- Log request IDs, user IDs, provider latency, model usage, and errors—but never raw API keys or private document contents.
- Redact SDP and TURN credentials from application logs.
- Add App Attest/Play Integrity as an extra abuse signal, not as the only authentication control.
- Define retention and deletion policies for audio transcripts, chats, vectors, and source documents.

## 15. Reliability and latency

Measure these separately:

- ICE request latency
- SDP negotiation latency
- time to peer connection
- speech-end detection latency
- final transcript latency
- LLM first-token latency
- TTS first-audio latency
- end-to-end speech-stop to first-audio latency

Recommended behavior:

- Fetch ICE only when starting a call; do not cache temporary TURN credentials indefinitely.
- Set a timeout on ICE gathering and SDP calls.
- Prefer direct WebRTC audio rather than proxying audio through Laravel.
- Show `connecting`, `listening`, `thinking`, and `speaking` states.
- Permit barge-in and let Inworld cancel the current response.
- Reconnect only transient failures; surface authentication/configuration failures immediately.
- Cancel background document work when a document is deleted.
- Use Laravel queues so large document processing does not block an HTTP request.

## 16. Testing plan

### Unit tests

- Realtime event reducer/state machine.
- Transcript delta aggregation by item ID.
- API error mapping.
- Authentication and ownership policies.
- Chunking and citation construction.
- Random scenario filtering.

### Integration tests

- ICE and SDP proxy with provider responses mocked.
- Invalid/oversized SDP rejection.
- Expired and revoked user token rejection.
- Upload URL restricted to one private storage object.
- PostgreSQL/pgvector search cannot access another user's chunks.
- Tool call result is returned to the correct realtime call.

### Device tests

- English and Malayalam speakers across the target accents.
- Malayalam mixed with English names and technical terms.
- Quiet room, fan noise, traffic noise, and weak microphone.
- Long pauses to confirm low-eagerness semantic VAD does not cut speech.
- User interruption while Sarah is speaking.
- Wi-Fi to mobile-data transition.
- Bluetooth connect/disconnect during a call.
- Screen lock, background, incoming phone call, and audio focus changes.
- Slow and lossy networks.

Build consented English and Malayalam evaluation sets and measure word error rate separately instead of judging only a few manual examples.

## 17. Delivery phases

### Phase 1 — voice foundation

- Authentication
- Flutter WebRTC connection
- per-user English/Malayalam preference and STT routing
- Gemini Flash Lite conversation
- Sarah TTS
- transcript UI and call controls
- usage limits and basic observability

### Phase 2 — document chat

- private Laravel Storage uploads
- background extraction/indexing
- PostgreSQL/pgvector search
- text chat with citations
- document deletion and retention controls

### Phase 3 — voice + documents

- `search_documents` realtime tool
- spoken grounded answers
- citation display alongside the call

### Phase 4 — random mode

- safe scenario catalog
- backend selection and repetition control
- topic filters and analytics

### Phase 5 — production hardening

- subscription/quotas
- rate limiting and abuse controls
- device matrix testing
- privacy policy and account deletion
- alerting, dashboards, cost limits, and incident runbooks

## 18. Definition of done

The first production release is ready when:

- No permanent provider credential is present in the Flutter binary, network responses, logs, or remote configuration.
- English and Malayalam speech are each transcribed acceptably across their target device/accent test sets.
- WebRTC reconnect/disconnect behavior is predictable.
- Users can interrupt the AI naturally.
- Documents are private by default and every retrieval query is ownership-filtered.
- Document answers include verifiable citations.
- Deleted documents are removed from Laravel Storage and their PostgreSQL/pgvector rows are deleted.
- Random prompts come from an approved catalog.
- Authentication, quotas, rate limits, monitoring, and provider cost alerts are active.

## 19. Existing web reference

The current React implementation can be used as a protocol reference:

- Flutter should reproduce the flow in `src/client/useVoiceSession.ts`.
- Port the two signaling operations from `src/worker/index.ts` into Laravel controllers/services using Laravel's HTTP client.
- Laravel owns authentication, language preferences, quotas, document APIs, queues, and PostgreSQL/pgvector retrieval.
- The API key remains a Laravel server secret; the mobile application receives only signaling results and safe session configuration.
