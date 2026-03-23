import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilldrills/models/firestore/measurement.dart';
import 'package:skilldrills/models/firestore/skill.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/firestore/timer_mode.dart';
import 'drill_type.dart';

class Drill {
  final String? title;
  final String? description;
  final Activity? activity;
  final DrillType? drillType;
  List<Measurement>? measurements;
  List<Skill>? skills;

  /// Pro: whether this drill is pinned to the top of the list.
  bool isPinned;

  /// Pro: sort position within the pinned section (0-indexed, lower = higher).
  int sortOrder;

  /// Timer behavior for drills with duration measurements.
  /// Defaults to [TimerMode.none] for drills without duration measurements.
  TimerMode timerMode;

  /// Default countdown duration in seconds (for countdown mode).
  /// Example: 60 for a 60-second plank hold.
  int? defaultCountdownSeconds;

  /// Target time in seconds (for stopwatch mode with a goal).
  /// Example: 120 for "complete drill in under 2 minutes".
  int? targetSeconds;

  DocumentReference? reference;

  Drill(this.title, this.description, this.activity, this.drillType)
      : isPinned = false,
        sortOrder = 0,
        timerMode = TimerMode.none;

  Drill.fromMap(Map<String, dynamic>? map, {this.reference})
      : assert(map!['title'] != null),
        assert(map!['description'] != null),
        assert(map!["activity"] != null),
        assert(map!['drill_type'] != null),
        title = map!['title'],
        description = map['description'],
        activity = Activity.fromMap(map['activity']),
        drillType = DrillType.fromMap(map['drill_type']),
        isPinned = (map['is_pinned'] as bool?) ?? false,
        sortOrder = (map['sort_order'] as int?) ?? 0,
        timerMode = TimerMode.fromString(map['timer_mode'] as String?),
        defaultCountdownSeconds = map['default_countdown_seconds'] != null ? (map['default_countdown_seconds'] as num).toInt() : null,
        targetSeconds = map['target_seconds'] != null ? (map['target_seconds'] as num).toInt() : null;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      "activity": activity!.toMap(),
      'drill_type': drillType!.toMap(),
      'is_pinned': isPinned,
      'sort_order': sortOrder,
      'timer_mode': timerMode.toFirestore(),
      if (defaultCountdownSeconds != null) 'default_countdown_seconds': defaultCountdownSeconds,
      if (targetSeconds != null) 'target_seconds': targetSeconds,
    };
  }

  Drill.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
