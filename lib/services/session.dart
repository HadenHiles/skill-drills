import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/models/firestore/measurement_result.dart';
import 'package:skilldrills/models/firestore/session.dart' as session_model;

class SessionService extends ChangeNotifier {
  // ── Stopwatch ──────────────────────────────────────────────────────────────
  Stopwatch? _watch;
  Timer? _timer;
  Duration? _currentDuration = Duration.zero;

  Duration? get currentDuration => _currentDuration;
  bool get isRunning => _timer != null;

  // ── Session metadata ───────────────────────────────────────────────────────
  String? _sessionTitle;
  DateTime? _startedAt;
  String? _routineId;
  String? _routineTitle;

  String? get sessionTitle => _sessionTitle;
  String? get routineId => _routineId;
  String? get routineTitle => _routineTitle;
  DateTime? get startedAt => _startedAt;

  // ── In-progress drill results ──────────────────────────────────────────────
  final List<session_model.DrillResult> _drillResults = [];

  List<session_model.DrillResult> get drillResults => List.unmodifiable(_drillResults);

  // ── Preferred activity (set at session start for empty sessions) ───────────
  // Stored in memory only — never persisted, cleared on reset so there is no
  // cross-session caching.
  String? _preferredActivityTitle;
  String? _preferredActivityIcon;
  String? _preferredSetsLabel;
  String? _preferredRepsLabel;

  String? get preferredActivityTitle => _preferredActivityTitle;
  String? get preferredActivityIcon => _preferredActivityIcon;
  String? get preferredSetsLabel => _preferredSetsLabel;
  String? get preferredRepsLabel => _preferredRepsLabel;

  /// The activity title the session is locked to. Returns the preferred activity
  /// when set (before any drills are added), then derives it from the first drill.
  String? get lockedActivityTitle => _drillResults.isNotEmpty ? _drillResults.first.activityTitle : _preferredActivityTitle;

  // ── Active drill index (drives the tab bar + PageView) ────────────────────
  int _currentDrillIndex = 0;
  int get currentDrillIndex => _currentDrillIndex;

  void setCurrentDrillIndex(int index) {
    _currentDrillIndex = index.clamp(0, _drillResults.isEmpty ? 0 : _drillResults.length - 1);
    notifyListeners();
  }

  // ── Rest-timer countdown ───────────────────────────────────────────────────
  int? _restCountdown;
  Timer? _restTimer;

  int? get restCountdown => _restCountdown;

