# Activity Rewards — version 20 review preparation

Release target: BHRC Hospital, package `com.biohelix.app`, version `1.0.7+20`.
Prepared on 2 October 2026. This document does not confirm Google Play approval.

## Built artifact and checks performed

- Signed release AAB: `build/app/outputs/bundle/release/BHRC-Hospital-1.0.7-20.aab` (112,179,017 bytes).
- SHA-256: `39DA19A836CE1806FE1AAAEFDA7395F3AE9C21F6E6C05ECDB0D7898ECED34FFA`.
- The manifest extracted from the AAB confirms package `com.biohelix.app`, version name `1.0.7`, version code `20`, minimum SDK 26 and target SDK 36.
- Its only Health Connect uses-permission is `android.permission.health.READ_STEPS`. There is no Health Connect calorie, distance, write, background-read or history-read permission.
- The release manifest sets `android:usesCleartextTraffic="false"`. This blocks ordinary Android HTTP traffic; it is not a network-capture test of every native transport.
- The DEX string table contains the new permission rationale explaining steps-only access, seven-day totals/date/timezone syncing, optional connection, local disconnect and retained server data. The old literal claiming reads of daily steps, active calories and distance is absent. This is inspection of the compiled artifact, not an executed permission-screen test.
- Bundletool structural validation and JAR signature verification succeeded. These checks do not establish acceptance by Play Console.
- Static analysis of the changed activity widget and its profile library completed with no issues. Four existing tests passed on the final source: two fitness-model checks, one error-message check and the profile points/transaction navigation test.
- A direct production attempt to verify the documented demo OTP returned HTTP 422 (`Invalid OTP code`). No release-device login, Health Connect read, server sync, reward award or disconnect flow was exercised.

The final build explicitly uses the production HTTPS API and `SHOW_DEV_OTP=false`. The version 19 AAB was preserved in the local temporary release archive before rebuilding. The initial build attempt reused a generated test-plugin registration and failed; regenerating Flutter's release tooling resolved that compilation failure without changing app dependencies.

## Store listing paragraph

Optionally connect Health Connect on Android to view your daily steps toward a walking goal and earn eligible MyClub points under BHRC's reward rules. Daily step totals sync to your BHRC patient profile for Activity Rewards. You can disconnect activity syncing at any time. Activity scores are general wellness indicators and are not medical advice, diagnosis or treatment.

This paragraph is ready for inclusion in the full listing after the live sync and rewards flow has been tested. No listing has been published from this task.

## App access instructions

Before submitting these instructions, supply a dedicated reviewer account and a repeatable login method that does not require access to a staff member's phone. Verify it against the signed release and production API. The repository's example OTP `123456` returned HTTP 422 (`Invalid OTP code`) during a live verification attempt; it must not be presented as a working reviewer credential.

1. Install the submitted release on an Android device with Health Connect available. Ensure a compatible fitness source has written today's step records into Health Connect. BHRC reads existing records; it does not write or independently collect steps.
2. Complete onboarding. Sign in using the reviewer phone number and MRN supplied in Play Console's App access fields, then enter the validated reviewer OTP.
3. Review the Privacy Policy and Terms and accept the consent screen if it appears. Stay on the connected patient's own profile.
4. Open the Home dashboard and scroll to **Activity Rewards**, immediately below the Book Doctors, Book Test and AI Checkup quick links.
5. Tap **Connect activity**. Read the disclosure about server syncing. Grant the Health Connect permission to read steps. No calories, distance, cadence, write, background-read or history-read permission should be requested.
6. Return to BHRC. Confirm that the card shows today's step total, progress toward the step goal, the activity-score ring, and **MyClub points today**. Points depend on the active backend reward rules, thresholds and caps; do not expect a fixed award without checking those rules.
7. Tap **More activity options** on the card and choose **Refresh activity**. Confirm steps update and an unchanged total does not award points again. Open **Profile**, tap the membership card's **View points & transactions**, and inspect **Rewards Wallet → Points credit history** for the matching award when a threshold has been reached. Return to **Home** for the next step.
8. Choose **Disconnect activity** from the same menu and confirm. The card returns to **Connect activity**. Reopening BHRC must not restart device step syncing until the user reconnects. Existing Health Connect records, the Health Connect permission and previously synced BHRC server records remain.
9. To revoke the permission as a separate check, open Health Connect's app permissions for BHRC and revoke steps. Reconnect in BHRC and confirm permission is requested again before reading.

The connected-device steps above have not been performed in this task. No Android device was attached when checked.

## Deletion and retention evidence

The inspected backend checkout is a separate repository under `BHRC-Hospital`.

Backend compatibility fix and policy templates are committed locally as `53f68d6` (`Support steps-only activity sync`). This commit has not been pushed or deployed. The local backend checks passed 18 fitness/reward tests and formatting validation; PHPStan still reports the same six type errors present in the original service revision.

- The initial `FitnessActivityController.php` required `active_calories` and `distance_meters`, while the Android client sends only `date` and `steps` within each day, plus request `timezone`. The local backend has now been corrected to accept steps-only requests and retain optional calorie/distance support for clients supplying those values. A migration makes unavailable measurements nullable; steps-only scoring matches the app's step-goal progress. The fix has not been deployed or verified against production.
- `FitnessActivityService.php` stores records in `fitness_daily_metrics`. Its seven-day history query is a display window, not a retention purge. No fitness expiry task was found.
- `RewardEngine.php` also stores the step quantity in reward events and includes quantities in loyalty transaction descriptions. A complete step-data deletion process must cover these copies, rather than just deleting daily metrics.
- `PatientController::destroyAccount` revokes user tokens, marks the patient inactive, removes the patient-to-user link and deletes the portal user. It does not delete the patient or their fitness and reward records. The foreign-key cascade on the patient ID does not run when only the user is deleted.

These are code-inspection findings, not a live account-deletion test. No live patient account or fitness records were deleted.

## Remaining submission requirements

- The English and Malayalam privacy policies were published through the authenticated Company Info CMS on 2 October 2026. Both persisted after reloading the CMS. `/api/v1/legal-content` returns both corrected policies exactly, and both Terms and Conditions remain unchanged. The public `/privacy-policy` page visibly renders the corrected English policy. Evidence, backups and screenshots are in `docs/privacy-policy-2026-10-02`.
- Correct or substantiate the separate live website sidebar claims of "End-to-End Encryption" and "No Third-party Sharing". They are outside the CMS policy and remain present. The local page template already has different wording; the deployed frontend has not been rebuilt or deployed in this task. The live public page also lacks the Malayalam language switch present in the local page template; the Malayalam policy is verified in the CMS and app API only.
- Deploy the backend compatibility fix and its migration, then verify the live steps-only sync contract, reward calculation and duplicate-sync behavior. The local fitness/rewards tests passed (18 tests, 149 assertions); see `BHRC-Hospital/docs/activity-sync-v20.md`. These automated backend tests do not replace release-device testing.
- Establish a fitness retention/deletion process covering daily metrics, reward events and transaction descriptions. Do not claim portal account deletion automatically erases synced fitness data under the currently inspected implementation.
- Validate reviewer credentials and complete the device test steps above.
- Align Play Console Data safety and Health Connect declarations with server collection, authenticated patient linkage, purposes, retention and deletion.

Version 20's app wording explains the current retention and disconnect behavior. Correct wording alone does not establish backend deletion compliance or resolve Google's earlier objection to step access.
