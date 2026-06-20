# BioHelix App Feature List

This document lists the main user-facing and platform features present in the Flutter patient app.

## App Entry And Session

- Splash screen with BioHelix branding.
- Onboarding screen with a swipe-to-start interaction.
- Patient OTP login flow.
- Patient sign-up support through session and repository APIs.
- Stored authentication token support.
- Saved family/profile recovery support.
- API configuration through `.env`.
- Dio-based API client with bearer-token support.
- Authenticated media URL handling for protected documents and images.

## Main Patient Portal

- Bottom navigation shell with five tabs:
  - Home
  - Reports
  - Bookings
  - Checkup
  - Profile
- Pull-to-refresh portal data.
- Back-button behavior that returns to Home before exiting.
- Exit confirmation dialog.
- Floating Health AI assistant shortcut on Home.

## Home Dashboard

- Patient greeting and hero section.
- Home banners and announcement ticker.
- Health tips.
- Special offers.
- Upcoming appointments preview.
- Featured doctors section.
- Popular lab tests section.
- Popular health packages section.
- Language toggle for English and Malayalam.
- Quick actions grid:
  - Book Appointment
  - Lab Reports
  - Prescriptions
  - AI Assistant
  - Lab Test Order
  - ID Card
  - MyClub
  - Health Trends
  - Discharge
  - AI Trend Analysis
  - AI Package Design

## Doctors And Appointments

- Doctor directory.
- Doctor detail page.
- Doctor profile information, specialization, schedule, and fee display.
- Appointment booking with available date and slot selection.
- Appointment list in Bookings.
- Appointment cancellation.
- Appointment check-in.
- Appointment rescheduling.

## Lab Tests And Packages

- Lab test catalog.
- Lab test detail page.
- Lab test booking flow.
- Lab package catalog.
- Lab package booking flow.
- Package landing page from home banners and recommendations.
- Cart and checkout-style booking screens.
- Patient detail capture for lab orders.
- Address capture for home collection.
- Home collection and visit-style booking options.
- Slot selection.
- Price summary.
- Payment screen flow.
- Booking success screen.
- Lab order cancellation.
- Lab order rescheduling.
- Lab package order cancellation.
- Lab package order rescheduling.

## Reports, Records, And Documents

- Medical records tab.
- Filtering for records such as lab reports, prescriptions, and summaries.
- Prescription detail viewing.
- Medicine list display with dosage, frequency, duration, and instructions.
- Document upload through file picker.
- Protected document URL resolution.
- Document preview/opening.
- AI document analysis and summary generation.
- Document-specific AI chat.
- Document deletion.
- Tests hub with Find Tests and Results views.

## Health AI Assistant

- Global patient AI assistant.
- Text chat with AI.
- Previous chat thread list.
- New chat creation.
- Chat thread rename.
- Chat thread deletion.
- Chat thread switching.
- Markdown rendering for AI responses.
- Speech-to-text voice input.
- Text-to-speech AI voice playback.
- Live voice-style interaction controls.
- Stop/interruption controls for AI voice.
- File attachment support in assistant messages.
- Attachment upload status messaging.
- English and Malayalam assistant strings.
- AI disclaimer messaging.

## AI Health Checkup

- AI Health Checkup tab.
- Previous assessment history.
- Start new assessment flow.
- English and Malayalam assessment language selection.
- Basic patient detail capture.
- AI-guided health questionnaire.
- Health analysis submission.
- Health score result.
- Risk and precaution display.
- Peer comparison display when available.
- Suggested individual tests.
- Matched health package recommendations.
- Unmatched package suggestions.
- Book recommended package from results.
- Retake assessment.

## Health Trends And AI Planning

- Health Trends quick action page.
- AI Trend Analysis quick action page.
- Vitals trend display.
- BMI, weight, heart rate, and blood pressure summaries.
- Comparison against previous readings.
- Recent AI-analyzed report summaries.
- Trend insight generation from vitals, documents, and patient conditions.
- AI Package Design page.
- Periodic preventive test planning.
- Care plan notes.
- Recommended package matching based on patient conditions and goals.

## MyClub, ID Card, And Loyalty

- Rewards Wallet page.
- Patient ID card information.
- Membership tier display.
- QR/barcode-oriented ID card data.
- MyClub points summary.
- Currency value display.
- Tier progress.
- Benefits display.
- Loyalty transaction history.
- Redemption configuration support from backend data.

## Profile And Vitals

- Patient profile tab.
- Personal information display:
  - Full name
  - Mobile number
  - Email
  - Date of birth
- Profile update support through provider and repository APIs.
- Vitals saving support.
- Vitals trend loading.
- Privacy policy external link.
- Sign out.

## Emergency Support

- Emergency support screen components.
- Primary ambulance call card.
- Emergency contact cards.
- Emergency location card.
- Emergency tips.
- URL launcher based phone call support.
- Fallback emergency contacts for ambulance, hospital reception, and helpline.

## Localization, Theme, And Platform

- English locale support.
- Malayalam locale support.
- Flutter localization delegates.
- Light theme.
- Dark theme.
- Theme mode provider.
- SharedPreferences-backed language selection.
- Android, iOS, web, macOS, Windows, and Linux project targets.

## Assets And Branding

- BHRC logo assets.
- Doctor and lab-themed image assets.
- App launcher icon configuration.
- Play Store submission checklist included in the repository.

