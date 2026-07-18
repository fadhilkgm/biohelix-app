# BHRC live voice: backend and VPS handoff

## Purpose

This document explains the live voice path implemented for the BioHelix Flutter app and the Laravel/VPS work required to run it safely.

The target experience is a turn-oriented realtime conversation:

```text
Patient speaks
  -> Flutter captures mono PCM16 audio
  -> WSS voice gateway receives small audio frames
  -> Sarvam streaming STT returns transcript updates
  -> Laravel runs the clinical safety gate and existing AI chat context
  -> Sarvam streaming TTS returns audio chunks
  -> Flutter starts speaking before the complete answer is finished
  -> Patient can interrupt and start another turn
```

This is not a normal HTTP voice upload. The existing HTTP endpoint remains the push-to-talk fallback.

## What changed in this repository

### Flutter app

Added:

- `lib/patient_portal/assistant/voice/live_voice_controller.dart`
- `lib/patient_portal/assistant/voice/live_voice_state.dart`
- `lib/patient_portal/assistant/voice/voice_gateway_client.dart`
- `lib/patient_portal/assistant/voice/voice_protocol.dart`
- `lib/patient_portal/assistant/voice/microphone_stream.dart`
- `lib/patient_portal/assistant/voice/streaming_audio_player.dart`

Updated:

- `patient_assistant_tab.dart` wires the live stage to `LiveVoiceController`.
- `patient_assistant_helpers.dart` starts/stops the realtime controller for live mode.
- `patient_portal_provider_chat.dart` reconciles finalized live turns into the chat history.
- `pubspec.yaml` adds `web_socket_channel` and `flutter_soloud`.

The Flutter client:

- Requests microphone permission.
- Captures mono PCM16 at 16 kHz with echo cancellation and noise suppression requested.
- Sends binary WebSocket frames.
- Uses a 4-byte big-endian header length followed by a JSON header and PCM payload.
- Displays partial/final transcript and streamed response text.
- Plays streamed PCM16 TTS chunks.
- Cancels the current generation on interruption.
- Rejects stale events by session/generation.

### Laravel API

Added:

- `ai_voice_sessions` migration.
- `AIVoiceSession` model.
- `VoiceSessionController`.
- `VoiceSessionTicketService`.
- `VoiceSafetyPolicyService`.

Added authenticated endpoint:

```http
POST /api/v1/patients/chat/global/threads/{conversation}/voice-sessions
Authorization: Bearer <sanctum-token>
Content-Type: application/json

{
  "locale": "en-IN",
  "protocol": "bh-voice.v1",
  "device_id": "opaque-device-id"
}
```

Response:

```json
{
  "session": {
    "session_id": "uuid",
    "gateway_url": "wss://voice.example.com",
    "ticket": "base64-payload.hmac-sha256",
    "expires_at": "2026-07-19T00:15:00Z",
    "ticket_expires_at": "2026-07-19T00:01:00Z",
    "limits": {
      "max_utterance_seconds": 60,
      "max_session_seconds": 900,
      "max_turns": 30
    }
  }
}
```

The ticket is short-lived, scoped to one session, signed by Laravel, and sent in the first WebSocket `hello` frame. It must not be put in the WebSocket URL.

The old `/patients/chat/voice-config` response no longer returns provider credentials. It reports a server-side provider only. Flutter must not call Sarvam, Replicate, Gemini, or any other provider directly.

### VPS gateway

Added:

```text
BHRC-Hospital/voice-gateway/
  src/index.ts
  src/protocol.ts
  package.json
  package-lock.json
  tsconfig.json
```

The gateway currently:

- Listens on `127.0.0.1:47822` by default.
- Accepts WSS connections behind Nginx/Caddy.
- Validates the ticket signature and expiry.
- Calls Laravel internal bootstrap/close/turn endpoints.
- Validates protocol version, frame size, sequence, codec, sample rate, and channel count.
- Streams PCM frames to Sarvam STT.
- Sends transcript updates to Flutter.
- Calls Laravel for the safety gate and existing clinical chat response.
- Streams raw signed 16-bit PCM TTS chunks at 24 kHz back to Flutter.
- Tracks generation and stops sending stale output after interruption.

The gateway is intentionally separate from PHP-FPM. Laravel remains responsible
for authorization, patient ownership, policy, clinical context, persistence, and
the LLM request. The gateway must not query the patient database directly.

The gateway is a long-running Node.js process. It must not be run inside a normal Laravel controller or PHP-FPM request.

