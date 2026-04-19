# BioHelix Patient App — Design System Guide

> **Single source of truth** for typography, colors, spacing, components, and layout patterns.  
> Reference this document before building any new screen to maintain full visual consistency.

---

## 1. Typography

### Font Family
- **Primary font:** `Manrope` (via `google_fonts` package)
- Applied globally via `GoogleFonts.manropeTextTheme(...)` in `AppTheme.light()` and `AppTheme.dark()`
- Never use the system default font family on any visible text

### Type Scale

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

### Body Copy Line Heights (specific cases)
- General body copy: `height: 1.4`
- Card subtitles / Secondary text: `height: 1.35`
- Document summary blocks: `height: 1.5`

### Text Weight Conventions
| Use case | Weight |
|----------|--------|
| Screen / section titles | `w700` or `w800` |
| Card titles | `w700`–`w800` |
| Body content | `w400`–`w500` |
| Labels / badges / tags | `w600`–`w700` |
| Button labels | `w600` |
| Badge / chip text | `w700` |
| "View all" links | `w700` |
| Stat numbers / values | `w800` |

---

## 2. Color Palette

### Core Brand Colors (`AppColors` — `lib/core/theme/app_colors.dart`)

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#1B4D3E` | Deep green — main CTA, active states |
| `primaryLight` | `#4C7D6D` | Dark-mode primary |
| `primaryDark` | `#0D2A22` | Deep tonal variant |
| `accent` | `#2E8B57` | Sea Green secondary CTA |

### Neutrals — Light Theme
| Token | Hex | Usage |
|-------|-----|-------|
| `backgroundLight` | `#F9FAFB` | Page / scaffold background |
| `surfaceLight` | `#FFFFFF` | Cards, sheets, modals |
| `textPrimaryLight` | `#111827` | All primary text |
| `textSecondaryLight` | `#4B5563` | Subtitles, meta, hints |
| `dividerLight` | `#E5E7EB` | Dividers, card borders |
| `inputBackgroundLight` | `#F3F4F6` | Input fills |

### Neutrals — Dark Theme
| Token | Hex | Usage |
|-------|-----|-------|
| `backgroundDark` | `#111827` | Page background |
| `surfaceDark` | `#1F2937` | Card surfaces |
| `textPrimaryDark` | `#F9FAFB` | Primary text |
| `textSecondaryDark` | `#9CA3AF` | Secondary / hint text |
| `dividerDark` | `#374151` | Borders, dividers |
| `inputBackgroundDark` | `#374151` | Input fills |

### Semantic Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `error` | `#EF4444` | Validation errors, cancelled states |
| `success` | `#10B981` | Confirmed, completed states |
| `warning` | `#F59E0B` | Pending states, caution |
| `info` | `#3B82F6` | Informational, scheduled states |

### Premium Home Extended Colors (`premium_home/design/app_colors.dart`)
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

### Quick Action Icon Colors
| Action | Icon Color | Background |
|--------|-----------|------------|
| AI Assistant / AI Trend | `#0EA5E9` Sky Blue | `#DFF3FF` |
| Lab Reports | `#8B5CF6` Violet | `#EDE9FE` |
| Prescriptions / Health Trends | `#10B981` Emerald | `#DDF7EC` or `#DEF7EF` |
| Discharge | `#F59E0B` Amber | `#FFF5DB` |
| ID Card | `#3B82F6` Blue | `#E7F0FE` |
| Book Appointment | `#6366F1` Indigo | `#E8EAFE` |
| AI Package Design | `#8B5CF6` Violet | `#F1E8FF` |
| MyClub | `#F59E0B` Amber | `#FEF0E4` |
| Lab Test Order | `#EF4444` Red | `#FEE2E2` |

### Gradient Patterns
| Context | Colors |
|---------|--------|
| Auth screen background | `primary @8% → scaffoldBackground` (top → bottom) |
| Home hero header | `#114784 @85% → #12A0C7 @65%` (top → bottom) |
| Membership card | `#7648F6 → #6B3FEB → #8448F3` (top-left → bottom-right) |
| Health packages header | `#0F5E56 → #178E81` (top-left → bottom-right) |
| Banner image overlays | `black @62% → black @18%` (bottom → top) |

### Status Badge Colors
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

---

## 3. Spacing System (`AppSpacing`)

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

### Layout Rules
- **Screen horizontal padding:** 16 dp (consistent on all screens)
- **AppBar:** left-aligned title, no `centerTitle`, elevation `0.5`
- **Safe area:** Always use `SafeArea` or `MediaQuery.viewPadding.top` manually for hero headers
- **Bottom list padding:** 24 dp to clear the floating bottom nav bar

---

## 4. Border Radius System

| Usage | Radius |
|-------|--------|
| Global theme default | `12 dp` (`AppTheme.borderRadius`) |
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
| Section step-badges | `999 dp` |
| "View Profile" inline button | `9 dp` |
| Icon background containers | `12–18 dp` |
| Snackbar (floating) | `14 dp` |
| Input fields | `12 dp` |

