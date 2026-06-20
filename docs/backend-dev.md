# Questions for Laravel Developer

These are open items discovered during the Flutter ↔ Laravel API integration. The Flutter app has been updated on our side — the items below need confirmation or a small change from you.

---

## 1. AI Chat — what key does the reply come back as?

**Endpoint:** `POST /patients/chat/global/threads/{threadId}/messages`

The app currently looks for the AI reply text under these keys in order: `reply` → `message` → `content`.

**Please confirm which key your response uses**, for example:
```json
{ "reply": "Here is your answer..." }
```
or
```json
{ "message": "Here is your answer..." }
```

---

## 2. AI Chat — lab suggestions in chat response

**Endpoint:** `POST /patients/chat/global/threads/{threadId}/messages`

The app supports the AI suggesting lab tests and packages inside the chat reply. If you want this to work, include these keys in the response:

```json
{
  "reply": "Based on your symptoms, I recommend...",
  "suggestedTests": [
    { "id": 1, "testName": "Complete Blood Count", "basePrice": 250, ... }
  ],
  "suggestedPackages": [
    { "id": 1, "name": "Basic Health Package", "basePrice": 1200, ... }
  ]
}
```

If you don't include them, the chat will still work — suggestions will just be empty.

---

## 3. Document Chat — what key does the reply come back as?

**Endpoint:** `POST /patients/documents/{documentId}/chat`

Same question as above. The app tries `reply` → `message` → `content`. Please confirm which key your response uses.

---

## 4. Vitals GET response — field names for heart rate and temperature

**Endpoint:** `GET /patients/me/vitals`

The app now expects these field names in the vitals trend array (which matches your POST docs):

| Field | Expected key |
|---|---|
| Heart rate / pulse | `pulseRate` |
| Body temperature | `temperature` |
| Blood pressure systolic | `bloodPressureSystolic` |
| Blood pressure diastolic | `bloodPressureDiastolic` |
| Oxygen saturation | `oxygenSaturation` |
| Respiratory rate | `respiratoryRate` |
| Recorded at | `recordedAt` |

**Please make sure the GET response uses the same camelCase keys as the POST body**, not snake_case or different names.

Expected response shape:
```json
{
  "trend": [
    {
      "id": 1,
      "pulseRate": 72,
      "temperature": 36.8,
      "bloodPressureSystolic": 120,
      "bloodPressureDiastolic": 80,
      "oxygenSaturation": 98,
      "respiratoryRate": 16,
      "height": 170,
      "weight": 70,
      "recordedAt": "2026-06-18T10:30:00Z"
    }
  ]
}
```

---

## 5. `GET /patients/me` — response wrapper key

**Endpoint:** `GET /patients/me`

The app expects the patient object wrapped under a `patient` key:
```json
{
  "patient": { "id": 5, "name": "...", ... }
}
```
Please confirm this is the shape your endpoint returns.

---

## 6. Home Offers — response shape

**Endpoint:** `GET /home-offers`

Your docs say this returns "discounted lab packages as offer cards" but don't show the exact schema. The app expects:
```json
{
  "offers": [
    {
      "id": 1,
      "title": "...",
      "subtitle": "...",
      "gradientFrom": "#0C2C6D",
      "gradientTo": "#1A6EAA",
      "buttonBorderColor": "#05B3E6",
      "ctaLabel": "Book Now",
      "ctaTarget": "/lab/packages",
      "sortOrder": 0,
      "isActive": true
    }
  ]
}
```
Please confirm the response matches this shape, or share the actual schema.

---

## 7. `GET /patients/me/dashboard` — full response shape

**Endpoint:** `GET /patients/me/dashboard`

The app expects this full structure. Please confirm all keys are present:

```json
{
  "patient": { ... },
  "metrics": {
    "totalRecords": 0,
    "availableRecords": 0,
    "processingRecords": 0,
    "showingRecords": 0,
    "upcomingBookings": 0
  },
  "recentBookings": [ ... ],
  "recentPrescriptions": [ ... ],
  "recentDocuments": [ ... ],
  "recentSummaries": [ ... ],
  "idCard": {
    "registrationNumber": "PAT-000005",
    "patientName": "Aisha Rahman",
    "membershipTier": "Classic",
    "qrValue": "BHRC-ABCDEFGH",
    "bloodGroup": "O+",
    "barcodeValue": "",
    "memberSince": "2024-01-01"
  },
  "myClub": {
    "patientId": 5,
    "points": 0,
    "currencyValue": 0,
    "tier": "Classic",
    "transactions": []
  },
  "emergencyContacts": [
    { "name": "BHRC Ambulance", "number": "+91 7510210222" }
  ],
  "latestVitals": null
}
```

---

## No action needed from you on these (already handled on Flutter side)

- `POST /bookings` — the app no longer sends extra patient fields (`name`, `phone`, `dob`, `place`). It now only sends `doctorId`, `bookingDate`, `timeslot`, and optional `notes`.
- `POST /patient/lab-package-orders` — the app now sends `packageId` (was previously sending `labPackageId` by mistake).
- `POST /patients/documents` — the app now sends the file under the field name `document` (was `file`).
- `POST /patients/me/vitals` — the app now sends `pulseRate` and `temperature` (was `heartRate` and `bodyTemperature`), and also includes `recordedAt`.
- Base URL — the app now points to `/api/v1`.