## Important current limitation

The gateway has the end-to-end transport and provider boundaries, but the Laravel LLM response is currently returned as one text value by the existing `AIChatService`. Therefore response text is sent as one `response.text.delta` event and TTS begins after Laravel returns the complete response.

This is already a realtime audio transport and supports interruption, but it is not yet token-level LLM streaming. To achieve the lowest first-audio latency, the backend developer should add a streaming LLM adapter and emit multiple `response.text.delta` events while the model is generating. The current synchronous path is a safe fallback.

Do not advertise token-level streaming until that adapter is implemented and tested.

The Flutter microphone remains available while the assistant speaks. Local voice activity above the barge-in threshold stops playback, invalidates the current generation, and starts the next turn. The gateway discards late STT/TTS callbacks whose generation is no longer current.

## Laravel routes required by the gateway

These routes are outside `auth:sanctum` because the gateway authenticates with a private shared secret:

```http
POST /api/v1/internal/voice/sessions/bootstrap
X-Voice-Gateway-Secret: <VOICE_GATEWAY_INTERNAL_SECRET>

{
  "session_id": "uuid",
  "ticket": "base64-payload.hmac-sha256",
  "protocol": "bh-voice.v1"
}
```

Successful response:

```json
{
  "session_id": "uuid",
  "locale": "ml-IN",
  "conversation_id": 123
}
```

```http
POST /api/v1/internal/voice/turns
X-Voice-Gateway-Secret: <VOICE_GATEWAY_INTERNAL_SECRET>
Content-Type: application/json

{
  "session_id": "uuid",
  "turn_id": "client-turn-id",
  "generation": 0,
  "transcript": "I have chest pain",
  "locale": "en-IN"
}
```

Response:

```json
{
  "text": "This may be an emergency. Please call an ambulance...",
  "safety_escalation": true
}
```

```http
POST /api/v1/internal/voice/sessions/{session}/close
X-Voice-Gateway-Secret: <VOICE_GATEWAY_INTERNAL_SECRET>
Content-Type: application/json

{
  "reason": "user_stopped",
  "generation": 1,
  "turns": 2
}
```

## WebSocket protocol

### Client hello

```json
{
  "v": "bh-voice.v1",
  "type": "hello",
  "session_id": "uuid",
  "ticket": "base64-payload.hmac-sha256"
}
```

### Client audio start

```json
{
  "v": "bh-voice.v1",
  "type": "audio.start",
  "session_id": "uuid",
  "turn_id": "client-turn-id",
  "generation": 0
}
```

### Binary audio frame

```text
4 bytes: unsigned big-endian JSON header length
N bytes: JSON header
remaining bytes: PCM signed 16-bit little-endian mono audio
```

Header:

```json
{
  "v": "bh-voice.v1",
  "type": "audio",
  "session_id": "uuid",
  "turn_id": "client-turn-id",
  "sequence": 0,
  "encoding": "pcm_s16le",
  "sample_rate": 16000,
  "channels": 1,
  "payload_length": 3200
}
```

The gateway rejects a frame when:

- The session is not authenticated.
- The session ID or turn ID is wrong.
- The sequence is not exactly the next sequence.
- The payload length is inconsistent.
- The frame is larger than the configured limit.
- The codec is not PCM16 little-endian, 16 kHz, mono.

### Client commit and cancellation

```json
{
  "v": "bh-voice.v1",
  "type": "audio.commit",
  "session_id": "uuid",
  "turn_id": "client-turn-id",
  "generation": 0
}
```

```json
{
  "v": "bh-voice.v1",
  "type": "response.cancel",
  "session_id": "uuid",
  "turn_id": "client-turn-id",
  "generation": 1
}
```

When cancelling, increment `generation`. Every provider callback must compare its captured generation with the current session generation before emitting output.

### Server events

The Flutter client handles:

```text
session.ready
transcript.partial
transcript.final
turn.accepted
response.text.delta
response.text.final
response.audio.start
response.audio.chunk
response.audio.end
response.cancelled
safety.escalation
error
session.ended
```

Server events contain at least `v`, `type`, and `session_id`; turn-related events also contain `turn_id` and `generation`.

## Environment configuration

Add these values to the real Laravel `.env`. Never commit the real values:

