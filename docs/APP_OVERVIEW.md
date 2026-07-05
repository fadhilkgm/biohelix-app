# BioHelix App — Comprehensive Overview

> Single source of truth for app structure, layouts, design system (colors, fonts,
> spacing, components), features, and workflows.
> Snapshot as of **2026-07-04**.

---

## 1. App Entry Point

- `lib/main.dart` — bootstraps Flutter, loads `.env`, runs `BioHelixApp`.
- `lib/app.dart` (`BioHelixApp`) — builds the dependency graph and wires it into
  `MultiProvider`:
  - `AppConfig` (from `.env`), `AuthStorage`, `ApiClient`, `PatientRepository`
  - `SessionProvider` (auth/session state, initialized on startup)
  - `PatientPortalProvider` (patient portal domain state)
  - `ThemeProvider`, `LanguageProvider` (app-wide UI prefs)
  - Root widget renders `SplashScreen` first.

## 2. Top-Level Folder Structure

```
lib/
  core/                  # Shared infrastructure, not feature-specific
    config/              # AppConfig (.env-driven)
    constants/           # Asset path constants
    l10n/                # App strings (EN / ML)
    network/             # ApiClient (Dio), ApiException
    providers/           # ThemeProvider, LanguageProvider
    storage/             # AuthStorage, OnboardingStorage (local persistence)
    theme/                # AppColors, AppTextStyles, AppShadows, AppTheme
    utils/               # phone_utils, etc.
    widgets/             # Reusable low-level widgets (buttons, cards, sidebar, bottom bar)

  features/              # Pre-portal flows (run before the user is inside the app shell)
    splash/
    onboarding/
    auth/                # OTP login / signup
    session/             # SessionProvider + session-level logic
    home/                # (legacy/simple home, superseded by patient_portal/home)

  patient_portal/        # The authenticated app itself
    core/                # PatientRepository, PatientPortalProvider (domain layer)
    shell/               # PatientAppShell — bottom-nav scaffold, tab routing
    home/                # Home dashboard tab
    premium_home/        # Newer/alternate home design (own design/app_colors.dart)
    doctors/             # Doctor directory + detail + appointment booking
    bookings/            # Appointment list/management tab
    labs/ , lab_booking/ # Lab test directory + booking flow
    tests/               # Test/report results
    records/             # Health records / documents
    health_profile/      # Patient health profile data
    ai_checkup/          # AI-driven checkup feature
    assistant/           # Health AI assistant (floating shortcut + chat)
    my_club/             # MyClub membership feature
    emergency/           # Emergency contacts/info
    profile/             # Patient profile/settings tab
    shared/              # Widgets/models shared across patient_portal features
```

Each feature folder generally follows: `presentation/` (screens, widgets),
`providers/` or `data/` (state, repositories), `models/` — but check the individual
folder since not all are identically shaped yet.

## 3. Navigation & App Shell Layout

- `patient_portal/shell/patient_app_shell.dart` (`PatientAppShell`) is the root
  scaffold once a patient is authenticated.
- Bottom navigation (`shell/widgets/bottom_nav_bar_widget.dart`) drives 5 tabs:
  **Home → Reports → Bookings → Checkup → Profile**.
- Back-button behavior: pressing back from any non-Home tab returns to Home;
  pressing back from Home shows an exit-confirmation dialog.
- A floating "Health AI Assistant" shortcut overlays the Home tab.
- Routing is done via in-shell tab state (IndexedStack-style), not named routes —
  new tabs/screens should be registered inside `PatientAppShell`, not `app.dart`.

## 4. State Management Pattern

