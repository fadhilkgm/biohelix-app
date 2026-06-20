# BioHelix Play Store Submission Checklist

Use this checklist for the Android app with package name `com.biohelix.app`.

## 1. Build Artifact

- [ ] Upload this bundle to Play Console internal, closed, or production track:
  `build/app/outputs/bundle/release/app-release.aab`
- [ ] Confirm the package name shown in Play Console is `com.biohelix.app`.
- [ ] Increment `version:` in `pubspec.yaml` before every new upload.

## 2. Signing And Release Keys

- [ ] Back up these two files outside the repo and outside your laptop:
  - `android/app/upload-keystore.jks`
  - `android/key.properties`
- [ ] Store the keystore password in your password manager.
- [ ] Enable Play App Signing in Play Console.
- [ ] Decide whether this generated upload key is your long-term upload key. If yes, keep it permanently. If no, replace it before wider rollout.

## 3. Store Listing Assets

- [ ] App name: `BioHelix`
- [ ] Short description: prepare one line focused on patient access to appointments, reports, prescriptions, and doctors.
- [ ] Full description: explain OTP sign-in, appointments, lab access, records, prescriptions, and document tools.
- [ ] App icon: verify launcher icon is final brand artwork.
- [ ] Screenshots: phone screenshots for
  - sign in / OTP flow
  - patient dashboard
  - appointments or booking flow
  - lab tests or reports
  - doctor discovery
  - profile or records
- [ ] Feature graphic if Play Console asks for it.

## 4. Content And Policy Declarations

This app appears to handle patient and health-related information. Treat the policy answers conservatively and accurately.

- [ ] Add a public privacy policy URL before moving beyond internal testing.
- [ ] Data safety: disclose collection or processing of the following if they are sent to your backend or stored remotely:
  - phone number
  - MRN / medical record number
  - patient identity and profile data
  - appointments
  - prescriptions
  - medical records
  - uploaded documents
  - chat or document-analysis content
  - authentication token / account session data
- [ ] Data safety: disclose local device storage of sign-in/session data because the app stores auth tokens locally.
- [ ] Data safety: disclose microphone/audio usage if speech input is enabled in production builds.
- [ ] App access: provide reviewer instructions and a test account path if login is required.
- [ ] Content rating: complete questionnaire carefully. Do not under-report medical or user-generated content.
- [ ] Ads declaration: mark `No` unless the app actually serves ads.
- [ ] Health apps review: verify your listing and privacy policy do not overstate diagnosis, treatment, or medical claims unless you are prepared to substantiate them.

## 5. Permissions Review

Current Android permissions and visibility points:

- `INTERNET`
- `RECORD_AUDIO`
- Android query for `android.speech.RecognitionService`

Checklist:

- [ ] Keep `RECORD_AUDIO` only if voice input is user-visible and necessary.
- [ ] If microphone is optional or not ready for review, remove it before production to reduce review risk.
- [ ] Make sure the in-app explanation for microphone access is clear and user initiated.

## 6. Reviewer Notes

Prepare a short note in Play Console like this:

> BioHelix is a patient portal app. Users sign in using mobile number, MRN, and OTP. After sign-in, they can view appointments, prescriptions, records, doctor listings, lab items, and uploaded documents. Microphone access is used only for user-initiated voice input features if enabled.

Add reviewer credentials or a test patient flow if Play review cannot access the app otherwise.

## 7. Functional Release Testing

Run this on at least one real Android device using the signed release build.

- [ ] Fresh install works.
- [ ] App launches with correct app name and icon.
- [ ] OTP login works with production or staging reviewer-safe credentials.
- [ ] Returning user session restore works after app restart.
- [ ] Logout clears access properly.
- [ ] Dashboard loads without placeholder or broken API errors.
- [ ] Doctor list and doctor detail open correctly.
- [ ] Appointment booking flow works.
- [ ] Lab tests / lab packages / lab orders load.
- [ ] Documents list loads.
- [ ] Document upload works.
- [ ] Document analysis/chat features work or are hidden if not production ready.
- [ ] Profile update works.
- [ ] Voice features work only when user grants permission.
- [ ] No HTTP-only endpoints are required in release.
- [ ] Upgrade install from previous internal build works without data loss.

## 8. Backend And Environment Checks

- [ ] Confirm `.env` points to the correct HTTPS API base URL for release.
- [ ] Confirm release backend is stable and accessible from external tester devices.
- [ ] Disable any developer OTP shortcuts or test bypasses before production.
- [ ] Verify error logging and monitoring are enabled on the backend.
- [ ] Confirm privacy policy and support email/website are live.

## 9. Before Closed Or Production Rollout

- [ ] Replace placeholder screenshots and text in Play listing.
- [ ] Verify there are no references to staging, debug, internal, or test environments in UI copy.
- [ ] Review all patient-facing text for medical-risk wording.
- [ ] Make sure support contact details are correct.
- [ ] Confirm internal testers have already exercised sign-in, records, and upload flows successfully.

## 10. Current Repo-Specific Notes

- The release bundle has already been built successfully.
- Android release signing is configured through `android/key.properties`.
- The app is now using package name `com.biohelix.app`.
- Release no longer allows cleartext traffic by default; debug and profile still do.
- No privacy policy file or privacy-policy documentation was found in this repo, so that still needs to exist externally before broader rollout.


# DEMO ACCOUNT

Phone number: +919876543210
MRN: PLAYTEST01
OTP: 123456
MRN: BH000001