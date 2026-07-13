# BioHelix Production Live Voice Plan

## Decision and scope

Build true live voice as a separate realtime path while keeping the existing HTTP voice endpoint as a push-to-talk fallback.

```text
Flutter
  |-- REST + Sanctum --> Laravel (auth, authorization, context, policy, history)
  `-- WSS ------------> Cloudflare Worker
                           `-- VoiceSession Durable Object
                                |-- streaming STT
                                |-- streaming LLM
                                |-- streaming TTS
                                |-- safety gates and cancellation
                                `-- Queue --> signed Laravel persistence API
```

Laravel remains the system of record. The Worker owns only transient realtime session orchestration. Flutter never receives vendor credentials or performs medical reasoning. Raw audio is not retained by default.

Use WebSocket for the first production release. The assistant is turn-oriented with barge-in, not a two-person call. Fix the first wire format to mono PCM16, 16 kHz, 20-40 ms frames; introduce Opus only if measured bandwidth costs justify it. Do not promise fully simultaneous speech: if acoustic echo cancellation is inadequate, fall back to half-duplex or require headphones.

## Current-system assessment

### What can be retained

- Sanctum authentication and patient ownership checks in `BHRC-Hospital/routes/api.php` and `GlobalChatController.php`.
- `AIChatConversation` and `AIChatMessage` as authoritative conversation history.
- Context, language, short voice responses, and basic emergency wording in `AIChatService.php`.
- Provider abstractions, R2 support, correlated AI traces, and existing service tests.
- The Flutter live-stage UI and current push-to-talk recorder/player as a fallback experience.

### Blocking gaps

- The existing live mode is device STT -> full HTTP chat response -> device TTS, not streaming.
- Partial STT is submitted after 550 ms, which can split clinically important sentences.
- Failed live requests do not resume listening; old requests cannot be cancelled; repeated text can be suppressed across sessions.
- Flutter uses overlapping booleans rather than a legal state machine and has no robust app/audio lifecycle handling.
- Laravel buffers up to 25 MB, base64-expands it, then blocks synchronously across STT, LLM, and TTS.
- Chat/voice routes lack voice-specific throttles, quotas, idempotency, per-conversation serialization, and cancellation.
- A provider failure can leave an orphan user message because persistence is not transactional/status-driven.
- Conversation timestamps are not reliably touched when messages arrive, affecting thread ordering.
- There is no session/turn schema, streaming gateway, one-use ticket, signed callback, deterministic safety layer, cost ledger, or realtime SLO dashboard.
- Generated R2 reply audio has a signed URL but no explicit object lifecycle policy.
- Tests do not cover HTTP voice authorization/validation, concurrency, idempotency, lifecycle, reconnect, barge-in, load, or clinical safety.

## Protocol: `bh-voice.v1`

### Session creation

Flutter calls:

```http
POST /api/v1/patients/chat/global/threads/{conversation}/voice-sessions
Authorization: Bearer <sanctum-token>
Idempotency-Key: <uuid>

{
  "locale": "ml-IN",
  "protocol": "bh-voice.v1",
  "device_id": "opaque-installation-id"
}
```

Laravel verifies ownership, entitlement, consent, quotas, and the one-active-session rule. It creates a session and returns its ID, gateway URL, limits, and a 60-second one-use asymmetrically signed ticket. The ticket contains opaque IDs, ticket `jti`, scope, locale, protocol, limits, issued time, and expiry; it contains no patient data or medical context.

The WSS ticket is sent in the first `hello` control frame, never in a URL.

### Events

JSON control frames:

- Client: `hello`, `audio.start`, `audio.commit`, `response.cancel`, `session.end`, `ping`.
- Server: `session.ready`, `transcript.partial`, `transcript.final`, `turn.accepted`, `response.text.delta`, `response.text.final`, `response.audio.start`, `response.audio.end`, `response.cancelled`, `safety.escalation`, `error`, `session.ended`.

Binary frames carry PCM audio plus protocol version, audio epoch, monotonic sequence number, timestamp, and payload length. Every control event carries `session_id`, `turn_id`, `event_seq`, `generation`, `trace_id`, and protocol version where applicable. Every mutation has a UUID idempotency/event key.

### State and interruption

```text
connecting -> ready -> listening -> transcribing -> reasoning -> speaking
                      ^                         |
                      `------ barge-in ---------'
any state -> degraded | reconnecting | closing -> closed
```

