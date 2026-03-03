import 'package:cloud_firestore/cloud_firestore.dart';

/// Measurement – the atomic unit of a drill schema.
///
/// [role]    "result" | "target" — whether this captures a recorded value or a goal.
/// [type]    "amount" | "duration" — drives the input widget rendered during a session.
///           Extendable to "boolean" | "scale" without schema changes.
/// [label]   Human-readable input label shown in UI (e.g. "Reps", "Score", "Time").
/// [order]   Display/input order within a drill.
/// [value]   Recorded value: int count for "amount", int seconds for "duration". Null until recorded.
/// [target]  Goal value: same encoding as value. Null until set.
/// [reverse] true = lower is better (e.g. a lap-time target where faster is better).
class Measurement {
  final String role;
  final String type;
  final String label;
  final int order;
  num? value;
  num? target;
  bool reverse;
  DocumentReference? reference;

  Measurement(this.role, this.type, this.label, this.order, this.value, this.target, this.reverse);

  Measurement.fromMap(Map<String, dynamic>? map, {this.reference})
      : assert(map != null),
        role = (map!['role'] as String?) ?? 'result',
        type = (map['type'] as String?) ?? 'amount',
        label = (map['label'] as String?) ?? '',
        order = (map['order'] as int?) ?? 0,
        value = map['value'],
        target = map['target'],
        reverse = (map['reverse'] as bool?) ?? false;

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'type': type,
      'label': label,
      'order': order,
      'value': value,
      'target': target,
      'reverse': reverse,
    };
  }

  Measurement.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
