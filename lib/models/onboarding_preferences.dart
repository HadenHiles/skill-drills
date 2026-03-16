import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's onboarding selections locally (SharedPreferences) until
/// they authenticate, at which point [factory.dart] reads these values and
/// applies them to the Firestore bootstrap (active activities, default drills, etc.).
class OnboardingPreferences {
  static const String _keyHasSeenWelcome = 'has_seen_welcome';
  static const String _keySelectedActivities = 'onboarding_selected_activities';
  static const String _keyIncludeDefaultDrills = 'onboarding_include_default_drills';

  /// Activity titles selected by the user during onboarding (e.g. ["Hockey", "Guitar"]).
  /// Empty means "no preference" — bootstrap will mark all activities as active.
  List<String> selectedActivities;

  /// Whether to seed the user's library with pre-built drill-type templates.
  bool includeDefaultDrills;

  OnboardingPreferences({
    this.selectedActivities = const [],
    this.includeDefaultDrills = true,
  });

  // ── Persistence ────────────────────────────────────────────────────────────

  /// Returns true if the user has already completed the welcome flow.
  /// When [uid] is provided, checks a UID-scoped key first so that a fresh
  /// account (or a reinstall with a new UID) always sees onboarding, while an
  /// existing account with persisted NSUserDefaults correctly skips it.
  static Future<bool> hasSeenWelcome({String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    if (uid != null && (prefs.getBool('${_keyHasSeenWelcome}_$uid') ?? false)) {
      return true;
    }
    return prefs.getBool(_keyHasSeenWelcome) ?? false;
  }

  /// Called when the user completes (or dismisses) the welcome flow.
  /// Pass [uid] when the user is already authenticated so the flag is also
  /// stored under a UID-scoped key, enabling per-account tracking.
  static Future<void> markWelcomeSeen({String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenWelcome, true);
    if (uid != null) {
      await prefs.setBool('${_keyHasSeenWelcome}_$uid', true);
    }
  }

  /// Loads previously saved onboarding preferences (if any).
  static Future<OnboardingPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = prefs.getString(_keySelectedActivities);
    final List<String> activities = activitiesJson != null ? List<String>.from(jsonDecode(activitiesJson)) : [];
    return OnboardingPreferences(
      selectedActivities: activities,
      includeDefaultDrills: prefs.getBool(_keyIncludeDefaultDrills) ?? true,
    );
  }

  /// Persists the current onboarding preferences locally.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedActivities, jsonEncode(selectedActivities));
    await prefs.setBool(_keyIncludeDefaultDrills, includeDefaultDrills);
  }

  /// Removes stored onboarding preferences once they have been applied
  /// to Firestore (called from factory.dart after bootstrap).
  static Future<void> clearAfterApply() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySelectedActivities);
    await prefs.remove(_keyIncludeDefaultDrills);
  }
}
