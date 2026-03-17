import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilldrills/models/firestore/measurement.dart';
import 'package:skilldrills/models/firestore/skill.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'drill_type.dart';

class Drill {
  final String? title;
  final String? description;
  final Activity? activity;
  final DrillType? drillType;
  List<Measurement>? measurements;
  List<Skill>? skills;

  /// Pro: whether this drill is pinned to the top of the list.
  bool isPinned;

  /// Pro: sort position within the pinned section (0-indexed, lower = higher).
  int sortOrder;
  DocumentReference? reference;

  Drill(this.title, this.description, this.activity, this.drillType)
      : isPinned = false,
        sortOrder = 0;

  Drill.fromMap(Map<String, dynamic>? map, {this.reference})
      : assert(map!['title'] != null),
        assert(map!['description'] != null),
        assert(map!["activity"] != null),
        assert(map!['drill_type'] != null),
        title = map!['title'],
        description = map['description'],
        activity = Activity.fromMap(map['activity']),
        drillType = DrillType.fromMap(map['drill_type']),
        isPinned = (map['is_pinned'] as bool?) ?? false,
        sortOrder = (map['sort_order'] as int?) ?? 0;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      "activity": activity!.toMap(),
      'drill_type': drillType!.toMap(),
      'is_pinned': isPinned,
      'sort_order': sortOrder,
    };
  }

  Drill.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
