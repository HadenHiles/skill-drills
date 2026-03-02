import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilldrills/models/firestore/measurement.dart';

/// MeasurementTarget – a [Measurement] with role "target", capturing the
/// goal value for a drill. [target] holds the goal; [value] is always null.
/// [reverse] = true means lower is better (e.g. a lap-time target).
class MeasurementTarget extends Measurement {
  String? id;

  MeasurementTarget(String type, String label, int order, num? target, bool reverse) : super('target', type, label, order, null, target, reverse);

  // ignore: use_super_parameters
  MeasurementTarget.fromMap(Map<String, dynamic>? map, {DocumentReference? reference})
      : id = map!['id'],
        super.fromMap(map, reference: reference);

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'id': id,
      };

  MeasurementTarget.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