```dotenv
# Existing Laravel values
APP_URL=https://www.bhrchospital.com
QUEUE_CONNECTION=redis
CACHE_STORE=redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379

# Existing provider keys stay on the VPS
SARVAM_API_KEY=...
SARVAM_BASE_URL=https://api.sarvam.ai
SARVAM_STT_MODEL=saaras:v2.5
SARVAM_TTS_MODEL=bulbul:v2
SARVAM_TTS_SPEAKER=anushka
REPLICATE_API_TOKEN=...

# Laravel-issued voice tickets
VOICE_GATEWAY_URL=wss://voice.example.com
VOICE_GATEWAY_TICKET_SECRET=<long-random-secret>
VOICE_GATEWAY_INTERNAL_SECRET=<different-long-random-secret>
VOICE_TICKET_TTL=60
VOICE_MAX_UTTERANCE_SECONDS=60
VOICE_MAX_SESSION_SECONDS=900
VOICE_MAX_TURNS=30
```

The two voice secrets must be different:

- `VOICE_GATEWAY_TICKET_SECRET`: used by Laravel to sign ticket claims and by the gateway to verify them.
- `VOICE_GATEWAY_INTERNAL_SECRET`: used by the gateway when calling Laravel internal endpoints.

Generate them with a password manager or:

```bash
openssl rand -hex 32
```

Flutter build configuration only needs the normal API URL:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://www.bhrchospital.com/api/v1
```

Do not pass provider keys through `--dart-define`.

## VPS installation

Example Ubuntu/Debian setup:

```bash
sudo apt update
sudo apt install -y nginx redis-server php8.3-cli php8.3-fpm nodejs npm
sudo systemctl enable --now redis-server
```

Install Laravel:

```bash
cd /var/www/BHRC-Hospital
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan optimize
php artisan storage:link
```

Install and build the gateway:

```bash
cd /var/www/BHRC-Hospital/voice-gateway
npm ci
npm run build
```

The gateway must bind only to loopback:

```dotenv
VOICE_GATEWAY_PORT=47822
LARAVEL_INTERNAL_URL=http://127.0.0.1
VOICE_GATEWAY_TICKET_SECRET=<same-as-Laravel>
VOICE_GATEWAY_INTERNAL_SECRET=<same-as-Laravel>
SARVAM_API_KEY=<server-secret>
SARVAM_STT_MODEL=saaras:v2.5
SARVAM_TTS_MODEL=bulbul:v2
SARVAM_TTS_SPEAKER=anushka
VOICE_MAX_SESSION_SECONDS=900
VOICE_MAX_TURNS=30
```

Do not expose port `47822` directly to the internet.

## Process manager

Use Supervisor or systemd. Example Supervisor configuration:

```ini
[program:bhrc-voice-gateway]
directory=/var/www/BHRC-Hospital/voice-gateway
command=/usr/bin/node /var/www/BHRC-Hospital/voice-gateway/dist/index.js
user=www-data
autostart=true
autorestart=true
startsecs=5
stopwaitsecs=15
redirect_stderr=true
stdout_logfile=/var/log/bhrc-voice-gateway.log
environment=NODE_ENV="production"
```

Laravel workers also need a process manager:

```ini
[program:bhrc-laravel-worker]
directory=/var/www/BHRC-Hospital
command=/usr/bin/php artisan queue:work redis --sleep=1 --tries=3 --timeout=120
user=www-data
numprocs=2
autostart=true
autorestart=true
stopwaitsecs=3600
redirect_stderr=true
stdout_logfile=/var/log/bhrc-laravel-worker.log
```

## Nginx

Use a separate hostname for the WebSocket gateway:

```nginx
server {
    listen 443 ssl http2;
    server_name voice.example.com;

    # TLS certificate configuration omitted.

    location / {
        proxy_pass http://127.0.0.1:47822;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 960s;
        proxy_send_timeout 60s;
        proxy_buffering off;
    }
}
```

Also ensure:

- DNS `voice.example.com` points to the VPS.
- TLS certificate covers the gateway hostname.
- Only ports 80/443 are public.
- The WebSocket upgrade path is not cached.
- Request/body logging does not log tickets, audio, transcripts, or patient IDs.

## Laravel deployment checks

Run:

```bash
php artisan migrate --force
php artisan route:list --path=api/v1/internal/voice
php artisan route:list --path=api/v1/patients/chat/global/threads
php artisan config:clear
php artisan config:cache
php artisan queue:restart
```

Verify:

- `voiceConfig` never returns `api_key`.
- A patient cannot create a session for another patient’s conversation.
- A ticket expires after 60 seconds.
- A ticket cannot be used for a different session.
- A ticket cannot be reused after the session has been closed.
- The internal routes reject a missing or incorrect gateway secret.
- The internal routes are not accessible with a patient’s Sanctum token alone.
- Session creation enforces one active voice session per patient.
- Session close clears the active-session key.
- The emergency gate returns the approved response before normal LLM generation.

## Provider notes

Sarvam streaming STT accepts base64 audio chunks over its own WebSocket and supports raw PCM formats. The gateway sends 16 kHz PCM16 mono. Confirm the exact model and SDK version in the provider account before deployment; the SDK may type some model options narrowly even when the provider supports newer model versions.

Sarvam streaming TTS is configured with `output_audio_codec=linear16`, `speech_sample_rate=24000`, and mono output. The Flutter player expects signed 16-bit PCM at 24 kHz. If the selected provider/SDK returns MP3, WAV containers, or another codec, add a server-side decoder/transcoder or change the Flutter playback contract. Do not send encoded audio to a raw PCM player. Some Sarvam WAV streaming responses may omit the RIFF header, so WAV is intentionally not used for this raw PCM path.

## Document and PNG lab-report flow

The assistant attachment flow supports PDF, PNG, JPG/JPEG, and WEBP reports:

```text
Flutter picker
  -> POST /api/v1/patients/documents (multipart)
  -> PatientDocument + private R2 object
  -> POST /api/v1/patients/documents/{id}/analyze
  -> LocalClinicalOcrService
       |-- pdftotext for selectable PDFs
       |-- pdftoppm + Tesseract for scanned PDFs
       `-- Tesseract TSV for PNG/JPG/WEBP
  -> redaction before LLM context
  -> structured AIAnalysisResult
  -> redacted context for document chat/global clinical context
```

