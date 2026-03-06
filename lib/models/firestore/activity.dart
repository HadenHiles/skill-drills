import 'package:cloud_firestore/cloud_firestore.dart';
import 'skill.dart';

// Exported so callers can sort / filter on this field name without magic strings.
const String kActivityLastActivatedAtField = 'last_activated_at';

/// Terminology labels for a given activity.
/// Controls how "drills", "sets", and "reps" are called throughout the UI.
///
/// All values are stored per-Activity document in Firestore.
/// [defaultsFor] and [iconFor] are seed/fallback helpers only — never used
/// as the runtime source of truth.
class ActivityTerminology {
  final String drillLabel; // singular, e.g. "Drill", "Exercise", "Skill"
  final String setsLabel; // plural, e.g. "Sets", "Rounds", "Intervals"
  final String repsLabel; // plural, e.g. "Reps", "Laps", "Shots"

  const ActivityTerminology({
    this.drillLabel = 'Drill',
    this.setsLabel = 'Sets',
    this.repsLabel = 'Reps',
  });

  /// Domain-appropriate defaults for each of the 14 standard activities.
  /// Used only when seeding a new activity; values are always persisted to Firestore.
  static ActivityTerminology defaultsFor(String? title) {
    switch (title?.trim()) {
      // Baseball: "rounds" of batting/fielding practice; "reps" count swings/throws
      case 'Baseball':
        return const ActivityTerminology(setsLabel: 'Rounds');
      // Golf: practice in "sets" of "balls" hit
      case 'Golf':
        return const ActivityTerminology(repsLabel: 'Balls');
      // Weight Training: universally "exercises", "sets", "reps"
      case 'Weight Training':
        return const ActivityTerminology(drillLabel: 'Exercise');
      // Tennis: "rounds" of a drill pattern; track individual "shots"
      case 'Tennis':
        return const ActivityTerminology(setsLabel: 'Rounds', repsLabel: 'Shots');
      // Running: a discrete "workout"; grouped in "intervals"; each rep is a "lap"
      case 'Running':
        return const ActivityTerminology(drillLabel: 'Workout', setsLabel: 'Intervals', repsLabel: 'Laps');
      // Volleyball: "rounds" to avoid ambiguity with the game-play "set"
      case 'Volleyball':
        return const ActivityTerminology(setsLabel: 'Rounds');
      // Martial Arts: "rounds" mirror the sparring/pad-work round structure
      case 'Martial Arts':
        return const ActivityTerminology(setsLabel: 'Rounds');
      // Gymnastics: individual movement elements are called "skills"
      case 'Gymnastics':
        return const ActivityTerminology(drillLabel: 'Skill');
      // Guitar: musicians do "exercises"; multiple "passes" through a piece
      case 'Guitar':
        return const ActivityTerminology(drillLabel: 'Exercise', setsLabel: 'Passes');
      // All other activities (Hockey, Basketball, Soccer, Pickleball, Lacrosse, custom)
      default:
        return const ActivityTerminology();
    }
  }

  /// Default emoji icon for each of the 14 standard activities.
  static String iconFor(String? title) {
    switch (title?.trim()) {
      case 'Hockey':
        return '🏒';
      case 'Basketball':
        return '🏀';
      case 'Baseball':
        return '⚾';
      case 'Golf':
        return '⛳';
      case 'Soccer':
        return '⚽';
      case 'Weight Training':
        return '🏋️';
      case 'Tennis':
        return '🎾';
      case 'Running':
        return '🏃';
      case 'Volleyball':
        return '🏐';
      case 'Martial Arts':
        return '🥋';
      case 'Pickleball':
        return '🏓';
      case 'Lacrosse':
        return '🥍';
      case 'Gymnastics':
        return '🤸';
      case 'Guitar':
        return '🎸';
      default:
        return '🎯';
    }
  }
}

/// Activity – a named skill domain chosen by the user (e.g. "Hockey", "Guitar").
/// Each Activity has a list of [skills] (sub-disciplines, e.g. "Shooting", "Passing")
/// that are used to categorise drills.
///
/// [isActive] – whether this activity is currently active for the user.
/// Free users may have at most [SkillDrillsUser.freeActiveActivityLimit] active
/// activities at one time. Inactive activities are preserved (drills/history
/// intact) but hidden from session start and drill authoring.
class Activity {
  String? id;
  final String? title;
  bool isActive;
  List<Skill>? skills;
  final String? createdBy;
  DocumentReference? reference;

  /// The last time this activity was toggled on.
  ///
  /// Written as a server timestamp whenever [isActive] is set to `true`.
  /// Used by [enforceActivityLimit] to decide which activities to keep when a
  /// paid subscription lapses — the [kFreeActiveActivityLimit] most recently
  /// activated are retained; the rest are disabled.  A `null` here means the
  /// activity has never been explicitly activated (seeded default), and it is
  /// treated as the oldest for enforcement purposes.
  DateTime? lastActivatedAt;

  /// Terminology config – how this activity labels its drills, sets, and reps.
  String drillLabel; // singular, e.g. "Drill"
  String setsLabel; // plural, e.g. "Sets"
  String repsLabel; // plural, e.g. "Reps"

  /// Emoji icon displayed alongside the activity name throughout the UI.
  String icon;

  Activity(
    this.title,
    this.createdBy, {
    this.isActive = true,
    this.lastActivatedAt,
    String? drillLabel,
    String? setsLabel,
    String? repsLabel,
    String? icon,
  })  : drillLabel = drillLabel ?? ActivityTerminology.defaultsFor(title).drillLabel,
        setsLabel = setsLabel ?? ActivityTerminology.defaultsFor(title).setsLabel,
        repsLabel = repsLabel ?? ActivityTerminology.defaultsFor(title).repsLabel,
        icon = icon ?? ActivityTerminology.iconFor(title);

  Activity.fromMap(Map<String, dynamic>? map, {this.reference})
      : assert(map!['title'] != null),
        id = map!['id'],
        title = map['title'],
        isActive = (map['is_active'] as bool?) ?? true,
        lastActivatedAt = (map[kActivityLastActivatedAtField] as Timestamp?)?.toDate(),
        skills = [],
        createdBy = map['created_by'],
        drillLabel = (map['drill_label'] as String?)?.isNotEmpty == true ? map['drill_label'] as String : ActivityTerminology.defaultsFor(map['title'] as String?).drillLabel,
        setsLabel = (map['sets_label'] as String?)?.isNotEmpty == true ? map['sets_label'] as String : ActivityTerminology.defaultsFor(map['title'] as String?).setsLabel,
        repsLabel = (map['reps_label'] as String?)?.isNotEmpty == true ? map['reps_label'] as String : ActivityTerminology.defaultsFor(map['title'] as String?).repsLabel,
        icon = (map['icon'] as String?)?.isNotEmpty == true ? map['icon'] as String : ActivityTerminology.iconFor(map['title'] as String?);

  Map<String, dynamic> toMap() {
    List<Map<String, dynamic>> skillMaps = [];
    for (var s in skills ?? []) {
      skillMaps.add(s.toMap());
    }

    return {
      'id': id,
      'title': title,
      'is_active': isActive,
      'skills': skillMaps,
      'created_by': createdBy,
      'drill_label': drillLabel,
      'sets_label': setsLabel,
      'reps_label': repsLabel,
      'icon': icon,
      if (lastActivatedAt != null) kActivityLastActivatedAtField: Timestamp.fromDate(lastActivatedAt!),
    };
  }

  Activity.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);

  // For select dialogs
  @override
  operator ==(other) => other is Activity && other.id == id;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ createdBy.hashCode;
}
