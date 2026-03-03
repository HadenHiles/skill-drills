import 'package:cloud_firestore/cloud_firestore.dart';

/// A single drill entry inside a [Routine], ordered by [order].
///
/// Stores a lightweight snapshot so the routine list can render without
/// needing to read every drill document again.
/// [sets] and [reps] are optional; they indicate how many sets/reps to
/// perform for this drill step (terminology is defined by the parent Activity).
class RoutineDrill {
  final String drillId;
  final String title;
  final int order;

  /// Optional number of sets to perform (e.g. 3 sets).
  int? sets;

  /// Optional number of reps per set (e.g. 10 reps).
  int? reps;

  DocumentReference? reference;

  RoutineDrill(this.drillId, this.title, this.order, {this.sets, this.reps});

  RoutineDrill.fromMap(Map<String, dynamic> map, {this.reference})
      : drillId = map['drill_id'] as String,
        title = map['title'] as String,
        order = (map['order'] as num).toInt(),
        sets = map['sets'] != null ? (map['sets'] as num).toInt() : null,
        reps = map['reps'] != null ? (map['reps'] as num).toInt() : null;

  Map<String, dynamic> toMap() => {
        'drill_id': drillId,
        'title': title,
        'order': order,
        if (sets != null) 'sets': sets,
        if (reps != null) 'reps': reps,
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
