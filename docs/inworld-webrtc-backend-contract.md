# Inworld WebRTC backend contract

The Flutter application uses Laravel as the authenticated signaling proxy.
Flutter never receives an Inworld credential.

All routes below use the API client's existing bearer token.

## `GET /v1/realtime/ice`

Laravel calls Inworld `GET /v1/realtime/ice-servers` with the server-side
credential and returns only:

```json
{
  "ice_servers": [
    {"urls": ["stun:example"]},
    {
      "urls": ["turn:example"],
      "username": "temporary-user",
      "credential": "temporary-credential"
    }
  ]
}
```

The response must use `Cache-Control: no-store`. Apply authentication,
entitlement, per-user/IP throttling, and an upstream timeout.

## `GET /v1/realtime/session-config`

Laravel returns a complete safe Inworld client event. Model identifiers and
instructions come from server allow-lists, never request parameters.

```json
{
  "type": "session.update",
  "session": {
    "type": "realtime",
    "model": "google-ai-studio/gemini-2.5-flash-lite",
    "instructions": "Server-controlled instructions for the saved language.",
    "output_modalities": ["audio", "text"],
    "max_output_tokens": 100,
    "audio": {
      "input": {
        "transcription": {
          "model": "assemblyai/u3-rt-pro",
          "language": "en"
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
}
```

Use `soniox/stt-rt-v4` and language `ml` for Malayalam. A language change
affects the next WebRTC session.

## `POST /v1/realtime/calls`

Request and response bodies use `Content-Type: application/sdp`. Laravel:

1. Requires authentication and `application/sdp`.
2. Rejects bodies over 100 KB or bodies not starting with `v=0`.
3. Calls Inworld's realtime call endpoint with the server credential.
4. Returns only the SDP answer with `Cache-Control: no-store`.
5. Normalizes upstream errors and never returns provider headers or secrets.

The Flutter client waits for ICE gathering before this request and applies the
returned body as its remote SDP answer.

## Runtime behavior

- Microphone and AI audio travel over WebRTC RTP.
- JSON events travel over the ordered `oai-events` data channel.
- Flutter sends the session configuration only after that channel opens.
- Inworld semantic VAD creates turns and enables interruption.
- Flutter stops a session when the app is backgrounded.
- Final transcript/answer pairs are reconciled into the existing chat thread.

## `POST /v1/realtime/turns`

Since realtime media does not pass through Laravel, Flutter submits each
completed turn for authoritative persistence:

```json
{
  "conversation_id": "existing-chat-thread-id",
  "transcript": "Final user transcript",
  "response": "Final assistant response",
  "idempotency_key": "unique-turn-key"
}
```

Laravel validates conversation ownership, bounds both text fields, applies
medical safety/audit policy, and stores the user and assistant messages in one
database transaction. The idempotency key is unique per user and returns the
original result on retry. Laravel must not invoke the LLM again for this route.

The removed `/patients/chat/.../voice`, `/voice-config`, and
`/voice-sessions` WebSocket contracts must not be reintroduced.
