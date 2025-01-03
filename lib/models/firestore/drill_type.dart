import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilldrills/models/firestore/measurement.dart';

class DrillType {
  final String? id; // Ensure unique
  final String? title;
  final String? descriptor;
  final int? order;
  int timerInSeconds;
  List<Measurement>? measurements;
  DocumentReference? reference;

  DrillType(this.id, this.title, this.descriptor, this.timerInSeconds, this.order);

  DrillType.fromMap(Map<String, dynamic>? map, {this.reference})
      : assert(map!['id'] != null),
        assert(map!['title'] != null),
        assert(map!['descriptor'] != null),
        id = map!['id'],
        title = map['title'],
        descriptor = map['descriptor'],
        timerInSeconds = map['timer_in_seconds'] ?? 0,
        measurements = [],
        order = map['order'];

  Map<String, dynamic> toMap() {
    List<Map<String, dynamic>>? measures = [];

    for (var m in measurements!) {
      measures.add(m.toMap());
    }

    return {
      'id': id,
      'title': title,
      'descriptor': descriptor,
      'measurements': measures,
      'timer_in_seconds': timerInSeconds,
      'order': order,
    };
  }

  DrillType.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);

  // For select dialogs
  @override
  operator ==(other) => other is DrillType && other.id == id;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;
}
