import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skilldrills/models/firestore/session.dart';

/// Exports the authenticated user's complete session history to a CSV file and
/// triggers the OS share sheet so the user can save or share it.
///
/// CSV columns:
///   session_date, session_title, session_duration_seconds,
///   activity_title, drill_title, set_number,
///   measurement_label, measurement_type, measurement_value
Future<void> exportSessionHistory() async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final snap = await FirebaseFirestore.instance.collection('sessions').doc(uid).collection('sessions').orderBy('started_at', descending: true).get();

  final rows = <List<dynamic>>[
    [
      'session_date',
      'session_title',
      'session_duration_seconds',
      'activity_title',
      'drill_title',
      'set_number',
      'measurement_label',
      'measurement_type',
      'measurement_value',
    ],
  ];

  for (final doc in snap.docs) {
    final session = Session.fromSnapshot(doc as DocumentSnapshot<Map<String, dynamic>>);
    final sessionDate = '${session.startedAt.year}-${session.startedAt.month.toString().padLeft(2, '0')}-${session.startedAt.day.toString().padLeft(2, '0')}';

    for (final dr in session.drillResults) {
      if (dr.setResults.isEmpty) {
        // Drill was added but no sets recorded.
        rows.add([
          sessionDate,
          session.title,
          session.durationSeconds ?? '',
          dr.activityTitle,
          dr.drillTitle,
          '',
          '',
          '',
          '',
        ]);
        continue;
      }
      for (var si = 0; si < dr.setResults.length; si++) {
        final setResult = dr.setResults[si];
        for (final m in setResult.measurementResults) {
          rows.add([
            sessionDate,
            session.title,
            session.durationSeconds ?? '',
            dr.activityTitle,
            dr.drillTitle,
            si + 1,
            m.label,
            m.type,
            m.value ?? '',
          ]);
        }
      }
    }
  }

  final csv = const ListToCsvConverter().convert(rows);
  final dir = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${dir.path}/skill_drills_export_$timestamp.csv');
  await file.writeAsString(csv);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    subject: 'SkillDrills Session History',
  );
}