> **Rule:** Prefer `24–28 dp` for primary content cards, `12–16 dp` for secondary/utility elements, `999` for pills and badges.

---

## 5. Shadow System (`AppShadows`)

| Level | Blur | Offset | Opacity (light) | Use case |
|-------|------|--------|-----------------|----------|
| `low` | 8 dp | (0, 2) | 6% | Cards at rest, subtle lift |
| `medium` | 16 + 6 dp | (0, 4) + (0, 1) | 10% | Floating cards |
| `high` | 28 + 10 dp | (0, 8) + (0, 2) | 16% | Bottom nav bar, modals |
| `primary` (glow) | 18 dp | (0, 6) | 30% | Hero / primary-color buttons |

- Dark mode reduces all shadow opacity by **50%**

---

## 6. Button System

### Primary Button (`CustomButton` — filled)
```
Background:    AppColors.primary (#1B4D3E)
Foreground:    White
Border-radius: 14 dp
Padding:       horizontal 20 dp, vertical 14 dp
Font:          14 sp, w600, letterSpacing 0.2
Shadow:        AppShadows.low (enabled, not loading)
Disabled:      AnimatedOpacity → 0.65
Loading:       22×22 CircularProgressIndicator (strokeWidth 2.2)
```

### Outlined Button (`CustomButton` — `isOutlined: true`)
```
Background:    Transparent
Border:        1.5 dp solid primary (or white if onDark)
Foreground:    Primary color (or white if onDark)
Border-radius: 14 dp
Padding:       horizontal 20 dp, vertical 14 dp
```

### On-dark variant (`onDark: true`)
```
Filled:   White background, primary foreground
Outlined: White border + white text
```

### FilledButton (Material 3 — modals & package pages)
```
Background:    AppColors.primary or #0F5E56
Border-radius: 14 dp
Padding:       vertical 14 dp
```

### Onboarding CTA Button
```
Background:    Color.lerp(backdropColor, overlayColor, 0.6) — dynamic
Border:        white @ 18% opacity, 1 dp
Border-radius: 14 dp
Font:          titleMedium, w700, white
```

> **Rule:** Use `CustomButton` for all primary and secondary CTAs. Use `FilledButton` only in bottom sheets / modals.

---

## 7. Input Fields

### `CustomTextField` + `AppTheme.inputDecorationTheme`
```
Fill:          #F3F4F6 (light) / #374151 (dark)
Border:        none (default), primary 2dp (focused), error 1dp (error)
Border-radius: 12 dp
Padding:       horizontal 16 dp, vertical 16 dp
Label:         Above field as Text(titleMedium, w600) + SizedBox(height: 8)
HintStyle:     body1 @ textSecondary
```

### Input icon conventions
- `Icons.phone_android_rounded` → Phone
- `Icons.badge_outlined` → MRN / ID
- `Icons.lock_open_rounded` → OTP/Password

---

## 8. Cards

### Standard Card (`AppTheme.cardTheme`)
```
Elevation:     0
Border:        1 dp solid divider color
Border-radius: 12 dp
Margin:        EdgeInsets.zero
```

### Large Content Card (Records / Documents)
```
Border-radius: 24–28 dp
Padding:       16 dp all
Icon container: 52×52, borderRadius 18, accentColor @12%
```

### Quick-action tile
```
Width:         156 dp | borderRadius: 22 dp | padding: 16 dp
Icon box:      44×44, borderRadius 14
Border:        1 dp outlineVariant
```

### Quick-action grid card
```
Background:    White | Border: 1.5 dp iconColor @8%
Border-radius: 20 dp | Shadow: iconColor @4%, blur 10, offset (0,4)
Icon:          44×44, borderRadius 14 | Grid: 3 col, ratio 0.85
```

### Metric card
```
Width:         (screenWidth - 44) / 2
Background:    color @8% | borderRadius: 22 dp | padding: 16 dp
Icon:          CircleAvatar radius 20, color @16%
Value:         headlineSmall, w800, accent color
```

### Package card (health packages list)
```
Background:    White | borderRadius: 24 dp
Shadow:        black @6%, blur 16, offset (0, 8)
Image:         148 dp tall, top-only corners 24 dp radius
```

---

## 9. Bottom Navigation Bar

```
Container:     margin ltrb(16, 0, 16, 20) | padding h8 v8
Background:    surfaceLight / surfaceDark
Border-radius: 28 dp | Shadow: AppShadows.high
```

### Active item
```
Background:    primary @10% | borderRadius: 16 dp
Icon:          selectedIcon, primaryColor, 22 dp
Label:         10 sp, w600, primaryColor
```

### Inactive item
```
Icon:          outline variant, textSecondary, 22 dp
Label:         10 sp, w400, textSecondary
```

### Tab order
1. Home — `home_outlined` / `home_rounded`
2. Records — `folder_outlined` / `folder_rounded`
3. Bookings — `calendar_month_outlined` / `calendar_month_rounded`
4. My Club — `workspace_premium_outlined` / `workspace_premium_rounded`
5. Profile — `person_outline_rounded` / `person_rounded`

