# BHRC Play policy remediation and release handoff

## Current candidate: version 22 — 9 October 2026

**Version 22 supersedes the version 20 and 21 candidates below. Do not upload those older candidates to resolve this rejection.** Their sections are retained as historical evidence.

Google rejected version code 19 for **Health Connect by Android Permissions policy: Excessive data access for declared feature**, specifically **StepsCadence/Steps**. The exact issue was supplied by the user and confirmed on the authenticated Play Console issue page on 9 October. Removing cadence while continuing to request `READ_STEPS` would leave the permission Google objected to.

### Android changes and signed artifact

- Removed every Health Connect permission, provider query, permission-rationale activity and permission-usage alias from the Android manifest.
- Removed the AndroidX Health Connect dependency and native permission/read channel. The install-referrer implementation is preserved.
- Android no longer offers Activity Rewards, reads device activity or sends activity-sync requests. An upgrade clears the saved activity-owner connection. It does not delete historical server records or Health Connect source records.
- The existing iOS Apple Health path remains available. Hospital bookings, patient health records, membership rewards from other sources, and AI features remain health features; their declarations must still reflect their actual data use.
- Signed AAB: `build/app/outputs/bundle/release/BHRC-Hospital-1.0.9-22.aab`, package `com.biohelix.app`, version `1.0.9+22`, **111,772,542 bytes**.
- SHA-256: `E680B4FDE65B62B326BEC459DBF22B41E4A76DCECB9F8EEEA40DDA7ADF66CED3`.
- Final source: clean Flutter analysis and **251 passing Flutter tests**. Four new tests cover Android service calls, upgrade cleanup, lifecycle/profile changes, hidden Activity Rewards and continued iOS channel support.
- Final bundle: **zero Health Connect permissions**, no activity-recognition/body-sensor substitute, no Health Connect manifest entry points and no AndroidX Health Connect classes in DEX. Bundletool validation and JAR signature verification pass. The upload certificate matches version 21; minimum SDK is 26 and target SDK is 36. Bundle configuration and all ten 64-bit native libraries pass the 16 KB checks.
- The updated verifier also rejects version 21 because it contains `READ_STEPS`, demonstrating that the gate detects the exact removed permission. Evidence: `build/release-22-verification.json`, `build/release-22-permission-regression.json`, `build/release-22-analysis.log`, `build/release-22-full-tests.log`, and `build/release-22-build.log`.
- Compiled Dart markers for the AI-report endpoint, acknowledgement handling, health notice and production API are present in version 22; see `build/release-22-compiled-features.json`. A compact artifact/status handoff is in `build/release-22-handoff.json`.
- Gradle's final `releaseRuntimeClasspath` also contains no `androidx.health.connect` dependency; see `build/release-22-health-dependency-check.log`.

These checks establish the packaged permission removal. They do not establish Google Play approval or an Android runtime test. No Android device is attached, and the available emulator cannot boot with the current virtualization setup.

### Backend and privacy publication

On 9 October the user authorized committing, pushing and pulling the backend onto production through the SSH MCP. Local `main`, GitHub `main` and `/var/www/html/bhrc/BHRC-Hospital` now match **`f625eb542b3ffbfb0c56f2cb6d32387e3f5a4cb9`**. The VPS fast-forwarded from `ab97656`, including the earlier `53f68d6` steps-only compatibility commit. Both the optional-fitness-measurement and AI-report-table migrations completed. Composer autoload generation, route/view cache refresh and the production frontend build succeeded; the production checkout is clean. The prior Git revision and frontend assets are preserved under `codex/pre-play-policy-20261009` and `/root/bhrc-deploy-backups/20261009-play-policy`.

The production AI-report POST URL now returns **HTTP 401 without authentication**, rather than the previous 404. `/up` returns **HTTP 200**, and the admin queue redirects unauthenticated visitors to login. These establish deployment and authentication gates; a report submitted through the signed Android app and its production admin review have not been tested. The current local reporting/fitness/reward checks pass **31 tests / 197 assertions**, and all six PHP implementation files changed across the release pass targeted PHPStan. Repository-wide PHPStan reports errors in other modules and does not pass.

Updated patch exports are checked against their stated bases and do not alter the actual backend Git index:

- `build/BHRC-backend-v22-policy.patch`: apply to `53f68d6b1537455b079b87e7dd251b0efb7f0f0a`.
- `build/BHRC-backend-v20-v22-policy.patch`: includes the previously undeployed steps-only compatibility commit; apply to `ab97656ee2a6a6d621288df059a6671b00c6a05c`.

