# Skill Drills — UI Style Guide

> **Single source of truth** for all UI decisions in this project.  
> When generating new features via Copilot or any other tool, reference these guidelines to ensure visual consistency.

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Color System](#2-color-system)
3. [Typography](#3-typography)
4. [Spacing](#4-spacing)
5. [Shape & Border Radius](#5-shape--border-radius)
6. [Elevation & Shadow](#6-elevation--shadow)
7. [Component Patterns](#7-component-patterns)
8. [Iconography](#8-iconography)
9. [Theme Usage in Code](#9-theme-usage-in-code)
10. [Do's and Don'ts](#10-dos-and-donts)

---

## 1. Design Philosophy

Skill Drills is an **active, achievement-focused** training tracker. The visual language should feel:

- **Energetic** — bold typography, strong contrast, confident color.
- **Modern & clean** — generous whitespace, rounded corners, flat/low-elevation surfaces.
- **Legible at a glance** — athletes look at metrics quickly; readability wins over decoration.
- **Dark-mode-first ready** — the deep dark palette is the "hero" experience; light mode should be equally polished.

---

## 2. Color System

All colors are defined as constants in `lib/theme/theme.dart` under `SkillDrillsColors`.

### Brand Colors

| Token | Hex | Usage |
|---|---|---|
| `brandBlue` | `#02A4DD` | Primary brand color. Buttons, links, active states, progress bars. |
| `brandBlueDark` | `#0186B5` | Pressed / hover variant of brand blue. |
| `energyOrange` | `#FF6B35` | Accent / high-energy CTA (e.g. "Finish session", badges, streaks). |
| `energyOrangeDark` | `#E05520` | Pressed variant of energy orange. |

> **Rule:** Use `brandBlue` for primary actions (sign in, save, confirm). Use `energyOrange` sparingly for high-stakes, achievement, or time-sensitive elements.

### Semantic Colors

| Token | Hex | Usage |
|---|---|---|
| `success` | `#22C55E` | Positive outcomes, completed state. |
| `warning` | `#F59E0B` | Caution states. |
| `error` / `errorDark` | `#EF4444` / `#FF6B6B` | Errors, validation failures, destructive actions. |

### Light Mode Neutrals

| Token | Hex | Usage |
|---|---|---|
| `lightBackground` | `#F0F4F8` | `Scaffold` background. |
| `lightSurface` | `#FFFFFF` | Cards, dialogs, nav bar, app bar. |
| `lightCard` | `#FFFFFF` | `Card` widget background. |
| `lightAppBar` | `#FFFFFF` | App bar background (also `colorScheme.primary` in light). |
| `lightDivider` | `#E2E8F0` | `Divider`, input borders. |
| `lightOnSurface` | `#1A202C` | Primary text on light backgrounds. |
| `lightOnSurfaceMuted` | `#718096` | Secondary / hint text on light backgrounds. |

### Dark Mode Neutrals

| Token | Hex | Usage |
|---|---|---|
| `darkBackground` | `#0E1117` | `Scaffold` background. |
| `darkSurface` | `#161B22` | Cards, dialogs, nav bar, app bar. |
| `darkCard` | `#1C2128` | `Card` widget background. |
| `darkAppBar` | `#161B22` | App bar background (also `colorScheme.primary` in dark). |
| `darkDivider` | `#30363D` | `Divider`, input borders. |
| `darkOnSurface` | `#E6EDF3` | Primary text on dark backgrounds. |
| `darkOnSurfaceMuted` | `#8B949E` | Secondary / hint text on dark backgrounds. |

### Login Screen Gradient

The splash/login screen uses a `LinearGradient` instead of a flat color:

```dart
LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0186B5), SkillDrillsColors.brandBlue, Color(0xFF01C4A1)],
  stops: [0.0, 0.5, 1.0],
)
```

---

## 3. Typography

### Fonts

| Font | Weights Available | Usage |
|---|---|---|
| **Choplin** | ExtraLight → Black (all italics too) | Display, headings, button labels, section titles — anything impactful |
| **System default** (Roboto / SF Pro) | Regular, Medium, SemiBold, Bold | Body text, form labels, captions |

> The Choplin font files live in `assets/fonts/`. Never hard-code a non-Choplin font for display-level text.

### Text Scale

All styles are accessed via `Theme.of(context).textTheme.*` — never hard-code sizes outside a one-off widget.

| Token | Font | Weight | Size | Usage |
|---|---|---|---|---|
| `displayLarge` | Choplin | Black (w900) | 32 | Full-screen hero titles |
| `displayMedium` | Choplin | Bold (w700) | 28 | Section hero titles |
| `displaySmall` | Choplin | Bold (w700) | 24 | Page headers |
| `headlineMedium` | Choplin | Bold (w700) | 20 | Card headings, panel titles |
| `headlineSmall` | System | SemiBold (w600) | 18 | Sub-headings |
| `titleLarge` | System | Bold (w700) | 14 | Settings section labels, `UPPERCASE` category labels — brand blue color |
| `titleMedium` | System | SemiBold (w600) | 16 | List tile titles |
| `titleSmall` | System | Medium (w500) | 14 | List tile subtitles, muted labels |
| `bodyLarge` | System | Regular | 16 | Primary body copy |
| `bodyMedium` | System | Regular | 14 | Secondary body copy, captions |
| `bodySmall` | System | Regular | 12 | Timestamps, fine print |
| `labelLarge` | Choplin | Bold (w700) | 15 | Button labels (auto-applied via `ElevatedButtonTheme`) |

### Letter Spacing Rules

- ALL-CAPS labels (section headers, `BasicTitle`): `letterSpacing: 0.8`
- Button labels: `letterSpacing: 0.4`
- Normal body text: default (0)

---

## 4. Spacing

Constants live in `SkillDrillsSpacing` in `lib/theme/theme.dart`.

| Token | Value | Usage |
|---|---|---|
| `xs` | 4 dp | Tight internal padding (chip, badge) |
| `sm` | 8 dp | Default card margin, icon-to-text gap |
| `md` | 16 dp | Standard horizontal content padding |
| `lg` | 24 dp | Section spacing, screen edge padding |
| `xl` | 32 dp | Large vertical gaps |
| `xxl` | 48 dp | Hero section breathing room |

> **Rule:** Never use arbitrary spacing values. Map to the closest token. Use multiples of 4 for anything not covered.

---

## 5. Shape & Border Radius

All border-radius values live in `SkillDrillsRadius`.

| Token | Value | Usage |
|---|---|---|
| `xs` | 6 dp | Chips, small badges |
| `sm` | 10 dp | **Buttons** (primary), text fields, small cards |
| `md` | 14 dp | **Cards**, list tiles with elevation |
| `lg` | 20 dp | Bottom sheets, dialogs, modals |
| `full` | 100 dp | Avatars, pill badges, FABs |

Pre-built `BorderRadius` constants: `SkillDrillsRadius.xsBorderRadius`, `.smBorderRadius`, `.mdBorderRadius`, `.lgBorderRadius`.

> **Rule:** Avoid `BorderRadius.zero` (sharp corners) unless intentionally matching a third-party widget (e.g. `flutter_signin_button`).

---

## 6. Elevation & Shadow

The design uses minimal, purposeful elevation.

| Surface | Light Elevation | Dark Elevation |
|---|---|---|
| Scaffold background | 0 | 0 |
| App bar (default) | 0 | 0 |
| App bar (scrolled under) | 1 | 1 |
| Cards | 2 | 2 |
| Dialogs | 8 | 12 |
| Buttons | 0 (flat) | 0 (flat) |
| Bottom nav | 8 | 8 |

Shadow colors: `rgba(0,0,0, 0.094)` light · `rgba(0,0,0, 0.31)` dark.

> **Rule:** Prefer `elevation: 0` with a distinct background color to create separation, rather than heavy drop shadows.

---

## 7. Component Patterns

### Buttons

Use **theme-driven** buttons — do not add custom `style:` unless overriding for a specific one-off reason (e.g. the login gradient screen uses `backgroundColor: Colors.white`).

```dart
// ✅ Primary action
ElevatedButton(
  onPressed: () { ... },
  child: const Text('Save Drill'),
)

// ✅ Destructive / secondary
TextButton(
  style: TextButton.styleFrom(foregroundColor: SkillDrillsColors.error),
  onPressed: () { ... },
  child: const Text('Delete'),
)

// ✅ Outlined / ghost
OutlinedButton(
  onPressed: () { ... },
  child: const Text('Cancel'),
)

// ✅ Energy accent (use sparingly — finish session, streak CTA, etc.)
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: SkillDrillsColors.energyOrange,
    foregroundColor: Colors.white,
  ),
  onPressed: () { ... },
  child: const Text('Finish Session'),
)
```

- Minimum height: **48 dp**
- Full-width buttons in forms / bottom areas
- Use `Choplin` font via `labelLarge` (already wired into `ElevatedButtonTheme`)

### Text Fields

All fields get the `InputDecorationTheme` automatically. Just provide `labelText` and optionally a `prefixIcon`:

```dart
TextFormField(
  decoration: const InputDecoration(
    labelText: 'Drill Name',
    prefixIcon: Icon(Icons.sports),
  ),
)
```

- Filled background, outlined border
- Brand blue focus ring (2 dp)
- `10 dp` border radius (sm)
- Always use `labelText` (floating label) not `hintText` alone

### Cards

```dart
Card(
  // elevation, color, shape already come from CardTheme
  child: Padding(
    padding: const EdgeInsets.all(SkillDrillsSpacing.md),
    child: ...,
  ),
)
```

- Radius: `14 dp` (md)
- Default margin: `8 dp` horizontal, `4 dp` vertical (from `CardTheme`)
- Never set `color:` on `Card` — use `cardTheme.color`

### Dialogs

```dart
showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Override Session?'),
    content: Text('...', style: Theme.of(context).textTheme.bodyMedium),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ElevatedButton(onPressed: () { ... }, child: const Text('Continue')),
    ],
  ),
);
```

- Radius: `20 dp` (lg) — from `dialogTheme`
- Floating snackbars use `SnackBarBehavior.floating` automatically

### Section Titles (App Bar / List)

Use `BasicTitle` widget for all `SliverAppBar` titles and tab-level headings:

```dart
const BasicTitle(title: 'Drills') // Renders DRILLS in Choplin Black
```

For settings section headers, use `Theme.of(context).textTheme.titleLarge` (brand blue, 14 dp, bold).

### Progress / Loading

```dart
// Linear - use at the top of a list while loading
LinearProgressIndicator() // color auto-set to brandBlue

// Circular - use in buttons or inline
CircularProgressIndicator() // same
```

---

## 8. Iconography

- Use **Material Icons** (`Icons.*`) throughout.
- Prefer the **outlined** variant (`Icons.lock_outline`, `Icons.email_outlined`) for form prefix icons.
- Prefer the **rounded** variant for navigation and action icons.
- Default icon color comes from `iconTheme` — never hard-code `Colors.black` or `Colors.white` for icons; use `Theme.of(context).iconTheme.color` or let the theme handle it.
- Icon size: **24 dp** default, **28 dp** for app bar actions, **20 dp** for inline/body icons.

---

## 9. Theme Usage in Code

### Accessing Colors

```dart
// ✅ Brand blue from anywhere
SkillDrillsColors.brandBlue

// ✅ Theme-aware surface color (adapts light/dark automatically)
Theme.of(context).colorScheme.surface

// ✅ Primary text color
Theme.of(context).textTheme.bodyLarge!.color

// ✅ Brand blue via colorScheme (secondary)
Theme.of(context).colorScheme.secondary

// ✅ Energy orange (tertiary)
Theme.of(context).colorScheme.tertiary

// ❌ Avoid raw hex values in widget files
const Color(0xFF02A4DD) // only acceptable inside theme.dart
```

### colorScheme Mapping

| Key | Light | Dark | Used for |
|---|---|---|---|
| `primary` | `#FFFFFF` | `#161B22` | App bar background |
| `onPrimary` | `#718096` | `#8B949E` | Muted icon/text on app bar |
| `secondary` | `#02A4DD` | `#02A4DD` | Brand blue actions |
| `onSecondary` | White | White | Text on brand-blue surfaces |
| `tertiary` | `#FF6B35` | `#FF6B35` | Energy orange accents |
| `surface` | `#FFFFFF` | `#161B22` | Cards, nav bar |
| `onSurface` | `#1A202C` | `#E6EDF3` | Primary text |

> **Note:** `colorScheme.primary` maps to the app bar color, **not** the brand blue. For the brand color always use `Theme.of(context).primaryColor` or `SkillDrillsColors.brandBlue`.

### Sign-In / Auth Screens

Auth screens (`_SignInScreen`, `_SignUpScreen`) use `SkillDrillsTheme.lightTheme` explicitly via a `Theme` widget, ensuring they always render in light mode regardless of the device setting. This is intentional.

---

## 10. Do's and Don'ts

### ✅ Do

- Import `SkillDrillsColors`, `SkillDrillsRadius`, `SkillDrillsSpacing` when you need design tokens.
- Use `Theme.of(context).textTheme.*` for all text styles.
- Let `ElevatedButtonTheme` handle button shape/padding — just provide `child`.
- Use `Card` with an inner `Padding(EdgeInsets.all(SkillDrillsSpacing.md), ...)` for content cards.
- Use `Choplin` for display text, headings, and button labels.
- Use outlined Material icon variants for form fields.
- Keep the login screen gradient (`brandBlue` → teal `#01C4A1`) — it's the brand splash.

### ❌ Don't

- Hard-code `Colors.black`, `Colors.white`, `Colors.black87`, or `Colors.black54` in widget files — use theme tokens.
- Use `BorderRadius.zero` for app-created buttons or cards.
- Use raw `TextStyle(color: Colors.xxx)` in widget files when a `textTheme` slot covers the intent.
- Set `elevation:` on `Card` widgets — it comes from `CardTheme`.
- Use `showDialog` with `SimpleDialog` for auth forms — use `MaterialPageRoute` with `fullscreenDialog: true`.
- Add a new font family without updating `pubspec.yaml` AND documenting it here.
- Use `primaryColor` for anything other than the brand blue — use `colorScheme.secondary` for programmatic access in widget code where appropriate.