Only one generation may be active per session. Illegal transitions are rejected. On local VAD speech during playback, Flutter stops playback immediately, increments its audio epoch, sends `response.cancel`, and starts capturing the new turn. The Durable Object aborts LLM/TTS work and increments its generation so late provider bytes are discarded. Persist the assistant text actually delivered and mark the turn `interrupted`.

Reconnect only finalized control state inside a short grace period; never replay stale microphone frames. Abort an unfinished turn after the grace period.

## Phase 0 - compliance, safety, and vendor benchmark

This phase blocks production implementation choices.

1. Obtain BHRC clinical approval for English, Malayalam, and code-switched policy text, emergency responses, disclaimers, and escalation paths.
2. Review applicable Indian DPDP and healthcare obligations, plus any other operating jurisdiction. Approve vendor DPA, subprocessors, data residency, retention/training opt-out, breach obligations, and deletion/export support.
3. Benchmark genuine streaming STT and TTS providers using elderly speakers, Malayalam, English, code-switching, background noise, weak mobile networks, and medical vocabulary. Require incremental streaming, cancellation, compliant data handling, and acceptable cost.
4. Define versioned deterministic pre-LLM emergency rules and post-generation prohibited-output rules. Emergency detection must cover chest pain, breathing difficulty, stroke signs, heavy bleeding, fainting, and self-harm in both supported languages.
5. Define consent version, context purpose, retention periods, audit access, daily/session limits, and cost budgets.

Gate: legal/privacy approval, clinical sign-off, threat model, provider benchmark, and measurable latency feasibility are recorded.

## Phase 1 - harden the existing push-to-talk fallback

Backend:

- Add a dedicated voice rate limiter by patient, device, and IP.
- Require `Idempotency-Key`; serialize active work per conversation; make retries return the original turn.
- Reduce the byte cap and validate decoded duration, codec, channel count, sample rate, MIME signature, silence, and maximum utterance length.
- Avoid unnecessary full-buffer/base64 paths where the selected provider permits streaming/multipart upload.
- Add stable error codes, bounded retry with jitter only for safe transient failures, provider timeouts, circuit breakers, and fallback behavior.
- Persist turn status (`accepted`, `processing`, `completed`, `failed`, `cancelled`) and prevent orphan/duplicate turns.
- Touch the conversation on completed messages; paginate thread lists and messages.
- Add an explicit R2 lifecycle/deletion policy for synthesized audio.

Flutter:

- Submit native STT only on a final result or approved endpointing policy; remove the 550 ms partial-result send.
- Restart listening after failures, reset all session-specific deduplication state, reject stale replies, and add cancellation tokens.
- Delete temporary recordings in `finally`; add max-duration/file-size enforcement and upload progress.
- Label this experience `Hands-free` or `Push-to-talk`, not `Live`.

Gate: timeout, retry, duplicate submission, app backgrounding, and provider failure produce no duplicate/orphan messages and always release audio resources.

## Phase 2 - Laravel realtime control plane

### New components

- `BHRC-Hospital/app/Modules/Api/Http/Controllers/Chat/VoiceSessionController.php`
- `BHRC-Hospital/app/Modules/Api/Http/Controllers/Internal/VoiceGatewayController.php`
- `BHRC-Hospital/app/Modules/AI/Services/Voice/VoiceSessionTicketService.php`
- `BHRC-Hospital/app/Modules/AI/Services/Voice/VoiceContextService.php`
- `BHRC-Hospital/app/Modules/AI/Services/Voice/VoiceTurnPersistenceService.php`
- `BHRC-Hospital/app/Modules/AI/Services/Voice/VoiceSafetyPolicyService.php`
- `BHRC-Hospital/app/Http/Middleware/VerifyVoiceGatewaySignature.php`
- `BHRC-Hospital/app/Modules/AI/Models/AIVoiceSession.php`
- `BHRC-Hospital/app/Modules/AI/Models/AIVoiceUsage.php`
- `BHRC-Hospital/config/voice.php`
- Forward-only migrations and feature/contract tests.

### Persistence

