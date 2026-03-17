import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilldrills/models/firestore/drill_note.dart';

/// A single drill entry inside a [Routine], ordered by [order].
///
/// Stores a lightweight snapshot so the routine list can render without
/// needing to read every drill document again.
///
/// ### Planning fields
/// Non-Weight-Training activities use [sets] × [reps] as the plan target.
/// Weight Training activities use [weight] × [reps] × [rir] instead
/// (the set count is determined by history / user preference during the session).
class RoutineDrill {
  final String drillId;
  final String title;
  final int order;

  /// Target number of sets (non-Weight-Training activities).
  int? sets;

  /// Target reps per set.
  int? reps;

  /// Target load in the user's preferred weight unit (Weight Training only).
  num? weight;

  /// Target Reps In Reserve — 0 = failure, 5 = very easy (Weight Training only).
  int? rir;

  /// Per-drill notes authored in the routine builder.
  /// These are always pre-loaded when starting a session from this routine.
  List<DrillNote> notes;

  DocumentReference? reference;

  RoutineDrill(
    this.drillId,
    this.title,
    this.order, {
    this.sets,
    this.reps,
    this.weight,
    this.rir,
    List<DrillNote>? notes,
  }) : notes = notes ?? [];

  RoutineDrill.fromMap(Map<String, dynamic> map, {this.reference})
      : drillId = map['drill_id'] as String,
        title = map['title'] as String,
        order = (map['order'] as num).toInt(),
        sets = map['sets'] != null ? (map['sets'] as num).toInt() : null,
        reps = map['reps'] != null ? (map['reps'] as num).toInt() : null,
        weight = map['weight'] as num?,
        rir = map['rir'] != null ? (map['rir'] as num).toInt() : null,
        notes = (map['notes'] as List?)?.map((n) => DrillNote.fromMap(n as Map<String, dynamic>)).toList() ?? [];

  Map<String, dynamic> toMap() => {
        'drill_id': drillId,
        'title': title,
        'order': order,
        if (sets != null) 'sets': sets,
        if (reps != null) 'reps': reps,
        if (weight != null) 'weight': weight,
        if (rir != null) 'rir': rir,
        'notes': notes.map((n) => n.toMap()).toList(),
      };

  RoutineDrill.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data()!, reference: snapshot.reference);
}

/// A saved routine: an ordered sequence of drills tied to one [activityTitle].
///
/// Firestore path: `routines/{uid}/routines/{routineId}`
/// Drills subcollection: `…/drills/{drillDocId}`
class Routine {
  String? id;
  final String title;
  final String description;

  /// The activity this routine belongs to (e.g. "Hockey", "Guitar").
  /// All drills in the routine must belong to the same activity.
  final String? activityTitle;

  /// Cached singular drill label from the activity (e.g. "Drill", "Exercise").
  /// Stored so the routine list can display "3 exercises" without a Firestore read.
  final String drillLabel;

  List<RoutineDrill>? drills;
  final DateTime? createdAt;
  DocumentReference? reference;

  Routine(
    this.title,
    this.description, {
    this.activityTitle,
    this.drillLabel = 'Drill',
    this.drills,
    this.createdAt,
  });

  Routine.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['title'] != null),
        id = map['id'] as String?,
        title = map['title'] as String,
        description = (map['description'] as String?) ?? '',
        activityTitle = map['activity_title'] as String?,
        drillLabel = (map['drill_label'] as String?)?.isNotEmpty == true ? map['drill_label'] as String : 'Drill',
        createdAt = map['created_at'] != null ? (map['created_at'] as Timestamp).toDate() : null;

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'activity_title': activityTitle,
        'drill_label': drillLabel,
        'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      };

  Routine.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data()!, reference: snapshot.reference);
}
