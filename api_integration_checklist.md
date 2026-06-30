# BHRC Hospital — API Integration Checklist
> For app developer review · Last updated: 2026-06-30

Use this checklist to verify every customer-facing API endpoint is correctly integrated in the mobile/frontend app. Tick each item after testing against a live or staging environment.

Base URL: `{{base_url}}/api/v1`

---

## Auth

- [ ] `POST /auth/register` — patient registers with email + password; receives token
- [ ] `POST /auth/login` — patient logs in with email + password; receives token
- [ ] `POST /auth/otp/send` — sends OTP to phone number
- [ ] `POST /auth/otp/verify` — verifies OTP; receives token for existing patients
- [ ] `POST /auth/signup` — registers new patient via OTP flow; receives token
- [ ] `POST /auth/logout` — invalidates token (requires `Authorization: Bearer <token>`)
- [ ] `GET /auth/profile` — returns authenticated user object
- [ ] `POST /auth/verification/send` — sends email verification link
- [ ] `POST /auth/verification/otp` — verifies email via OTP

---

## Patient Profile

- [ ] `GET /patients/me` — returns patient profile fields (name, phone, DOB, gender, blood group, address, etc.)
- [ ] `PATCH /patients/me` — updates patient profile; confirm changes persist
- [ ] `GET /patients/me/dashboard` — returns upcoming bookings, recent documents, vitals, summaries, ID card, MyClub
- [ ] `GET /patients/me/prescriptions` — returns prescriptions list
- [ ] `GET /patients/me/summaries` — returns consultation summaries
- [ ] `GET /patients/me/myclub` — returns membership, loyalty points, available plans
- [ ] `GET /medical-records/me` — returns full medical records

---

## Banners & Home Content

- [ ] `GET /banners` — returns active banner list (image URL, title, link)
- [ ] `GET /home-banners` — alternate banner endpoint (same data)
- [ ] `GET /home-ticker-messages` — returns ticker/marquee messages
- [ ] `GET /home-offers` — returns promotional offers

---

## Doctors & Departments

- [ ] `GET /departments` — returns department list
- [ ] `GET /doctors` — returns doctor list with name, specialization, fee, schedule
- [ ] `GET /doctors/{doctorId}/available-slots` — returns available appointment slots for a given date

---

## Lab Tests & Packages

- [ ] `GET /lab/tests` — returns full test catalogue (name, code, price, category)
- [ ] `GET /lab/packages` — returns package catalogue (name, code, price, included tests)
- [ ] `GET /lab/body-points` — returns body point / sample type list

---

## Bookings

### Doctor Booking
- [ ] `POST /bookings/doctors` — books a doctor appointment; receives booking confirmation
- [ ] `PATCH /bookings/doctors/{bookingId}/cancel` — cancels a doctor booking
- [ ] `GET /patients/bookings` — lists all bookings for patient
- [ ] `PATCH /patients/bookings/{bookingId}/cancel` — cancel via legacy endpoint
- [ ] `PATCH /patients/bookings/{bookingId}/reschedule` — reschedule appointment

### Lab Test Booking
- [ ] `POST /bookings/tests` — books one or more lab tests in a single order
- [ ] `PATCH /bookings/tests/{batchId}/cancel` — cancels a test batch
- [ ] `GET /patient/lab-orders` — lists patient's lab test orders
- [ ] `POST /patient/lab-orders` — alternate test order endpoint (OTP-auth clients)
- [ ] `PATCH /patient/lab-orders/{bookingId}` — updates an existing lab order

### Package Booking
- [ ] `POST /bookings/packages` — books a lab package
- [ ] `PATCH /bookings/packages/{bookingId}/cancel` — cancels a package booking
- [ ] `GET /patient/lab-package-orders` — lists patient's package orders
- [ ] `POST /patient/lab-package-orders` — alternate package order endpoint
- [ ] `PATCH /patient/lab-package-orders/{bookingId}` — updates a package order

---

## Vitals

- [ ] `GET /patients/me/vitals` — returns vitals history (BP, HR, weight, height, BMI, SpO2, temperature)
- [ ] `POST /patients/me/vitals` — records a new vitals entry

---

## Health Profile