Create `ai_voice_sessions` containing session UUID, conversation/patient IDs, state, locale, protocol/context/safety/consent versions, ticket JTI hash, timestamps, close reason, and aggregate usage.

Add message metadata: `turn_id`, `channel`, `sequence`, `delivery_status`, `language`, and bounded metadata. Enforce unique `(conversation_id, turn_id, role)` and ordered `(conversation_id, sequence)` indexes. Store provider/model, audio seconds, tokens, cost, and stage latency in `ai_voice_usage` or bounded metadata.

Extract prompt and minimal context construction from `AIChatService` into `VoiceContextService`/a shared context service. Text chat and the gateway bootstrap must consume the same versioned policy. Do not copy clinical prompts or independently query records in the Worker.

### Internal gateway APIs

```text
POST /api/v1/internal/voice/sessions/{session}/bootstrap
POST /api/v1/internal/voice/turns
POST /api/v1/internal/voice/sessions/{session}/usage
POST /api/v1/internal/voice/sessions/{session}/close
```

Worker requests include key ID, timestamp, nonce, body SHA-256, event ID, and HMAC signature. Laravel rejects clock skew, replayed nonces, excessive bodies, invalid session scope, and unknown keys. Support overlapping key IDs for rotation. Queue redelivery is harmless because persistence is idempotent and transactionally ordered.

Gate: cross-patient session creation is impossible; ticket reuse/replay fails; callback replay is harmless; concurrent turns remain ordered; context is minimal and policy-versioned.

## Phase 3 - Worker and Durable Object gateway

Create a separate deployable package:

```text
voice-gateway/
  src/index.ts
  src/durable-objects/VoiceSession.ts
  src/protocol/events.ts
  src/protocol/binary-frame.ts
  src/auth/ticket-verifier.ts
  src/laravel/client.ts
  src/providers/stt.ts
  src/providers/llm.ts
  src/providers/tts.ts
  src/safety/emergency-gate.ts
  src/queues/persist-turn.ts
  src/observability/telemetry.ts
  test/
  wrangler.jsonc
  package.json
  tsconfig.json
```

Use one SQLite-backed Durable Object per session, WebSocket hibernation, transactionally persisted state transitions, and a short outbox. The DO is transient coordination, not the medical database. Cloudflare Queue delivers finalized turns/usage to Laravel with retry and dead-letter handling.

Implement provider adapters with cancellation and explicit timeouts. Use the existing OpenAI-compatible reasoning provider only if its streaming endpoint passes the benchmark. STT/TTS remain interchangeable adapters selected by compliance and performance results.

Enforce handshake rate, one connection per session, maximum buffered bytes, 60-second utterance cap, 15-minute session cap, 30-second idle warning/closure, turns/minute, bytes/minute, and provider-token ceiling through Laravel-issued limits plus Worker-side enforcement.

Gate: all legal state transitions are unit-tested; fake-provider integration tests cover cancellation and out-of-order bytes; DO restart/hibernation and duplicate Queue delivery preserve correctness; malformed/oversized frames are rejected safely.

## Phase 4 - Flutter production voice client

Add:

- `lib/patient_portal/assistant/voice/live_voice_controller.dart`
- `lib/patient_portal/assistant/voice/live_voice_state.dart`
- `lib/patient_portal/assistant/voice/voice_gateway_client.dart`
- `lib/patient_portal/assistant/voice/voice_protocol.dart`
- `lib/patient_portal/assistant/voice/microphone_stream.dart`
- `lib/patient_portal/assistant/voice/streaming_audio_player.dart`
- `lib/patient_portal/assistant/voice/voice_activity_detector.dart`
- `lib/patient_portal/assistant/voice/voice_session_repository.dart`

Update `patient_assistant_tab.dart` so it renders controller state and emits intents only. Remove the pseudo-live loop from `patient_assistant_helpers.dart`. Extend `patient_portal_provider_chat.dart` to create sessions and reconcile finalized turns by stable `turn_id`.

Use a sealed state machine, generation tokens, and injectable microphone/player/gateway interfaces. Handle microphone permission states, app pause/background/termination, audio focus, phone calls, route changes, speaker/earpiece, wired and Bluetooth devices, reconnect/backoff, token expiry, low bandwidth, and permission revocation. Configure native voice-chat audio sessions and acoustic echo cancellation/noise suppression where available.