  void startRestCountdown(int seconds) {
    _restTimer?.cancel();
    _restCountdown = seconds;
    notifyListeners();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restCountdown != null && _restCountdown! > 0) {
        _restCountdown = _restCountdown! - 1;
        notifyListeners();
      } else {
        t.cancel();
        _restCountdown = null;
        notifyListeners();
      }
    });
  }

  void clearRestCountdown() {
    _restTimer?.cancel();
    _restTimer = null;
    _restCountdown = null;
    notifyListeners();
  }

  /// True while [finishSession] is persisting to Firestore.
  bool _saving = false;
  bool get saving => _saving;

  // ── Constructor ────────────────────────────────────────────────────────────

  SessionService() {
    _watch = Stopwatch();
  }

  // ── Timer helpers ──────────────────────────────────────────────────────────

  void _onTick(Timer timer) {
    _currentDuration = _watch!.elapsed;
    notifyListeners();
  }

  static String defaultSessionTitle() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[DateTime.now().weekday - 1]} Session';
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Start a new session. Clears any previous state.
  ///
  /// [activityTitle], [activityIcon], [setsLabel], [repsLabel] can be supplied
  /// for "empty" sessions so the drill-picker is pre-filtered (and locked) to
  /// the chosen activity without requiring an initial drill to be added first.
  void start({
    String? title,
    String? routineId,
    String? routineTitle,
    String? activityTitle,
    String? activityIcon,
    String? setsLabel,
    String? repsLabel,
  }) {
    _sessionTitle = title ?? defaultSessionTitle();
    _startedAt = DateTime.now();
    _routineId = routineId;
    _routineTitle = routineTitle;
    _preferredActivityTitle = activityTitle;
    _preferredActivityIcon = activityIcon;
    _preferredSetsLabel = setsLabel;
    _preferredRepsLabel = repsLabel;
    _drillResults.clear();
    _watch!.reset();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
    _watch!.start();
    notifyListeners();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _watch?.stop();
    _currentDuration = _watch?.elapsed;
    notifyListeners();
  }

  /// Cancel and wipe all session state.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _watch?.reset();
    _currentDuration = Duration.zero;
    _sessionTitle = null;
    _startedAt = null;
    _routineId = null;
    _routineTitle = null;
    _preferredActivityTitle = null;
    _preferredActivityIcon = null;
    _preferredSetsLabel = null;
    _preferredRepsLabel = null;
    _drillResults.clear();
    _currentDrillIndex = 0;
    _restTimer?.cancel();
    _restTimer = null;
    _restCountdown = null;
    notifyListeners();
  }

  // ── Drill management ───────────────────────────────────────────────────────

  void addDrill(session_model.DrillResult drillResult) {
    _drillResults.add(drillResult);
    notifyListeners();
  }

  void removeDrill(int index) {
    if (index >= 0 && index < _drillResults.length) {
      _drillResults.removeAt(index);
      // Keep currentDrillIndex in bounds
      if (_currentDrillIndex >= _drillResults.length && _drillResults.isNotEmpty) {
        _currentDrillIndex = _drillResults.length - 1;
      } else if (_drillResults.isEmpty) {
        _currentDrillIndex = 0;
      }
      notifyListeners();
    }
  }

  // ── Set management ─────────────────────────────────────────────────────────

  /// Appends a new set to the drill, pre-filled with the historic values for
  /// that set's position. If no historic values exist for the new index,
  /// copies the last set's values as a sensible within-session default.
  void addSet(int drillIndex) {
    if (drillIndex < _drillResults.length) {
      final drill = _drillResults[drillIndex];
      final sets = drill.setResults;
      final newIndex = sets.length; // the index of the set we're about to add

      List<num?> historicVals = [];
      if (newIndex < drill.historicSetValues.length) {
        historicVals = drill.historicSetValues[newIndex];
      } else if (sets.isNotEmpty) {
        // No history for this index – copy last set's values as default.
        historicVals = sets.last.measurementResults.map((m) => m.value).toList();
      }

      final newMeas = <MeasurementResult>[];
      for (var mi = 0; mi < drill.measurementResults.length; mi++) {
        final template = drill.measurementResults[mi];
        final val = mi < historicVals.length ? historicVals[mi] : 0;
        newMeas.add(MeasurementResult(template.type, template.label, template.order, val ?? 0));
      }
      sets.add(session_model.SetResult(measurementResults: newMeas));
      notifyListeners();
    }
  }

  void removeSet(int drillIndex, int setIndex) {
    if (drillIndex < _drillResults.length) {
      final sets = _drillResults[drillIndex].setResults;
      if (setIndex >= 0 && setIndex < sets.length) {
        sets.removeAt(setIndex);
        notifyListeners();
      }
    }
  }

  /// Toggles the completion flag on a set. If the set is marked complete and
  /// the drill has a rest timer configured, starts the countdown. If all sets
  /// in the drill are complete, auto-advances to the next drill after a delay.
  void toggleSetComplete(int drillIndex, int setIndex) {
    if (drillIndex >= _drillResults.length) return;
    final drill = _drillResults[drillIndex];
    if (setIndex >= drill.setResults.length) return;

    drill.setResults[setIndex].isComplete = !drill.setResults[setIndex].isComplete;

    // Start rest countdown when a set is checked complete
    if (drill.setResults[setIndex].isComplete && drill.restTimerSeconds != null) {
      startRestCountdown(drill.restTimerSeconds!);
    }

    // Auto-advance when all sets in this drill are done
    if (drill.allSetsComplete && _currentDrillIndex < _drillResults.length - 1) {
      Future.delayed(const Duration(milliseconds: 700), () {
        _currentDrillIndex = drillIndex + 1;
        notifyListeners();
      });
    }

    notifyListeners();
  }

  /// Updates a measurement value within a specific set of a drill.
  void updateSetMeasurementValue(int drillIndex, int setIndex, int measIndex, num? value) {
    if (drillIndex < _drillResults.length) {
      final sets = _drillResults[drillIndex].setResults;
      if (setIndex < sets.length && measIndex < sets[setIndex].measurementResults.length) {
        sets[setIndex].measurementResults[measIndex].value = value;
        notifyListeners();
      }
    }
  }

  /// Sets the rest-timer duration for a drill (null = no rest timer).
  void setDrillRestTimer(int drillIndex, int? seconds) {
    if (drillIndex < _drillResults.length) {
      _drillResults[drillIndex].restTimerSeconds = seconds;
      notifyListeners();
    }
  }

  // ── Legacy measurement / sets updates (kept for compatibility) ─────────────

  void updateMeasurementValue(int drillIndex, int measIndex, num? value) {
    if (drillIndex < _drillResults.length && measIndex < _drillResults[drillIndex].measurementResults.length) {
      _drillResults[drillIndex].measurementResults[measIndex].value = value;
      notifyListeners();
    }
  }

  void updateDrillSets(int drillIndex, int? sets) {
    if (drillIndex < _drillResults.length) {
      _drillResults[drillIndex].sets = sets;
      notifyListeners();
    }
  }

  void updateDrillReps(int drillIndex, int? reps) {
    if (drillIndex < _drillResults.length) {
      _drillResults[drillIndex].reps = reps;
      notifyListeners();
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  /// Stops the timer, builds a [Session] document, and persists it to Firestore.
  /// Resets service state when done.
  Future<void> finishSession() async {
    _stop();
    _saving = true;
    notifyListeners();

    final now = DateTime.now();
    final session = session_model.Session(
      _sessionTitle ?? defaultSessionTitle(),
      _startedAt ?? now,
      routineId: _routineId,
      routineTitle: _routineTitle,
      drillResults: List<session_model.DrillResult>.from(_drillResults),
    );
    session.endedAt = now;
    session.durationSeconds = _currentDuration?.inSeconds;

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('sessions').doc(uid).collection('sessions').add(session.toMap());
    } finally {
      _saving = false;
      reset();
    }
  }

  // ── Provider ───────────────────────────────────────────────────────────────

  static SessionService of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<SessionServiceProvider>()!;
    return provider.service;
  }
}

