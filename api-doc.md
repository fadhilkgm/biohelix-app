# BHRC Hospital API Documentation (v1)

This documentation provides details for all endpoints exposed under the `/api/v1` namespace. It is designed to help mobile (Flutter) developers construct clean API clients, serialization models, and request flows.

---

## Table of Contents
1. [General Information](#general-information)
2. [Authentication Endpoints](#1-authentication-endpoints)
   - [Register Patient](#register-patient-post)
   - [Login Patient](#login-patient-post)
   - [Get Profile](#get-profile-get)
   - [Logout](#logout-post)
3. [Public Catalogue Endpoints](#2-public-catalogue-endpoints)
   - [List Lab Packages](#list-lab-packages-get)
   - [List Lab Tests](#list-lab-tests-get)
   - [List Doctors](#list-doctors-get)
4. [Booking Endpoints](#3-booking-endpoints)
   - [Book Package](#book-package-post)
   - [Cancel Package Booking](#cancel-package-booking-patch)
   - [Book Tests (Batch)](#book-tests-batch-post)
   - [Cancel Test Booking Batch](#cancel-test-booking-batch-patch)
   - [Book Doctor](#book-doctor-post)
   - [Cancel Doctor Booking](#cancel-doctor-booking-patch)
5. [Flutter Integration Guidelines](#5-flutter-integration-guidelines)

---

## General Information

- **Base URL**: `http://localhost:8000/api/v1` (or your production server URL)
- **Content-Type**: `application/json`
- **Accept**: `application/json` (Required for Laravel validation exceptions to return JSON instead of HTML redirects)
- **Authentication**: Bearer Token via Laravel Sanctum. Include the header `Authorization: Bearer <your_token>` on protected routes.

---

## 1. Authentication Endpoints

### Register Patient [POST]
Creates a new patient profile and returns a session Bearer token.

- **URL**: `/auth/register`
- **Headers**:
  ```http
  Accept: application/json
  Content-Type: application/json
  ```
- **Request Body**:
  ```json
  {
    "phone": "+919876543210",
    "password": "password123",
    "password_confirmation": "password123",
    "first_name": "Aisha",
    "last_name": "Rahman",
    "gender": "female",
    "email": "aisha.rahman@example.com",
    "date_of_birth": "1994-04-12",
    "blood_group": "O+"
  }
  ```
- **Sample Success Response (201 Created)**:
  ```json
  {
    "token": "1|abc123token...",
    "patient": {
      "id": 5,
      "patient_number": "PT-000005",
      "patient_card_number": "BHRC-1234-5678",
      "first_name": "Aisha",
      "last_name": "Rahman",
      "full_name": "Aisha Rahman",
      "gender": "female",
      "phone": "+919876543210",
      "email": "aisha.rahman@example.com",
      "date_of_birth": "1994-04-12",
      "blood_group": "O+",
      "status": "active",
      "registration_date": "2026-06-13"
    }
  }
  ```

---

### Login Patient [POST]
Authenticates an existing patient by phone and password.

- **URL**: `/auth/login`
- **Headers**:
  ```http
  Accept: application/json
  Content-Type: application/json
  ```
- **Request Body**:
  ```json
  {
    "phone": "+919876543210",
    "password": "password123"
  }
  ```
- **Sample Success Response (200 OK)**:
  ```json
  {
    "token": "2|def456token...",
    "patient": {
      "id": 5,
      "patient_number": "PT-000005",
      "patient_card_number": "BHRC-1234-5678",
      "first_name": "Aisha",
      "last_name": "Rahman",
      "full_name": "Aisha Rahman",
      "gender": "female",
      "phone": "+919876543210",
      "email": "aisha.rahman@example.com",
      "date_of_birth": "1994-04-12",
      "blood_group": "O+",
      "status": "active",
      "registration_date": "2026-06-13"
    }
  }
  ```

---

### Get Profile [GET]
Retrieve the profile details of the currently authenticated patient.

- **URL**: `/auth/profile`
- **Headers**:
  ```http
  Accept: application/json
  Authorization: Bearer <your_token>
  ```
- **Sample Success Response (200 OK)**:
  ```json
  {
    "id": 5,
    "patient_number": "PT-000005",
    "patient_card_number": "BHRC-1234-5678",
    "first_name": "Aisha",
    "last_name": "Rahman",
    "full_name": "Aisha Rahman",
    "gender": "female",
    "phone": "+919876543210",
    "email": "aisha.rahman@example.com",
    "date_of_birth": "1994-04-12",
    "blood_group": "O+",
    "status": "active",
    "registration_date": "2026-06-13"
  }
  ```

---

### Logout [POST]
Invalidates the Bearer token currently being used for authentication.

- **URL**: `/auth/logout`
- **Headers**:
  ```http
  Accept: application/json
  Authorization: Bearer <your_token>
  ```
- **Sample Success Response (200 OK)**:
  ```json
  {
    "message": "Logged out successfully."
  }
  ```

---

## 2. Public Catalogue Endpoints

### List Lab Packages [GET]
Retrieves all active health checkup packages. Paginated by 20.

- **URL**: `/lab/packages`
- **Query Parameters**:
  - `search` (Optional): Filter packages by name (uses soft matching).
- **Headers**:
  ```http
  Accept: application/json
  ```
- **Sample Success Response (200 OK)**:
  ```json
  {
    "data": [
      {
        "id": 1,
        "package_code": "GEN-01",
        "package_name": "Genomic Wellness Panel",
        "description": "Comprehensive genomic panel assessing 120+ health markers.",
        "price": "999.00",
        "discounted_price": null,
        "validity": 30,
        "status": "active",
        "image_path": "packages/genomic.jpg",
        "image_url": "https://storage.r2.cloudflare.com/biohelix/packages/genomic.jpg",
        "tests": [
          {
            "id": 1,
            "test_code": "TS-001",
            "test_name": "Thyroid Stimulating Hormone (TSH)",
            "price": "250.00"
          },
          {
            "id": 2,
            "test_code": "CBC-01",
            "test_name": "Complete Blood Count (CBC)",
            "price": "350.00"
          }
        ],
        "test_count": 2,
        "created_at": "2026-06-13T07:00:00.000000Z"
      }
    ],
    "links": {
      "first": "http://localhost:8000/api/v1/lab/packages?page=1",
      "last": "http://localhost:8000/api/v1/lab/packages?page=1",
      "prev": null,
      "next": null
    },
    "meta": {
      "current_page": 1,
      "from": 1,
      "last_page": 1,
      "path": "http://localhost:8000/api/v1/lab/packages",
      "per_page": 20,
      "to": 1,
      "total": 1
    }
  }
  ```

---

### List Lab Tests [GET]
Retrieves all active laboratory tests. Paginated by 30.

- **URL**: `/lab/tests`
- **Query Parameters**:
  - `category` (Optional): Filter by exact category string (e.g. `Blood`, `Thyroid`).
  - `search` (Optional): Filter tests by name.
- **Headers**:
  ```http
  Accept: application/json
  ```
- **Sample Success Response (200 OK)**:
  ```json
  {
    "data": [
      {
        "id": 1,
        "test_code": "TS-001",
        "test_name": "Thyroid Stimulating Hormone (TSH)",
        "category": "Thyroid",
        "body_part": "Blood",
        "price": "250.00",
        "description": "Measures the amount of TSH in the blood.",
        "status": "active",
        "created_at": "2026-06-13T07:00:00.000000Z"
      }
    ],
    "links": {
      "first": "http://localhost:8000/api/v1/lab/tests?page=1",
      "last": "http://localhost:8000/api/v1/lab/tests?page=1",
      "prev": null,
      "next": null
    },
    "meta": {
      "current_page": 1,
      "from": 1,
      "last_page": 1,
      "path": "http://localhost:8000/api/v1/lab/tests",
      "per_page": 30,
      "to": 1,
      "total": 1
    }
  }
  ```

---

### List Doctors [GET]
Retrieves all active doctor listings along with their respective weekly schedule templates. Paginated by 15.

- **URL**: `/doctors`
- **Query Parameters**:
  - `specialization` (Optional): Filter doctors by exact specialization.
  - `search` (Optional): Search doctors by name or specialization text.
- **Headers**:
  ```http
  Accept: application/json
  ```
- **Sample Success Response (200 OK)**:
  ```json
  {
    "data": [
      {
        "id": 1,
        "doctor_code": "DOC-001",
        "name": "Dr. Sarah Paul",
        "specialization": "Cardiology",
        "qualification": "MD, DM (Cardiology)",
        "registration_number": "TCMC-45678",
        "consultation_fee": "500.00",
        "phone": "+919876543211",
        "email": "sarah.paul@bhrc.com",
        "description": "Senior Cardiologist with 15+ years experience.",
        "profile_photo_url": "https://storage.r2.cloudflare.com/biohelix/doctors/doctor1.jpg",
        "status": "active",
        "schedules": [
          {
            "id": 1,
            "day_of_week": "monday",
            "session_name": "morning",
            "start_time": "09:00",
            "end_time": "13:00"
          }
        ],
        "created_at": "2026-06-13T07:00:00.000000Z"
      }
    ],
    "links": {
      "first": "http://localhost:8000/api/v1/doctors?page=1",
      "last": "http://localhost:8000/api/v1/doctors?page=1",
      "prev": null,
      "next": null
    },
    "meta": {
      "current_page": 1,
      "from": 1,
      "last_page": 1,
      "path": "http://localhost:8000/api/v1/doctors",
      "per_page": 15,
      "to": 1,
      "total": 1
    }
  }
  ```

---

## 3. Booking Endpoints

All endpoints in this section require authentication headers:
`Authorization: Bearer <your_token>`

---

### Book Package [POST]
Book a diagnostic lab package.

- **URL**: `/bookings/packages`
- **Request Body**:
  ```json
  {
    "package_id": 1,
    "booking_date": "2026-06-15",
    "booking_time": "09:30",
    "notes": "Morning slot preferred."
  }
  ```
- **Sample Success Response (201 Created)**:
  ```json
  {
    "id": 12,
    "booking_number": "BKG-20260613-0042",
    "booking_type": "package",
    "booking_date": "2026-06-15",
    "booking_time": "09:30",
    "status": "pending",
    "payment_status": "unpaid",
    "notes": "Morning slot preferred.",
    "patient_id": 5,
    "doctor_id": null,
    "schedule_id": null,
    "test_id": null,
    "package_id": 1,
    "patient": {
      "id": 5,
      "name": "Aisha Rahman",
      "patient_number": "PT-000005",
      "patient_card_number": "BHRC-1234-5678",
      "gender": "female",
      "phone": "+919876543210",
      "email": "aisha.rahman@example.com",
      "date_of_birth": "1994-04-12",
      "blood_group": "O+",
      "address": "Ponnani, Kerala"
    },
    "package": {
      "id": 1,
      "package_code": "GEN-01",
      "package_name": "Genomic Wellness Panel"
    }
  }
  ```

---

### Cancel Package Booking [PATCH]
Cancel a pending/confirmed package booking.

- **URL**: `/bookings/packages/{package_booking_id}/cancel`
- **Sample Success Response (200 OK)**:
  ```json
  {
    "message": "Package booking cancelled successfully."
  }
  ```

---

### Book Tests (Batch) [POST]
Book multiple lab tests simultaneously under a single batch.

- **URL**: `/bookings/tests`
- **Request Body**:
  ```json
  {
    "test_ids": [1, 2],
    "booking_date": "2026-06-15",
    "booking_time": "08:30",
    "notes": "Fasting sample."
  }
  ```
- **Sample Success Response (201 Created)**:
  ```json
  {
    "batch_id": "4a7b53cc-cd21-4f11-8e9a-4122d2ee5bb2",
    "bookings": [
      {
        "id": 13,
        "booking_number": "BKG-20260613-0043",
        "booking_type": "test",
        "booking_date": "2026-06-15",
        "booking_time": "08:30",
        "status": "pending",
        "payment_status": "unpaid",
        "notes": "Fasting sample.",
        "patient_id": 5,
        "doctor_id": null,
        "schedule_id": null,
        "test_id": 1,
        "package_id": null,
        "patient": {
          "id": 5,
          "name": "Aisha Rahman",
          "patient_number": "PT-000005",
          "patient_card_number": "BHRC-1234-5678",
          "gender": "female",
          "phone": "+919876543210",
          "email": "aisha.rahman@example.com",
          "date_of_birth": "1994-04-12",
          "blood_group": "O+",
          "address": "Ponnani, Kerala"
        },
        "test": {
          "id": 1,
          "test_code": "TS-001",
          "test_name": "Thyroid Stimulating Hormone (TSH)"
        }
      }
    ]
  }
  ```

---

### Cancel Test Booking Batch [PATCH]
Cancel all test bookings associated with a single batch UUID.

- **URL**: `/bookings/tests/{test_batch_uuid}/cancel`
- **Sample Success Response (200 OK)**:
  ```json
  {
    "message": "Test bookings cancelled successfully."
  }
  ```

---

### Book Doctor [POST]
Book an appointment with a specialist.

- **URL**: `/bookings/doctors`
- **Request Body**:
  ```json
  {
    "doctor_id": 1,
    "schedule_id": 1,
    "booking_date": "2026-06-15",
    "booking_time": "10:30",
    "notes": "First consultation."
  }
  ```
- **Sample Success Response (201 Created)**:
  ```json
  {
    "id": 14,
    "booking_number": "BKG-20260613-0044",
    "booking_type": "doctor",
    "booking_date": "2026-06-15",
    "booking_time": "10:30",
    "status": "pending",
    "payment_status": "unpaid",
    "notes": "First consultation.",
    "patient_id": 5,
    "doctor_id": 1,
    "schedule_id": 1,
    "test_id": null,
    "package_id": null,
    "patient": {
      "id": 5,
      "name": "Aisha Rahman",
      "patient_number": "PT-000005",
      "patient_card_number": "BHRC-1234-5678",
      "gender": "female",
      "phone": "+919876543210",
      "email": "aisha.rahman@example.com",
      "date_of_birth": "1994-04-12",
      "blood_group": "O+",
      "address": "Ponnani, Kerala"
    },
    "doctor": {
      "id": 1,
      "name": "Dr. Sarah Paul"
    },
    "schedule": {
      "id": 1,
      "day_of_week": "monday",
      "start_time": "09:00",
      "end_time": "13:00"
    }
  }
  ```

---

### Cancel Doctor Booking [PATCH]
Cancel a pending/confirmed doctor appointment booking.

- **URL**: `/bookings/doctors/{doctor_booking_id}/cancel`
- **Sample Success Response (200 OK)**:
  ```json
  {
    "message": "Doctor booking cancelled successfully."
  }
  ```

---

## 4. Flutter Integration Guidelines

### 1. HTTP Client Configuration
Use [Dio](https://pub.dev/packages/dio) or the standard [http](https://pub.dev/packages/http) library. Ensure the client intercepts requests to add the `Bearer` token and mandatory headers:
```dart
import 'package:dio/dio.dart';

Dio getApiClient(String? token) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  ));
  return dio;
}
```

### 2. Handling Validation Errors
If you submit incorrect input (e.g. invalid phone number, mismatched password, or missing required fields), the Laravel backend returns a `422 Unprocessable Entity` response. In Flutter, catch this error and display specific field errors:
```json
{
  "message": "The given data was invalid.",
  "errors": {
    "phone": [
      "The phone field must be a valid mobile number."
    ]
  }
}
```

### 3. State Management (Tokens)
- Store the token returned during Register/Login in secure local storage using [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) or similar.
- Use a state management pattern (like Riverpod, Bloc, or Provider) to handle user login state and automatically append the token to HTTP requests.
- When an API returns a `401 Unauthorized` status code, clear the local token storage and redirect the user back to the login screen.