Gate: a physical-device matrix passes Android/iOS, speaker, wired/Bluetooth, interruptions, lifecycle changes, reconnect, weak-network shaping, English, and Malayalam. Stale audio/text is never rendered after cancellation or a new generation.

## Phase 5 - deterministic safety, resilience, and observability

- Run the emergency detector before normal LLM generation. On a positive result, cancel normal generation and play an approved localized emergency response.
- Validate model output before streaming TTS; block medication changes, definitive diagnoses, fabricated record claims, and prohibited recommendations.
- Add clear not-a-doctor/not-an-emergency-service disclosure and explicit microphone/AI-processing consent.
- Never place audio, transcripts, prompts, tickets, signed URLs, or patient IDs in URLs, crash analytics, or ordinary logs. Pseudonymize exported telemetry.
- Propagate one trace ID across Flutter diagnostics, Worker, vendors, Queue, and Laravel. Record only state transitions, byte/duration counts, provider status, tokens/cost, cancellation reason, queue attempts, and policy versions.
- Add dashboards and alerts for latency, availability, provider failures, queue age/dead letters, persistence lag, auth spikes, emergency-gate errors, cost, and error-budget burn.

### Initial SLOs

- Gateway availability: 99.9% monthly.
- Successful authenticated session establishment: 99.5%.
- p95 session-ready: <1 second.
- p95 final transcript after end-of-speech: <800 ms.
- p95 first text token after final transcript: <1.5 seconds.
- p95 first audible response after end-of-speech: <2.5 seconds.
- p99 local barge-in playback stop: <250 ms.
- 99.9% completed turns persisted within 60 seconds.
- Duplicate permanent turns: zero.
- Raw audio retained without explicit consent/policy: zero.

Gate: load/soak and chaos tests meet SLOs; the approved critical emergency corpus has 100% recall; prohibited-output tests pass; privacy review finds no PHI leakage.

## Verification matrix

### Backend and contract tests

- Session authorization, entitlement, consent, quotas, ticket expiry/replay, and one-active-session enforcement.
- HMAC signature validation, nonce replay, key rotation, event idempotency, transactional ordering, and Queue redelivery.
- Push-to-talk MIME/duration/size/silence validation, rate limits, provider timeout/retry/circuit behavior, and R2 cleanup.
- Pagination, conversation touch/order, cross-patient isolation, deletion/export, and retention jobs.

### Worker tests

- Protocol parser fuzzing, malformed/oversized/out-of-order frames, every state transition, generation cancellation, late-byte rejection, reconnect, idle/session limits, provider failure/fallback, DO restart/hibernation, Queue and Laravel outages.

### Flutter tests

- Controller unit tests with fake STT/audio/gateway events; widget tests for every state and disclosure; repository contract tests; physical-device integration tests for permissions, audio routes, phone calls, backgrounding, reconnect, packet loss, cancellation, and fallback.

### Clinical/security tests

- Clinician-reviewed English/Malayalam/code-switched golden set, noisy elderly speech, prompt injection through transcripts/documents, emergency cases, hallucination checks, prohibited medication/diagnosis output, penetration test, dependency/secret scanning, and retention/deletion audit.

## Rollout

Use independent server-side flags for hardened push-to-talk and realtime voice, plus a global kill switch. Roll out to staff accounts, then 1%, 10%, 50%, and 100% of eligible patients. Advance only after several days within SLOs and no severity-1 clinical, privacy, or security event. Automatically disable realtime voice and offer push-to-talk/text when gateway/provider health exceeds thresholds.

## Recommended delivery order

1. Compliance, clinical policy, vendor benchmark, threat model, and SLO/cost budget.
2. Push-to-talk hardening and current Flutter race/lifecycle fixes.
3. Laravel schema, shared context/policy, session ticket, signed internal APIs, and tests.
4. Worker/DO protocol, provider adapters, Queue persistence, cancellation, and telemetry.
5. Flutter streaming controller, audio pipeline, lifecycle/focus, and UI integration.
6. End-to-end safety, security, load, chaos, and clinical evaluation.
7. Flagged canary rollout with fallback and kill switch.

Do not start the Worker implementation before Phase 0 selects vendors and validates compliance/latency. Do not treat polishing the current HTTP loop as progress toward streaming; they are separate deliverables.