**Apply one matching patch, not both.** These latest `-policy.patch` exports include the public deletion-request section and supersede the earlier version 22 patch exports. Their apply checks and fingerprints are in `build/release-22-policy-backend-patches.json`; the older files are preserved. Follow the deployment procedure in the version 21 section, including migrations, asset build, cache/worker refresh and authenticated AI-report/admin-queue checks. Android step-sync checks in that older section are superseded by verifying that Android no longer offers or invokes activity access. Existing server retention/deletion responsibilities and any supported iOS activity flow still apply.

English and Malayalam privacy changes are prepared in `build/release-22-legal-content-proposal.json`. Its `cms_fields.privacy_policy` and `cms_fields.privacy_policy_ml` contain complete replacements based on the current live policies, with real company/contact details preserved. The proposal explains version 22's removal, earlier Android records and the separate iOS feature. Sections 5–12 and Terms remain unchanged. See `build/release-22-policy-proposal-check.json` and the live backup `build/release-22-legal-content-before.json`.

**The committed English and Malayalam privacy templates are now published to Company Info CMS** using `legal:publish-privacy-policy`. The previously empty support email and phone were restored from the prior public policy (`info@bhrchospital.com`, `7510210222`) and the company-info cache refreshed. Both Terms fields were verified unchanged. Production `/privacy-policy` and `/api/v1/legal-content` show the version 22 disclosures in both languages. Chrome also verified the public `#account-deletion` section and its email-request link in both languages. This verifies the public request instructions, not receipt or fulfillment of a deletion request. The earlier JSON proposal remains an archival draft; the published content was rendered from the committed templates with current CMS company details. Evidence: `build/release-22-backend-deployment.json`, the before/after production legal backups, and `build/release-22-deployed-privacy.jpg`.

### Play Console changes to accompany version 22

Chrome access resumed successfully on 9 October. Read-only inspection confirms production version 19 is rejected, internal testing is serving version 20, and closed testing `alpha` is serving version 6. The current health declaration still detects `android.permission.health.READ_STEPS`; it selects **Activity and fitness** and **Healthcare services and management**, with the earlier steps justification. No declaration or release has been changed in this resumed work.

1. Upload the verified version 22 AAB as the replacement candidate. Inspect all serving/review/draft tracks so an older permission-bearing bundle does not remain in the submitted release or continue to require the unwanted permission declaration. Console also recommends pausing the old alpha track if it is no longer used; review its use before changing that track.
2. Reopen **App content → Health apps** after the new artifact is processed. Remove Android **Activity and fitness** when no remaining Android feature warrants it; retain **Healthcare services and management** and any other health features actually present. Remove Steps/StepsCadence access and its obsolete justification once Console no longer detects the permission. Do not select “no health features.” Google requires the declaration to match the app's remaining features and requested data: [Health Connect publishing guidance](https://developer.android.com/health-and-fitness/health-connect/publish).
3. Remove current Android Health Connect / step-sync / Activity Rewards claims from all Play listing languages and reviewer instructions. Suggested release note: **Removed Android Health Connect access and Activity Rewards. Improved health guidance notices and added in-app reporting of AI responses.** Keep the health notice provided below. Do not promise deletion of retained historical activity through ordinary portal-account deletion.
4. Review Data safety against actual patient records, AI messages/voice, reports, identifiers, service providers and retained records. Removing Health Connect permissions does not eliminate the hospital app's other collection of health data. Do not simply deselect all health-data categories.
5. Confirm the backend and policy publication above, provide a verified repeatable reviewer login, and exercise the signed release on a real Android device: upgrade an earlier connected installation, confirm Activity Rewards and Health Connect prompts are absent, verify bookings/records/profile switching and submit a harmless AI report through to the admin review queue.
6. Review the complete release and declaration changes in Publishing overview, then submit for review. The build is ready for upload; publication readiness still depends on these external checks. Google determines acceptance.

## Historical version 20 preparation

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

## Version 21 build and deployment handoff — 8 October 2026

New signed candidate: `build/app/outputs/bundle/release/BHRC-Hospital-1.0.8-21.aab`, package `com.biohelix.app`, version `1.0.8+21`, 112,276,175 bytes. SHA-256: `BA76FEB150E22089FB1552C3ACC3C0B9093149C437309E779E7DF6FEF07BD3D4`. The version 20 bundle remains available.

