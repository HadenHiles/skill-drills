import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilldrills/models/firestore/personal_best.dart';
import 'package:skilldrills/models/firestore/session.dart' as session_model;

/// Computes personal bests for the given [session] and writes any new records
/// to `personal_bests/{uid}/bests`.
///
/// Returns the list of newly achieved [PersonalBest] records so the caller can
/// surface them in the post-session summary UI.
///
/// For each DrillResult in the session:
///   1. Fetches the drill's measurement definitions to read the `reverse` flag.
///   2. Finds the best value per measurement across all set results.
///   3. Compares against the stored personal best document.
///   4. Overwrites the document if the new value is better.
Future<List<PersonalBest>> updatePersonalBests(
  String uid,
  session_model.Session session,
  String sessionId,
) async {
  if (session.drillResults.isEmpty) return [];

  final pbRef = FirebaseFirestore.instance.collection('personal_bests').doc(uid).collection('bests');

  // Fetch measurement definitions for all unique drills to get reverse flags.
  final drillIds = session.drillResults.map((d) => d.drillId).toSet().toList();
  final measSnaps = await Future.wait(
    drillIds.map(
      (id) => FirebaseFirestore.instance.collection('drills').doc(uid).collection('drills').doc(id).collection('measurements').get(),
    ),
  );

  // Build a lookup: "drillId_label" → reverse flag.
  final reverseMap = <String, bool>{};
  for (var i = 0; i < drillIds.length; i++) {
    for (final doc in measSnaps[i].docs) {
      final data = doc.data();
      final label = (data['label'] as String?) ?? '';
      final reverse = (data['reverse'] as bool?) ?? false;
      reverseMap['${drillIds[i]}_$label'] = reverse;
    }
  }

  final newBests = <PersonalBest>[];

  for (final drillResult in session.drillResults) {
    // Compute the best value per measurement label across all set results.
    // Store (value, type, reverse) per label.
    final bestValues = <String, ({num value, String type, bool reverse})>{};

    for (final setResult in drillResult.setResults) {
      for (final meas in setResult.measurementResults) {
        if (meas.value == null) continue;
        final label = meas.label;
        final reverseKey = '${drillResult.drillId}_$label';
        // Fallback: duration type → lower is better; others → higher is better.
        final isReverse = reverseMap[reverseKey] ?? (meas.type == 'duration');

        final existing = bestValues[label];
        if (existing == null) {
          bestValues[label] = (
            value: meas.value!,
            type: meas.type,
            reverse: isReverse,
          );
        } else if (isReverse ? meas.value! < existing.value : meas.value! > existing.value) {
          bestValues[label] = (value: meas.value!, type: meas.type, reverse: isReverse);
        }
      }
    }

    // Compare each session best against the stored Firestore personal best.
    for (final entry in bestValues.entries) {
      final label = entry.key;
      final sessionBest = entry.value;
      final docId = PersonalBest.docId(drillResult.drillId, label);

      final existingDoc = await pbRef.doc(docId).get();
      final bool isBetter;
      if (!existingDoc.exists) {
        isBetter = true;
      } else {
        final existingValue = (existingDoc.data()!['best_value'] as num?) ?? 0;
        isBetter = sessionBest.reverse ? sessionBest.value < existingValue : sessionBest.value > existingValue;
      }

      if (isBetter) {
        final pb = PersonalBest(
          drillResult.drillId,
          drillResult.drillTitle,
          label,
          sessionBest.type,
          sessionBest.value,
          sessionBest.reverse,
          DateTime.now(),
          sessionId,
        );
        await pbRef.doc(docId).set(pb.toMap());
        newBests.add(pb);
      }
    }
  }

  return newBests;
}
