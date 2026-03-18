import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/theme/activity_theme.dart';
import 'package:skilldrills/theme/theme.dart';

/// Tracks the user's *primary* active [Activity] — defined as the one with
/// the most recent [Activity.lastActivatedAt] timestamp — and derives the
/// accent colour, emoji, and terminology labels used to skin the app.
///
/// Usage:
/// ```dart
/// activeActivityNotifier.start(uid); // call in Nav.initState()
/// activeActivityNotifier.stop();     // call on sign-out if needed
/// ```
///
/// Expose via [ChangeNotifierProvider] so widgets can call
/// `context.watch<ActiveActivityNotifier>()` to rebuild when it changes.
class ActiveActivityNotifier extends ChangeNotifier {
  Activity? _primary;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  // ── Public getters ────────────────────────────────────────────────────────

  /// The most recently activated active activity, or `null` before the first
  /// snapshot or when the user has no active activities.
  Activity? get primary => _primary;

  /// Accent colour derived from [primary].
  ///
  /// Priority:
  ///   1. [Activity.customColor] — user-set Pro override (any activity)
  ///   2. Predefined map in [ActivityColors] — standard activities
  ///   3. [SkillDrillsColors.brandBlue] — custom / unknown activities with no
  ///      user-set colour ("default theme")
  Color get accentColor {
    final p = _primary;
    if (p == null) return SkillDrillsColors.brandBlue;
    if (p.customColor != null) return Color(p.customColor!);
    return ActivityColors.forActivity(p.title);
  }

  /// `true` when the activity uses the default brand theme (brandBlue),
  /// i.e. it is a custom/unknown activity with no user-set colour.
  /// Used to decide whether to show the plain logo or the emoji overlay logo.
  bool get isDefaultTheme {
    final p = _primary;
    if (p == null) return true;
    // User has set an explicit colour → themed.
    if (p.customColor != null) return false;
    // Predefined standard activity → themed.
    if (ActivityColors.hasActivityTheme(p.title)) return false;
    // Custom / unknown with no override → default theme.
    return true;
  }

  /// Emoji representing the primary activity (e.g. "🏒" for Hockey).
  String get icon => _primary?.icon ?? '🎯';

  /// Activity-specific label for individual practice items (e.g. "Drill",
  /// "Exercise", "Workout").
  String get drillLabel => _primary?.drillLabel ?? 'Drill';

  /// Activity-specific label for groups of reps (e.g. "Sets", "Rounds",
  /// "Intervals").
  String get setsLabel => _primary?.setsLabel ?? 'Sets';

  /// Activity-specific label for individual repetitions (e.g. "Reps", "Laps",
  /// "Balls").
  String get repsLabel => _primary?.repsLabel ?? 'Reps';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Start listening for the primary active activity for [uid].
  ///
  /// Picks the activity with the most recent [kActivityLastActivatedAtField]
  /// among all currently active activities. If none have been explicitly
  /// activated yet (seeded defaults), falls back to alphabetical order.
  ///
  /// Safe to call multiple times — cancels any prior subscription first.
  void start(String uid) {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance.collection('activities').doc(uid).collection('activities').where('is_active', isEqualTo: true).snapshots().listen((snap) {
      if (snap.docs.isEmpty) {
        if (_primary != null) {
          _primary = null;
          notifyListeners();
        }
        return;
      }

      // Convert all docs to Activity objects.
      final activities = snap.docs
          .map((d) => Activity.fromSnapshot(
                d as DocumentSnapshot<Map<String, dynamic>>,
              ))
          .toList();

      // Pick the one with the most recent lastActivatedAt.  If none have been
      // explicitly activated, fall back to alphabetical order (stable sort).
      activities.sort((a, b) {
        final ta = a.lastActivatedAt;
        final tb = b.lastActivatedAt;
        if (ta == null && tb == null) {
          return (a.title ?? '').compareTo(b.title ?? '');
        }
        if (ta == null) return 1; // b wins
        if (tb == null) return -1; // a wins
        return tb.compareTo(ta); // descending — most recent first
      });

      final next = activities.first;
      if (next.id != _primary?.id || next.title != _primary?.title) {
        _primary = next;
        notifyListeners();
      }
    });
  }

  /// Stop listening and clear the cached activity (e.g. on sign-out).
  void stop() {
    _sub?.cancel();
    _sub = null;
    if (_primary != null) {
      _primary = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
