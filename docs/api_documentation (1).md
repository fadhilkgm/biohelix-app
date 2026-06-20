# BHRC Hospital API Documentation

This document describes the API routes currently registered in `routes/api.php`.

Base URL:

```text
{{base_url}}/api/v1
```

## Conventions

- Send JSON requests with `Accept: application/json` and `Content-Type: application/json`.
- Authenticated routes require `Authorization: Bearer <token>`.
- File upload routes use `multipart/form-data`.
- Validation errors are returned by Laravel with `message` and `errors`.
- The mobile-first routes use camelCase fields. Legacy routes keep their existing snake_case response and request fields.
- OTP responses include `dev_otp` outside production.

## Mobile Authentication

### Send OTP

`POST /auth/otp/send`

Looks up an existing patient by phone. `mrn` may match `patient_number` or `patient_card_number`.

Sample input:

```json
{
  "phone": "+919876543210",
  "mrn": "PAT-000005",
  "email": false
}
```

Sample response:

```json
{
  "success": true,
  "message": "OTP sent successfully",
  "dev_otp": "123456"
}
```

### Signup

`POST /auth/signup`

Creates a patient/user account and sends an OTP.

Sample input:

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

Sample response:

```json
{
  "success": true,
  "message": "OTP sent successfully",
  "dev_otp": "123456"
}
```

### Verify OTP

`POST /auth/otp/verify`

Sample input:

```json
{
  "phone": "+919876543210",
  "otp": "123456"
}
```

Sample response:

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

### Email Verification Link

`GET /auth/email/verify/{id}/{hash}?expires=...&signature=...`

This is the signed Laravel email verification callback. It has no JSON request body.

### Logout

`POST /auth/logout`

Authenticated. No request body.

Sample response:

```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

### Send Email Verification

`POST /auth/verification/send`

Authenticated. No request body.

Sample response:

```json
{
  "success": true,
  "message": "Verification email sent"
}
```

## Mobile Home Feed

### Home Banners

`GET /home-banners?target=mobile`

No request body.

Sample response:

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

### Home Ticker Messages

`GET /home-ticker-messages`

No request body.

Sample response:

```json
{
  "messages": []
}
```

### Home Offers

`GET /home-offers`

No request body.

Sample response:

```json
{
  "offers": [
    {
      "id": 1,
      "title": "Basic Health Package",
      "subtitle": "Discounted preventive package",
      "gradientFrom": "#0C2C6D",
      "gradientTo": "#1A6EAA",
      "buttonBorderColor": "#05B3E6",
      "ctaLabel": "Book Now",
      "ctaTarget": "/lab/packages/1",
      "sortOrder": 0,
      "isActive": true
    }
  ]
}
```

## Mobile Catalogue

### Doctors

`GET /doctors?search=sarah&specialization=Cardiology`

No request body.

Sample response:

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

### Doctor Available Slots

`GET /doctors/{doctorId}/available-slots?date=2026-06-22`

No request body. `date` is required.

Sample response:

```json
{
  "availableSlots": ["09:00-09:15", "09:15-09:30"]
}
```

### Departments

`GET /departments`

No request body.

Sample response:

```json
{
  "departments": [
    {
      "id": 1,
      "name": "Cardiology",
      "imageUrl": null
    }
  ]
}
```

### Patient Lab Tests

`GET /patient/lab-tests?search=blood&category=Blood`

No request body.

Sample response:

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

### Patient Lab Packages

`GET /patient/lab-packages?search=basic`

No request body.

Sample response:

```json
{
  "packages": [
    {
      "id": 1,
      "name": "Basic Health Package",
      "slug": "basic-health-package",
      "status": true,
      "basePrice": 1200,
      "discountedPrice": 999,
      "description": "Preventive health screening",
      "category": "Package",
      "imageUrl": null,
      "instructions": null,
      "resultEta": null,
      "totalTests": 2,
      "includedTests": [
        {
          "testName": "Complete Blood Count"
        }
      ]
    }
  ]
}
```

### Body Points

`GET /body-points`

No request body.

Sample response:

```json
{
  "bodyPoints": [
    {
      "id": 1,
      "name": "Chest",
      "slug": "chest",
      "imageX": 52.5,
      "imageY": 31.2,
      "status": true
    }
  ]
}
```

## Mobile Patient Profile

All routes in this section are authenticated.

### Current Patient

`GET /patients/me`

No request body.

Sample response:

```json
{
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

### Update Current Patient

`PATCH /patients/me`

Sample input:

```json
{
  "name": "Aisha Rahman",
  "dob": "1994-04-12",
  "gender": "female",
  "age": 32,
  "address": "Ponnani, Kerala",
  "email": "aisha@example.com",
  "bloodGroup": "O+",
  "allergies": "Penicillin",
  "chronicConditions": "Diabetes"
}
```

Sample response:

```json
{
  "patient": {
    "id": 5,
    "name": "Aisha Rahman",
    "phone": "+919876543210",
    "registrationNumber": "PAT-000005",
    "uuid": "BHRC-ABCDEFGH"
  }
}
```

### Dashboard

`GET /patients/me/dashboard`

No request body.

Sample response:

```json
{
  "patient": {},
  "metrics": {
    "totalRecords": 0,
    "availableRecords": 0,
    "processingRecords": 0,
    "showingRecords": 0,
    "upcomingBookings": 0
  },
  "upcomingBookings": [],
  "recentBookings": [],
  "recentPrescriptions": [],
  "recentDocuments": [],
  "recentSummaries": [],
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
    {
      "name": "BHRC Ambulance",
      "number": "+91 7510210222"
    }
  ],
  "latestVitals": null
}
```

### Prescriptions

`GET /patients/me/prescriptions`

No request body.

Sample response:

```json
{
  "prescriptions": []
}
```

### Summaries

`GET /patients/me/summaries`

No request body.

Sample response:

```json
{
  "summaries": [
    {
      "id": 1,
      "title": "blood-report.pdf",
      "status": "completed",
      "summary": "Report summary",
      "riskLevel": "low",
      "createdAt": "2026-06-20T10:30:00.000000Z"
    }
  ]
}
```

### MyClub

`GET /patients/me/myclub`

No request body.

Sample response:

```json
{
  "myClub": {
    "membership": {
      "id": 1,
      "planName": "Gold",
      "startDate": "2026-01-01",
      "expiryDate": "2026-12-31",
      "status": "active"
    },
    "pointsBalance": 120,
    "plans": [
      {
        "id": 1,
        "name": "Gold",
        "durationDays": 365,
        "price": 2500,
        "benefits": ["Priority booking"],
        "discountPercentage": 10
      }
    ]
  }
}
```

### Vitals

`GET /patients/me/vitals`

No request body.

Sample response:

```json
{
  "trend": [
    {
      "id": 1,
      "bloodPressureSystolic": 120,
      "bloodPressureDiastolic": 80,
      "pulseRate": 72,
      "oxygenSaturation": 98,
      "temperature": 36.8,
      "respiratoryRate": 16,
      "height": 170,
      "weight": 70,
      "bmi": 24.22,
      "recordedAt": "2026-06-20T10:30:00.000000Z"
    }
  ],
  "vitals": [
    {
      "id": 1,
      "bloodPressureSystolic": 120,
      "bloodPressureDiastolic": 80,
      "pulseRate": 72,
      "oxygenSaturation": 98,
      "temperature": 36.8,
      "respiratoryRate": 16,
      "height": 170,
      "weight": 70,
      "bmi": 24.22,
      "recordedAt": "2026-06-20T10:30:00.000000Z"
    }
  ]
}
```

### Save Vitals

`POST /patients/me/vitals`

Sample input:

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
  "recordedAt": "2026-06-20T10:30:00Z"
}
```

Sample response:

```json
{
  "vital": {
    "id": 1,
    "bloodPressureSystolic": 120,
    "bloodPressureDiastolic": 80,
    "pulseRate": 72,
    "oxygenSaturation": 98,
    "temperature": 36.8,
    "respiratoryRate": 16,
    "height": 170,
    "weight": 70,
    "bmi": 24.22,
    "recordedAt": "2026-06-20T10:30:00.000000Z"
  }
}
```

## Mobile Bookings

All routes in this section are authenticated.

### Create Doctor Booking

`POST /bookings`

Sample input:

```json
{
  "doctorId": 1,
  "bookingDate": "2026-06-22",
  "timeslot": "09:00-09:15",
  "notes": "First visit"
}
```

Sample response:

```json
{
  "success": true,
  "bookingId": 42
}
```

### List Patient Bookings

`GET /patients/bookings`

No request body.

Sample response:

```json
{
  "bookings": [
    {
      "id": 42,
      "bookingDate": "2026-06-22",
      "timeslot": "09:00-09:15",
      "status": "pending",
      "type": "doctor",
      "doctorId": 1,
      "doctorName": "Dr. Sarah Paul",
      "doctorSpecialization": "Cardiology",
      "testName": null,
      "packageName": null
    }
  ]
}
```

### Cancel Booking

`PATCH /patients/bookings/{bookingId}/cancel`

No request body.

Sample response:

```json
{
  "success": true
}
```

### Check In Booking

`PATCH /patients/bookings/{bookingId}/check-in`

No request body.

Sample response:

```json
{
  "success": true
}
```

### Reschedule Booking

`PATCH /patients/bookings/{bookingId}/reschedule`

Sample input:

```json
{
  "bookingDate": "2026-06-23",
  "timeslot": "10:00-10:15"
}
```

Sample response:

```json
{
  "success": true
}
```

## Mobile Lab Orders

All routes in this section are authenticated.

### List Lab Orders

`GET /patient/lab-orders`

No request body.

Sample response:

```json
{
  "orders": [
    {
      "id": 52,
      "batchId": "9d0dbd83-c4e2-49a1-b8bc-2e2b8bf49d88",
      "labTestId": 1,
      "testName": "Complete Blood Count",
      "doctorId": 1,
      "doctorName": "Dr. Sarah Paul",
      "date": "2026-06-22",
      "slot": "08:30",
      "status": "pending",
      "paymentStatus": "unpaid"
    }
  ]
}
```

### Create Lab Order

`POST /patient/lab-orders`

Use either `labTestIds` or `labTestId`. Optional extra fields are stored inside booking notes.

Sample input:

```json
{
  "labTestIds": [1, 2],
  "doctorId": 1,
  "date": "2026-06-22",
  "slot": "08:30",
  "paymentStatus": "paid",
  "collectionType": "home",
  "address": "12, MG Road, Ponnani",
  "amount": 600,
  "patientNameSnapshot": "Aisha Rahman",
  "patientAgeSnapshot": 32,
  "patientGenderSnapshot": "female",
  "patientPhoneSnapshot": "+919876543210",
  "bookingRef": "BKG-001",
  "urgency": "routine",
  "notes": "Fasting sample."
}
```

Sample response:

```json
{
  "success": true,
  "batchId": "9d0dbd83-c4e2-49a1-b8bc-2e2b8bf49d88"
}
```

### Update Lab Order

`PATCH /patient/lab-orders/{bookingId}`

Sample input:

```json
{
  "status": "cancelled",
  "date": "2026-06-23",
  "slot": "09:30"
}
```

Sample response:

```json
{
  "success": true
}
```

## Mobile Lab Package Orders

All routes in this section are authenticated.

### List Lab Package Orders

`GET /patient/lab-package-orders`

No request body.

Sample response:

```json
{
  "orders": [
    {
      "id": 60,
      "packageId": 1,
      "packageName": "Basic Health Package",
      "doctorId": 1,
      "doctorName": "Dr. Sarah Paul",
      "date": "2026-06-22",
      "slot": "08:30",
      "status": "pending",
      "paymentStatus": "unpaid"
    }
  ]
}
```

### Create Lab Package Order

`POST /patient/lab-package-orders`

Sample input:

```json
{
  "packageId": 1,
  "doctorId": 1,
  "date": "2026-06-22",
  "slot": "08:30",
  "paymentStatus": "partial",
  "collectionType": "home",
  "address": "12, MG Road, Ponnani",
  "amount": 999,
  "notes": "Morning collection preferred."
}
```

Sample response:

```json
{
  "success": true,
  "bookingId": 60
}
```

### Update Lab Package Order

`PATCH /patient/lab-package-orders/{bookingId}`

Sample input:

```json
{
  "status": "pending",
  "date": "2026-06-23",
  "slot": "09:30"
}
```

Sample response:

```json
{
  "success": true
}
```

## Mobile Records, Documents, And Chat

All routes in this section are authenticated.

### Medical Records

`GET /medical-records/me`

No request body.

Sample response:

```json
{
  "records": [
    {
      "id": "document-1",
      "type": "document",
      "title": "blood-report.pdf",
      "date": "2026-06-20",
      "summary": "uploaded",
      "data": {}
    }
  ]
}
```

### List Documents

`GET /patients/documents`

No request body.

Sample response:

```json
{
  "documents": [
    {
      "id": 1,
      "documentType": "lab_report",
      "sourceType": "mobile",
      "fileName": "blood-report.pdf",
      "fileUrl": "https://example.com/blood-report.pdf",
      "fileSize": 120000,
      "mimeType": "application/pdf",
      "uploadedAt": "2026-06-20T10:30:00.000000Z"
    }
  ]
}
```

### Upload Document

`POST /patients/documents`

Multipart sample input:

```text
document=@/path/to/blood-report.pdf
documentType=lab_report
```

Allowed files: `jpg`, `jpeg`, `png`, `pdf`, `webp`; max size `20480 KB`.

Sample response:

```json
{
  "document": {
    "id": 1,
    "documentType": "lab_report",
    "sourceType": "mobile",
    "fileName": "blood-report.pdf",
    "fileUrl": "https://example.com/blood-report.pdf",
    "fileSize": 120000,
    "mimeType": "application/pdf",
    "uploadedAt": "2026-06-20T10:30:00.000000Z"
  }
}
```

### Analyze Document

`POST /patients/documents/{documentId}/analyze`

No request body.

Sample response:

```json
{
  "success": true,
  "analysisId": 15,
  "status": "queued"
}
```

### Delete Document

`DELETE /patients/documents/{documentId}`

No request body.

Sample response:

```json
{
  "success": true
}
```

### Document Chat Messages

`GET /patients/documents/{documentId}/chat`

No request body.

Sample response:

```json
{
  "messages": [
    {
      "id": 1,
      "role": "assistant",
      "message": "Here is the answer...",
      "createdAt": "2026-06-20T10:30:00.000000Z"
    }
  ]
}
```

### Send Document Chat Message

`POST /patients/documents/{documentId}/chat`

Sample input:

```json
{
  "message": "Summarize this report"
}
```

Sample response:

```json
{
  "reply": "Here is the answer...",
  "content": "Here is the answer...",
  "message": {
    "id": 1,
    "role": "assistant",
    "message": "Here is the answer...",
    "createdAt": "2026-06-20T10:30:00.000000Z"
  },
  "suggestedTests": [],
  "suggestedPackages": []
}
```

## Mobile Global AI Chat

All routes in this section are authenticated.

### List Threads

`GET /patients/chat/global/threads`

No request body.

Sample response:

```json
{
  "threads": [
    {
      "id": 1,
      "title": "General health question",
      "status": "active",
      "messageCount": 2,
      "createdAt": "2026-06-20T10:30:00.000000Z",
      "updatedAt": "2026-06-20T10:35:00.000000Z"
    }
  ]
}
```

### Create Thread

`POST /patients/chat/global/threads`

Sample input:

```json
{
  "title": "General health question"
}
```

Sample response:

```json
{
  "thread": {
    "id": 1,
    "title": "General health question",
    "status": "active",
    "messageCount": 0,
    "createdAt": "2026-06-20T10:30:00.000000Z",
    "updatedAt": "2026-06-20T10:30:00.000000Z"
  }
}
```

### Show Thread

`GET /patients/chat/global/threads/{threadId}`

No request body.

Sample response:

```json
{
  "thread": {
    "id": 1,
    "title": "General health question",
    "status": "active",
    "messageCount": 2,
    "createdAt": "2026-06-20T10:30:00.000000Z",
    "updatedAt": "2026-06-20T10:35:00.000000Z"
  },
  "messages": []
}
```

### Send Thread Message

`POST /patients/chat/global/threads/{threadId}/messages`

Sample input:

```json
{
  "message": "What should I do before a fasting blood test?"
}
```

Sample response:

```json
{
  "reply": "Here is the answer...",
  "content": "Here is the answer...",
  "message": {
    "id": 2,
    "role": "assistant",
    "message": "Here is the answer...",
    "createdAt": "2026-06-20T10:35:00.000000Z"
  },
  "suggestedTests": [],
  "suggestedPackages": []
}
```

### Rename Thread

`PATCH /patients/chat/global/threads/{threadId}`

Sample input:

```json
{
  "title": "Updated title"
}
```

Sample response:

```json
{
  "thread": {
    "id": 1,
    "title": "Updated title",
    "status": "active",
    "messageCount": 2,
    "createdAt": "2026-06-20T10:30:00.000000Z",
    "updatedAt": "2026-06-20T10:40:00.000000Z"
  }
}
```

### Delete Thread

`DELETE /patients/chat/global/threads/{threadId}`

No request body.

Sample response:

```json
{
  "success": true
}
```

## Legacy Authentication

These routes are still registered under `/api/v1` for older clients.

### Register

`POST /auth/register`

Sample input:

```json
{
  "phone": "+919876543210",
  "password": "secret-password",
  "password_confirmation": "secret-password",
  "first_name": "Aisha",
  "last_name": "Rahman",
  "gender": "female",
  "email": "aisha@example.com",
  "date_of_birth": "1994-04-12",
  "blood_group": "O+"
}
```

Sample response:

```json
{
  "token": "plain-text-sanctum-token",
  "patient": {
    "id": 5,
    "patient_number": "PAT-000005",
    "patient_card_number": "BHRC-ABCDEFGH",
    "first_name": "Aisha",
    "last_name": "Rahman",
    "full_name": "Aisha Rahman",
    "gender": "female",
    "phone": "+919876543210",
    "email": "aisha@example.com",
    "date_of_birth": "1994-04-12",
    "blood_group": "O+",
    "status": "active",
    "registration_date": "2026-06-20",
    "email_verified": false
  },
  "verification": {
    "required": true,
    "channels": ["email"]
  }
}
```

### Login

`POST /auth/login`

Sample input:

```json
{
  "phone": "+919876543210",
  "password": "secret-password"
}
```

Alternative input:

```json
{
  "email": "aisha@example.com",
  "password": "secret-password"
}
```

Sample response:

```json
{
  "token": "plain-text-sanctum-token",
  "patient": {
    "id": 5,
    "patient_number": "PAT-000005",
    "full_name": "Aisha Rahman"
  },
  "verification": {
    "required": false,
    "channels": []
  }
}
```

### Legacy Profile

`GET /auth/profile`

Authenticated. No request body.

Sample response:

```json
{
  "id": 5,
  "patient_number": "PAT-000005",
  "patient_card_number": "BHRC-ABCDEFGH",
  "first_name": "Aisha",
  "last_name": "Rahman",
  "full_name": "Aisha Rahman",
  "gender": "female",
  "phone": "+919876543210",
  "email": "aisha@example.com",
  "date_of_birth": "1994-04-12",
  "blood_group": "O+",
  "status": "active",
  "registration_date": "2026-06-20",
  "email_verified": true
}
```

### Legacy Send Verification

`POST /auth/verification/send`

Authenticated. This current route is wired to email verification and ignores a channel body.

Sample input:

```json
{}
```

Sample response:

```json
{
  "success": true,
  "message": "Verification email sent"
}
```

### Legacy Verify OTP

`POST /auth/verification/otp`

Authenticated.

Sample input:

```json
{
  "otp": "123456"
}
```

Sample response:

```json
{
  "message": "Phone verified successfully."
}
```

## Legacy Public Catalogue

### Lab Packages

`GET /lab/packages?search=basic&page=1`

No request body.

Sample response:

```json
{
  "data": [
    {
      "id": 1,
      "package_code": "PKG-001",
      "package_name": "Basic Health Package",
      "description": "Preventive health screening",
      "price": 1200,
      "discounted_price": 999,
      "validity": null,
      "status": "active",
      "image_path": null,
      "image_url": null,
      "tests": [],
      "test_count": 2,
      "created_at": "2026-06-20T10:30:00.000000Z"
    }
  ],
  "links": {},
  "meta": {}
}
```

### Lab Tests

`GET /lab/tests?search=blood&category=Blood&page=1`

No request body.

Sample response:

```json
{
  "data": [
    {
      "id": 1,
      "test_code": "LAB-001",
      "test_name": "Complete Blood Count",
      "category": "Blood",
      "body_part": null,
      "price": 250,
      "description": "Fasting required",
      "status": "active",
      "created_at": "2026-06-20T10:30:00.000000Z"
    }
  ],
  "links": {},
  "meta": {}
}
```

### Lab Body Points

`GET /lab/body-points`

No request body.

Sample response:

```json
{
  "data": [
    {
      "id": 1,
      "label": "Chest",
      "body_part": "chest",
      "x": 52.5,
      "y": 31.2,
      "tests": []
    }
  ],
  "meta": {
    "total": 1,
    "image_aspect": 0.666667,
    "image_width": 1024,
    "image_height": 1536
  }
}
```

### Legacy Doctors

`GET /doctors?search=sarah&specialization=Cardiology`

This shares the same response shape as the mobile doctors endpoint.

### Banners

`GET /banners?position=hero&target=mobile`

No request body.

Sample response:

```json
{
  "data": [
    {
      "id": 1,
      "title": "Welcome to BHRC",
      "subtitle": "Leading Healthcare",
      "description": null,
      "image_path": "banners/welcome.jpg",
      "image_url": "https://example.com/banner.jpg",
      "link": "/book",
      "button_text": "Book Now",
      "button_link": "/book",
      "position": "hero",
      "target": "mobile",
      "is_active": true,
      "sort_order": 0,
      "created_at": "2026-06-20T10:30:00.000000Z",
      "updated_at": "2026-06-20T10:30:00.000000Z"
    }
  ]
}
```

## Legacy Bookings

All routes in this section are authenticated.

### Book Package

`POST /bookings/packages`

Sample input:

```json
{
  "package_id": 1,
  "booking_date": "2026-06-22",
  "booking_time": "08:30",
  "notes": "Morning slot preferred"
}
```

Sample response:

```json
{
  "id": 60,
  "booking_number": "BKG-000060",
  "booking_type": "package",
  "booking_date": "2026-06-22",
  "booking_time": "08:30",
  "status": "pending",
  "payment_status": "unpaid",
  "package_id": 1
}
```

### Cancel Package Booking

`PATCH /bookings/packages/{bookingId}/cancel`

No request body.

Sample response:

```json
{
  "message": "Package booking cancelled successfully."
}
```

### Book Tests

`POST /bookings/tests`

Sample input:

```json
{
  "test_ids": [1, 2],
  "booking_date": "2026-06-22",
  "booking_time": "08:30",
  "notes": "Fasting sample"
}
```

Sample response:

```json
{
  "batch_id": "9d0dbd83-c4e2-49a1-b8bc-2e2b8bf49d88",
  "bookings": [
    {
      "id": 52,
      "booking_type": "test",
      "booking_date": "2026-06-22",
      "booking_time": "08:30",
      "status": "pending",
      "test_id": 1
    }
  ]
}
```

### Cancel Test Booking Batch

`PATCH /bookings/tests/{batchId}/cancel`

No request body.

Sample response:

```json
{
  "message": "Test bookings cancelled successfully."
}
```

### Book Doctor

`POST /bookings/doctors`

Sample input:

```json
{
  "doctor_id": 1,
  "schedule_id": 3,
  "booking_date": "2026-06-22",
  "booking_time": "09:00",
  "notes": "First visit"
}
```

Sample response:

```json
{
  "id": 42,
  "booking_number": "BKG-000042",
  "booking_type": "doctor",
  "booking_date": "2026-06-22",
  "booking_time": "09:00",
  "status": "pending",
  "payment_status": "unpaid",
  "doctor_id": 1,
  "schedule_id": 3
}
```

### Cancel Doctor Booking

`PATCH /bookings/doctors/{bookingId}/cancel`

No request body.

Sample response:

```json
{
  "message": "Doctor booking cancelled successfully."
}
```

## Aid

### List Approved Aid Requests

`GET /aid?applicant_type=individual&search=surgery&page=1`

Public. No request body.

Sample response:

```json
{
  "data": [
    {
      "id": 1,
      "reference_code": "AID-ABCD1234",
      "applicant_type": "individual",
      "organisation_name": null,
      "reason": "Medical treatment support request...",
      "requested_amount": 50000,
      "raised_amount": 10000,
      "status": "approved",
      "created_at": "2026-06-20T10:30:00.000000Z"
    }
  ],
  "links": {},
  "meta": {}
}
```

### Show Approved Aid Request

`GET /aid/{aidRequestId}`

Public. No request body.

Sample response:

```json
{
  "id": 1,
  "reference_code": "AID-ABCD1234",
  "applicant_type": "individual",
  "organisation_name": null,
  "reason": "Medical treatment support request...",
  "requested_amount": 50000,
  "raised_amount": 10000,
  "status": "approved",
  "created_at": "2026-06-20T10:30:00.000000Z",
  "updated_at": "2026-06-20T10:30:00.000000Z",
  "proof_documents": [],
  "contributions": []
}
```

### Contribute To Aid Request

`POST /aid/{aidRequestId}/contribute`

Public. Provide `amount`, `note`, or both.

Sample input:

```json
{
  "amount": 500,
  "note": "Wishing a quick recovery."
}
```

Sample response:

```json
{
  "success": true,
  "message": "Thank you for your contribution! It has been recorded."
}
```

### Submit Aid Request

`POST /aid`

Authenticated. Multipart request.

Multipart sample input:

```text
applicant_type=individual
patient_name=Aisha Rahman
recipient_name=Aisha Rahman
organiser_name=Family Member
primary_bank_name=State Bank
primary_bank_account_name=Aisha Rahman
primary_bank_account_number=1234567890
upi_id=aisha@upi
upi_name=Aisha Rahman
reason=This request explains the medical need in at least fifty characters.
requested_amount=50000
proof_documents[]=@/path/to/estimate.pdf
proof_documents[]=@/path/to/report.pdf
```

Organisation-specific fields:

```text
applicant_type=organisation
organisation_name=Helping Hands Trust
organisation_reg_number=REG-12345
```

Sample response:

```json
{
  "success": true,
  "reference_code": "AID-ABCD1234",
  "message": "Aid request submitted successfully. Our team will review it shortly.",
  "aid_request": {
    "id": 1,
    "reference_code": "AID-ABCD1234",
    "applicant_type": "individual",
    "reason": "This request explains the medical need in at least fifty characters.",
    "requested_amount": 50000,
    "status": "pending",
    "created_at": "2026-06-20T10:30:00.000000Z"
  }
}
```

### Lookup Aid Request

`POST /aid/lookup`

Authenticated.

Sample input:

```json
{
  "reference_code": "AID-ABCD1234"
}
```

Sample response:

```json
{
  "id": 1,
  "reference_code": "AID-ABCD1234",
  "applicant_type": "individual",
  "organisation_name": null,
  "reason": "Medical treatment support request...",
  "requested_amount": 50000,
  "raised_amount": 10000,
  "status": "pending",
  "admin_note": null,
  "created_at": "2026-06-20T10:30:00.000000Z",
  "updated_at": "2026-06-20T10:30:00.000000Z"
}
```

## Legacy AI Chat

All routes in this section are authenticated.

### List Conversations

`GET /chat/conversations?page=1`

No request body.

Sample response:

```json
{
  "data": [
    {
      "id": 1,
      "patient_id": 5,
      "analysis_request_id": null,
      "title": "New Conversation",
      "status": "active",
      "messages_count": 2,
      "analysis_request": null
    }
  ],
  "links": {},
  "meta": {}
}
```

### Create Conversation

`POST /chat/conversations`

JSON sample input:

```json
{
  "title": "Report questions"
}
```

Multipart sample input with document:

```text
title=Report questions
document=@/path/to/blood-report.pdf
```

Allowed files: `jpg`, `jpeg`, `png`, `pdf`, `webp`; max size `20480 KB`.

Sample response:

```json
{
  "conversation": {
    "id": 1,
    "patient_id": 5,
    "analysis_request_id": 10,
    "title": "blood-report.pdf",
    "status": "active"
  },
  "analysis_status": "completed"
}
```

### Show Conversation

`GET /chat/conversations/{conversationId}`

No request body.

Sample response:

```json
{
  "conversation": {
    "id": 1,
    "title": "Report questions",
    "status": "active",
    "analysis_request_id": 10,
    "created_at": "2026-06-20T10:30:00.000000Z"
  },
  "messages": [
    {
      "id": 1,
      "role": "assistant",
      "message": "Here is the answer...",
      "created_at": "2026-06-20T10:30:00.000000Z"
    }
  ]
}
```

### Send Conversation Message

`POST /chat/conversations/{conversationId}/messages`

Sample input:

```json
{
  "message": "Explain this report in simple terms."
}
```

Sample response:

```json
{
  "id": 2,
  "role": "assistant",
  "message": "Here is the answer...",
  "created_at": "2026-06-20T10:35:00.000000Z"
}
```

### Delete Conversation

`DELETE /chat/conversations/{conversationId}`

No request body.

Sample response:

```json
{
  "message": "Conversation deleted."
}
```
