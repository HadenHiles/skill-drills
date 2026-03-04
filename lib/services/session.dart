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

  List<session_model.DrillResult> get drillResults =>
      List.unmodifiable(_drillResults);

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
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return '${days[DateTime.now().weekday - 1]} Session';
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Start a new session. Clears any previous state.
  void start({String? title, String? routineId, String? routineTitle}) {
    _sessionTitle = title ?? defaultSessionTitle();
    _startedAt = DateTime.now();
    _routineId = routineId;
    _routineTitle = routineTitle;
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
    _drillResults.clear();
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
      notifyListeners();
    }
  }

  // ── Measurement updates ────────────────────────────────────────────────────

  void updateMeasurementValue(int drillIndex, int measIndex, num? value) {
    if (drillIndex < _drillResults.length &&
        measIndex < _drillResults[drillIndex].measurementResults.length) {
      _drillResults[drillIndex].measurementResults[measIndex].value = value;
      notifyListeners();
    }
  }

  // ── Sets / Reps updates ────────────────────────────────────────────────────

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
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(uid)
          .collection('sessions')
          .add(session.toMap());
    } finally {
      _saving = false;
      reset();
    }
  }

  // ── Provider ───────────────────────────────────────────────────────────────

  static SessionService of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<SessionServiceProvider>()!;
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
  bool updateShouldNotify(SessionServiceProvider oldWidget) =>
      service != oldWidget.service;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: build a DrillResult from drill data + Firestore measurement fetch
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches the measurements subcollection for [drillId] and constructs a
/// [session_model.DrillResult] ready to be added to the in-progress session.
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
  final measSnap = await FirebaseFirestore.instance
      .collection('drills')
      .doc(uid)
      .collection('drills')
      .doc(drillId)
      .collection('measurements')
      .orderBy('order')
      .get();

  final measurementResults = measSnap.docs
      .map((doc) {
        final data = doc.data();
        if ((data['role'] as String?) == 'result') {
          return MeasurementResult(
            (data['type'] as String?) ?? 'amount',
            (data['label'] as String?) ?? '',
            (data['order'] as int?) ?? 0,
            null, // starts null – recorded during session
          );
        }
        return null;
      })
      .whereType<MeasurementResult>()
      .toList();

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
  );
}
