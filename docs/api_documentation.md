# BHRC Hospital Mobile API Documentation

This document describes the mobile-compatible Laravel API. The Flutter app base URL should be:

```text
{{base_url}}/api/v1
```

The endpoints below are registered under `/api/v1`.

## Conventions

- Authenticated requests use `Authorization: Bearer <token>`.
- Mobile responses use camelCase fields.
- Validation errors are returned by Laravel as `message` plus `errors`.
- OTP responses include `dev_otp` outside production.

## Authentication

### Send OTP

`POST /auth/otp/send`

```json
{
  "phone": "+919876543210",
  "mrn": "PAT-000005"
}
```

Response:

```json
{
  "success": true,
  "message": "OTP sent successfully",
  "dev_otp": "123456"
}
```

### Signup

`POST /auth/signup`

```json
{
  "phone": "+919876543210",
  "name": "Aisha Rahman",
  "dob": "1994-04-12",
  "place": "Ponnani, Kerala",
  "email": "aisha@example.com",
  "gender": "female"
}
```

Response is the same OTP response.

### Verify OTP

`POST /auth/otp/verify`

```json
{
  "phone": "+919876543210",
  "otp": "123456"
}
```

Response:

```json
{
  "token": "plain-text-sanctum-token",
  "patient": {
    "id": 5,
    "name": "Aisha Rahman",
    "phone": "+919876543210",
    "registrationNumber": "PAT-000005",
    "uuid": "BHRC-ABCDEFGH",
    "dob": "1994-04-12",
    "gender": "female",
    "age": 32,
    "address": "Ponnani, Kerala",
    "email": "aisha@example.com",
    "bloodGroup": "O+",
    "allergies": null,
    "chronicConditions": null
  }
}
```

### Email Verification

`POST /auth/verification/send`

Authenticated. Sends the normal Laravel signed email verification link.

### Logout

`POST /auth/logout`

Authenticated.

## Home Feed

`GET /home-banners?target=mobile`

```json
{
  "banners": [
    {
      "id": 1,
      "title": "Welcome to BHRC",
      "subtitle": "Leading Healthcare",
      "imageUrl": "https://example.com/banner.jpg",
      "ctaLabel": "Book Now",
      "ctaTarget": "/lab/packages",
      "sortOrder": 0,
      "isActive": true
    }
  ]
}
```

`GET /home-ticker-messages`

```json
{ "messages": [] }
```

`GET /home-offers`

Returns discounted lab packages as offer cards.

## Doctors and Departments

`GET /doctors?search=&specialization=`

```json
{
  "doctors": [
    {
      "id": 1,
      "name": "Dr. Sarah Paul",
      "specialization": "Cardiology",
      "qualifications": "MD",
      "availableTime": "09:00 - 13:00",
      "workingDays": "monday,tuesday",
      "workStartTime": "09:00",
      "workEndTime": "13:00",
      "slotDurationMinutes": 15,
      "departmentName": "Cardiology",
      "email": "doctor@example.com",
      "phone": "+919876543211",
      "imageUrl": null,
      "description": "Senior consultant",
      "consultationFee": 500
    }
  ]
}
```

`GET /departments`

`GET /doctors/{doctorId}/available-slots?date=2026-06-15`

```json
{ "availableSlots": ["09:00-09:15", "09:15-09:30"] }
```

## Lab Catalogue

`GET /patient/lab-tests?search=&category=`

Returns:

```json
{
  "tests": [
    {
      "id": 1,
      "testName": "Complete Blood Count",
      "categoryId": null,
      "categoryName": "Blood",
      "status": true,
      "basePrice": 250,
      "discountedPrice": null,
      "uuid": "LAB-001",
      "imageUrl": null,
      "instructions": "Fasting required",
      "resultEta": null,
      "bodyPoints": []
    }
  ]
}
```

`GET /body-points`

`GET /patient/lab-packages?search=`

Returns package data with `packages`, `includedTests`, `totalTests`, `basePrice`, and `discountedPrice`.

