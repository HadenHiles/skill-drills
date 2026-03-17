import 'package:cloud_firestore/cloud_firestore.dart';

/// Streak – tracks the daily practice streak for a single activity.
///
/// Stored at `streaks/{uid}/streaks/{docId}` where `docId` is derived from
/// the activity title via [Streak.docId].
class Streak {
  final String activityTitle;
  int currentStreak;
  int longestStreak;
  DateTime lastSessionDate;
  DocumentReference? reference;

  Streak(
    this.activityTitle,
    this.currentStreak,
    this.longestStreak,
    this.lastSessionDate,
  );

  Streak.fromMap(Map<String, dynamic> map, {this.reference})
      : activityTitle = (map['activity_title'] as String?) ?? '',
        currentStreak = (map['current_streak'] as int?) ?? 0,
        longestStreak = (map['longest_streak'] as int?) ?? 0,
        lastSessionDate = map['last_session_date'] != null ? (map['last_session_date'] as Timestamp).toDate() : DateTime.now();

  Map<String, dynamic> toMap() => {
        'activity_title': activityTitle,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'last_session_date': Timestamp.fromDate(lastSessionDate),
      };

  Streak.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data()!, reference: snapshot.reference);

  /// Firestore document ID derived from the activity title.
  static String docId(String activityTitle) => activityTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
}
