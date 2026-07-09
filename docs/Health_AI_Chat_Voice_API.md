# Health AI Chat & Voice — API Reference (for Flutter)

Endpoints the Flutter app uses for the AI assistant: text chat threads and
push-to-talk voice. All paths are under the base:

```
https://<your-host>/api/v1
```

---

## Authentication

All AI endpoints require a **Sanctum bearer token** obtained from the OTP login
flow. Send it on every request:

```
Authorization: Bearer <token>
Accept: application/json
```

### Get a token (OTP flow)
```
POST /auth/otp/send      { "phone": "9876543210" }
POST /auth/otp/verify    { "phone": "9876543210", "otp": "123456" }
```
`otp/verify` responds:
```json
{
  "token": "3|xxxxxxxxxxxxxxxxxxxx",
  "patient": { "id": 1, "name": "...", "phone": "...", "...": "..." }
}
```
Store `token` securely (Keychain / Keystore) and attach it as the bearer token.

---

## Shared object shapes

### `message` object
```json
{
  "id": 42,
  "role": "user | ai",
  "message": "text of the message",
  "content": "text of the message",
  "createdAt": "2026-07-07T10:20:30.000000Z",
  "suggestedTests":    [ /* labTest objects, AI replies only */ ],
  "suggestedPackages": [ /* labPackage objects, AI replies only */ ]
}
```
> `role` is `"user"` for the patient and `"ai"` for the assistant.
> `suggestedTests` / `suggestedPackages` appear only on AI messages and may be empty.

### `thread` object
```json
{
  "id": 7,
  "title": "New Conversation",
  "status": "active",
  "messageCount": 4,
  "createdAt": "2026-07-07T10:00:00.000000Z",
  "updatedAt": "2026-07-07T10:20:30.000000Z"
}
```

---

## 1. List chat threads
```
GET /patients/chat/global/threads
```
**200**
```json
{ "threads": [ { /* thread */ }, ... ] }
```

## 2. Create a thread
```
POST /patients/chat/global/threads
Body: { "title": "Optional title" }
```
**201**
```json
{ "thread": { /* thread */ } }
```

## 3. Get a thread with its messages
```
GET /patients/chat/global/threads/{threadId}
```
**200**
```json
{
  "thread":   { /* thread */ },
  "messages": [ { /* message */ }, ... ]   // ordered oldest → newest
}
```

## 4. Send a text message
```
POST /patients/chat/global/threads/{threadId}/messages
Content-Type: application/json
```
Body:
```json
{
  "message": "What does my last blood report mean?",
  "language": "en",        // optional: "en" | "ml"
  "mode": "text"           // optional: "text" | "voice"
}
```
**200** — the AI reply:
```json
{
  "reply": "Your report shows ...",
  "content": "Your report shows ...",
  "message": { /* message object, role: "ai" */ },
  "suggestedTests":    [ /* ... */ ],
  "suggestedPackages": [ /* ... */ ]
}
```
> Only the AI reply is returned. The user message is persisted server-side;
> render it optimistically in the UI.

## 5. Send a voice message (push-to-talk) ⭐
```
POST /patients/chat/global/threads/{threadId}/voice
Content-Type: multipart/form-data
```
Form fields:

| Field      | Type   | Required | Notes |
|------------|--------|----------|-------|
| `audio`    | file   | yes      | Recorded clip. Max **25 MB**. |
| `language` | string | no       | `"en"` or `"ml"`. Default `"en"`. |

Accepted audio MIME types:
`audio/wav`, `audio/x-wav`, `audio/mpeg`, `audio/mp4`, `audio/m4a`,
`audio/x-m4a`, `audio/aac`, `audio/ogg`, `audio/webm`.

**200**
```json
{
  "transcript": "what does my last blood report mean",
  "audio_url": "https://.../voice-replies/uuid.wav?signature=...",
  "reply": "Your report shows ...",
  "content": "Your report shows ...",
  "message": { /* message object, role: "ai" */ },
  "suggestedTests":    [ /* ... */ ],
  "suggestedPackages": [ /* ... */ ]
}
```

Flutter flow:
1. Record audio (e.g. `record` package) → get a file (`.m4a`/`.wav`).
2. Upload as multipart under field `audio`.
3. Show `transcript` as the user's message bubble.
4. Show `reply` / `message` as the AI bubble (render `suggested*` as cards).
5. If `audio_url` is **non-null**, download & play it (e.g. `just_audio`).
   If `audio_url` is **null**, TTS is not configured server-side — show text only.

> `audio_url` is a temporary signed URL (valid ~1 hour). Play or cache it soon;
> don't store it long-term.

> Latency: a voice turn runs STT → LLM → TTS and can take several seconds.
> Show a "thinking / listening" indicator and disable re-send until it returns.

## 6. Rename a thread
```
PATCH /patients/chat/global/threads/{threadId}
Body: { "title": "New title" }
```
**200** → `{ "thread": { /* thread */ } }`

## 7. Delete a thread
```
DELETE /patients/chat/global/threads/{threadId}
```
**200** → `{ "success": true }`

---

## Error responses

| Status | Meaning | Handle by |
|--------|---------|-----------|
| 401 | Missing/invalid token | Re-run login flow |
| 403 | Thread belongs to another patient | Refresh thread list |
| 422 | Validation error (e.g. audio too large / wrong type) | Show field message from `errors` |
| 500 | Upstream AI/transcription failure | Ask user to retry |

422 shape:
```json
{ "message": "The audio failed...", "errors": { "audio": ["..."] } }
```

---

## Notes for the Flutter developer
- Text and voice share the **same threads and history** — a voice turn appears
  in `GET /threads/{id}` like any other message.
- Do **not** call Replicate, Whisper, or any AI vendor directly. All AI runs
  server-side; the app only uploads audio/text and renders responses.
- `language: "ml"` gives Malayalam replies; spoken Malayalam audio depends on the
  server's TTS model being configured — always handle `audio_url == null`.
- Record in a supported format; `m4a` (AAC) from the `record` package works well
  and keeps uploads small.