The final source passes `flutter analyze` and all 247 Flutter tests. The final release build explicitly uses `API_BASE_URL=https://www.bhrchospital.com/api/v1` and `SHOW_DEV_OTP=false`. Bundletool validation and JAR signature verification pass. The upload certificate matches version 20. The manifest confirms minimum SDK 26, target SDK 36, cleartext disabled and only `READ_STEPS` for Health Connect. Bundle configuration requests 16 KB ZIP alignment; all ten arm64/x86_64 native libraries pass the ELF LOAD alignment and RELRO layout checks in `scripts/Test-PlayBundle.ps1`. Machine-readable results are in `build/release-21-verification.json`. These are build and binary checks, not a runtime test or confirmation of Play approval.

### AI policy changes

- Chat exposes a persistent **About health guidance** action. The English and Malayalam notice explains that BHRC is not a medical device, AI guidance does not diagnose, treat, cure or prevent conditions, and users should consult a qualified healthcare professional. Checkup consent includes the same notice.
- Patients can report a selected AI response from chat, voice captions (also when captions are hidden), checkup conversations and checkup results, without leaving the app. The form explains what is sent and offers medical-safety, offensive-content, incorrect-information and other categories.
- Success is displayed only after the API acknowledges a report ID. Failed requests remain retryable; repeated taps during submission are blocked. A report opened under one patient cannot be submitted after switching profiles.
- The backend authenticates reports, checks ownership of chat/message IDs, retrieves the stored assistant reply when an ID is supplied, rate limits submissions, and stores a pending report. Voice/checkup reports store the selected text snapshot. The super-admin review queue escapes report content and records completion. Reports are deleted when their reporting portal user is deleted.

