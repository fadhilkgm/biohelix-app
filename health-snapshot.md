# Health Snapshot

A per-day health summary for a patient combining clinical vitals (recorded by staff), manual
self-reported readings, and a computed health/risk score with an AI-style text summary.

## Data model

Table: `ai_health_snapshots`
Model: [`App\Modules\AI\Models\AIHealthSnapshot`](../app/Modules/AI/Models/AIHealthSnapshot.php)

| Column             | Type              | Notes                                                              |
|--------------------|-------------------|---------------------------------------------------------------------|
| `id`               | bigint            |                                                                     |
| `patient_id`       | FK → `patients`   | cascade delete                                                     |
| `snapshot_date`    | date              | one row per patient per day — unique on `(patient_id, snapshot_date)` |
| `bmi`              | decimal(5,2)      | computed from latest vital (weight/height), nullable                |
| `blood_sugar`      | decimal(6,2)      | mg/dL, manual entry only                                            |
| `cholesterol`      | decimal(6,2)      | mg/dL, manual entry only                                            |
| `risk_score`       | decimal(5,2)      | `100 - health_score`                                                 |
| `health_score`     | decimal(5,2)      | 0–100, see scoring below                                             |
| `latest_vitals`    | jsonb             | snapshot of BP/weight/height/temperature/SpO2 at generation time     |
| `latest_results`   | jsonb             | reserved for lab results, currently always `null`                    |
| `ai_summary`       | text              | human-readable summary string                                       |
| `other_conditions` | text              | free-text box, e.g. "fever", "sore throat"                          |
| `generated_at`     | timestamp         | when this row was computed                                          |
| `created_at` / `updated_at` | timestamp |                                                                     |

Migrations:
- [`2026_06_09_201840_create_ai_health_snapshots_table.php`](../database/migrations/2026_06_09_201840_create_ai_health_snapshots_table.php)
- [`2026_07_02_000806_add_manual_fields_to_ai_health_snapshots_table.php`](../database/migrations/2026_07_02_000806_add_manual_fields_to_ai_health_snapshots_table.php) — adds `blood_sugar`, `cholesterol`, `other_conditions`
- [`2026_07_02_001224_add_snapshot_date_to_ai_health_snapshots_table.php`](../database/migrations/2026_07_02_001224_add_snapshot_date_to_ai_health_snapshots_table.php) — adds `snapshot_date` + unique constraint, backfills existing rows

## Service

[`App\Modules\AI\Services\HealthSnapshotService::generateFor(Patient $patient, array $manual = [])`](../app/Modules/AI/Services/HealthSnapshotService.php)

Inputs:
- `$patient->latestVital` — most recent `PatientVital` (BP, pulse, temperature, weight, height, SpO2), recorded by staff.
- `$patient->healthProfiles()` — latest health profile, used for `chronic_conditions`.
- `$manual` (optional, keys are snake_case): `blood_sugar`, `cholesterol`, `other_conditions`, `blood_pressure_systolic`, `blood_pressure_diastolic`, `weight`.

Behavior:
- Upserts by `(patient_id, snapshot_date = today)` — calling it more than once on the same day updates that day's row instead of creating a new one.
- BMI is computed from the clinical vital (weight/height) if available.
- Blood pressure scoring prefers the clinical vital's systolic reading; falls back to the manually submitted systolic value if no vital exists yet.
- `latest_vitals` is built from the clinical vital when present; otherwise falls back to a minimal `{bp, weight}` object built from manual input.

### Health score heuristic (baseline 70, clamped 0–100)

| Factor                        | Condition                          | Score delta |
|--------------------------------|-------------------------------------|-------------|
| Systolic BP                    | 120–129                             | −5          |
|                                 | 130–139                             | −10         |
|                                 | ≥140                                 | −20         |
| Blood sugar (mg/dL)             | 100–125 (prediabetic)               | −10         |
|                                 | >125 (high)                          | −20         |
| Cholesterol (mg/dL)             | 200–239 (borderline high)            | −10         |
|                                 | ≥240 (high)                          | −20         |
| Other reported condition        | any free-text entry                  | −5          |
| BMI                             | <18.5 (underweight)                  | −10         |
|                                 | 18.5–24.9 (healthy)                  | +10         |
|                                 | 25–29.9 (overweight)                 | −5          |
|                                 | ≥30 (obese)                          | −15         |
| SpO2                            | <95%                                 | −15         |
| Chronic conditions (profile)    | each condition, capped at 4          | −5 (max −20)|

