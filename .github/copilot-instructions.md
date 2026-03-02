# SkillDrills – Copilot Instructions

## Project Overview

**SkillDrills** is a cross-platform Flutter application (iOS, Android) backed by Firebase (Firestore, Firebase Auth). It is a universal practice-tracking tool for athletes, musicians, gamers, and any skill domain. Users build custom _drills_ with flexible measurement schemas, run timed or open practice sessions, and track progress over time.

The long-term vision includes:

- A white-label / clone strategy targeting specific skill verticals (hockey, guitar, chess, yoga, etc.)
- An in-app **Skill/Sport Mode** selector that re-themes the UI and surfaces relevant curated drills
- A freemium model where free users get one active skill mode; paid tiers unlock multiple modes, saved routines, and advanced analytics

---

## Tech Stack

| Layer        | Technology                                                                                                          |
| ------------ | ------------------------------------------------------------------------------------------------------------------- |
| Framework    | Flutter (Dart)                                                                                                      |
| Backend / DB | Firebase Firestore (per-user subcollections)                                                                        |
| Auth         | Firebase Auth (email/password + Google Sign-In)                                                                     |
| State        | `provider` + `ChangeNotifier`, `InheritedWidget` for session service                                                |
| Local prefs  | `shared_preferences`                                                                                                |
| UI utilities | `sliding_up_panel`, `select_dialog`, `flutter_picker_plus`, `expandable`, `flutter_svg`, `settings_ui`, `vibration` |

---

## Repository Structure

```
lib/
  main.dart                   # App entry point, theme wiring, global service init
  login.dart                  # Auth screen (email + Google)
  nav.dart                    # Root bottom nav shell (5 tabs)
  nav_tab.dart                # NavTab widget wrapper
  session.dart                # Sliding session panel UI (in-progress session)
  firebase_options.dart

  models/
    settings.dart             # Local settings (vibrate, darkMode)
    skill_drills_dialog.dart  # Reusable dialog model

    firestore/
      activity.dart           # Activity (a named skill domain, e.g. "Slap Shot")
      category.dart           # Category tag (e.g. "Accuracy", "Speed")
      drill.dart              # Drill (belongs to Activity + DrillType, has Measurements)
      drill_type.dart         # DrillType (template: title, descriptor, timer, ordered Measurements)
      measurement.dart        # Measurement definition (type, metric, label, order, value, target, reverse)
      measurement_result.dart # Saved result for one measurement in a completed session
      measurement_target.dart # User-defined target for a measurement (with reverse flag)
      skill_drill_user.dart   # Extended user profile (displayName, email, photoURL)

  services/
    auth.dart                 # Auth helpers (Google sign-in, email validation, password strength)
    session.dart              # SessionService (stopwatch, timer, ChangeNotifier)
    factory.dart              # Firestore factory helpers
    dialogs.dart              # Global dialog helper
    utility.dart              # Utility functions (duration formatting, etc.)

  tabs/
    drills.dart               # Drills list tab (Firestore stream, CRUD)
    history.dart              # History tab (STUB – not yet implemented)
    routines.dart             # Routines tab (STUB – not yet implemented)
    profile.dart              # Profile tab (user info, session count)
    start.dart                # Start tab (quick-start session, shows saved routines)

    drills/
      drill_detail.dart       # Create / edit drill (activity, categories, drill type, measurements, targets)
      drill_item.dart         # Drill list item widget

    profile/
      settings/               # App settings screen

  theme/
    theme.dart                # Light + dark ThemeData
    settings_state_notifier.dart  # Settings state (darkMode, vibrate)

  widgets/
    app_list_item.dart        # Generic list item widget
    basic_title.dart          # AppBar title text
    user_avatar.dart          # Firebase auth avatar widget
```

---

## Data Model Design

### Core Entity Hierarchy

```
User (Firebase Auth UID)
 └── Activities[]            (user-defined skill domains, e.g. "Slap Shot", "C Major Scale")
      └── Categories[]       (tags per activity, e.g. "Accuracy", "Tempo")
 └── DrillTypes[]            (reusable drill templates)
      └── Measurements[]     (ordered list of metrics for this drill type)
 └── Drills[]                (user's drill library)
      ├── activity           (embedded Activity snapshot)
      ├── drillType          (embedded DrillType snapshot)
      ├── measurements[]     (subcollection – Measurement definitions with targets)
      └── categories[]       (subcollection – Category tags)
 └── Sessions[]              (to be built)
      ├── startedAt, endedAt, duration
      └── DrillResults[]
           └── MeasurementResults[]  (actual recorded values per measurement)
```

### Measurement Model (the core flexible primitive)

```dart
class Measurement {
  final String type;    // "amount" | "duration" — drives the input widget rendered
  final String metric;  // e.g. "reps", "seconds", "bpm", "yards", "goals"
  final String label;   // Human-readable label shown in the session UI
  final int order;      // Display/input order within a drill
  dynamic value;        // The recorded value (used in MeasurementResult)
  dynamic target;       // The goal value (used in MeasurementTarget)
  bool reverse;         // true = lower is better (e.g. time-to-complete)
}
```

**Design intent:** Every sport metric can be modeled by composing measurements. Examples:

- Hockey shot accuracy: `{ type: "amount", metric: "goals", label: "Goals scored", target: 10, reverse: false }`
- Speed skating lap: `{ type: "duration", metric: "seconds", label: "Lap time", target: 90, reverse: true }`
- Guitar scale BPM: `{ type: "amount", metric: "bpm", label: "Tempo", target: 120, reverse: false }`

---

## Navigation (5 Tabs)