---

## 10. Icons

### Conventions
- **Rounded variants always:** `*_rounded` suffix
- **Outlined for inactive/secondary:** `*_outlined` suffix
- **Standard size:** 24 dp | **Nav bar:** 22 dp | **Inline/badge:** 16–18 dp
- Arrow forward: `Icons.arrow_forward_rounded`
- Arrow back: `Icons.arrow_back_rounded`
- Inline row arrow: `Icons.arrow_forward_ios_rounded` (size 10)

### Icon-in-container pattern
```dart
Container(
  width: 44, height: 44,
  decoration: BoxDecoration(
    color: accentColor.withOpacity(0.12),
    borderRadius: BorderRadius.circular(14),
  ),
  child: Icon(icon, color: accentColor, size: 24),
)
```

---

## 11. Section Header Pattern

```dart
Row [
  Column [
    Text(title,    Manrope titleMedium w700 textPrimary)
    SizedBox(h: 8)
    Text(subtitle, Manrope bodyMedium  w500 textSecondary, height 1.35)
  ]
  Spacer
  InkWell(borderRadius: 12) [
    Text('View all', secondary color, w700)
    Icon(Icons.arrow_forward_rounded, size 16, secondary)
  ]
]
```

---

## 12. Status & Tag Badges

### Status badge
```
Padding:       h12 v7 | borderRadius: 999
Background:    statusColor @12% | Border: 1dp statusColor @16%
Font:          bodySmall, w700, letterSpacing 0.1
```

### Filter chip
- Selected: `primary` bg, white text/icons
- Unselected: surface bg, `outlineVariant` border
- borderRadius: 20 dp

### Pill label
```
Padding: h12 v7 | borderRadius: 999 | bg: surfaceContainerHighest
```

---

## 13. Animation Standards

| Element | Duration | Curve |
|---------|----------|-------|
| AnimatedSwitcher / transitions | 220 ms | default |
| Banner carousel auto-scroll | 450 ms | easeInOut |
| Banner carousel timer | 4 s | — |
| Nav item selection | 220 ms | easeInOut |
| Onboarding page swipe | 280 ms | easeOut |
| Button opacity (disabled) | 180 ms | default |
| Dot indicators expand | 220 ms | default |
| Snackbar auto-dismiss | 3 s | — |

### Page indicator dots
- Active: `26 dp` wide, `8 dp` tall, primary color, radius 99
- Inactive: `8 dp` wide, `8 dp` tall, outlineVariant or white @35%

---

## 14. AppBar Pattern

```
backgroundColor:   surfaceLight / surfaceDark
foregroundColor:   textPrimary
elevation:         0.5
centerTitle:       false  ← NEVER centered
surfaceTintColor:  transparent
```

For hero screens (Home tab): `extendBodyBehindAppBar: true`

---

## 15. Screen-by-Screen Reference

### Onboarding
- Full-bleed background image + per-page gradient overlay
- Dynamic glassmorphism CTA button
- Skip: `TextButton`, white foreground
- Animated pill dots at center

### Auth / Login
- Gradient bg: `primary @8% → scaffold`
- Leading icon: `Icons.local_hospital_rounded`, size 44, primary
- Form in `CustomCard` with step pill badge
- Primary CTA: `CustomButton` filled full-width
- Secondary CTA: `CustomButton` outlined full-width

### Home Dashboard
- Full-bleed hero: background image + blue gradient overlay, bottom 32 dp curve
- Membership card: purple gradient, 18 dp radius
- Announcement ticker overlaps hero (offset −17 dp)
- Quick actions: 3-column grid, 20 dp cards, icons 14 dp radius
- Banner carousel: 190 dp tall, 24 dp radius, viewport 94%
- Section headers: left title + right "View all"
- Doctor cards: horizontal list, 216 dp wide, 340 dp tall
- Lab/Package cards: horizontal list, 140 dp tall

### Tab Screens (Records, Bookings, Profile)
- Standard AppBar (no extension)
- Screen padding: 16 dp horizontal
- Filter chips: horizontal scrollable row at top
- Content cards: 24–28 dp radius

---

## 16. Do's and Don'ts

### ✅ Do
- Always use `AppColors`, `AppTextStyles`, `AppTheme`, `AppSpacing`, `AppRadius`
- Use `Theme.of(context)` tokens — not raw hex in widgets
- Use `CustomButton` for all primary and secondary CTAs
- Use `CustomTextField` for all form inputs
- Use `*_rounded` icon variants
- Use radius `999` for all pill/badge shapes
- Keep horizontal screen padding at `16 dp`
- Show loading with `CircularProgressIndicator` (strokeWidth `2.2`)

### ❌ Don't
- Hardcode colors outside design system files
- Use `centerTitle: true` on AppBars
- Use `elevation > 0` on cards or AppBars
- Use fonts other than Manrope
- Create new shadow values outside `AppShadows`
- Use font sizes outside the type scale
- Use `TextButton` or `ElevatedButton` for primary actions

---

## 17. File Locations (Quick Reference)

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
