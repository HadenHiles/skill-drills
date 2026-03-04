import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilldrills/models/firestore/measurement_result.dart';

/// DrillResult – all recorded data for one drill within a session.
/// Embedded as a list inside the [Session] document.
///
/// [setsLabel] / [repsLabel] are denormalised from the parent Activity so the
/// History UI can display the correct terminology without a secondary lookup.
class DrillResult {
  final String drillId;
  final String drillTitle;
  final String activityTitle;
  final String activityIcon;

  /// Position this drill was performed in the session (0-indexed).
  final int order;

  /// Terminology drawn from the parent Activity.
  final String setsLabel;
  final String repsLabel;

  /// How many sets the athlete performed for this drill.
  int? sets;

  /// How many reps per set.
  int? reps;

  /// One [MeasurementResult] per result-role measurement defined on this drill.
  /// Values are null until the athlete records them.
  List<MeasurementResult> measurementResults;

  DrillResult(
    this.drillId,
    this.drillTitle,
    this.activityTitle, {
    this.activityIcon = '🎯',
    required this.order,
    this.setsLabel = 'Sets',
    this.repsLabel = 'Reps',
    this.sets,
    this.reps,
    List<MeasurementResult>? measurementResults,
  }) : measurementResults = measurementResults ?? [];

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'drill_id': drillId,
        'drill_title': drillTitle,
        'activity_title': activityTitle,
        'activity_icon': activityIcon,
        'order': order,
        'sets_label': setsLabel,
        'reps_label': repsLabel,
        if (sets != null) 'sets': sets,
        if (reps != null) 'reps': reps,
        'measurement_results': measurementResults.map((m) => m.toMap()).toList(),
      };

  DrillResult.fromMap(Map<String, dynamic> map)
      : drillId = map['drill_id'] as String,
        drillTitle = map['drill_title'] as String,
        activityTitle = (map['activity_title'] as String?) ?? '',
        activityIcon = (map['activity_icon'] as String?) ?? '🎯',
        order = (map['order'] as num).toInt(),
        setsLabel = (map['sets_label'] as String?) ?? 'Sets',
        repsLabel = (map['reps_label'] as String?) ?? 'Reps',
        sets = map['sets'] != null ? (map['sets'] as num).toInt() : null,
        reps = map['reps'] != null ? (map['reps'] as num).toInt() : null,
        measurementResults = (map['measurement_results'] as List?)?.map((m) => MeasurementResult.fromMap(m as Map<String, dynamic>)).toList() ?? [];
}

// ─────────────────────────────────────────────────────────────────────────────

/// Session – a completed (or in-progress) practice session.
///
/// Firestore path: `sessions/{uid}/sessions/{sessionId}`
///
/// Drill results are embedded as an array for easy querying and to keep the
/// document self-contained. For very long sessions (50+ drills) this may
/// approach the 1 MB doc limit, but is fine for Phase 1.
///
/// Denormalised analytics fields stored at write-time:
/// - [drillCount]                  – number of drills performed
/// - [totalMeasurementsRecorded]   – how many non-null measurement values exist
/// - [activityTitles]              – unique activity names (for filtering)
class Session {
  String? id;
  final String title;
  final DateTime startedAt;
  DateTime? endedAt;

  /// Total session length in seconds.
  int? durationSeconds;

  /// Firestore document ID of the source [Routine] (null for free-form sessions).
  String? routineId;

  /// Human-readable routine title, denormalised for display without a join.
  String? routineTitle;

  List<DrillResult> drillResults;
  DocumentReference? reference;

  Session(
    this.title,
    this.startedAt, {
    this.routineId,
    this.routineTitle,
    List<DrillResult>? drillResults,
  }) : drillResults = drillResults ?? [];

  // ── Computed helpers ───────────────────────────────────────────────────────

  int get drillCount => drillResults.length;

  Duration? get duration => durationSeconds != null ? Duration(seconds: durationSeconds!) : null;

  int get totalMeasurementsRecorded => drillResults.fold<int>(
        0,
        (acc, d) => acc + d.measurementResults.where((m) => m.value != null).length,
      );

  List<String> get activityTitles => drillResults.map((d) => d.activityTitle).toSet().toList();

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'title': title,
        'started_at': Timestamp.fromDate(startedAt),
        'ended_at': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
        'duration_seconds': durationSeconds,
        if (routineId != null) 'routine_id': routineId,
        if (routineTitle != null) 'routine_title': routineTitle,
        'drill_results': drillResults.map((d) => d.toMap()).toList(),
        // Denormalised analytics/query fields
        'drill_count': drillCount,
        'total_measurements_recorded': totalMeasurementsRecorded,
        'activity_titles': activityTitles,
      };

  Session.fromMap(Map<String, dynamic> map, {this.reference})
      : id = map['id'] as String?,
        title = (map['title'] as String?) ?? 'Session',
        startedAt = map['started_at'] != null ? (map['started_at'] as Timestamp).toDate() : DateTime.now(),
        endedAt = map['ended_at'] != null ? (map['ended_at'] as Timestamp).toDate() : null,
        durationSeconds = map['duration_seconds'] != null ? (map['duration_seconds'] as num).toInt() : null,
        routineId = map['routine_id'] as String?,
        routineTitle = map['routine_title'] as String?,
        drillResults = (map['drill_results'] as List?)?.map((d) => DrillResult.fromMap(d as Map<String, dynamic>)).toList() ?? [];

  Session.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data()!, reference: snapshot.reference);
}