The mobile UI uploads the selected file, shows upload progress, starts analysis, and displays the summary, risk level, findings, and recommendations. A successful analysis is linked to the uploaded `PatientDocument`; repeated analyze requests reuse a completed/processing analysis instead of creating duplicate requests. Document chat lazily ensures analysis exists and then uses the document-scoped conversation.

Required VPS packages/configuration:

```bash
sudo apt install -y poppler-utils tesseract-ocr tesseract-ocr-eng
```

For Malayalam reports, install and configure the Malayalam Tesseract language data and include `mal` in the OCR language setting after clinical validation. The current OCR implementation uses English (`eng`) and must not be advertised as Malayalam OCR until that language pack and test corpus are installed.

The server must keep the R2 bucket private. If the app needs to preview a report, return a short-lived signed URL or authenticated media endpoint; do not make patient report objects publicly readable. The current upload limit is 20 MB at Laravel validation and the mobile UI rejects empty files and files over 25 MB before upload; keep those limits aligned by choosing one production limit, preferably 20 MB.

Analysis is synchronous in the current controller and may take up to several minutes. Keep PHP request and proxy timeouts above the configured analysis timeout, or move `analyseDocument` to a queued job and expose a polling/status endpoint before production-scale use. The UI should treat `202`/`processing` as pending rather than as a completed summary.

## Safety and privacy requirements

- Obtain clinical approval for English, Malayalam, and code-switched emergency phrases.
- Treat the current `VoiceSafetyPolicyService` patterns as an initial implementation, not clinical sign-off.
- Do not retain raw audio unless a documented consent and retention policy permits it.
- Do not place transcripts, audio, tickets, provider keys, or patient IDs in URLs.
- Redact patient data from gateway logs.
- Do not log provider request bodies.
- Limit utterance length, session duration, turns, bytes, and provider spend.
- Stop provider work on interruption, disconnect, app backgrounding, timeout, and session close.
- Keep push-to-talk and text fallback available.
- Test speaker, Bluetooth, wired headset, phone calls, app backgrounding, weak networks, English, Malayalam, and code-switching on physical devices.

## Completion criteria before production

- The Node gateway and Laravel app are deployed on the same VPS or private network.
- The exact Sarvam STT/TTS model and audio output codec are verified.
- LLM output is streamed or the product explicitly accepts synchronous LLM latency.
- Flutter receives `transcript.partial` before commit.
- First TTS audio arrives within the agreed SLO after end of speech.
- Barge-in stops local playback in under 250 ms and prevents late audio.
- Every completed turn is persisted once.
- Emergency corpus tests pass clinician review.
- Load, reconnect, restart, and provider-failure tests pass.
- The realtime feature can be disabled server-side without shipping a new app.