class SessionServiceProvider extends InheritedWidget {
  const SessionServiceProvider({
    super.key,
    required this.service,
    required super.child,
  });

  final SessionService service;

  @override
  bool updateShouldNotify(SessionServiceProvider oldWidget) => service != oldWidget.service;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: build a DrillResult from drill data + Firestore measurement fetch
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches the measurements subcollection for [drillId] and constructs a
/// [session_model.DrillResult] ready to be added to the in-progress session.
///
/// Deduplicates measurements by (type, label) to guard against double-saved
/// Firestore documents. Also pre-fills set values from the most recent session
/// history so each set defaults to the last recorded value for that position.
Future<session_model.DrillResult> buildDrillResultForSession({
  required String drillId,
  required String drillTitle,
  required String activityTitle,
  required String activityIcon,
  required String setsLabel,
  required String repsLabel,
  required int order,
  int? sets,
  int? reps,
}) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  // Fetch measurements and last session history in parallel.
  final results = await Future.wait([
    FirebaseFirestore.instance.collection('drills').doc(uid).collection('drills').doc(drillId).collection('measurements').orderBy('order').get(),
    FirebaseFirestore.instance.collection('sessions').doc(uid).collection('sessions').orderBy('started_at', descending: true).limit(20).get(),
  ]);

  final measSnap = results[0];
  final sessSnap = results[1];

  // Build deduplicated measurement template.
  // Use a set of "type|label" keys to skip exact duplicates.
  final seen = <String>{};
  final measurementResults = measSnap.docs
      .map((doc) {
        final data = doc.data();
        if ((data['role'] as String?) == 'result') {
          final type = (data['type'] as String?) ?? 'amount';
          final label = (data['label'] as String?) ?? '';
          final key = '$type|$label';
          if (seen.contains(key)) return null; // skip duplicate
          seen.add(key);
          return MeasurementResult(
            type,
            label,
            (data['order'] as int?) ?? 0,
            null, // starts null – recorded during session
          );
        }
        return null;
      })
      .whereType<MeasurementResult>()
      .toList();

  // Find the most recent session that contains this drill and extract
  // per-set defaults indexed by set position.
  List<List<num?>> historicSetValues = []; // historicSetValues[setIndex][measIndex]
  for (final sessionDoc in sessSnap.docs) {
    final data = sessionDoc.data();
    final drillResultsList = data['drill_results'] as List?;
    if (drillResultsList == null) continue;
    final matchingDrill = drillResultsList.cast<Map<String, dynamic>>().cast<Map<String, dynamic>?>().firstWhere(
          (d) => d?['drill_id'] == drillId,
          orElse: () => null,
        );
    if (matchingDrill == null) continue;

    final setResultsList = matchingDrill['set_results'] as List?;
    if (setResultsList == null || setResultsList.isEmpty) continue;

    historicSetValues = setResultsList.map<List<num?>>((s) {
      final measList = (s as Map<String, dynamic>)['measurement_results'] as List?;
      if (measList == null) return [];
      return measList.map<num?>((m) => (m as Map<String, dynamic>)['value'] as num?).toList();
    }).toList();
    break; // use the most recent match only
  }

  // Build a set pre-filled with historic values for the given set position.
  // Falls back to 0 for each measurement when no history exists.
  session_model.SetResult makeSet(int setIndex) {
    final meas = <MeasurementResult>[];
    for (var mi = 0; mi < measurementResults.length; mi++) {
      final m = measurementResults[mi];
      num? defaultVal;
      if (setIndex < historicSetValues.length) {
        final vals = historicSetValues[setIndex];
        if (mi < vals.length) defaultVal = vals[mi];
      }
      // Default to 0 when no history (per spec).
      defaultVal ??= 0;
      meas.add(MeasurementResult(m.type, m.label, m.order, defaultVal));
    }
    return session_model.SetResult(measurementResults: meas);
  }

  return session_model.DrillResult(
    drillId,
    drillTitle,
    activityTitle,
    activityIcon: activityIcon,
    order: order,
    setsLabel: setsLabel,
    repsLabel: repsLabel,
    sets: sets,
    reps: reps,
    measurementResults: measurementResults,
    historicSetValues: historicSetValues,
    // Seed the first set from the measurement template so the user is
    // immediately shown a set row to fill in.
    setResults: [makeSet(0)],
  );
}
