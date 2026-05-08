# Voice Health Assistant Implementation Plan

## Summary
Build v1 as a Malayalam + English voice-enabled Health AI Assistant inside the Flutter patient app. Reuse the existing assistant/chat infrastructure instead of creating a separate feature.

The assistant supports text chat, mic input, live voice mode, AI reply playback through TTS, report/image attachments, chat thread history, and safe health guidance.

UI placement:
- Add a floating Health AI button on the Home tab above the bottom nav.
- Keep Quick Actions -> AI Assistant.
- Keep AI Health Checkup as a separate bottom-nav tab for structured risk assessment.

## App Files
- `lib/patient_portal/shell/patient_app_shell.dart`: add the Home-only assistant FAB and open the existing `_AssistantPage`.
- `lib/patient_portal/assistant/screens/patient_assistant_tab.dart`: add starter prompts, language-aware voice configuration calls, and empty-state assistant guidance.
- `lib/patient_portal/assistant/widgets/patient_assistant_helpers.dart`: set STT/TTS locale from app language, pass `language` and `mode` to chat sends, and localize voice/upload snackbars.
- `lib/patient_portal/assistant/widgets/patient_assistant_chat_input.dart`: localize hint, live/stop labels, mic tooltips, recording badge, and disclaimer.
- `lib/patient_portal/assistant/widgets/patient_assistant_chat_header.dart`: localize title, status, and action tooltips.
- `lib/patient_portal/assistant/widgets/patient_assistant_chat_sidebar.dart`: localize chat history labels and menu actions.
- `lib/patient_portal/assistant/widgets/patient_assistant_message_bubble.dart`: localize voice playback controls.
- `lib/patient_portal/assistant/utils/patient_portal_provider_chat.dart`: extend `sendChatMessage` with optional `language` and `mode`.
- `lib/patient_portal/core/data/patient_repository.dart`: send `language` and `mode` to the global chat endpoint.
- `lib/core/l10n/app_strings.dart`: add assistant strings and repair core Malayalam text encoding.

## Backend Files
- `server/src/routes/patients.ts`: update patient global chat handlers to read `language` and `mode`.
- Existing auth and rate limiting already cover `/patients/chat`; no new middleware is required.
- Existing chat schema in `server/src/db/schema/chat.ts` remains unchanged; no migration is required for v1.

## Voice Behavior
- English:
  - STT locale: `en_IN`
  - TTS language: `en-IN`
  - Backend language: `en`
- Malayalam:
  - STT locale: `ml_IN`
  - TTS language: `ml-IN`
  - Backend language: `ml`
- Voice mode tells the backend to reply with shorter, speakable sentences and avoid tables.

## Medical Safety
The backend prompt must keep the assistant educational and practical. It may explain reports, symptoms, preventive care, available tests/packages, and next steps.

The assistant must not diagnose, prescribe, change medicine doses, or guarantee outcomes. For severe chest pain, severe breathlessness, fainting, stroke symptoms, heavy bleeding, suicidal intent, or other emergency red flags, it should advise immediate emergency care.

## Test Plan
- Run `flutter analyze`.
- Run `flutter test`.
- Run backend typecheck/test command from the backend repo.
- Manual checks:
  - Home FAB opens Health AI.
  - Quick Actions -> AI Assistant still works.
  - English text and voice receive English replies.
  - Malayalam text and voice receive Malayalam replies.
  - TTS speaks in the selected language.
  - Live mode sends final speech automatically.
  - Attachments still upload and remain usable in chat.
  - Red-flag symptom prompts produce urgent-care guidance.
  - AI Health Checkup still works independently.