- **Provider** (`package:provider`) is the only state management approach in use.
- Two layers of providers:
  1. **App-wide** (created once in `app.dart`): `SessionProvider`,
     `PatientPortalProvider`, `ThemeProvider`, `LanguageProvider`.
  2. **Feature-local**: individual features may define their own
     `ChangeNotifier` providers scoped with a `ChangeNotifierProvider` further
     down the widget tree (check each feature's `providers/` folder).
- Data flow: UI widget → feature provider → `PatientRepository` (or a
  feature-specific repository) → `ApiClient` (Dio) → REST backend.
- `SessionProvider` owns auth state and token lifecycle; `ApiClient` calls
  `onUnauthorized` (wired in `app.dart`) to force sign-out on 401s.

## 5. Networking & Config

- `ApiClient` (`core/network/api_client.dart`) wraps Dio, injects bearer tokens,
  and exposes authenticated media URL handling for protected images/documents.
- `AppConfig.fromEnvironment()` reads `.env` (see `.env.example`) for API base
  URL and other environment-dependent values.
- API endpoint reference lives in `docs/api-doc.md` and
  `docs/api_documentation.md` (kept separate from this overview doc).

## 6. Key Workflows

### Auth / Session
1. `SplashScreen` → checks stored auth token (`AuthStorage`) and onboarding flag.
2. If first run → `OnboardingScreen` → OTP login (`features/auth`).
3. On success, `SessionProvider` persists token + profile, then app routes into
   `PatientAppShell`.
4. Any 401 response globally triggers `SessionProvider.signOut()`.

### Home Dashboard
- `patient_portal/home` (or `premium_home` if that variant is active) assembles:
  greeting/hero, banners, health tips, offers, upcoming appointments preview,
  featured doctors, popular lab tests/packages, and the quick-actions grid.
- Language toggle (EN/ML) updates `LanguageProvider`, re-rendering strings from
  `core/l10n/app_strings.dart`.

### Booking Flow
- Doctor directory (`doctors/`) → doctor detail → date/slot selection →
  appointment created via `PatientRepository` → appears in `bookings/` tab.
- Lab tests follow the analogous path through `labs/` → `lab_booking/`.

### Reports / Records
- `tests/` and `records/` tabs surface lab/test results and documents, using
  `ApiClient`'s authenticated media URL support to fetch protected files.

---

## 7. Design System

### 7.1 Typography

**Font Family:** `Manrope` (via `google_fonts`), applied globally via
`GoogleFonts.manropeTextTheme(...)` in `AppTheme.light()` and `AppTheme.dark()`.
Never use the system default font on visible text.

| Token | `TextTheme` role | Size | Weight | Letter-spacing | Line height |
|-------|-----------------|------|--------|---------------|-------------|
| `h1` | `displayLarge` | 32 sp | Bold (700) | −0.5 | default |
| `h2` | `displayMedium` | 24 sp | Bold (700) | −0.3 | default |
| `h3` / Section hero | `displaySmall` | 20 sp | SemiBold (600) | — | default |
| `subtitle1` | `titleLarge` | 16 sp | Medium (500) | — | default |
| `subtitle2` | `titleMedium` | 14 sp | Medium (500) | — | default |
| `body1` | `bodyLarge` | 16 sp | Regular (400) | — | default |
| `body2` / Hint | `bodyMedium` | 14 sp | Regular (400) | — | 1.35–1.45 |
| `button` | `labelLarge` | 16 sp | SemiBold (600) | +0.5 | default |
| `caption` | `bodySmall` | 12 sp | Regular (400) | — | default |
| `overline` | — | 10 sp | Medium (500) | +1.5 | default |

Body copy line heights: general `1.4`, card subtitles/secondary text `1.35`,
document summary blocks `1.5`.

Text weight conventions: screen/section titles `w700–w800`, card titles
`w700–w800`, body content `w400–w500`, labels/badges/tags `w600–w700`, button
labels `w600`, stat numbers/values `w800`.

### 7.2 Color Palette

**Core Brand Colors** (`lib/core/theme/app_colors.dart`)

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#1B4D3E` | Deep green — main CTA, active states |
| `primaryLight` | `#4C7D6D` | Dark-mode primary |
| `primaryDark` | `#0D2A22` | Deep tonal variant |
| `accent` | `#2E8B57` | Sea Green secondary CTA |

**Neutrals — Light Theme**

| Token | Hex | Usage |
|-------|-----|-------|
| `backgroundLight` | `#F9FAFB` | Page / scaffold background |
| `surfaceLight` | `#FFFFFF` | Cards, sheets, modals |
| `textPrimaryLight` | `#111827` | All primary text |
| `textSecondaryLight` | `#4B5563` | Subtitles, meta, hints |
| `dividerLight` | `#E5E7EB` | Dividers, card borders |
| `inputBackgroundLight` | `#F3F4F6` | Input fills |

**Neutrals — Dark Theme**

| Token | Hex | Usage |
|-------|-----|-------|
| `backgroundDark` | `#111827` | Page background |
| `surfaceDark` | `#1F2937` | Card surfaces |
| `textPrimaryDark` | `#F9FAFB` | Primary text |
| `textSecondaryDark` | `#9CA3AF` | Secondary / hint text |
| `dividerDark` | `#374151` | Borders, dividers |
| `inputBackgroundDark` | `#374151` | Input fills |

**Semantic Colors**

| Token | Hex | Usage |
|-------|-----|-------|
| `error` | `#EF4444` | Validation errors, cancelled states |
| `success` | `#10B981` | Confirmed, completed states |
| `warning` | `#F59E0B` | Pending states, caution |
| `info` | `#3B82F6` | Informational, scheduled states |

**Premium Home Extended Colors** (`patient_portal/premium_home/design/app_colors.dart`)

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#F4F7F8` | Premium home background |
| `surface` | `#FFFFFF` | Card surface |
| `primary` | `#1E9D8B` | Teal green — hero accent |
| `secondary` | `#2A7CCF` | Blue — "View all" links |
| `accent` | `#66BCEB` | Light blue accent |
| `textPrimary` | `#17212B` | Primary text |
| `textSecondary` | `#7C8A96` | Subtitle / secondary text |
| `border` | `#E5ECEF` | Card / input borders |
| `cardShadow` | `#1A233545` | Drop shadow base |

> Two parallel color systems exist: the main `AppColors` (used by
> `AppTheme.light()/dark()`) and the Premium Home palette above, scoped to the
> premium home redesign.

**Quick Action Icon Colors**

| Action | Icon Color | Background |
|--------|-----------|------------|
| AI Assistant / AI Trend | `#0EA5E9` Sky Blue | `#DFF3FF` |
| Lab Reports | `#8B5CF6` Violet | `#EDE9FE` |
| Prescriptions / Health Trends | `#10B981` Emerald | `#DDF7EC` / `#DEF7EF` |
| Discharge | `#F59E0B` Amber | `#FFF5DB` |
| ID Card | `#3B82F6` Blue | `#E7F0FE` |
| Book Appointment | `#6366F1` Indigo | `#E8EAFE` |
| AI Package Design | `#8B5CF6` Violet | `#F1E8FF` |
| MyClub | `#F59E0B` Amber | `#FEF0E4` |
| Lab Test Order | `#EF4444` Red | `#FEE2E2` |

**Gradient Patterns**

| Context | Colors |
|---------|--------|
| Auth screen background | `primary @8% → scaffoldBackground` (top → bottom) |
| Home hero header | `#114784 @85% → #12A0C7 @65%` (top → bottom) |
| Membership card | `#7648F6 → #6B3FEB → #8448F3` (top-left → bottom-right) |
| Health packages header | `#0F5E56 → #178E81` (top-left → bottom-right) |
| Banner image overlays | `black @62% → black @18%` (bottom → top) |

**Status Badge Colors**

| Status | Color |
|--------|-------|
| Confirmed | `#10B981` |
| Scheduled / Rescheduled | `#2563EB` |
| Analyzed / Completed | `#15803D` |
| Processing | `#C2410C` |
| Pending | `#F59E0B` |
| Cancelled | `#EF4444` |
| Active | `#7C3AED` |
| Follow-up / Summary | `#0F766E` |
| Default | `#475569` |

### 7.3 Spacing System (`AppSpacing`)

| Token | Value | Use case |
|-------|-------|----------|
| `xxs` | 4 dp | Icon gap, micro spacing |
| `xs` | 8 dp | Tight internal gaps |
| `sm` | 12 dp | Form field gap, inner paddings |
| `md` | 16 dp | Standard padding, screen horizontal padding |
| `lg` | 20 dp | Top/hero padding |
| `xl` | 24 dp | Screen padding, card padding |
| `xxl` | 32 dp | Hero section bottom curve |
| `cardPadding` | 16 dp | Default card internal padding |
| `sectionGap` | 18 dp | Gap between home sections |
| `listItemGap` | 14 dp | Gap between horizontal list items |

Layout rules: screen horizontal padding is **16 dp** everywhere; AppBar is
left-aligned (no `centerTitle`), elevation `0.5`; always use `SafeArea` /
`MediaQuery.viewPadding.top` for hero headers; bottom list padding **24 dp** to
clear the floating bottom nav bar.

### 7.4 Border Radius System

| Usage | Radius |
|-------|--------|
| Global theme default | `12 dp` |
| Custom button (filled & outlined) | `14 dp` |
| Standard cards (theme) | `12 dp` |
| Large content cards (records, documents) | `24–28 dp` |
| Quick-action cards | `20 dp` |
| Quick-action icon containers | `14 dp` |
| Metric / mini-stat cards | `22 dp` |
| Vitals / mini-stat cells | `18 dp` |
| Banner carousel items | `24 dp` |
| Health packages hero | `24 dp` |
| Membership/identity card | `18 dp` |
| Home hero bottom curve | `32 dp` |
| Bottom nav bar | `28 dp` |
| Filter chips | `20 dp` |
| Status badges / pill labels | `999 dp` (fully rounded) |
| "View Profile" inline button | `9 dp` |
| Icon background containers | `12–18 dp` |
| Snackbar (floating) | `14 dp` |
| Input fields | `12 dp` |

> Rule: prefer `24–28 dp` for primary content cards, `12–16 dp` for
> secondary/utility elements, `999` for pills and badges.

### 7.5 Shadow System (`AppShadows`)

| Level | Blur | Offset | Opacity (light) | Use case |
|-------|------|--------|-----------------|----------|
| `low` | 8 dp | (0, 2) | 6% | Cards at rest, subtle lift |
| `medium` | 16 + 6 dp | (0, 4) + (0, 1) | 10% | Floating cards |
| `high` | 28 + 10 dp | (0, 8) + (0, 2) | 16% | Bottom nav bar, modals |
| `primary` (glow) | 18 dp | (0, 6) | 30% | Hero / primary-color buttons |

Dark mode reduces all shadow opacity by **50%**.

### 7.6 Component Patterns

**Buttons**
- Primary (`CustomButton`, filled): `AppColors.primary` bg, white fg, radius
  14 dp, padding h20/v14, font 14sp w600, `AppShadows.low`, disabled opacity
  0.65, loading spinner 22×22 (strokeWidth 2.2).
- Outlined (`CustomButton isOutlined: true`): transparent bg, 1.5 dp primary
  border, radius 14 dp.
- On-dark variant: filled → white bg/primary fg; outlined → white border/text.
- `FilledButton` (Material 3): only for modals/bottom sheets/package pages.
- Rule: use `CustomButton` for all primary/secondary CTAs; never
  `TextButton`/`ElevatedButton` for primary actions.

**Input Fields** (`CustomTextField` + `AppTheme.inputDecorationTheme`)
- Fill `#F3F4F6` (light) / `#374151` (dark); no border by default, primary
  2 dp when focused, error 1 dp on error; radius 12 dp; padding h16/v16;
  label above field (titleMedium w600 + 8 dp gap).
- Icon conventions: phone → `Icons.phone_android_rounded`, MRN/ID →
  `Icons.badge_outlined`, OTP/password → `Icons.lock_open_rounded`.

**Cards**
- Standard (`AppTheme.cardTheme`): elevation 0, 1 dp divider border, radius 12 dp.
- Large content card (records/documents): radius 24–28 dp, 16 dp padding, icon
  container 52×52 radius 18.
- Quick-action tile: 156 dp wide, radius 22 dp, icon box 44×44 radius 14.
- Quick-action grid card: white bg, radius 20 dp, 3-col grid, ratio 0.85.
- Metric card: width `(screenWidth-44)/2`, color @8% bg, radius 22 dp.
- Package card: white bg, radius 24 dp, image 148 dp tall (top corners only).

**Bottom Navigation Bar**
- Container margin `ltrb(16,0,16,20)`, radius 28 dp, `AppShadows.high`.
- Active item: primary @10% bg, radius 16 dp, primary icon/label (w600).
- Inactive item: outline-variant icon/label (w400).
- Tab order: Home (`home_rounded`) → Records (`folder_rounded`) → Bookings
  (`calendar_month_rounded`) → My Club (`workspace_premium_rounded`) → Profile
  (`person_rounded`).

**Icons**
- Always `*_rounded` for active/standard, `*_outlined` for inactive/secondary.
- Standard size 24 dp, nav bar 22 dp, inline/badge 16–18 dp.
- Icon-in-container pattern: 44×44 box, accentColor @12% bg, radius 14.

**Section Header Pattern**: title (titleMedium w700) + subtitle (bodyMedium
w500 secondary, 8 dp gap) on the left; "View all" (w700 secondary) + arrow
icon on the right.

**Status & Tag Badges**
- Status badge: padding h12/v7, radius 999, statusColor @12% bg + @16% border,
  bodySmall w700.
- Filter chip: selected = primary bg/white text; unselected = surface
  bg/outlineVariant border; radius 20 dp.
- Pill label: padding h12/v7, radius 999, `surfaceContainerHighest` bg.

**Animation Standards**

| Element | Duration | Curve |
|---------|----------|-------|
| Transitions (AnimatedSwitcher) | 220 ms | default |
| Banner carousel auto-scroll | 450 ms | easeInOut |
| Banner carousel timer | 4 s | — |
| Nav item selection | 220 ms | easeInOut |
| Onboarding CTA tap | 180 ms | default |
| Button opacity (disabled) | 180 ms | default |
| Dot indicators expand | 220 ms | default |
| Snackbar auto-dismiss | 3 s | — |

**AppBar Pattern**: surface bg, textPrimary fg, elevation 0.5, `centerTitle:
false` (never centered), `surfaceTintColor: transparent`. Hero screens (Home)
use `extendBodyBehindAppBar: true`.

**Screen-by-Screen Notes**
- Onboarding: full-bleed hero image + gradient fade, bottom-aligned CTA.
- Auth/Login: `primary @8% → scaffold` gradient bg, form in `CustomCard`.
- Home: full-bleed hero (blue gradient overlay, 32 dp bottom curve), purple
  membership card, 3-col quick actions grid, 190 dp banner carousel (24 dp
  radius, 94% viewport), horizontal doctor/lab/package card lists.
- Tab screens (Records, Bookings, Profile): standard AppBar, 16 dp padding,
  scrollable filter chip row, 24–28 dp content cards.

### 7.7 Do's and Don'ts

**Do:** use `AppColors`/`AppTextStyles`/`AppTheme`/`AppSpacing`/`AppRadius`
tokens (not raw hex); use `Theme.of(context)`; use `CustomButton` and
`CustomTextField`; use `*_rounded` icons; use radius `999` for pills/badges;
keep horizontal screen padding at 16 dp; show loading via
`CircularProgressIndicator` (strokeWidth 2.2).

**Don't:** hardcode colors outside design system files; use `centerTitle:
true`; use `elevation > 0` on cards/AppBars; use fonts other than Manrope;
create shadow values outside `AppShadows`; use font sizes outside the type
scale; use `TextButton`/`ElevatedButton` for primary actions.

### 7.8 Design File Locations

| Asset | Path |
|-------|------|
| Global colors | `lib/core/theme/app_colors.dart` |
| Global text styles | `lib/core/theme/app_text_styles.dart` |
| Global shadows | `lib/core/theme/app_shadows.dart` |
| Theme configuration | `lib/core/theme/app_theme.dart` |
| Custom button | `lib/core/widgets/custom_button.dart` |
| Custom text field | `lib/core/widgets/custom_text_field.dart` |
| Bottom nav bar | `lib/core/widgets/custom_bottom_bar.dart` |
| Premium home colors | `lib/patient_portal/premium_home/design/app_colors.dart` |
| Premium spacing | `lib/patient_portal/premium_home/design/app_spacing.dart` |
| Premium radii | `lib/patient_portal/premium_home/design/app_radius.dart` |
| Premium text styles | `lib/patient_portal/premium_home/design/app_text_styles.dart` |
| Section header | `lib/patient_portal/premium_home/widgets/section_header_widget.dart` |
| Quick actions grid | `lib/patient_portal/premium_home/widgets/quick_actions_grid_widget.dart` |

---

## 8. Feature List

### App Entry And Session
- Splash screen with BioHelix branding.
- Onboarding screen with a Get Started button.
- Patient OTP login flow.
- Patient sign-up support through session and repository APIs.
- Stored authentication token support.
- Saved family/profile recovery support.
- API configuration through `.env`.
- Dio-based API client with bearer-token support.
- Authenticated media URL handling for protected documents and images.

### Main Patient Portal
- Bottom navigation shell with five tabs: Home, Reports, Bookings, Checkup, Profile.
- Pull-to-refresh portal data.
- Back-button behavior that returns to Home before exiting.
- Exit confirmation dialog.
- Floating Health AI assistant shortcut on Home.

### Home Dashboard
- Patient greeting and hero section.
- Home banners and announcement ticker.
- Health tips.
- Special offers.
- Upcoming appointments preview.
- Featured doctors section.
- Popular lab tests section.
- Popular health packages section.
- Language toggle for English and Malayalam.
- Quick actions grid: Book Appointment, Lab Reports, Prescriptions, AI
  Assistant, Lab Test Order, ID Card, MyClub, Health Trends, Discharge, AI
  Trend Analysis, AI Package Design.

### Doctors And Appointments
- Doctor directory.
- Doctor detail page.
- Doctor profile information, specialization, schedule, and fee display.
- Appointment booking with available date and slot selection.
- Appointment list in Bookings.
- Appointment cancellation.
- Appointment check-in.
- Appointment rescheduling.

### Lab Tests And Packages
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

### Reports, Records, And Documents
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

### Health AI Assistant
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

### AI Health Checkup
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

### Health Trends And AI Planning
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

### MyClub, ID Card, And Loyalty
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

### Profile And Vitals
- Patient profile tab.
- Personal information display: full name, mobile number, email, date of birth.
- Profile update support through provider and repository APIs.
- Vitals saving support.
- Vitals trend loading.
- Privacy policy external link.
- Sign out.

### Emergency Support
- Emergency support screen components.
- Primary ambulance call card.
- Emergency contact cards.
- Emergency location card.
- Emergency tips.
- URL launcher based phone call support.
- Fallback emergency contacts for ambulance, hospital reception, and helpline.

### Localization, Theme, And Platform
- English locale support.
- Malayalam locale support.
- Flutter localization delegates.
- Light theme.
- Dark theme.
- Theme mode provider.
- SharedPreferences-backed language selection.
- Android, iOS, web, macOS, Windows, and Linux project targets.

### Assets And Branding
- BHRC logo assets.
- Doctor and lab-themed image assets.
- App launcher icon configuration.
- Play Store submission checklist included in the repository.

---

## 9. Update Log

When something in this app's structure, layout, colors/fonts, features, or
workflows changes, add a short dated entry here instead of rewriting the
sections above. Only fold an entry into the relevant section (and remove it
from this log) once it's no longer "new" — e.g. during an occasional cleanup
pass.

- _(no entries yet)_
