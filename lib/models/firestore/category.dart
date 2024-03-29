import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  String? id;
  final String title;
  DocumentReference? reference;

  Category(this.title);

  Category.fromMap(Map<String, dynamic>? map, {this.reference})
      : assert(map!['title'] != null),
        id = map!['id'],
        title = map['title'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
    };
  }

  Category.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);

  // For select dialogs
  @override
  String toString() => title;

  @override
  operator ==(other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;
}