- [ ] `GET /patients/me/health-profile` — returns latest health profile (conditions, medications, allergies, symptoms)
- [ ] `POST /patients/me/health-profile` — saves a new health profile snapshot
- [ ] `GET /patients/me/health-profile/history` — returns paginated history of all snapshots; check `source` field (`self_reported`, `assessment_derived`, `document_derived`)

---

## Health Snapshot *(added 2026-06-30)*

- [ ] `GET /patients/me/health-snapshot` — returns computed health snapshot; auto-generates if none exists
  - Verify fields: `bmi`, `health_score`, `risk_score`, `latest_vitals`, `ai_summary`, `generated_at`
  - Verify `health_score` is 0–100 and `risk_score` = `100 - health_score`
- [ ] `POST /patients/me/health-snapshot/refresh` — recomputes snapshot from latest vitals + profile; verify `generated_at` updates

---

## AI Health Assessment

- [ ] `POST /health-assessment/start` — starts a session; returns `session_token` and `questions` array
  - Verify questions are personalised when patient has a health profile
  - Verify each question has `id`, `question`, `category`, and 4 `options` (A–D)
- [ ] `GET /health-assessment/{token}` — fetches session state; verify `status` progresses correctly
- [ ] `POST /health-assessment/{token}/answers` — submits answers map `{ "1": "C", "2": "B", ... }`; returns `results`
  - Verify `results` contains `risk_level`, `summary`, `insights`, `recommended_packages`, `recommended_tests`, `custom_package`
  - Verify `risk_level` is one of: `low`, `moderate`, `high`, `critical`
- [ ] `GET /health-assessment/{token}/results` — fetches results after evaluation; same structure as above
- [ ] `GET /health-assessment/history` — returns list of past evaluated assessments

---

## AI Suggestions *(added 2026-06-30)*

- [ ] `GET /patients/me/ai-suggestions` — returns recommendation list
  - Verify each item has `recommendation_type`, `reason`, `score`, `is_accepted`, and a populated `item` object (or `null`)
  - Verify `item.type` is either `lab_test` or `lab_package`
- [ ] `PATCH /patients/me/ai-suggestions/{id}/accept` — marks a suggestion accepted; verify `is_accepted` becomes `true` on re-fetch

---

## Documents

- [ ] `GET /patients/documents` — lists uploaded documents
- [ ] `POST /patients/documents` — uploads a document (`multipart/form-data`); verify file types: jpg, jpeg, png, pdf, webp (max 20 MB)
- [ ] `POST /patients/documents/{id}/analyze` — triggers AI analysis; verify status returns `queued`
- [ ] `DELETE /patients/documents/{id}` — deletes document
- [ ] `GET /patients/documents/{id}/chat` — fetches document chat history
- [ ] `POST /patients/documents/{id}/chat` — sends a question about the document; verify `reply` in response

---

## AI Chat (Global Threads)

- [ ] `GET /patients/chat/global/threads` — lists all chat threads
- [ ] `POST /patients/chat/global/threads` — creates a new thread with a `title`
- [ ] `GET /patients/chat/global/threads/{id}` — fetches thread with message history
- [ ] `POST /patients/chat/global/threads/{id}/messages` — sends a message; verify `reply` in response
- [ ] `PATCH /patients/chat/global/threads/{id}` — renames thread; verify title updates
- [ ] `DELETE /patients/chat/global/threads/{id}` — deletes thread; verify removed from list

---

## General Checks

- [ ] All authenticated endpoints return `401` when called without a token
- [ ] All authenticated endpoints return `403` when a patient tries to access another patient's data
- [ ] Error responses use `{ "message": "...", "errors": { ... } }` structure for validation failures (422)
- [ ] Pagination endpoints include a `meta` block with `current_page`, `last_page`, `total`
- [ ] File upload size limits are enforced (413 or 422 for oversized files)
- [ ] `Accept: application/json` header is sent on all requests to ensure JSON error responses

---

## Notes for Developer

- Token format: Sanctum Bearer token — store securely, send as `Authorization: Bearer <token>`
- After login/signup, always store and reuse the token; do not re-authenticate on each request
- Health snapshot auto-generates on first `GET` — no need to call `/refresh` proactively; call it after the patient records new vitals or updates their health profile
- Assessment session tokens expire — check `expires_at` and redirect to start a new session if expired (API returns `410 Gone`)
- Recommended packages from assessment results can be booked directly via `POST /bookings/packages`
