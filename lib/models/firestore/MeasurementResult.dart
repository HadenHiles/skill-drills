import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilldrills/models/firestore/Measurement.dart';

/// MeasurementValue
/// @value The value of the saved measurement
class MeasurementResult extends Measurement {
  String? id;
  @override
  final String type;
  @override
  final String metric;
  @override
  final String label;
  @override
  final int order;
  @override
  dynamic value;
  @override
  DocumentReference? reference;

  MeasurementResult(this.type, this.metric, this.label, this.order, this.value) : super(type, metric, label, order, value, null, false);

  MeasurementResult.fromMap(super.map, {this.reference})
      : assert(map!['type'] != null),
        assert(map!['metric'] != null),
        id = map!['id'],
        type = map['type'],
        metric = map['metric'],
        label = map['label'],
        order = map['order'],
        value = map['value'],
        super.fromMap();

  MeasurementResult.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
