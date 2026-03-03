import 'package:cloud_firestore/cloud_firestore.dart';

/// A single drill entry inside a [Routine], ordered by [order].
///
/// Stores a lightweight snapshot so the routine list can render without
/// needing to read every drill document again.
class RoutineDrill {
  final String drillId;
  final String title;
  final int order;
  DocumentReference? reference;

  RoutineDrill(this.drillId, this.title, this.order);

  RoutineDrill.fromMap(Map<String, dynamic> map, {this.reference})
      : drillId = map['drill_id'] as String,
        title = map['title'] as String,
        order = (map['order'] as num).toInt();

  Map<String, dynamic> toMap() => {
        'drill_id': drillId,
        'title': title,
        'order': order,
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

  List<RoutineDrill>? drills;
  final DateTime? createdAt;
  DocumentReference? reference;

  Routine(this.title, this.description, {this.activityTitle, this.drills, this.createdAt});

  Routine.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['title'] != null),
        id = map['id'] as String?,
        title = map['title'] as String,
        description = (map['description'] as String?) ?? '',
        activityTitle = map['activity_title'] as String?,
        createdAt = map['created_at'] != null ? (map['created_at'] as Timestamp).toDate() : null;

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'activity_title': activityTitle,
        'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      };

  Routine.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data()!, reference: snapshot.reference);
}