`risk_score = 100 - health_score`. `ai_summary` is a generated sentence listing the health score plus every triggered finding, e.g.:

> "Health score: 55/100. Key findings: Prediabetic blood sugar (110 mg/dL); Borderline high cholesterol (205 mg/dL); Reported: Mild fever since yesterday, sore throat."

## API endpoints

All routes are under the authenticated patient group in [`routes/api.php`](../routes/api.php) (prefix `api/v1`), handled by [`HealthSnapshotController`](../app/Modules/Api/Http/Controllers/Patient/HealthSnapshotController.php).

### `GET /patients/me/health-snapshot`
Returns the latest snapshot (by `snapshot_date`). If the patient has none yet, one is auto-generated from clinical vitals.

```json
{
  "success": true,
  "snapshot": {
    "snapshot_date": "2026-07-02",
    "bmi": 24.3,
    "blood_sugar": 110.0,
    "cholesterol": 205.0,
    "risk_score": 45.0,
    "health_score": 55.0,
    "latest_vitals": { "bp": "128/82", "heart_rate": null, "temperature": 37.1, "weight": 74.5, "height": 172, "bmi": 24.3, "oxygen_saturation": 98, "recorded_at": "2026-07-01T09:00:00+00:00" },
    "latest_results": null,
    "other_conditions": "Mild fever since yesterday, sore throat",
    "ai_summary": "Health score: 55/100. Key findings: ...",
    "generated_at": "2026-07-02T10:20:00+00:00"
  }
}
```

### `POST /patients/me/health-snapshot`
Manual entry ("add" button). All fields optional/nullable — a patient can submit just one field (e.g. only `otherConditions`).

Request body (camelCase):
```json
{
  "bloodPressureSystolic": 128,
  "bloodPressureDiastolic": 82,
  "bloodSugar": 110,
  "cholesterol": 205,
  "weight": 74.5,
  "otherConditions": "Mild fever since yesterday, sore throat"
}
```

Validation:
- `bloodPressureSystolic`: integer, 50–300
- `bloodPressureDiastolic`: integer, 30–200
- `bloodSugar`: numeric, 0–1000
- `cholesterol`: numeric, 0–1000
- `weight`: numeric, 1–500
- `otherConditions`: string, max 1000 chars

Response: `201`, same `snapshot` shape as `GET`, with `message: "Health snapshot recorded."`. Upserts today's row — calling this again the same day overwrites today's entry rather than creating a duplicate.

### `POST /patients/me/health-snapshot/refresh`
Recomputes today's snapshot purely from clinical vitals/profile (no manual input). Same response shape, `message: "Health snapshot refreshed."`.

### `GET /patients/me/health-snapshot/history`
Paginated list of past snapshots ("history" button), newest first, one entry per day.

Query params: `page` (standard Laravel pagination).

```json
{
  "success": true,
  "snapshots": [
    { "snapshot_date": "2026-07-02", "health_score": 55.0, "...": "..." },
    { "snapshot_date": "2026-07-01", "health_score": 70.0, "...": "..." }
  ],
  "meta": { "current_page": 1, "last_page": 3, "total": 62 }
}
```

## Related modules

- Clinical vitals: [`App\Modules\Vitals\Models\PatientVital`](../app/Modules/Vitals/Models/PatientVital.php), submitted via [`VitalsController::store`](../app/Modules/Api/Http/Controllers/Patient/VitalsController.php) (`POST /patients/me/vitals`).
- Chronic conditions: [`App\Modules\Patient\Models\PatientHealthProfile`](../app/Modules/Patient/Models/PatientHealthProfile.php).

## Known limitations

- `latest_results` (lab results) is not yet wired up — always `null`.
- Reference ranges (BP, sugar, cholesterol) are simple fixed thresholds, not personalized by age/sex/fasting-state.
- `other_conditions` is unstructured free text — no severity/duration fields, and a flat −5 score penalty regardless of what's entered.
