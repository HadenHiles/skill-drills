import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/models/firestore/drill_note.dart';
import 'package:skilldrills/models/firestore/measurement_result.dart';
import 'package:skilldrills/models/firestore/personal_best.dart';
import 'package:skilldrills/models/firestore/session.dart' as session_model;
import 'package:skilldrills/models/firestore/timer_mode.dart';
import 'package:skilldrills/services/haptics.dart';
import 'package:skilldrills/services/personal_bests.dart';
import 'package:skilldrills/services/streaks.dart';
import 'package:skilldrills/services/subscription.dart';

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
        hapticRestComplete();
      }
    });
  }

  void clearRestCountdown() {
    _restTimer?.cancel();
    _restTimer = null;
    _restCountdown = null;
    notifyListeners();
  }

  // ── Per-drill timer (countdown or stopwatch) ───────────────────────────────
  int? _activeDrillTimerIndex; // which drill's timer is running
  TimerMode? _drillTimerMode; // countdown or stopwatch
  Timer? _drillTimer;
  Stopwatch? _drillStopwatch;
  int? _drillCountdownRemaining; // seconds remaining (countdown mode)
  Duration? _drillElapsed; // elapsed time (stopwatch mode)

  int? get activeDrillTimerIndex => _activeDrillTimerIndex;
  TimerMode? get drillTimerMode => _drillTimerMode;
  int? get drillCountdownRemaining => _drillCountdownRemaining;
  Duration? get drillElapsed => _drillElapsed;
  bool get drillTimerRunning => _drillTimer != null || (_drillStopwatch?.isRunning ?? false);

  /// Starts a countdown timer for the drill at [drillIndex].
  void startDrillCountdown(int drillIndex, int seconds) {
    _stopDrillTimer();
    _activeDrillTimerIndex = drillIndex;
    _drillTimerMode = TimerMode.countdown;
    _drillCountdownRemaining = seconds;
    notifyListeners();
    _drillTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_drillCountdownRemaining != null && _drillCountdownRemaining! > 0) {
        _drillCountdownRemaining = _drillCountdownRemaining! - 1;
        notifyListeners();
      } else {
        t.cancel();
        _drillTimer = null;
        notifyListeners();
        hapticRestComplete(); // vibrate when countdown completes
      }
    });
  }

  /// Starts a stopwatch for the drill at [drillIndex].
  void startDrillStopwatch(int drillIndex) {
    _stopDrillTimer();
    _activeDrillTimerIndex = drillIndex;
    _drillTimerMode = TimerMode.stopwatch;
    _drillStopwatch = Stopwatch();
    _drillStopwatch!.start();
    notifyListeners();
    _drillTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      _drillElapsed = _drillStopwatch!.elapsed;
      notifyListeners();
    });
  }

  /// Pauses the active drill timer (works for both countdown and stopwatch).
  void pauseDrillTimer() {
    if (_drillTimerMode == TimerMode.stopwatch && _drillStopwatch != null) {
      _drillStopwatch!.stop();
      _drillElapsed = _drillStopwatch!.elapsed;
    }
    _drillTimer?.cancel();
    _drillTimer = null;
    notifyListeners();
  }

  /// Resumes a paused drill timer.
  void resumeDrillTimer() {
    if (_activeDrillTimerIndex == null) return;
    if (_drillTimerMode == TimerMode.countdown && _drillCountdownRemaining != null) {
      // Resume countdown from where it left off
      _drillTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_drillCountdownRemaining != null && _drillCountdownRemaining! > 0) {
          _drillCountdownRemaining = _drillCountdownRemaining! - 1;
          notifyListeners();
        } else {
          t.cancel();
          _drillTimer = null;
          notifyListeners();
          hapticRestComplete();
        }
      });
    } else if (_drillTimerMode == TimerMode.stopwatch && _drillStopwatch != null) {
      // Resume stopwatch
      _drillStopwatch!.start();
      _drillTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
        _drillElapsed = _drillStopwatch!.elapsed;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  /// Stops and clears the active drill timer.
  void stopDrillTimer() {
    _stopDrillTimer();
    notifyListeners();
  }

  void _stopDrillTimer() {
    _drillTimer?.cancel();
    _drillTimer = null;
    _drillStopwatch?.stop();
    _drillStopwatch?.reset();
    _drillStopwatch = null;
    _activeDrillTimerIndex = null;
    _drillTimerMode = null;
    _drillCountdownRemaining = null;
    _drillElapsed = null;
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
    _stopDrillTimer();
    notifyListeners();
  }

  // ── Drill management ───────────────────────────────────────────────────────

  void addDrill(session_model.DrillResult drillResult) {
    _drillResults.add(drillResult);
    notifyListeners();
  }

  // ── Notes management ──────────────────────────────────────────────────────

  /// Adds [note] to the drill at [drillIndex].
  void addNoteToDrill(int drillIndex, DrillNote note) {
    if (drillIndex < 0 || drillIndex >= _drillResults.length) return;
    _drillResults[drillIndex].notes.add(note);
    notifyListeners();
  }

  /// Toggles the [isPinned] flag on the note at [noteIndex] within [drillIndex].
  void toggleNotePin(int drillIndex, int noteIndex) {
    if (drillIndex < 0 || drillIndex >= _drillResults.length) return;
    final notes = _drillResults[drillIndex].notes;
    if (noteIndex < 0 || noteIndex >= notes.length) return;
    notes[noteIndex].isPinned = !notes[noteIndex].isPinned;
    notifyListeners();
  }

  /// Removes the note at [noteIndex] from the drill at [drillIndex].
  void deleteNote(int drillIndex, int noteIndex) {
    if (drillIndex < 0 || drillIndex >= _drillResults.length) return;
    final notes = _drillResults[drillIndex].notes;
    if (noteIndex < 0 || noteIndex >= notes.length) return;
    notes.removeAt(noteIndex);
    notifyListeners();
  }

  /// Updates the text of an existing note.
  void updateNoteText(int drillIndex, int noteIndex, String text) {
    if (drillIndex < 0 || drillIndex >= _drillResults.length) return;
    final notes = _drillResults[drillIndex].notes;
    if (noteIndex < 0 || noteIndex >= notes.length) return;
    notes[noteIndex].text = text;
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
  /// Saves the current session to Firestore.
  ///
  /// For Pro users, also updates personal bests and streak records, and
  /// returns the list of newly beaten [PersonalBest] records so the UI can
  /// show a post-session summary. Returns an empty list for free users.
  Future<List<PersonalBest>> finishSession() async {
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

    List<PersonalBest> newBests = [];
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final docRef = await FirebaseFirestore.instance.collection('sessions').doc(uid).collection('sessions').add(session.toMap());

      // Pro-only post-save hooks.
      final isPro = await hasActiveSubscription();
      if (isPro && session.drillResults.isNotEmpty) {
        // Compute personal bests.
        newBests = await updatePersonalBests(uid, session, docRef.id);
        // Update streak for each distinct activity in this session.
        final activityTitles = session.drillResults.map((d) => d.activityTitle).toSet();
        await Future.wait(
          activityTitles.map((a) => updateStreak(uid, a, now)),
        );
      }
    } finally {
      _saving = false;
      reset();
    }
    return newBests;
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

  /// Target weight (Weight Training — used as default for the weight column).
  num? weight,

  /// Target RIR (Weight Training — used as default for the RIR column).
  int? rir,

  /// Notes pre-authored in the routine builder. Always shown in‐session.
  List<DrillNote>? routineNotes,

  /// The routine ID — used to fetch pinned notes from the most recent
  /// prior session of the same routine+drill.
  String? routineId,

  /// Pre-fetched sessions snapshot. When building multiple DrillResults at
  /// once (e.g. starting from a routine), pass this to avoid re-querying
  /// Firestore for the same sessions data on every drill.
  QuerySnapshot<Map<String, dynamic>>? preloadedSessions,
}) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  // When a pre-fetched sessions snapshot is available (e.g. routine start),
  // only fetch the drill measurements. Otherwise fetch both in parallel.
  final QuerySnapshot<Map<String, dynamic>> measSnap;
  final QuerySnapshot<Map<String, dynamic>> sessSnap;

  if (preloadedSessions != null) {
    measSnap = await FirebaseFirestore.instance.collection('drills').doc(uid).collection('drills').doc(drillId).collection('measurements').orderBy('order').get();
    sessSnap = preloadedSessions;
  } else {
    final fetches = await Future.wait([
      FirebaseFirestore.instance.collection('drills').doc(uid).collection('drills').doc(drillId).collection('measurements').orderBy('order').get(),
      FirebaseFirestore.instance.collection('sessions').doc(uid).collection('sessions').orderBy('started_at', descending: true).limit(20).get(),
    ]);
    measSnap = fetches[0];
    sessSnap = fetches[1];
  }

  // Build deduplicated measurement template.
  // Use a set of "type|label" keys to skip exact duplicates.
  // Normalize legacy 'rpe' measurements to 'rir' for Weight Training so that
  // drills that have both an 'rpe' and an 'rir' field don't render two identical
  // scale pickers, and so the column header always reads "RIR" rather than
  // "RPE (1–10)" for those drills.
  final seen = <String>{};
  final measurementResults = measSnap.docs
      .map((doc) {
        final data = doc.data();
        if ((data['role'] as String?) == 'result') {
          var type = (data['type'] as String?) ?? 'amount';
          var label = (data['label'] as String?) ?? '';
          if (type == 'rpe' && activityTitle == 'Weight Training') {
            type = 'rir';
            label = 'RIR';
          }
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
  List<DrillNote> pinnedHistoricNotes = [];

  for (final sessionDoc in sessSnap.docs) {
    final data = sessionDoc.data();

    // Only pull pinned notes from sessions created from the same routine.
    final sessionRoutineId = data['routine_id'] as String?;
    final isMatchingRoutine = routineId != null && sessionRoutineId == routineId;

    final drillResultsList = data['drill_results'] as List?;
    if (drillResultsList == null) continue;
    final matchingDrill = drillResultsList.cast<Map<String, dynamic>>().cast<Map<String, dynamic>?>().firstWhere(
          (d) => d?['drill_id'] == drillId,
          orElse: () => null,
        );
    if (matchingDrill == null) continue;

    // Extract historic set values from the most recent matching session.
    if (historicSetValues.isEmpty) {
      final setResultsList = matchingDrill['set_results'] as List?;
      if (setResultsList != null && setResultsList.isNotEmpty) {
        historicSetValues = setResultsList.map<List<num?>>((s) {
          final measList = (s as Map<String, dynamic>)['measurement_results'] as List?;
          if (measList == null) return [];
          return measList.map<num?>((m) => (m as Map<String, dynamic>)['value'] as num?).toList();
        }).toList();
      }
    }

    // Extract pinned session notes from the same routine.
    if (isMatchingRoutine && pinnedHistoricNotes.isEmpty) {
      final rawNotes = matchingDrill['notes'] as List?;
      if (rawNotes != null) {
        pinnedHistoricNotes = rawNotes.map((n) => DrillNote.fromMap(n as Map<String, dynamic>)).where((n) => n.isPinned && n.source == 'session').toList();
      }
    }

    if (historicSetValues.isNotEmpty && (routineId == null || pinnedHistoricNotes.isNotEmpty || !isMatchingRoutine)) {
      break; // found what we need
    }
  }

  // Build a set pre-filled with historic values for the given set position.
  // Falls back to routine target values (weight / reps / rir) when no history
  // exists, then 0 for any remaining measurements.
  final repsLabelLower = repsLabel.toLowerCase();

  session_model.SetResult makeSet(int setIndex) {
    final meas = <MeasurementResult>[];
    for (var mi = 0; mi < measurementResults.length; mi++) {
      final m = measurementResults[mi];
      num? defaultVal;
      if (setIndex < historicSetValues.length) {
        final vals = historicSetValues[setIndex];
        if (mi < vals.length) defaultVal = vals[mi];
      }
      if (defaultVal == null) {
        // Use routine target values for matching measurements; fall back to 0.
        if (reps != null && m.label.toLowerCase() == repsLabelLower) {
          defaultVal = reps;
        } else if (weight != null && (m.label.toLowerCase().contains('weight') || m.label.toLowerCase().contains('load'))) {
          defaultVal = weight;
        } else if (rir != null && m.type == 'rir') {
          defaultVal = rir;
        } else {
          defaultVal = 0;
        }
      }
      meas.add(MeasurementResult(m.type, m.label, m.order, defaultVal));
    }
    return session_model.SetResult(measurementResults: meas);
  }

  // When a routine specifies the number of sets, seed that many rows upfront.
  // Otherwise start with a single set (the user can add more).
  final initialSetCount = sets != null && sets > 0 ? sets : 1;

  // Combine routine notes and pinned historic session notes into the initial
  // notes list for this drill result. Duplicate texts (same source+text)
  // are de-duped so we don't show the same note twice.
  final combinedNotes = <DrillNote>[...?routineNotes];
  for (final hn in pinnedHistoricNotes) {
    final alreadyPresent = combinedNotes.any((n) => n.text == hn.text && n.source == 'session');
    if (!alreadyPresent) combinedNotes.add(hn);
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
    notes: combinedNotes,
    // Seed the initial set rows. If the routine specified a set count, create
    // that many rows; otherwise start with one so the user sees a row to fill in.
    setResults: List.generate(initialSetCount, makeSet),
  );
}