These changes address the published [AI-generated content reporting requirement](https://support.google.com/googleplay/android-developer/answer/13985936) and [health disclaimer requirement](https://support.google.com/googleplay/android-developer/answer/16679511). The actual rejection message in Play Console could not be read, so these changes must not be described as a verified resolution of that rejection.

### Backend deployment owned by the user

The user confirmed they will deploy the backend separately. The local backend checkout contains the version 20 steps-only compatibility commit `53f68d6` and the new version 21 reporting changes. A production probe on 8 October returned HTTP 404 for `/api/v1/patients/ai/content-reports`; the new route is not yet live. Do not submit this candidate before deploying and verifying the report flow.

1. Deploy the backend source, including the new controllers, model, Blade review view, API/web routes, sidebar link and the fitness compatibility changes. Patch exports in `build/BHRC-backend-v21.patch` (relative to `53f68d6`) and `build/BHRC-backend-v20-v21.patch` (also includes that previously undeployed commit) are provided for handoff. Run `git apply --check` against the corresponding base before applying a patch; do not apply both.
2. Use the existing production backup/release process. Run `composer install --no-dev --optimize-autoloader` and `php artisan migrate --force`. Required migrations include `2026_10_02_000001_allow_missing_fitness_measurements` and `2026_10_08_000001_create_ai_content_reports_table`.
3. Rebuild frontend assets through the existing deployment process so the super-admin sidebar includes **AI Content Reports**, clear/rebuild application caches, and restart long-running application workers through that process.
4. With a dedicated reviewer account, submit a harmless test report in the signed app. Confirm HTTP 201 with `report.id` and `report.status=pending`. Log in as super-admin at `/backend/ai-content-reports`, verify the selected response/reason and mark it reviewed. Confirm that an ordinary patient cannot access this queue. Staff must review reported content and use findings to improve AI instructions/content controls.
5. Complete the steps-only sync, reward idempotency, profile isolation and disconnect checks described above. Existing fitness/reward retention and deletion responsibilities still apply; the reporting migration does not change them.

Local backend verification passes 31 tests / 197 assertions for reports, fitness and rewards, targeted Pint, PHPStan for the reporting and fitness files, and ESLint for the sidebar. The previously reported six fitness PHPStan errors are resolved by documenting the real Carbon casts and removing redundant null-safe access. Production deployment, migration execution and real-device checks remain unverified.

### Submission checks still required

- Obtain the exact Play Console issue and rejection text, and match the implemented changes to it. Computer Use ended because it could not verify Chrome's current URL safely; no Play Console fields or releases were changed.
- Confirm the backend deployment and live reporting/sync checks above. The user owns this deployment.
- Supply a repeatable reviewer login and exercise the signed release on an Android device. The available emulator failed to boot, and no physical device was attached. The earlier example OTP remains unsuitable for reviewer instructions.
- Verify Data safety, Health Connect and health-app declarations, and ensure the store description includes the health notice. Suggested English text: **BHRC is not a medical device. AI guidance is for general information and does not diagnose, treat, cure or prevent any medical condition. AI can make mistakes. Consult a qualified healthcare professional for medical advice, diagnosis or treatment; seek immediate medical care in an emergency.**
- The 8 October public HTTP privacy response contains the Health Connect disclosure and no longer contains the old literal sidebar claims about end-to-end encryption or no third-party sharing. This is an HTML-source check, not a rendered browser inspection; evidence is in `build/release-21-public-policy-check.json`. Both policy languages remain available through the legal-content API. Verify operational fitness-data deletion/retention before claiming compliance.

Release confidence is limited by the unread Console rejection, undeployed backend and absent Android runtime test. A signed, structurally valid bundle alone does not establish submission readiness.

## Additional Console inspection for version 22 — 9 October 2026

The current Policy status issue list contains one rejection: excessive Health Connect access. Publishing overview still has three unsubmitted changes: **production version 19 / Start full rollout**, **Data safety**, and **Health apps**. **Do not use the existing “Submit 3 changes for review” button before replacing version 19 with version 22 and checking those declarations.** Managed publishing is off, so an approved production submission can publish without a further manual publishing step. No external fields or releases were changed during this inspection.

### Data safety corrections prepared

Read-only inspection and source comparison found the following concrete mismatches. The complete proposed answers and source pointers are in `build/release-22-data-safety-proposal.json`; existing selection/preview evidence is in `build/release-22-console-selected-data-types.json` and `build/release-22-console-data-safety-preview.txt`.

- The declaration says **My app does not allow users to create an account**, and describes accounts as created by clinic administrators. The actual Register UI calls `/auth/signup`, creates a portal user/patient and verifies the phone OTP. The visible flow supports **Username and other authentication**. Do not declare password authentication merely because an unused repository method supports a separate password API.
- **Other personal info** is not selected, although signup sends gender and may send date of birth. Select that category and disclose its collection/handling. Gender and place are required by the signup UI, so the current **Address: Optional** answer also needs correction unless the app is changed to make place optional. Google defines the category to include birth date/gender and requires optional collection to be avoidable by all users: [Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469).
- Keep **Health info**. Also retain **Fitness info** for the manually supplied initial-assessment `activity_level`; removing Health Connect does not remove that optional user input. The Android step-sync permission and this Data safety classification describe different data paths.
- The preview says the developer has not provided a deletion-request mechanism. The local public privacy page now has a prominent, bilingual **BHRC Hospital account and data deletion** section at `#account-deletion`, with an email request action and an explanation of retained records. This is included in the latest policy patches. After deploying frontend assets, verify `https://www.bhrchospital.com/privacy-policy#account-deletion` renders and the contact address works before entering it in Console.
- The preview's privacy URL is `http://bhrchospital.com/privacy-policy`. Its prepared replacement is the verified HTTPS URL `https://www.bhrchospital.com/privacy-policy` (HTTP 200). This URL has not been saved in Console.

The public request section passes ESLint and `npm run build`; the compiled asset contains both languages, the anchor and encoded email subject. Evidence: `build/release-22-privacy-page-lint.log`, `build/release-22-backend-frontend-build.log`, and `build/release-22-privacy-page-verification.json`. It is not deployed or browser-tested in production. The latest live policy API still lacks the version 22 disclosure in both languages; see `build/release-22-live-policy-status.json`.

The request link alone does not prove fulfillment. Verify BHRC's staff process removes associated account data, handles processor copies and explains legitimate retained records before certifying deletion answers. The existing portal-delete implementation does not automatically erase patient/fitness/reward data. Google permits a public email request path and documented legitimate retention exceptions: [Account deletion guidance](https://support.google.com/googleplay/android-developer/answer/13327111).

### Store description prepared

The default listing has only **English (en-IN)**. Its current description has no Health Connect or Activity Rewards claim, but it incorrectly says all accounts are provider-created and lacks the health notice. `build/release-22-store-listing-proposal.json` supplies an 885-character replacement with phone/OTP signup, the existing core features, AI reporting and the health notice. App name and short description are preserved. The original text is backed up in `build/release-22-store-listing-before.json`. Nothing has been typed or saved in Console. Publish the proposed AI-reporting claim only after the reporting API is deployed and verified. Six existing phone screenshots are present; their visual compatibility with version 22 remains unverified.

The signed Android AAB is unchanged. These additional changes concern the backend/frontend deployment and Console metadata; they do not require rebuilding version 22's unchanged Android source. The subsequent internal-testing publication below supersedes the earlier pending upload authorization.

## Version 22 internal testing publication — 9 October 2026

The user explicitly requested **internal testing only** so they can test the app, and prohibited a production release. Version **22 (1.0.9)** was uploaded and published to internal track `4701042470835459719`, release `9`. Play Console displayed **Ready to release** with no blocking errors, then **Available to internal testers**, released on **9 October at 11:45 Asia/Calcutta**. Version 20 was excluded from the new internal release. The verified AAB SHA-256 remains `E680B4FDE65B62B326BEC459DBF22B41E4A76DCECB9F8EEEA40DDA7ADF66CED3`.

The existing **Dev Testers** email list remains selected with **11 users**. Tester opt-in URL: https://play.google.com/apps/internaltest/4701042470835459719 . Sign in on the Android phone using a Google account in that tester list, join the test if prompted, then install or update BHRC Hospital through Google Play. Propagation can take about an hour or longer, as stated by the Console publishing dialog.

The incomplete upload to the newly created production draft was canceled when the user changed the release destination. That empty production draft was discarded. Production still showed rejected version 19 and available version 15; no production submission or rollout was made. Data safety, Health apps, Health Connect and store-listing corrections were not saved or submitted in this turn.

On the signed version 22 app, check phone/OTP login and registration, bookings and records, patient-profile switching, absence of Android Health Connect prompts and Activity Rewards, and AI-response reporting. Confirm a harmless report appears in the staff review queue, and test account deletion only with a disposable test account after understanding which medical records are retained. Reviewer access and the staff process for deletion requests remain to be verified before production submission.

Evidence: `build/release-22-internal-published.jpg`, `build/release-22-internal-testers.jpg`, `build/release-22-production-unchanged.jpg`, and `build/release-22-handoff.json`.

## Console and policy alignment audit — 9 October 2026

This section supersedes the earlier statements that the backend was undeployed and Console corrections were only prepared. The reporting endpoint, migrations and bilingual privacy policy are deployed at backend commit `f625eb542b3ffbfb0c56f2cb6d32387e3f5a4cb9`. Version **22 (1.0.9)** remains available in **internal testing only**. No production release, rollout or review submission was made. **Production is not ready merely after a successful phone test:** the operational and implementation findings below also need resolution.

### Saved Console corrections

All ten App content declarations, the default English (en-IN) listing, its six original screenshots, store settings and the uploaded version 22 permission list were inspected. The record and remaining limitations are in `build/release-22-policy-audit.json`.

| Declaration | Audited answer or change | State |
| --- | --- | --- |
| Privacy policy | Replaced HTTP with `https://www.bhrchospital.com/privacy-policy`. | Saved, ready for review; not submitted. |
| Health apps | Healthcare services and management; Medical reference and education. Removed Activity and fitness. Replaced the obsolete step-access justification with an explicit version 22 removal explanation. | Saved, ready for review; not submitted. |
| Data safety | Phone/OTP signup; deletion-request URL; gender/DOB; required signup address; purchase history; voice retention; actual collection/sharing purposes. | Corrected draft saved and exported; not finalized or submitted. |
| Financial features | Existing rewards/points/incentives declaration matches MyClub. | Inspected, unchanged. |
| Sign-in details | Restricted access; existing fixed-OTP reviewer instructions. | Inspected, unchanged; repeatable access unverified. |
| Advertising ID | No. Uploaded version 22 has no AD_ID permission. | Inspected, unchanged. |
| Target audience | 18 and over. Intended adult patients/guardians; guardian-consent operations unverified. | Inspected, unchanged. |
| Content ratings | Existing completed IARC certificate, Everyone/3+, All other app types, Online content. | Summary inspected, unchanged; full historic questionnaire and runtime AI moderation not verified. |
| Ads | No. No advertising SDK found in the reviewed source; hospital service offers exist. Live campaign inventory unverified. | Inspected, unchanged. |
| Government apps | No. No government-affiliation feature found in the reviewed source/listing. | Inspected, unchanged. |

The Data safety draft retains 13 data types. Manually entered activity level is stored in `PatientHealthProfile.lifestyle_notes` and included in health context sent to AI services. **Fitness info is therefore declared collected and shared**, optional, non-ephemeral, for App functionality and Personalisation. This data path remains even though Android Health Connect was removed. Gender/age in AI context is covered by shared Other personal info. Unsupported Personalisation purposes were removed from email, address and phone; their App functionality and Account management purposes remain. Raw uploaded images undergo local OCR before redacted clinical text is sent to the model; the image itself is stored separately. Do not infer that all image files are sent to the AI model.

All **782 machine-readable answers** in the re-exported `build/release-22-data-safety-final-draft.csv` match the reviewed import. The optional question about data-only deletion without deleting the account remains unanswered because fulfillment has not been verified. AI sharing disclosures remain conservative; processor exemptions and independent-use practices have not been certified. [Google Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469).

The default full description now explains phone/OTP registration, core patient features and in-app AI-response reporting. It includes the notice that BHRC Hospital is not a medical device, does not diagnose/treat/cure/prevent conditions, and that Health AI is general information requiring professional consultation. The app name and short description remain the same. The obsolete fifth screenshot promising precise treatment and complete wellness was removed from the draft; screenshots 1, 2, 3, 4 and 6 remain. Both text and asset changes were saved as drafts. Existing support email/phone were preserved because replacement contact operations are unverified. [Google health-content guidance](https://support.google.com/googleplay/android-developer/answer/16679511).

Evidence: `build/release-22-data-safety-reviewed-saved.jpg`, `build/release-22-health-declaration-saved.jpg`, `build/release-22-privacy-url-saved.jpg`, `build/release-22-store-description-draft.jpg`, `build/release-22-store-assets-draft.jpg`, and `build/release-22-outdated-screenshot-5.jpg`. Original declaration/listing backups remain under `build/release-22-*-before.*`.

### Publishing queue must not be submitted as it stands

Publishing overview currently displays **Submit 4 changes for review**: production **19 (1.0.7) / Start full rollout**, Privacy policy, Data safety and Health apps. **Managed publishing is off.** The rejected version 19 is still in this queue. Do not use the global submission button. The corrected Data safety answers and store listing are drafts; the App content list still dates the finalized Data safety declaration to **30 September**. A draft save does not replace the finalized declaration for review.

Once the findings below are resolved, the user must authorize production separately. Prepare the approved replacement release, exclude/replace version 19, finalize the reviewed declarations/listing, then check the entire publishing queue before submitting. The existing closed Alpha version 7 draft has not been discarded or edited. Evidence: `build/release-22-publishing-queue-audit.txt`, its screenshot, and `build/release-22-tracks-audit.txt`.

Play Console independently confirms that uploaded version 22 requests **no Health Connect or READ_STEPS permission**. Its nine detected permissions include Play-added `CHECK_LICENSE`; the local signed AAB has eight. The Android target is 36, minimum is 26, and Play reports 16 KB support. Evidence: `build/release-22-console-bundle.txt`, `build/release-22-console-permissions.txt`, and its screenshot. Internal tester URL: https://play.google.com/apps/internaltest/4701042470835459719 .

Legacy inspection found no Health Connect permissions in active closed Alpha version 6 (four total permissions). Version 15 has READ_ACTIVE_CALORIES_BURNED, READ_DISTANCE and READ_STEPS among eleven permissions. Its bundle detail currently says **Archived / 0 releases**, while release history still labels production release 15 **Available on Google Play**. Live installation/recovery eligibility was not tested; this audit does not resolve that difference or change production/closed-testing settings. Rejected version 19 remains the production item queued for full rollout. Evidence: `build/release-22-legacy-6-permissions.txt` and `build/release-22-legacy-15-permissions.txt`. A future approved replacement must leave the intended release tracks serving the compliant bundle; changing the internal track alone does not resolve the pending production rejection.

### Findings that still block production confidence

1. **Account and associated-data deletion operations:** the user answered **Not yet verified** for monitoring `info@bhrchospital.com` and fulfilling deletion requests. `PatientController::destroyAccount` revokes tokens, detaches/deactivates the patient and deletes the portal user; it retains associated patient records. The public bilingual request page is deployed, but a request link and portal closure do not prove associated-data erasure. Verify a staffed process, processor-copy removal and specific legitimate retention exceptions, including the treatment of non-medical AI/fitness data and backups. [Google account deletion guidance](https://support.google.com/googleplay/android-developer/answer/13327111).
2. **Repeatable reviewer login:** the Console contains fixed-OTP instructions. A safer read-only `php artisan about --only=environment --json` confirmed production mode and debugging off. Production source creates a random OTP, expires it after ten minutes, consumes it on verification and omits development OTPs from responses; no isolated reviewer bypass was found. The existing instructions have not been demonstrated to work on the deployed app. Provide and test an isolated synthetic reviewer account with reusable, location-independent access to all required features, while preserving normal-user authentication. No real patient credentials were copied into the audit artifacts. Evidence: `build/release-22-runtime-environment-audit.json`. [Google review-access guidance](https://support.google.com/googleplay/android-developer/answer/15748846).
3. **Unverified paid status:** `BookingPaymentMethod.online` maps directly to `paid`. `LabOrderController` and `PackageOrderController` accept that client field and persist it through `BookingHelpers::paymentStatus`, without a verified payment settlement. The visible flow confirms the booking without a payment gateway. Make paid/partial status server-authoritative and use verified settlement, or remove the unimplemented online-payment path. Test rejection of forged paid claims. No financial transaction or code change for this defect was made during this audit.
4. **Provider practices:** active production AI/voice configuration, processor agreements, independent training/advertising purposes, provider retention and deletion practices remain unverified. Source shows provider transfers of clinical context, messages/documents and voice. The SSH MCP approval check refused the production configuration read because it classified it as destructive and could not present its approval prompt; the read did not execute. Do not claim all service-provider exemptions or provider deletion/training guarantees.
5. **Android and staff moderation tests:** no physical Android test, authenticated production report submission or report-to-staff-queue workflow has been completed. An unauthenticated reporting request returning 401 verifies authentication enforcement only. Verify that harmless test reports arrive in the authorized staff queue and are handled; check English/Malayalam text, checkup and voice safety behavior. The existing IARC summary is not proof that all generative output satisfies content policies. [Google AI-generated content guidance](https://support.google.com/googleplay/android-developer/answer/13985936).

### Transcript-retention source and scheduler check

AI Checkup sets a 30-day expiry and `purgeExpiredTranscripts` removes conversation turns while retaining derived facts. The deployed `php artisan schedule:list` shows `ai-checkup:purge-transcripts` daily at 01:00; the read-only environment check confirmed timezone **Asia/Kolkata**. `/etc/cron.d/bhrc-scheduler` invokes `artisan schedule:run` every minute as `www-data`; the cron service is active and the file is root-owned with mode 644. Thus the cleanup is registered and the scheduler is configured. Actual execution against expired production records was not tested, and daily cleanup occurs on the next scheduled run after expiry. This check does not establish provider retention, backup erasure or deletion-request fulfillment. No purge command was executed during the audit. Evidence: `build/release-22-runtime-environment-audit.json`.

### Internal-testing acceptance checks

- Install version 22 from Google Play with an existing internal-tester Google account. Confirm app version, phone/OTP login and registration, logout and re-login.
- Confirm no Android Health Connect permission prompt, step synchronization or Activity Rewards remains. Exercise optional manual health/activity input and consent.
- Check records, document upload, appointments and family/profile switching with synthetic records; confirm one patient's data is not visible in another profile.
- Check text AI, document explanations, AI Checkup and voice in both languages. Confirm the health notice, consent and emergency guidance. Exercise network loss/retry, denial of microphone permission, and safe refusal of inappropriate medical requests.
- Report one harmless response from each available AI surface. Confirm acknowledgment and the authorized staff review entry without including actual patient information.
- Verify booking pricing and server-confirmed payment state after the payment defect is fixed; do not interpret the current Online selector as a settled payment.
- Delete only a named disposable test account after understanding retained records. Separately verify the web-request/staff/processor deletion process and the documented exceptions.
- Demonstrate the exact reusable reviewer instructions on a fresh device/session, then finalize declarations and prepare production only with the user's authorization.

No Android source changed during this metadata audit, so the signed version 22 bundle was not rebuilt. Earlier automated build/test results remain the prior evidence; they were not repeated or represented as new device tests. The backend working tree remained clean. Outer-repository changes from the earlier build work were preserved and were not committed or pushed during this audit.
