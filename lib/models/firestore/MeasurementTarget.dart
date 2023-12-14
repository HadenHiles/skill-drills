import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilldrills/models/firestore/Measurement.dart';

/// MeasurementTarget
/// @target The target for the measurement (what MeasurementValue is the user aiming for)
/// @reverse Is the measurement target incremental or decremental
class MeasurementTarget extends Measurement {
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
  dynamic target;
  @override
  bool reverse;
  @override
  DocumentReference? reference;

  MeasurementTarget(this.type, this.metric, this.label, this.order, this.target, this.reverse) : super(type, metric, label, order, null, target, reverse);

  MeasurementTarget.fromMap(super.map, {this.reference})
      : assert(map!['type'] != null),
        assert(map!['metric'] != null),
        id = map!['id'],
        type = map['type'],
        metric = map['metric'],
        label = map['label'],
        order = map['order'],
        target = map['target'],
        reverse = map['reverse'] ?? false,
        super.fromMap();

  MeasurementTarget.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
