import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilldrills/models/firestore/streak.dart';

/// Updates (or creates) the streak document for [activityTitle] based on
/// [sessionDate]. Stored at `streaks/{uid}/streaks/{docId}`.
///
/// Rules:
///   - Same calendar day as [lastSessionDate] → no-op (already counted).
///   - [lastSessionDate] is yesterday → extend streak.
///   - Gap > 1 day → reset streak to 1.
Future<void> updateStreak(
  String uid,
  String activityTitle,
  DateTime sessionDate,
) async {
  final ref = FirebaseFirestore.instance.collection('streaks').doc(uid).collection('streaks').doc(Streak.docId(activityTitle));

  // Normalise both dates to midnight in local timezone for comparison.
  final today = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

  final snap = await ref.get();
  if (!snap.exists) {
    await ref.set(Streak(activityTitle, 1, 1, today).toMap());
    return;
  }

  final streak = Streak.fromMap(snap.data()!, reference: snap.reference);
  final last = DateTime(
    streak.lastSessionDate.year,
    streak.lastSessionDate.month,
    streak.lastSessionDate.day,
  );

  if (last == today) return; // Streak already counted for today.

  final yesterday = today.subtract(const Duration(days: 1));
  if (last == yesterday) {
    // Extend the streak.
    streak.currentStreak++;
    if (streak.currentStreak > streak.longestStreak) {
      streak.longestStreak = streak.currentStreak;
    }
  } else {
    // Gap detected – reset to 1.
    streak.currentStreak = 1;
  }
  streak.lastSessionDate = today;
  await ref.set(streak.toMap());
}