| Index | Tab                     | Status                                                                         |
| ----- | ----------------------- | ------------------------------------------------------------------------------ |
| 0     | **Profile**             | Partially built — shows user info, placeholder session count                   |
| 1     | **History**             | Stub — empty `Container()`                                                     |
| 2     | **Start** (center/home) | Partially built — quick-start session, "My Routines" section placeholder       |
| 3     | **Drills**              | Functional — list, create, edit, delete drills with full measurement authoring |
| 4     | **Routines**            | Stub — empty `Container()`                                                     |

The **Start** tab hosts a `sliding_up_panel` session overlay that slides up from the bottom when a session is active.

---

## Current Feature State

### ✅ Working

- Firebase Auth (email/password + Google Sign-In)
- Drill CRUD (create/edit/delete) with full measurement schema authoring
- Activity and Category management (linked to drills)
- DrillType templates with ordered measurements and timers
- Session timer (stopwatch via `SessionService`)
- In-session slide-up panel UI (cancel/end session buttons, timer display)
- App settings (dark mode toggle, vibration toggle)
- Light + dark theming
- Custom "Choplin" font branding

### 🚧 Partially Built

- Start tab: quick-start button works; Routines section is a placeholder
- Profile tab: shows avatar and display name; session count is hardcoded `0`
- Session panel: timer and cancel/end exist but recording drill results is not implemented

### ❌ Not Yet Built

- **Session drill results recording** — selecting drills during a session and saving `MeasurementResult` values
- **Session persistence to Firestore** — saving completed sessions as `Session` documents with nested `DrillResult` + `MeasurementResult` subcollections
- **History tab** — listing past sessions, drill-level breakdowns, and progress over time
- **Routines tab** — authoring and saving ordered sets of drills as a `Routine`
- **Routine → Session flow** — starting a session from a saved routine and stepping through drills
- **Profile stats** — real session count, streaks, personal bests, charts
- **Skill/Sport Mode** — user selects their active skill (hockey, guitar, chess, etc.); drives curated default activities/drill types and subtle UI theming changes
- **Paid tiers** — free = 1 active skill mode; paid = multiple modes, unlimited routines, analytics export

---

## Roadmap

### Phase 1 – Core Loop (MVP completion)

1. **Session drill flow** — during an active session the user can add drills from their library, step through each drill's measurements, and input result values
2. **Session save** — on "End Session" persist a `Session` Firestore document with `DrillResult[]` and `MeasurementResult[]` subcollections
3. **History tab** — list past sessions (date, duration, drill count); tap to view drill-level results per session
4. **Profile stats** — compute and display real session count, total practice time, and per-drill personal bests from session history

### Phase 2 – Routines

5. **Routine model** — `Routine { title, description, drills: DrillRef[] }` stored in Firestore subcollection under user
6. **Routines tab** — CRUD for routines; drag-to-reorder drills within a routine
7. **Start from routine** — Start tab surfaces saved routines; tapping one pre-loads the drill sequence into the session

### Phase 3 – Skill Modes

8. **Skill/Sport Mode model** — `SkillMode { id, title, icon, accentColor, defaultActivities[], defaultDrillTypes[] }`
9. **Mode selector UI** — onboarding screen or profile setting to choose active skill (Hockey, Golf, Guitar, Chess, Yoga, Fitness, etc.)
10. **Themed UI per mode** — accent color, illustrations, and curated empty-state copy adapt to the selected mode
11. **Curated drill library** — seed Firestore with default `Activity` + `DrillType` templates per skill mode that users can adopt into their own library

### Phase 4 – Monetization & Analytics

12. **Subscription/tier system** — `RevenueCat` or `in_app_purchase`; enforce 1 active skill mode on free tier
13. **Progress charts** — per-drill measurement trend lines using `fl_chart` or `syncfusion_flutter_charts`
14. **Streaks & achievements** — session streak tracking, milestone badge system
15. **Data export** — CSV/JSON export of session history for paid users

### Phase 5 – White-Label / Clone Readiness

16. **Flavor configuration** — Flutter flavors (`--flavor hockey`, `--flavor guitar`) to swap branding assets, app name, default mode, and Firebase project
17. **Remote config** — Firebase Remote Config for feature flags, curated content per flavor
18. **App Store / Play Store assets** — per-flavor metadata, screenshots, descriptions

---

## Code Style & Conventions

- Follow the rules in [STYLE_GUIDE.md](../STYLE_GUIDE.md)
- Firestore collections live under the authenticated user's UID: `collection('drills').doc(uid).collection('drills')`
- Models have three constructors: `ClassName(...)`, `ClassName.fromMap(map, {reference})`, `ClassName.fromSnapshot(snapshot)`
- `toMap()` is used for all Firestore writes
- Widgets are split into `StatefulWidget` / `State` pairs even when simple, to allow future interactivity
- `Theme.of(context)` values for all colors — no hardcoded color literals except in `theme.dart`
- Use `navigatorKey.currentState!.push(MaterialPageRoute(...))` for navigation from outside the widget tree
- Session state lives in the global `SessionService` singleton accessed via `SessionServiceProvider` inherited widget

---

## Key Design Decisions & Constraints

- **General-purpose compromise**: The `Measurement` model is intentionally generic (`type`, `metric`, `label`) so that any sport or skill can be modeled without schema changes. Sport-specific UX is layered on top via Skill Modes, not by changing the data model.
- **Per-user Firestore data**: All user content (drills, activities, sessions, routines) lives under `/{collection}/{uid}/{subcollection}` — no shared public content yet.
- **No offline-first yet**: The app assumes connectivity. Firestore's built-in caching provides light offline resilience but is not explicitly configured.
- **Measurement `type` values**: Currently `"amount"` and `"duration"`. Extending to `"boolean"`, `"scale"` (1–10), or `"distance"` is planned and should be backward-compatible by adding new input widget cases.
