import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilldrills/models/firestore/measurement.dart';

/// MeasurementResult – a [Measurement] with role "result", capturing the
/// value recorded during a completed drill. [value] holds the recorded result;
/// [target] is always null (targets are stored in [MeasurementTarget]).
class MeasurementResult extends Measurement {
  String? id;

  MeasurementResult(String type, String label, int order, num? value) : super('result', type, label, order, value, null, false);

  // ignore: use_super_parameters
  MeasurementResult.fromMap(Map<String, dynamic>? map, {DocumentReference? reference})
      : id = map!['id'],
        super.fromMap(map, reference: reference);

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'id': id,
      };

  MeasurementResult.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