## Patient Profile

All endpoints in this section are authenticated.

`GET /patients/me`

`PATCH /patients/me`

Accepted fields: `name`, `dob`, `gender`, `address`, `email`, `bloodGroup`, `allergies`, `chronicConditions`.

`GET /patients/me/dashboard`

`GET /patients/me/prescriptions`

`GET /patients/me/summaries`

`GET /patients/me/myclub`

`GET /patients/me/vitals`

`POST /patients/me/vitals`

```json
{
  "bloodPressureSystolic": 120,
  "bloodPressureDiastolic": 80,
  "pulseRate": 72,
  "oxygenSaturation": 98,
  "temperature": 36.8,
  "respiratoryRate": 16,
  "height": 170,
  "weight": 70,
  "recordedAt": "2026-06-18T10:30:00Z"
}
```

## Doctor Bookings

Authenticated.

`POST /bookings`

```json
{
  "doctorId": 1,
  "bookingDate": "2026-06-20",
  "timeslot": "09:00-09:15",
  "notes": "First visit"
}
```

Response:

```json
{ "success": true, "bookingId": 42 }
```

`GET /patients/bookings`

`PATCH /patients/bookings/{bookingId}/cancel`

`PATCH /patients/bookings/{bookingId}/check-in`

`PATCH /patients/bookings/{bookingId}/reschedule`

```json
{
  "bookingDate": "2026-06-21",
  "timeslot": "10:00-10:15"
}
```

## Lab Orders

Authenticated.

`GET /patient/lab-orders`

`POST /patient/lab-orders`

```json
{
  "labTestIds": [1, 2],
  "doctorId": 1,
  "date": "2026-06-20",
  "slot": "08:30",
  "collectionType": "home",
  "address": "12, MG Road, Ponnani",
  "amount": 600,
  "paymentStatus": "pending",
  "patientNameSnapshot": "Aisha Rahman",
  "patientAgeSnapshot": 32,
  "patientGenderSnapshot": "female",
  "patientPhoneSnapshot": "+919876543210",
  "bookingRef": "BKG-001",
  "urgency": "routine",
  "notes": "Fasting sample."
}
```

`PATCH /patient/lab-orders/{bookingId}`

For cancel: `{ "status": "cancelled" }`

For reschedule: `{ "date": "2026-06-21", "slot": "09:30" }`

## Lab Package Orders

Authenticated.

`GET /patient/lab-package-orders`

`POST /patient/lab-package-orders`

```json
{
  "packageId": 1,
  "doctorId": 1,
  "date": "2026-06-20",
  "slot": "08:30"
}
```

`PATCH /patient/lab-package-orders/{bookingId}`

## Medical Records and Documents

Authenticated.

`GET /medical-records/me`

`GET /patients/documents`

`POST /patients/documents`

Multipart fields:

- `document`: file, required
- `documentType`: string, optional

`POST /patients/documents/{documentId}/analyze`

Queues an analysis request record and returns `202`.

`DELETE /patients/documents/{documentId}`

`GET /patients/documents/{documentId}/chat`

`POST /patients/documents/{documentId}/chat`

```json
{ "message": "Summarize this report" }
```

## Global AI Chat

Authenticated.

`GET /patients/chat/global/threads`

`POST /patients/chat/global/threads`

```json
{ "title": "General health question" }
```

`GET /patients/chat/global/threads/{threadId}`

`POST /patients/chat/global/threads/{threadId}/messages`

```json
{ "message": "What should I do before a fasting blood test?" }
```

`PATCH /patients/chat/global/threads/{threadId}`

```json
{ "title": "Updated title" }
```

`DELETE /patients/chat/global/threads/{threadId}`

## Legacy API

Some older compatibility routes also remain under `/api/v1`, including password-based auth, old catalogue paths, legacy booking paths, aid endpoints, and legacy chat endpoints. Prefer the mobile-compatible endpoints documented above for the Flutter app.
