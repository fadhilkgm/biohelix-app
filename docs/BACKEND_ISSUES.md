# Backend API Issues — BioHelix

Tested against: `https://bhrchospital.com/api/v1`
Tested on: 2026-06-20

---

## Summary

| # | Endpoint | Severity | Type |
|---|----------|----------|------|
| 1 | `GET /patient/lab-tests` | Critical | 500 — DB migration incomplete |
| 2 | `GET /patients/me/myclub` | High | Response key mismatch — silent data loss |
| 3 | `GET /health` | Low | 404 — endpoint doesn't exist |

---

## Issue 1 — `/patient/lab-tests` returns 500

**Severity:** Critical — breaks the lab tests screen entirely.

**Request:**
```
GET /api/v1/patient/lab-tests
Authorization: Bearer <token>
```

**Response:**
```json
{
  "message": "SQLSTATE[42703]: Undefined column: 7 ERROR: column body_point_tests.lab_test_id does not exist\nLINE 1: select \"body_points\".*, \"body_point_tests\".\"lab_test_id\" as ...",
  "exception": "..."
}
```

**Root Cause:**
A migration added a `body_point_tests` pivot table but did not include the `lab_test_id` column (or the column was renamed and the query was not updated). The query tries to join `body_points` through `body_point_tests.lab_test_id` which doesn't exist in the database.

**Fix:**
Check the migration for `body_point_tests`. Either:
- Add the missing `lab_test_id` column in a new migration, or
- Update the Eloquent relationship on the `LabTest` model to use the correct column name.

---

## Issue 2 — `/patients/me/myclub` response key mismatch

**Severity:** High — MyClub / loyalty screen always shows empty data, even when real data exists.

**Request:**
```
GET /api/v1/patients/me/myclub
Authorization: Bearer <token>
```

**Actual API response (top-level keys):**
```json
{
  "membership": null,
  "pointsBalance": 0,
  "plans": []
}
```

**What the Flutter app expects:**
```json
{
  "myClub": {
    "membership": ...,
    "pointsBalance": ...,
    "plans": [...]
  }
}
```

The app reads `response['myClub']` (`patient_repository.dart`, `getMyClub()`). Since the API returns a flat object with no `myClub` wrapper, `response['myClub']` is always `null`. The app then calls `_map(null)` which returns `{}`, and `MyClubSummary.fromJson({})` silently produces an empty result — no error is thrown, so this is invisible in logs.

**Fix (pick one):**

Option A — Wrap the API response:
```json
{
  "myClub": {
    "membership": null,
    "pointsBalance": 0,
    "plans": []
  }
}
```

Option B — Update the Flutter app to read the flat response (if changing the API is not possible):
```dart
// patient_repository.dart — getMyClub()
Future<MyClubSummary> getMyClub() async {
  final response = await _apiClient.getJson('/patients/me/myclub');
  return MyClubSummary.fromJson(_map(response['myClub'] ?? response));
}
```

Option A is preferred to keep the response consistent with the rest of the API (which wraps data under a named key).

---

## Issue 3 — `/health` returns 404

**Severity:** Low — not user-facing, but breaks health monitoring.

**Requests tried:**
```
GET https://bhrchospital.com/health        → 404
GET https://bhrchospital.com/api/v1/health → 404
```

The app config has `HEALTH_ENDPOINT=/health` and the `ApiClient.checkHealth()` method calls it on startup. The route doesn't exist on the server.

**Fix:**
Add a health route in Laravel:
```php
// routes/api.php or routes/web.php
Route::get('/health', fn () => response()->json(['status' => 'ok']));
```

---

## Endpoints Verified Working

### Auth
| Endpoint | Result |
|----------|--------|
| `POST /auth/signup` | ✅ Returns `dev_otp` |
| `POST /auth/otp/send` | ✅ Works for existing patients |
| `POST /auth/otp/verify` | ✅ Returns bearer token + patient |

### Public
| Endpoint | Result |
|----------|--------|
| `GET /doctors` | ✅ |
| `GET /departments` | ✅ |
| `GET /home-banners?target=mobile` | ✅ |
| `GET /home-ticker-messages` | ✅ |
| `GET /home-offers` | ✅ |
| `GET /body-points` | ✅ |
| `GET /patient/lab-packages` | ✅ |

### Authenticated
| Endpoint | Result |
|----------|--------|
| `GET /patients/me` | ✅ |
| `PATCH /patients/me` | ✅ |
| `GET /patients/me/dashboard` | ✅ |
| `GET /patients/bookings` | ✅ |
| `GET /patients/me/prescriptions` | ✅ |
| `GET /medical-records/me` | ✅ |
| `GET /patients/documents` | ✅ |
| `GET /patients/me/summaries` | ✅ |
| `POST /patients/me/vitals` | ✅ |
| `GET /patients/me/vitals` | ✅ |
| `GET /patient/lab-orders` | ✅ |
| `GET /patient/lab-package-orders` | ✅ |
| `POST /patients/chat/global/threads` | ✅ |
| `GET /patients/chat/global/threads/{id}` | ✅ |
| `POST /patients/chat/global/threads/{id}/messages` | ✅ AI responds correctly |
| `PATCH /patients/chat/global/threads/{id}` | ✅ |
| `DELETE /patients/chat/global/threads/{id}` | ✅ |
