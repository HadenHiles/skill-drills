import 'package:cloud_firestore/cloud_firestore.dart';

/// Skill – a sub-discipline or focus area within an [Activity]
/// (e.g. "Shooting" or "Passing" within "Hockey").
/// Skills are used to tag [Drill]s for filtering and organisation.
class Skill {
  String? id;
  final String title;
  DocumentReference? reference;

  Skill(this.title);

  Skill.fromMap(Map<String, dynamic>? map, {this.reference})
      : assert(map!['title'] != null),
        id = map!['id'],
        title = map['title'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
    };
  }

  Skill.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);

  // For select dialogs
  @override
  String toString() => title;

  @override
  operator ==(other) => other is Skill && other.id == id;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;
}
