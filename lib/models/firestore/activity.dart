import 'package:cloud_firestore/cloud_firestore.dart';
import 'skill.dart';

/// Activity – a named skill domain chosen by the user (e.g. "Hockey", "Guitar").
/// Each Activity has a list of [skills] (sub-disciplines, e.g. "Shooting", "Passing")
/// that are used to categorise drills.
class Activity {
  String? id;
  final String? title;
  List<Skill>? skills;
  final String? createdBy;
  DocumentReference? reference;

  Activity(this.title, this.createdBy);

  Activity.fromMap(Map<String, dynamic>? map, {this.reference})
      : assert(map!['title'] != null),
        id = map!['id'],
        title = map['title'],
        skills = [],
        createdBy = map['created_by'];

  Map<String, dynamic> toMap() {
    List<Map<String, dynamic>> skillMaps = [];
    for (var s in skills ?? []) {
      skillMaps.add(s.toMap());
    }

    return {
      'id': id,
      'title': title,
      'skills': skillMaps,
      'created_by': createdBy,
    };
  }

  Activity.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);

  // For select dialogs
  @override
  operator ==(other) => other is Activity && other.id == id;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ createdBy.hashCode;
}
