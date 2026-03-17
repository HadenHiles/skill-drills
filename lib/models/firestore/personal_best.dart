import 'package:cloud_firestore/cloud_firestore.dart';

/// PersonalBest – the best recorded value for a single drill + measurement combination.
///
/// Stored at `personal_bests/{uid}/bests/{docId}` where `docId` is generated
/// from the drill ID and measurement label via [PersonalBest.docId].
class PersonalBest {
  final String drillId;
  final String drillTitle;
  final String measurementLabel;
  final String measurementType;
  num bestValue;
  final bool reverse;
  DateTime achievedAt;
  String sessionId;
  DocumentReference? reference;

  PersonalBest(
    this.drillId,
    this.drillTitle,
    this.measurementLabel,
    this.measurementType,
    this.bestValue,
    this.reverse,
    this.achievedAt,
    this.sessionId,
  );

  PersonalBest.fromMap(Map<String, dynamic> map, {this.reference})
      : drillId = (map['drill_id'] as String?) ?? '',
        drillTitle = (map['drill_title'] as String?) ?? '',
        measurementLabel = (map['measurement_label'] as String?) ?? '',
        measurementType = (map['measurement_type'] as String?) ?? 'amount',
        bestValue = (map['best_value'] as num?) ?? 0,
        reverse = (map['reverse'] as bool?) ?? false,
        achievedAt = map['achieved_at'] != null ? (map['achieved_at'] as Timestamp).toDate() : DateTime.now(),
        sessionId = (map['session_id'] as String?) ?? '';

  Map<String, dynamic> toMap() => {
        'drill_id': drillId,
        'drill_title': drillTitle,
        'measurement_label': measurementLabel,
        'measurement_type': measurementType,
        'best_value': bestValue,
        'reverse': reverse,
        'achieved_at': Timestamp.fromDate(achievedAt),
        'session_id': sessionId,
      };

  PersonalBest.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data()!, reference: snapshot.reference);

  /// Firestore document ID for this drill + measurement combination.
  /// Sanitises the label to ensure it's a valid Firestore doc ID.
  static String docId(String drillId, String measurementLabel) => '${drillId}_${measurementLabel.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';
}
