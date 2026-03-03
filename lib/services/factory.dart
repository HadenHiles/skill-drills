import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/onboarding_preferences.dart';
import 'package:skilldrills/models/firestore/skill.dart';
import 'package:skilldrills/models/firestore/drill.dart';
import 'package:skilldrills/models/firestore/drill_type.dart';
import 'package:skilldrills/models/firestore/measurement.dart';
import 'package:skilldrills/models/firestore/measurement_target.dart';
import 'package:skilldrills/models/firestore/measurement_result.dart';
import 'package:skilldrills/models/firestore/skill_drill_user.dart';
import 'package:skilldrills/models/firestore/routine.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

/// True while [bootstrap] is running. Widgets can listen to this to show a
/// friendly loading state instead of a confusing empty state.
final ValueNotifier<bool> isBootstrapping = ValueNotifier(false);

// ─────────────────────────────────────────────────────────────────────────────
// Bootstrap entry point (called from Nav.initState)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> bootstrap() async {
  isBootstrapping.value = true;
  try {
    addUser();

    // Read one-time onboarding preferences (cleared after first apply).
    final onboardingPrefs = await OnboardingPreferences.load();

    await Future.wait([
      bootstrapActivities(selectedActivities: onboardingPrefs.selectedActivities),
      bootstrapDrillTypes(includeDefault: onboardingPrefs.includeDefaultDrills),
    ]);
    await bootstrapDrills();

    // Clear the per-activity selections now that they have been applied.
    // The opted_out_default_drills flag is NOT cleared — it persists so future
    // bootstrap runs continue to skip seeding.
    await OnboardingPreferences.clearAfterApply();
  } finally {
    isBootstrapping.value = false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER
// ─────────────────────────────────────────────────────────────────────────────

void addUser() {
  FirebaseFirestore.instance.collection('users').doc(auth.currentUser!.uid).get().then((snapshot) {
    if (auth.currentUser!.uid.isNotEmpty && !snapshot.exists) {
      FirebaseFirestore.instance.collection('users').doc(auth.currentUser!.uid).set(SkillDrillsUser(auth.currentUser!.displayName, auth.currentUser!.email, auth.currentUser!.photoURL).toMap());
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITIES
// ─────────────────────────────────────────────────────────────────────────────

Future<void> bootstrapActivities({List<String> selectedActivities = const []}) async {
  final snapshot = await FirebaseFirestore.instance.collection("activities").doc(auth.currentUser!.uid).collection("activities").get();
  if (snapshot.docs.isEmpty) {
    await resetActivities(selectedActivities: selectedActivities);
  }
}

Future<void> resetActivities({List<String> selectedActivities = const []}) async {
  final uid = auth.currentUser!.uid;
  final snapshot = await FirebaseFirestore.instance.collection("activities").doc(uid).collection("activities").get();
  for (var doc in snapshot.docs) {
    final skillSnap = await doc.reference.collection('skills').get();
    for (var s in skillSnap.docs) {
      s.reference.delete();
    }
    doc.reference.delete();
  }
  final Map<String, List<String>> activitySkills = {
    'Hockey': ['Skating', 'Shooting', 'Stickhandling', 'Passing', 'Defense'],
    'Basketball': ['Shooting', 'Dribbling', 'Passing', 'Rebounding', 'Defense', 'Conditioning'],
    'Baseball': ['Hitting', 'Throwing', 'Pitching', 'Ground Balls', "Pop Fly's", 'Base Running'],
    'Golf': ['Drive', 'Iron Play', 'Chip', 'Putt', 'Bunker', 'Approach'],
    'Soccer': ['Ball Control', 'Passing', 'Shooting', 'Dribbling', 'Defending', 'Fitness'],
    'Weight Training': ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core', 'Full Body', 'Cardio'],
    'Tennis': ['Serve', 'Forehand', 'Backhand', 'Volley', 'Return', 'Footwork'],
    'Running': ['Sprints', 'Intervals', 'Tempo', 'Distance', 'Hills', 'Recovery'],
    'Volleyball': ['Serve', 'Pass', 'Set', 'Spike', 'Block', 'Defense'],
    'Martial Arts': ['Striking', 'Kicks', 'Defense', 'Footwork', 'Combinations', 'Conditioning'],
    'Pickleball': ['Serve', 'Dink', 'Third Shot', 'Drive', 'Volley', 'Footwork'],
    'Lacrosse': ['Catching', 'Passing', 'Shooting', 'Cradling', 'Ground Balls', 'Footwork'],
    'Gymnastics': ['Strength', 'Flexibility', 'Balance', 'Handstand', 'Core', 'Conditioning'],
    'Guitar': ['Scales', 'Chords', 'Strumming', 'Picking', 'Rhythm', 'Theory'],
  };
  for (var entry in activitySkills.entries) {
    // If the user selected specific activities during onboarding, mark all
    // others as inactive so the UI is focused on their chosen domains.
    // An empty selectedActivities list means "no preference" — all active.
    final isActive = selectedActivities.isEmpty || selectedActivities.contains(entry.key);
    final a = Activity(entry.key, null, isActive: isActive);
    final actDoc = FirebaseFirestore.instance.collection("activities").doc(uid).collection("activities").doc();
    a.id = actDoc.id;
    a.skills = [];
    actDoc.set(a.toMap());

    for (var skillTitle in entry.value) {
      _saveActivitySkill(actDoc, Skill(skillTitle));
    }
  }
}

void _saveActivitySkill(DocumentReference actRef, Skill s) {
  final skillDoc = actRef.collection('skills').doc();
  s.id = skillDoc.id;
  skillDoc.set(s.toMap());
}

// ─────────────────────────────────────────────────────────────────────────────
// DRILL TYPES  (6 universal + 4 per activity × 14 activities = 62 total)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> bootstrapDrillTypes({bool includeDefault = true}) async {
  final uid = auth.currentUser!.uid;

  // Persist the opted-out decision so future bootstraps also skip seeding.
  if (!includeDefault) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('opted_out_default_drills', true);
    return;
  }

  // Respect a previously stored opt-out.
  final prefs = await SharedPreferences.getInstance();
  final optedOut = prefs.getBool('opted_out_default_drills') ?? false;
  if (optedOut) return;

  final allTypes = _allDrillTypes();
  final snapshot = await FirebaseFirestore.instance.collection('drill_types').doc(uid).collection('drill_types').get();
  if (snapshot.docs.length == allTypes.length) return;
  for (var doc in snapshot.docs) {
    final mSnap = await doc.reference.collection('measurements').get();
    for (var m in mSnap.docs) {
      m.reference.delete();
    }
    doc.reference.delete();
  }
  for (var dt in allTypes) {
    final dtDoc = FirebaseFirestore.instance.collection('drill_types').doc(uid).collection('drill_types').doc();
    for (var m in dt.measurements!) {
      _saveMeasurement(dtDoc, m);
    }
    dtDoc.set(dt.toMap());
  }
}

void _saveMeasurement(DocumentReference dtRef, Measurement m) {
  dtRef.collection('measurements').doc().set(m.toMap());
}

List<DrillType> _allDrillTypes() => [
      ..._universalDrillTypes(),
      ..._hockeyDrillTypes(),
      ..._basketballDrillTypes(),
      ..._baseballDrillTypes(),
      ..._golfDrillTypes(),
      ..._soccerDrillTypes(),
      ..._weightTrainingDrillTypes(),
      ..._tennisDrillTypes(),
      ..._runningDrillTypes(),
      ..._volleyballDrillTypes(),
      ..._martialArtsDrillTypes(),
      ..._pickleballDrillTypes(),
      ..._lacrosseDrillTypes(),
      ..._gymnasticsDrillTypes(),
      ..._guitarDrillTypes(),
    ];

// ── Universal ─────────────────────────────────────────────────────────────────

List<DrillType> _universalDrillTypes() => [
      DrillType('count', 'Count / Reps', 'Simple repetition counter with optional target', 0, 1)
        ..measurements = [
          MeasurementResult('amount', 'Count', 1, null) as Measurement,
          MeasurementTarget('amount', 'Target Count', 2, null, false) as Measurement,
        ],
      DrillType('score', 'Score / Accuracy', 'Track hits, attempts, and an optional target', 0, 2)
        ..measurements = [
          MeasurementResult('amount', 'Score', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Score', 3, null, false) as Measurement,
        ],
      DrillType('duration', 'Duration / Time', 'Track elapsed time with an optional target', 0, 3)
        ..measurements = [
          MeasurementResult('duration', 'Time', 1, null) as Measurement,
          MeasurementTarget('duration', 'Target Time', 2, null, true) as Measurement,
        ],
      DrillType('count_duration', 'Count + Time', 'Repetition count alongside completion time', 0, 4)
        ..measurements = [
          MeasurementResult('amount', 'Count', 1, null) as Measurement,
          MeasurementResult('duration', 'Time', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Count', 3, null, false) as Measurement,
          MeasurementTarget('duration', 'Target Time', 4, null, true) as Measurement,
        ],
      DrillType('sets', 'Sets', 'Multiple sets with reps and optional weight', 0, 5)
        ..measurements = [
          MeasurementResult('amount', 'Sets', 1, null) as Measurement,
          MeasurementResult('amount', 'Reps', 2, null) as Measurement,
          MeasurementResult('amount', 'Weight (kg)', 3, null) as Measurement,
          MeasurementTarget('amount', 'Target Reps', 4, null, false) as Measurement,
        ],
      DrillType('pace', 'Pace / Laps', 'Distance and time for pace-based drills', 0, 6)
        ..measurements = [
          MeasurementResult('amount', 'Distance (m)', 1, null) as Measurement,
          MeasurementResult('duration', 'Time', 2, null) as Measurement,
          MeasurementTarget('duration', 'Target Time', 3, null, true) as Measurement,
        ],
    ];

// ── Hockey ────────────────────────────────────────────────────────────────────

List<DrillType> _hockeyDrillTypes() => [
      DrillType('hockey_shot_accuracy', 'Shot Accuracy', 'Goals scored out of shots taken', 0, 7, activityKey: 'Hockey')
        ..measurements = [
          MeasurementResult('amount', 'Goals Scored', 1, null) as Measurement,
          MeasurementResult('amount', 'Shots Taken', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Goals', 3, null, false) as Measurement,
        ],
      DrillType('hockey_stickhandling', 'Stickhandling Circuit', 'Reps or laps through a stickhandling course', 0, 8, activityKey: 'Hockey')
        ..measurements = [
          MeasurementResult('amount', 'Laps / Reps', 1, null) as Measurement,
          MeasurementResult('duration', 'Time', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Laps', 3, null, false) as Measurement,
        ],
      DrillType('hockey_skating_time', 'Skating Time Trial', 'Complete a skating course as fast as possible', 0, 9, activityKey: 'Hockey')
        ..measurements = [
          MeasurementResult('duration', 'Completion Time', 1, null) as Measurement,
          MeasurementResult('rpe', 'RPE (1–10)', 2, null) as Measurement,
          MeasurementTarget('duration', 'Target Time', 3, null, true) as Measurement,
          MeasurementTarget('rpe', 'Target RPE', 4, null, false) as Measurement,
        ],
      DrillType('hockey_passing', 'Passing Accuracy', 'Successful passes out of total attempts', 0, 10, activityKey: 'Hockey')
        ..measurements = [
          MeasurementResult('amount', 'Passes Made', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Passes', 3, null, false) as Measurement,
        ],
    ];

// ── Basketball ────────────────────────────────────────────────────────────────

List<DrillType> _basketballDrillTypes() => [
      DrillType('basketball_free_throw', 'Free Throws', 'Makes and attempts from the free throw line', 0, 11, activityKey: 'Basketball')
        ..measurements = [
          MeasurementResult('amount', 'Makes', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Makes', 3, null, false) as Measurement,
        ],
      DrillType('basketball_shooting', 'Spot Shooting', 'Makes and attempts from a specific court location', 0, 12, activityKey: 'Basketball')
        ..measurements = [
          MeasurementResult('amount', 'Makes', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Makes', 3, null, false) as Measurement,
        ],
      DrillType('basketball_dribbling', 'Dribbling Circuit', 'Circuit completion time with optional error count', 0, 13, activityKey: 'Basketball')
        ..measurements = [
          MeasurementResult('duration', 'Completion Time', 1, null) as Measurement,
          MeasurementResult('amount', 'Errors', 2, null) as Measurement,
          MeasurementTarget('duration', 'Target Time', 3, null, true) as Measurement,
        ],
      DrillType('basketball_conditioning', 'Conditioning', 'Timed run or court sprint drill', 0, 14, activityKey: 'Basketball')
        ..measurements = [
          MeasurementResult('duration', 'Time', 1, null) as Measurement,
          MeasurementResult('amount', 'Rounds', 2, null) as Measurement,
          MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
          MeasurementTarget('duration', 'Target Time', 4, null, true) as Measurement,
          MeasurementTarget('rpe', 'Target RPE', 5, null, false) as Measurement,
        ],
    ];

// ── Baseball ──────────────────────────────────────────────────────────────────

List<DrillType> _baseballDrillTypes() => [
      DrillType('baseball_batting', 'Batting Practice', 'Quality contact out of total swings', 0, 15, activityKey: 'Baseball')
        ..measurements = [
          MeasurementResult('amount', 'Solid Hits', 1, null) as Measurement,
          MeasurementResult('amount', 'Swings', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Hits', 3, null, false) as Measurement,
        ],
      DrillType('baseball_fielding', 'Fielding Drill', 'Clean fielded balls out of total attempts', 0, 16, activityKey: 'Baseball')
        ..measurements = [
          MeasurementResult('amount', 'Clean Fielded', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Clean', 3, null, false) as Measurement,
        ],
      DrillType('baseball_pitching', 'Pitching', 'Strikes thrown out of total pitches', 0, 17, activityKey: 'Baseball')
        ..measurements = [
          MeasurementResult('amount', 'Strikes', 1, null) as Measurement,
          MeasurementResult('amount', 'Pitches', 2, null) as Measurement,
          MeasurementResult('rpe', 'Arm RPE (1–10)', 3, null) as Measurement,
          MeasurementTarget('amount', 'Target Strikes', 4, null, false) as Measurement,
          MeasurementTarget('rpe', 'Target Arm RPE', 5, null, false) as Measurement,
        ],
      DrillType('baseball_throwing', 'Throwing Accuracy', 'On-target throws out of total attempts', 0, 18, activityKey: 'Baseball')
        ..measurements = [
          MeasurementResult('amount', 'On Target', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Throws', 3, null, false) as Measurement,
        ],
    ];

// ── Golf ──────────────────────────────────────────────────────────────────────

List<DrillType> _golfDrillTypes() => [
      DrillType('golf_putting', 'Putting', 'Makes and attempts from a given distance', 0, 19, activityKey: 'Golf')
        ..measurements = [
          MeasurementResult('amount', 'Makes', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Makes', 3, null, false) as Measurement,
        ],
      DrillType('golf_short_game', 'Chipping / Short Game', 'Balls within target proximity out of attempts', 0, 20, activityKey: 'Golf')
        ..measurements = [
          MeasurementResult('amount', 'In Zone', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target In Zone', 3, null, false) as Measurement,
        ],
      DrillType('golf_driving', 'Driving Accuracy', 'Fairways hit out of total drives', 0, 21, activityKey: 'Golf')
        ..measurements = [
          MeasurementResult('amount', 'Fairways Hit', 1, null) as Measurement,
          MeasurementResult('amount', 'Drives', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Fairways', 3, null, false) as Measurement,
        ],
      DrillType('golf_iron_play', 'Iron Play', 'Greens hit in regulation out of attempts', 0, 22, activityKey: 'Golf')
        ..measurements = [
          MeasurementResult('amount', 'Greens Hit', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Greens', 3, null, false) as Measurement,
        ],
    ];

// ── Soccer ────────────────────────────────────────────────────────────────────

List<DrillType> _soccerDrillTypes() => [
      DrillType('soccer_shooting', 'Shooting', 'Goals and shots on target out of total attempts', 0, 23, activityKey: 'Soccer')
        ..measurements = [
          MeasurementResult('amount', 'Goals', 1, null) as Measurement,
          MeasurementResult('amount', 'Shots on Target', 2, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 3, null) as Measurement,
          MeasurementTarget('amount', 'Target Goals', 4, null, false) as Measurement,
        ],
      DrillType('soccer_juggling', 'Juggling', 'Consecutive touches without the ball hitting the ground', 0, 24, activityKey: 'Soccer')
        ..measurements = [
          MeasurementResult('amount', 'Best Streak', 1, null) as Measurement,
          MeasurementTarget('amount', 'Target Streak', 2, null, false) as Measurement,
        ],
      DrillType('soccer_dribbling', 'Dribbling Circuit', 'Cone circuit completion time with error count', 0, 25, activityKey: 'Soccer')
        ..measurements = [
          MeasurementResult('duration', 'Completion Time', 1, null) as Measurement,
          MeasurementResult('amount', 'Errors', 2, null) as Measurement,
          MeasurementTarget('duration', 'Target Time', 3, null, true) as Measurement,
        ],
      DrillType('soccer_passing', 'Passing Drill', 'Successful passes out of total attempts', 0, 26, activityKey: 'Soccer')
        ..measurements = [
          MeasurementResult('amount', 'Successful', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Passes', 3, null, false) as Measurement,
        ],
    ];

// ── Weight Training ───────────────────────────────────────────────────────────

List<DrillType> _weightTrainingDrillTypes() => [
      DrillType('weight_compound', 'Compound Lift', 'Multi-joint barbell or machine exercise', 0, 27, activityKey: 'Weight Training')
        ..measurements = [
          MeasurementResult('amount', 'Sets', 1, null) as Measurement,
          MeasurementResult('amount', 'Reps', 2, null) as Measurement,
          MeasurementResult('amount', 'Weight (kg)', 3, null) as Measurement,
          MeasurementResult('rpe', 'RPE (1–10)', 4, null) as Measurement,
          MeasurementResult('rir', 'RIR', 5, null) as Measurement,
          MeasurementTarget('amount', 'Target Weight (kg)', 6, null, false) as Measurement,
          MeasurementTarget('amount', 'Target Reps', 7, null, false) as Measurement,
          MeasurementTarget('rpe', 'Target RPE', 8, null, false) as Measurement,
          MeasurementTarget('rir', 'Target RIR', 9, null, false) as Measurement,
        ],
      DrillType('weight_isolation', 'Isolation Exercise', 'Single-joint dumbbell or cable exercise', 0, 28, activityKey: 'Weight Training')
        ..measurements = [
          MeasurementResult('amount', 'Sets', 1, null) as Measurement,
          MeasurementResult('amount', 'Reps', 2, null) as Measurement,
          MeasurementResult('amount', 'Weight (kg)', 3, null) as Measurement,
          MeasurementResult('rpe', 'RPE (1–10)', 4, null) as Measurement,
          MeasurementResult('rir', 'RIR', 5, null) as Measurement,
          MeasurementTarget('amount', 'Target Reps', 6, null, false) as Measurement,
          MeasurementTarget('rpe', 'Target RPE', 7, null, false) as Measurement,
          MeasurementTarget('rir', 'Target RIR', 8, null, false) as Measurement,
        ],
      DrillType('weight_bodyweight', 'Bodyweight Exercise', 'No-equipment exercise — push-ups, pull-ups, dips, etc.', 0, 29, activityKey: 'Weight Training')
        ..measurements = [
          MeasurementResult('amount', 'Sets', 1, null) as Measurement,
          MeasurementResult('amount', 'Reps', 2, null) as Measurement,
          MeasurementResult('rir', 'RIR', 3, null) as Measurement,
          MeasurementTarget('amount', 'Target Reps', 4, null, false) as Measurement,
          MeasurementTarget('rir', 'Target RIR', 5, null, false) as Measurement,
        ],
      DrillType('weight_cardio', 'Cardio', 'Aerobic conditioning with duration and optional distance', 0, 30, activityKey: 'Weight Training')
        ..measurements = [
          MeasurementResult('duration', 'Duration', 1, null) as Measurement,
          MeasurementResult('amount', 'Distance (km)', 2, null) as Measurement,
          MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
          MeasurementTarget('duration', 'Target Duration', 4, null, false) as Measurement,
          MeasurementTarget('rpe', 'Target RPE', 5, null, false) as Measurement,
        ],
    ];

// ── Tennis ────────────────────────────────────────────────────────────────────

List<DrillType> _tennisDrillTypes() => [
      DrillType('tennis_serve', 'Serve Practice', 'First and second serves in vs. total attempts', 0, 31, activityKey: 'Tennis')
        ..measurements = [
          MeasurementResult('amount', 'First Serves In', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target In', 3, null, false) as Measurement,
        ],
      DrillType('tennis_groundstroke', 'Groundstroke Consistency', 'Consecutive rally balls or cross-court targets hit', 0, 32, activityKey: 'Tennis')
        ..measurements = [
          MeasurementResult('amount', 'Best Streak', 1, null) as Measurement,
          MeasurementResult('amount', 'Target Zone Hits', 2, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 3, null) as Measurement,
          MeasurementTarget('amount', 'Target Streak', 4, null, false) as Measurement,
        ],
      DrillType('tennis_volley', 'Volley Drill', 'Controlled volleys kept in play or on target', 0, 33, activityKey: 'Tennis')
        ..measurements = [
          MeasurementResult('amount', 'Successful Volleys', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Volleys', 3, null, false) as Measurement,
        ],
      DrillType('tennis_footwork', 'Footwork & Conditioning', 'Court movement drill — time and RPE', 0, 34, activityKey: 'Tennis')
        ..measurements = [
          MeasurementResult('duration', 'Time', 1, null) as Measurement,
          MeasurementResult('amount', 'Rounds', 2, null) as Measurement,
          MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
          MeasurementTarget('duration', 'Target Time', 4, null, true) as Measurement,
          MeasurementTarget('rpe', 'Target RPE', 5, null, false) as Measurement,
        ],
    ];

// ── Running ───────────────────────────────────────────────────────────────────

List<DrillType> _runningDrillTypes() => [
      DrillType('running_interval', 'Interval Run', 'Distance, time, and effort for interval training', 0, 35, activityKey: 'Running')
        ..measurements = [
          MeasurementResult('amount', 'Distance (m)', 1, null) as Measurement,
          MeasurementResult('duration', 'Split Time', 2, null) as Measurement,
          MeasurementResult('amount', 'Reps', 3, null) as Measurement,
          MeasurementResult('rpe', 'RPE (1–10)', 4, null) as Measurement,
          MeasurementTarget('duration', 'Target Split', 5, null, true) as Measurement,
          MeasurementTarget('rpe', 'Target RPE', 6, null, false) as Measurement,
        ],
      DrillType('running_tempo', 'Tempo / Steady State', 'Sustained effort run — distance, time, and pace', 0, 36, activityKey: 'Running')
        ..measurements = [
          MeasurementResult('amount', 'Distance (km)', 1, null) as Measurement,
          MeasurementResult('duration', 'Total Time', 2, null) as Measurement,
          MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
          MeasurementTarget('duration', 'Target Time', 4, null, true) as Measurement,
          MeasurementTarget('rpe', 'Target RPE', 5, null, false) as Measurement,
        ],
      DrillType('running_sprint', 'Sprint / Speed Work', 'Max-effort runs — distance, time, and rep count', 0, 37, activityKey: 'Running')
        ..measurements = [
          MeasurementResult('amount', 'Distance (m)', 1, null) as Measurement,
          MeasurementResult('duration', 'Best Time', 2, null) as Measurement,
          MeasurementResult('amount', 'Reps', 3, null) as Measurement,
          MeasurementTarget('duration', 'Target Time', 4, null, true) as Measurement,
        ],
      DrillType('running_drill', 'Running Form Drill', 'Repetitions of a mechanics drill (A-run, B-skip, etc.)', 0, 38, activityKey: 'Running')
        ..measurements = [
          MeasurementResult('amount', 'Reps', 1, null) as Measurement,
          MeasurementResult('duration', 'Time', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Reps', 3, null, false) as Measurement,
        ],
    ];

// ── Volleyball ────────────────────────────────────────────────────────────────

List<DrillType> _volleyballDrillTypes() => [
      DrillType('volleyball_serve', 'Serving Accuracy', 'Serves in-bounds or on-target out of total attempts', 0, 39, activityKey: 'Volleyball')
        ..measurements = [
          MeasurementResult('amount', 'Serves In', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target In', 3, null, false) as Measurement,
        ],
      DrillType('volleyball_pass', 'Passing / Receive', 'Controlled passes to target zone out of attempts', 0, 40, activityKey: 'Volleyball')
        ..measurements = [
          MeasurementResult('amount', 'On Target', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target On Target', 3, null, false) as Measurement,
        ],
      DrillType('volleyball_attack', 'Attacking / Spiking', 'Successful attacks or kills out of total swings', 0, 41, activityKey: 'Volleyball')
        ..measurements = [
          MeasurementResult('amount', 'Kills / On Target', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Kills', 3, null, false) as Measurement,
        ],
      DrillType('volleyball_setting', 'Setting Consistency', 'Consecutive sets kept on target or best streak', 0, 42, activityKey: 'Volleyball')
        ..measurements = [
          MeasurementResult('amount', 'Best Streak', 1, null) as Measurement,
          MeasurementResult('amount', 'Total Sets', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Streak', 3, null, false) as Measurement,
        ],
    ];

// ── Martial Arts ──────────────────────────────────────────────────────────────

List<DrillType> _martialArtsDrillTypes() => [
      DrillType('ma_combination', 'Combination Drill', 'Repetitions of a strike/kick combination', 0, 43, activityKey: 'Martial Arts')
        ..measurements = [
          MeasurementResult('amount', 'Reps', 1, null) as Measurement,
          MeasurementResult('duration', 'Time', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Reps', 3, null, false) as Measurement,
        ],
      DrillType('ma_bag_work', 'Bag / Pad Work', 'Timed rounds with output and RPE tracking', 0, 44, activityKey: 'Martial Arts')
        ..measurements = [
          MeasurementResult('amount', 'Rounds', 1, null) as Measurement,
          MeasurementResult('duration', 'Round Duration', 2, null) as Measurement,
          MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
          MeasurementTarget('amount', 'Target Rounds', 4, null, false) as Measurement,
          MeasurementTarget('rpe', 'Target RPE', 5, null, false) as Measurement,
        ],
      DrillType('ma_footwork', 'Footwork Drill', 'Shadow movement patterns — time and reps', 0, 45, activityKey: 'Martial Arts')
        ..measurements = [
          MeasurementResult('amount', 'Reps', 1, null) as Measurement,
          MeasurementResult('duration', 'Time', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Reps', 3, null, false) as Measurement,
        ],
      DrillType('ma_conditioning', 'Martial Arts Conditioning', 'Timed conditioning circuit with RPE', 0, 46, activityKey: 'Martial Arts')
        ..measurements = [
          MeasurementResult('duration', 'Duration', 1, null) as Measurement,
          MeasurementResult('amount', 'Rounds', 2, null) as Measurement,
          MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
          MeasurementTarget('duration', 'Target Duration', 4, null, false) as Measurement,
          MeasurementTarget('rpe', 'Target RPE', 5, null, false) as Measurement,
        ],
    ];

// ── Pickleball ────────────────────────────────────────────────────────────────

List<DrillType> _pickleballDrillTypes() => [
      DrillType('pk_dink', 'Dinking Consistency', 'Consecutive dinks or cross-court dinks in a rally', 0, 47, activityKey: 'Pickleball')
        ..measurements = [
          MeasurementResult('amount', 'Best Streak', 1, null) as Measurement,
          MeasurementResult('amount', 'Total Dinks', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Streak', 3, null, false) as Measurement,
        ],
      DrillType('pk_serve', 'Serve Placement', 'Serves landing in target zones out of attempts', 0, 48, activityKey: 'Pickleball')
        ..measurements = [
          MeasurementResult('amount', 'Zone Hits', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Zone Hits', 3, null, false) as Measurement,
        ],
      DrillType('pk_third_shot', 'Third Shot Drop', 'Successful drops landing in kitchen out of attempts', 0, 49, activityKey: 'Pickleball')
        ..measurements = [
          MeasurementResult('amount', 'In Kitchen', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target In Kitchen', 3, null, false) as Measurement,
        ],
      DrillType('pk_drive', 'Drive & Reset', 'Drives and reset neutralisation — accuracy tracked', 0, 50, activityKey: 'Pickleball')
        ..measurements = [
          MeasurementResult('amount', 'Successful', 1, null) as Measurement,
          MeasurementResult('amount', 'Attempts', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Successful', 3, null, false) as Measurement,
        ],
    ];

// ── Lacrosse ──────────────────────────────────────────────────────────────────

List<DrillType> _lacrosseDrillTypes() => [
      DrillType('lax_wall_ball', 'Wall Ball', 'Catches out of total throws against a wall', 0, 51, activityKey: 'Lacrosse')
        ..measurements = [
          MeasurementResult('amount', 'Catches', 1, null) as Measurement,
          MeasurementResult('amount', 'Throws', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Catches', 3, null, false) as Measurement,
        ],
      DrillType('lax_shooting', 'Shooting Accuracy', 'Goals or on-target shots out of total rips', 0, 52, activityKey: 'Lacrosse')
        ..measurements = [
          MeasurementResult('amount', 'On Target', 1, null) as Measurement,
          MeasurementResult('amount', 'Shots', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target On Target', 3, null, false) as Measurement,
        ],
      DrillType('lax_cradling', 'Cradling Circuit', 'Cradling reps or circuit completion time', 0, 53, activityKey: 'Lacrosse')
        ..measurements = [
          MeasurementResult('amount', 'Reps', 1, null) as Measurement,
          MeasurementResult('duration', 'Time', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Reps', 3, null, false) as Measurement,
        ],
      DrillType('lax_ground_ball', 'Ground Ball Drill', 'Ground balls secured out of total contests', 0, 54, activityKey: 'Lacrosse')
        ..measurements = [
          MeasurementResult('amount', 'Secured', 1, null) as Measurement,
          MeasurementResult('amount', 'Contests', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Secured', 3, null, false) as Measurement,
        ],
    ];

// ── Gymnastics / Calisthenics ─────────────────────────────────────────────────

List<DrillType> _gymnasticsDrillTypes() => [
      DrillType('gym_hold', 'Static Hold', 'Duration hold of a static skill position', 0, 55, activityKey: 'Gymnastics')
        ..measurements = [
          MeasurementResult('duration', 'Best Hold', 1, null) as Measurement,
          MeasurementResult('amount', 'Sets', 2, null) as Measurement,
          MeasurementTarget('duration', 'Target Hold', 3, null, false) as Measurement,
        ],
      DrillType('gym_skill_reps', 'Skill Repetitions', 'Clean executions of a skill out of total attempts', 0, 56, activityKey: 'Gymnastics')
        ..measurements = [
          MeasurementResult('amount', 'Clean Reps', 1, null) as Measurement,
          MeasurementResult('amount', 'Total Attempts', 2, null) as Measurement,
          MeasurementResult('rir', 'RIR', 3, null) as Measurement,
          MeasurementTarget('amount', 'Target Clean', 4, null, false) as Measurement,
          MeasurementTarget('rir', 'Target RIR', 5, null, false) as Measurement,
        ],
      DrillType('gym_conditioning', 'Gymnastics Conditioning', 'Timed conditioning circuit', 0, 57, activityKey: 'Gymnastics')
        ..measurements = [
          MeasurementResult('amount', 'Sets', 1, null) as Measurement,
          MeasurementResult('amount', 'Reps', 2, null) as Measurement,
          MeasurementResult('rir', 'RIR', 3, null) as Measurement,
          MeasurementTarget('amount', 'Target Reps', 4, null, false) as Measurement,
          MeasurementTarget('rir', 'Target RIR', 5, null, false) as Measurement,
        ],
      DrillType('gym_flexibility', 'Flexibility / Mobility', 'Stretch depth or hold duration for a mobility position', 0, 58, activityKey: 'Gymnastics')
        ..measurements = [
          MeasurementResult('duration', 'Hold Time', 1, null) as Measurement,
          MeasurementResult('amount', 'Sets', 2, null) as Measurement,
          MeasurementTarget('duration', 'Target Hold', 3, null, false) as Measurement,
        ],
    ];

// ── Guitar ────────────────────────────────────────────────────────────────────

List<DrillType> _guitarDrillTypes() => [
      DrillType('guitar_scale', 'Scale Practice', 'Scale runs with tempo (BPM) and accuracy tracking', 0, 59, activityKey: 'Guitar')
        ..measurements = [
          MeasurementResult('amount', 'BPM Achieved', 1, null) as Measurement,
          MeasurementResult('amount', 'Clean Runs', 2, null) as Measurement,
          MeasurementResult('amount', 'Total Runs', 3, null) as Measurement,
          MeasurementTarget('amount', 'Target BPM', 4, null, false) as Measurement,
        ],
      DrillType('guitar_chord', 'Chord Transitions', 'Clean chord changes per minute or streak of clean changes', 0, 60, activityKey: 'Guitar')
        ..measurements = [
          MeasurementResult('amount', 'Changes / Min', 1, null) as Measurement,
          MeasurementResult('amount', 'Best Streak (clean)', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Changes / Min', 3, null, false) as Measurement,
        ],
      DrillType('guitar_technique', 'Technique Drill', 'Repetitions of a technique pattern at a target BPM', 0, 61, activityKey: 'Guitar')
        ..measurements = [
          MeasurementResult('amount', 'BPM Achieved', 1, null) as Measurement,
          MeasurementResult('amount', 'Reps / Minutes', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target BPM', 3, null, false) as Measurement,
        ],
      DrillType('guitar_repertoire', 'Song / Repertoire', 'Run-throughs with quality and notes-per-pass rating', 0, 62, activityKey: 'Guitar')
        ..measurements = [
          MeasurementResult('amount', 'Run-throughs', 1, null) as Measurement,
          MeasurementResult('amount', 'Quality (1–10)', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Quality', 3, null, false) as Measurement,
        ],
    ];

// ─────────────────────────────────────────────────────────────────────────────
// DEFAULT DRILLS  (seeded on first launch only — skipped if any drills exist)
// ─────────────────────────────────────────────────────────────────────────────

class _DrillSpec {
  final String title;
  final String description;
  final String activityTitle;
  final String drillTypeId;
  final List<String> skillTitles;
  final List<Measurement> measurements;
  _DrillSpec({required this.title, required this.description, required this.activityTitle, required this.drillTypeId, required this.skillTitles, required this.measurements});
}

Future<void> bootstrapDrills() async {
  final uid = auth.currentUser!.uid;
  final existingDrills = await FirebaseFirestore.instance.collection('drills').doc(uid).collection('drills').limit(1).get();
  if (existingDrills.docs.isNotEmpty) return;

  // ── Parallel reads ───────────────────────────────────────────────────────
  final actSnap = await FirebaseFirestore.instance.collection('activities').doc(uid).collection('activities').get();
  final dtSnap = await FirebaseFirestore.instance.collection('drill_types').doc(uid).collection('drill_types').get();

  // Fetch all activity-skills and drill-type-measurements in parallel.
  final activitySkillFutures = actSnap.docs.map((doc) => doc.reference.collection('skills').get());
  final dtMeasurementFutures = dtSnap.docs.map((doc) => doc.reference.collection('measurements').orderBy('order').get());
  final activitySkillSnaps = await Future.wait(activitySkillFutures);
  final dtMeasurementSnaps = await Future.wait(dtMeasurementFutures);

  final Map<String, Activity> activityMap = {};
  for (var i = 0; i < actSnap.docs.length; i++) {
    final a = Activity.fromSnapshot(actSnap.docs[i]);
    a.skills = activitySkillSnaps[i].docs.map((s) => Skill.fromSnapshot(s)).toList();
    activityMap[a.title!] = a;
  }

  final Map<String, DrillType> drillTypeMap = {};
  for (var i = 0; i < dtSnap.docs.length; i++) {
    final dt = DrillType.fromSnapshot(dtSnap.docs[i]);
    dt.measurements = dtMeasurementSnaps[i].docs.map((m) => Measurement.fromSnapshot(m)).toList();
    drillTypeMap[dt.id!] = dt;
  }

  Skill? findSkill(String activityTitle, String skillTitle) {
    try {
      return activityMap[activityTitle]?.skills?.firstWhere((s) => s.title == skillTitle);
    } catch (_) {
      return null;
    }
  }

  // ── Batched writes ───────────────────────────────────────────────────────
  // Firestore batches are capped at 500 operations. We auto-flush when close.
  const batchLimit = 490;
  var batch = FirebaseFirestore.instance.batch();
  var opCount = 0;

  Future<void> maybeFlush() async {
    if (opCount >= batchLimit) {
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
      opCount = 0;
    }
  }

  for (final spec in _defaultDrillSpecs()) {
    final activity = activityMap[spec.activityTitle];
    final drillType = drillTypeMap[spec.drillTypeId];
    if (activity == null || drillType == null) continue;

    final skills = spec.skillTitles.map((t) => findSkill(spec.activityTitle, t)).whereType<Skill>().toList();
    final actSnap2 = Activity(activity.title, activity.createdBy);
    actSnap2.id = activity.id;
    actSnap2.skills = skills;

    final newRef = FirebaseFirestore.instance.collection('drills').doc(uid).collection('drills').doc();
    batch.set(newRef, Drill(spec.title, spec.description, actSnap2, drillType).toMap());
    opCount++;
    await maybeFlush();

    for (final m in spec.measurements) {
      batch.set(newRef.collection('measurements').doc(), m.toMap());
      opCount++;
      await maybeFlush();
    }
    for (final s in skills) {
      batch.set(newRef.collection('skills').doc(), s.toMap());
      opCount++;
      await maybeFlush();
    }
  }

  if (opCount > 0) await batch.commit();
}

List<_DrillSpec> _defaultDrillSpecs() => [
      // ── Hockey – Stickhandling / Puck Control
      _DrillSpec(
          title: 'Quick Dribbles',
          description: 'Stationary. Use a wooden ball or Green Biscuit and perform fast, short, soft taps — cup the blade over the puck to develop "soft hands". Keep the puck as close to the blade as possible throughout.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_stickhandling',
          skillTitles: ['Stickhandling'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 100, false) as Measurement]),
      _DrillSpec(
          title: 'Wide Stickhandling',
          description: 'Move the puck far to your forehand side, back through the middle, then far to the backhand side. Build forearm strength and puck control well away from your body — both forehand and backhand.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_stickhandling',
          skillTitles: ['Stickhandling'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 40, false) as Measurement]),
      _DrillSpec(
          title: 'Figure 8s',
          description: 'Place two cones or pucks about 1–2 feet apart. Move the puck in a continuous figure-8 pattern around them, alternating forehand and backhand. Improves edge control and tight maneuvering.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_stickhandling',
          skillTitles: ['Stickhandling'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 30, false) as Measurement]),
      _DrillSpec(
          title: 'Toe Pull Drill',
          description: 'Pull the puck from your forehand side across your body to the backhand using the toe of the blade, then push it back out — tracing an "S" shape. Mimics pulling the puck around a defender.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_stickhandling',
          skillTitles: ['Stickhandling'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 20, false) as Measurement]),
      // ── Hockey – Shooting & Accuracy
      _DrillSpec(
          title: 'Stationary Wrist Shot',
          description: 'Technique focus. Transfer weight from back foot to front foot, lock the elbow, snap the wrists, and follow through directly at the target. Track quality shots where mechanics felt correct.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_shot_accuracy',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Quality Shots', 1, null) as Measurement, MeasurementResult('amount', 'Shots Taken', 2, null) as Measurement, MeasurementTarget('amount', 'Target Quality', 3, 16, false) as Measurement]),
      _DrillSpec(
          title: 'Target Practice (Four Corners)',
          description: 'Place tape targets or small boxes in the four corners of the net. Call a corner before each shot and aim for it. Track hits on your called target — improves precision over power.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_shot_accuracy',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Targets Hit', 1, null) as Measurement, MeasurementResult('amount', 'Shots Taken', 2, null) as Measurement, MeasurementTarget('amount', 'Target Hits', 3, 15, false) as Measurement]),
      _DrillSpec(
          title: 'One-Touch Quick Release',
          description: 'Using a rebounder or passing partner, receive the puck and shoot immediately — minimize the time between receiving and releasing. Focus on reading the bounce and shooting in one fluid motion.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_shot_accuracy',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Goals / On Target', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target On Target', 3, 14, false) as Measurement]),
      _DrillSpec(
          title: 'Backhand Shots',
          description: 'Dedicated backhand shooting practice. Pull the puck in tight to your body, cup the blade underneath, and use a snap-release motion. Track shots on net out of total attempts.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_shot_accuracy',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'On Net', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target On Net', 3, 12, false) as Measurement]),
      // ── Hockey – Agility, Quickness & Conditioning
      _DrillSpec(
          title: 'Forward-Back Line Hops',
          description: 'Stand over a line and move your feet back and forth across it as quickly as possible with small, light steps. Improves foot speed and quickness off the mark. Track total reps in the set time.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_skating_time',
          skillTitles: ['Skating'],
          measurements: [MeasurementResult('duration', 'Work Time', 1, null) as Measurement, MeasurementResult('rpe', 'RPE (1–10)', 2, null) as Measurement, MeasurementTarget('duration', 'Target Duration', 3, 30, false) as Measurement, MeasurementTarget('rpe', 'Target RPE', 4, 7, false) as Measurement]),
      _DrillSpec(
          title: 'Lateral Hop and Stick',
          description: 'Start on one leg, hop sideways to simulate a skating push-off, and land on the opposite leg. Hold the landing for 3 seconds before the next rep. Builds single-leg stability and landing control.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_skating_time',
          skillTitles: ['Skating'],
          measurements: [MeasurementResult('duration', 'Work Time', 1, null) as Measurement, MeasurementResult('rpe', 'RPE (1–10)', 2, null) as Measurement, MeasurementTarget('duration', 'Target Duration', 3, 60, false) as Measurement, MeasurementTarget('rpe', 'Target RPE', 4, 7, false) as Measurement]),
      _DrillSpec(
          title: 'Jump Rope',
          description: 'Simple but essential. Jump rope at a steady pace to build timing, balance, coordination, and aerobic endurance. Alternate between two-foot and single-leg jumps each session.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_skating_time',
          skillTitles: ['Skating'],
          measurements: [MeasurementResult('duration', 'Duration', 1, null) as Measurement, MeasurementResult('rpe', 'RPE (1–10)', 2, null) as Measurement, MeasurementTarget('duration', 'Target Duration', 3, 300, false) as Measurement, MeasurementTarget('rpe', 'Target RPE', 4, 6, false) as Measurement]),
      _DrillSpec(
          title: 'Suicides 3-6-9',
          description: 'Set cones at 3, 6, and 9 yards. Sprint to the first cone and stop, backpedal to start, sprint to the second, backpedal, then sprint to the third. Trains explosive stop-and-start acceleration.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_skating_time',
          skillTitles: ['Skating'],
          measurements: [MeasurementResult('duration', 'Completion Time', 1, null) as Measurement, MeasurementResult('rpe', 'RPE (1–10)', 2, null) as Measurement, MeasurementTarget('duration', 'Target Time', 3, 20, true) as Measurement, MeasurementTarget('rpe', 'Target RPE', 4, 9, false) as Measurement]),
      // ── Basketball – Ball Handling
      _DrillSpec(
          title: 'Ball Slaps & Fingertip Dribble',
          description: 'Start by slapping the ball hard between both palms 20 times to wake up the hands. Then pound-dribble as low and fast as possible using only your fingertips — never your palm. Alternate hands every 10 reps. Builds grip strength and "feel" for the ball.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_dribbling',
          skillTitles: ['Dribbling'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 100, false) as Measurement]),
      _DrillSpec(
          title: 'Two-Ball Dribbling',
          description: 'Dribble two basketballs at the same time — first both hitting the floor together (simultaneous), then alternating one up while the other is down. Stay low, eyes up. Repeat both patterns for 30 seconds each. Rapidly builds off-hand strength and coordination.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_dribbling',
          skillTitles: ['Dribbling'],
          measurements: [MeasurementResult('duration', 'Time', 1, null) as Measurement, MeasurementTarget('duration', 'Target Duration', 2, 120, false) as Measurement]),
      // ── Basketball – Shooting
      _DrillSpec(
          title: 'Form Shooting (Close Range)',
          description: 'Stand 2–3 feet directly in front of the rim. Shoot with your shooting hand only — no guide hand. Focus on: elbow under the ball, high arc (peak above the rim), and index finger as the last point of contact. Track makes out of 25. Build muscle memory before adding distance.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_shooting',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Makes', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Makes', 3, 22, false) as Measurement]),
      _DrillSpec(
          title: 'Mikan Drill',
          description: 'Stand at the block, lay the ball off the backboard, catch it before it hits the floor, step to the opposite block, and repeat. Alternate left and right continuously without stopping. Develops touch around the rim, footwork, and left/right finishing.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_shooting',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Makes', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Makes', 3, 18, false) as Measurement]),
      // ── Basketball – Conditioning & Defense
      _DrillSpec(
          title: 'Defensive Slide Drill',
          description: 'Place two cones or marks 8–10 feet apart. Drop into a low defensive stance — hips back, weight on balls of feet, arms out. Slide laterally to the right cone, touch it, slide back. Never let your feet cross. Track complete round trips in 30 seconds.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_conditioning',
          skillTitles: [
            'Dribbling'
          ],
          measurements: [
            MeasurementResult('amount', 'Round Trips', 1, null) as Measurement,
            MeasurementResult('duration', 'Time', 2, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('amount', 'Target Trips', 4, 12, false) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 5, 8, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Free Throw Ritual',
          description: 'Shoot exactly 50 free throws using the same pre-shot routine every single time — same number of dribbles, same breath, same focus point. Track your best consecutive make streak. Consistency of routine is the goal, not just percentage.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_free_throw',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Makes', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Makes', 3, 40, false) as Measurement]),
      // ── Baseball – Hitting
      _DrillSpec(
          title: 'Tee Work',
          description: 'The most valuable solo hitting drill. Set the tee at three heights (low/middle/high) and two positions across the plate (inside/outside). Hit 10 balls at each of the 6 combinations for 60 total. Focus on keeping your weight back and driving through contact.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_batting',
          skillTitles: ['Hitting'],
          measurements: [MeasurementResult('amount', 'Solid Hits', 1, null) as Measurement, MeasurementResult('amount', 'Swings', 2, null) as Measurement, MeasurementTarget('amount', 'Target Solid', 3, 48, false) as Measurement]),
      _DrillSpec(
          title: 'Mirror Dry Swings',
          description: 'No ball needed. Stand in your batting stance in front of a full-length mirror or reflective surface. Take slow-motion swings, pausing at 3 checkpoints: load, hip clear, and contact. Check hip rotation, shoulder level, and head position. 20 slow swings per session.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_batting',
          skillTitles: ['Hitting'],
          measurements: [MeasurementResult('amount', 'Quality Reps', 1, null) as Measurement, MeasurementResult('amount', 'Total Reps', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 20, false) as Measurement]),
      // ── Baseball – Fielding & Throwing
      _DrillSpec(
          title: 'Wall Ball Fielding',
          description: 'Throw a tennis ball or rubber baseball against a concrete wall, brick steps, or sidewalk curb at different angles and speeds. Varying the angle creates random hops that mimic real ground balls. Field every hop with two hands, staying low. Builds quick hands and reaction time.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_fielding',
          skillTitles: ['Ground Balls'],
          measurements: [MeasurementResult('amount', 'Clean Fields', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 18, false) as Measurement]),
      _DrillSpec(
          title: 'Towel Pitching Drill',
          description: 'Hold a small towel in your pitching hand instead of a ball. Go through your full delivery on flat ground. At the release point the towel should snap toward a target (a glove hung on a fence, a strike zone drawn on a wall). Great for arm path, hip rotation, and extension — no stress on the arm.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_pitching',
          skillTitles: [
            'Pitching'
          ],
          measurements: [
            MeasurementResult('amount', 'Quality Reps', 1, null) as Measurement,
            MeasurementResult('amount', 'Total Reps', 2, null) as Measurement,
            MeasurementResult('rpe', 'Arm RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('amount', 'Target Reps', 4, 30, false) as Measurement,
            MeasurementTarget('rpe', 'Target Arm RPE', 5, 5, false) as Measurement
          ]),
      // ── Golf – Putting (at home on carpet)
      _DrillSpec(
          title: 'Gate Putting',
          description: 'On carpet or a putting mat, place two tees just wider than the putter head a few inches in front of the ball. You must roll the ball through the gate without touching either tee. Practice from 3, 6, and 10 feet. Trains a square face at impact — the single biggest factor in putting accuracy.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_putting',
          skillTitles: ['Putt'],
          measurements: [MeasurementResult('amount', 'Makes', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Makes', 3, 24, false) as Measurement]),
      _DrillSpec(
          title: 'Clock Putting',
          description: 'Set 8 balls around a cup in a clock pattern, all exactly 3 feet away. Try to make all 8 in a row. If you miss, start over from scratch. The non-negotiable restart creates pressure and builds consistency. Progress to a 4-foot clock once you can reliably complete the 3-foot round.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_putting',
          skillTitles: ['Putt'],
          measurements: [MeasurementResult('amount', 'Consecutive Makes', 1, null) as Measurement, MeasurementTarget('amount', 'Target Streak', 2, 8, false) as Measurement]),
      // ── Golf – Swing (at home, no ball needed)
      _DrillSpec(
          title: 'Mirror Swing Checkpoints',
          description: 'Stand sideways to a mirror in your setup position. Make slow-motion swings and pause at four positions: address, halfway back (club parallel), top of backswing, and impact position. Check: spine angle, hip turn, club plane, and wrist position. No ball — pure mechanics work.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_iron_play',
          skillTitles: ['Approach'],
          measurements: [MeasurementResult('amount', 'Quality Reps', 1, null) as Measurement, MeasurementResult('amount', 'Total Reps', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 20, false) as Measurement]),
      _DrillSpec(
          title: 'Towel Under-Arms Drill',
          description: 'Tuck a small rolled towel under both armpits and make half-speed half swings. If the towel drops at any point, your arms disconnected from your body rotation. Keeps the swing connected and prevents "chicken wing." 20 reps each session — great warm-up before any range session.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_short_game',
          skillTitles: ['Chip'],
          measurements: [MeasurementResult('amount', 'Clean Reps', 1, null) as Measurement, MeasurementResult('amount', 'Total Reps', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 18, false) as Measurement]),
      // ── Soccer – Touch & Juggling
      _DrillSpec(
          title: 'Toe Taps',
          description: 'Place the ball on the ground. Rapidly alternate tapping the top of the ball with the sole of each foot — right, left, right, left. Keep the ball stationary and your ankles relaxed. Start slow and increase speed. Builds a quick, soft first touch and coordination between feet.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_dribbling',
          skillTitles: ['Ball Control'],
          measurements: [MeasurementResult('amount', 'Taps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Taps', 3, 100, false) as Measurement]),
      _DrillSpec(
          title: 'Juggling Challenge',
          description: 'Keep the ball in the air using alternating feet. Start close to the ground, small controlled taps. Track your single best consecutive streak per session. Rotate surfaces each session: feet only, then thighs only, then mixed. Builds touch, concentration, and balance.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_juggling',
          skillTitles: ['Ball Control'],
          measurements: [MeasurementResult('amount', 'Best Streak', 1, null) as Measurement, MeasurementTarget('amount', 'Target Streak', 2, 25, false) as Measurement]),
      // ── Soccer – Passing & Dribbling
      _DrillSpec(
          title: 'Wall First Touch',
          description: 'Stand 4–6 feet from a solid wall. Pass the ball against it firmly and control the return with a different surface each rep: inside of left foot, inside of right, outside of left, outside of right, then sole, instep. The goal is to kill the ball dead in one touch. Do 40 reps.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_passing',
          skillTitles: ['Passing'],
          measurements: [MeasurementResult('amount', 'Clean First Touches', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 34, false) as Measurement]),
      _DrillSpec(
          title: 'L-Turn & Cruyff Turn Combo',
          description: 'Set a cone 10 yards ahead. Dribble at pace toward it. At 1 yard out, alternate which turn you use each rep: L-Turn (sole stop → push 90°) or Cruyff (fake cross → drag behind your standing leg). Builds two essential change-of-direction tools. Track reps where you maintained ball control through the turn.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_dribbling',
          skillTitles: ['Dribbling'],
          measurements: [MeasurementResult('amount', 'Clean Turns', 1, null) as Measurement, MeasurementResult('amount', 'Total Turns', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 16, false) as Measurement]),
      // ── Weight Training – Lower Body
      _DrillSpec(
          title: 'Bulgarian Split Squat',
          description: 'Rest your rear foot on a chair, couch, or bench behind you. Lower your front knee until your rear knee nearly touches the floor, then drive back up through your front heel. Arguably the best single-leg movement for at-home training — builds quad strength, hip flexor flexibility, and balance with zero equipment.',
          activityTitle: 'Weight Training',
          drillTypeId: 'weight_bodyweight',
          skillTitles: ['Legs'],
          measurements: [MeasurementResult('amount', 'Sets', 1, null) as Measurement, MeasurementResult('amount', 'Reps', 2, null) as Measurement, MeasurementResult('rir', 'RIR', 3, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 4, 10, false) as Measurement, MeasurementTarget('rir', 'Target RIR', 5, 2, false) as Measurement]),
      _DrillSpec(
          title: 'Romanian Deadlift (Dumbbell)',
          description: 'Hold a dumbbell in each hand (or a loaded backpack). Stand tall, hinge at the hips pushing them back while keeping a flat back, lower the weights along your shins until you feel a deep hamstring stretch, then drive hips forward to stand. Trains the entire posterior chain at home with minimal equipment.',
          activityTitle: 'Weight Training',
          drillTypeId: 'weight_compound',
          skillTitles: [
            'Back'
          ],
          measurements: [
            MeasurementResult('amount', 'Sets', 1, null) as Measurement,
            MeasurementResult('amount', 'Reps', 2, null) as Measurement,
            MeasurementResult('amount', 'Weight (kg)', 3, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 4, null) as Measurement,
            MeasurementResult('rir', 'RIR', 5, null) as Measurement,
            MeasurementTarget('amount', 'Target Reps', 6, 10, false) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 7, 7, false) as Measurement,
            MeasurementTarget('rir', 'Target RIR', 8, 3, false) as Measurement
          ]),
      // ── Weight Training – Upper Body
      _DrillSpec(
          title: 'Push-up Progression',
          description: 'Work through a push-up progression in a single set: standard → close-grip → wide-grip → decline (feet elevated). Each variation until failure. Rest 60 seconds between variations. Builds chest, tricep, and shoulder strength with zero equipment — the single most effective at-home upper body drill.',
          activityTitle: 'Weight Training',
          drillTypeId: 'weight_bodyweight',
          skillTitles: [
            'Chest'
          ],
          measurements: [
            MeasurementResult('amount', 'Total Reps', 1, null) as Measurement,
            MeasurementResult('amount', 'Sets', 2, null) as Measurement,
            MeasurementResult('rir', 'RIR (last set)', 3, null) as Measurement,
            MeasurementTarget('amount', 'Target Total', 4, 50, false) as Measurement,
            MeasurementTarget('rir', 'Target RIR', 5, 1, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Pull-ups',
          description: 'Grip a pull-up bar with hands shoulder-width apart, palms facing away. From a dead hang, pull your chest to the bar — elbows drive down and back. Lower slowly (3-count). If no pull-up bar: use a table edge for inverted rows (feet on floor, body at 45°). Both train the same pulling pattern.',
          activityTitle: 'Weight Training',
          drillTypeId: 'weight_bodyweight',
          skillTitles: ['Back'],
          measurements: [MeasurementResult('amount', 'Sets', 1, null) as Measurement, MeasurementResult('amount', 'Reps', 2, null) as Measurement, MeasurementResult('rir', 'RIR', 3, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 4, 10, false) as Measurement, MeasurementTarget('rir', 'Target RIR', 5, 2, false) as Measurement]),
      // ── Basketball – Additional Drills ───────────────────────────────────────
      _DrillSpec(
          title: 'Around the World',
          description: 'Shoot from 7 spots around the arc — right corner, right wing, right elbow, top of key, left elbow, left wing, left corner. Make at least 2 from each spot before advancing. Reveals weak zones and builds confidence from every angle. Complete all 7 spots in both directions each session.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_shooting',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Spots Completed', 1, null) as Measurement, MeasurementResult('amount', 'Total Shots', 2, null) as Measurement, MeasurementTarget('amount', 'Target Spots', 3, 7, false) as Measurement]),
      _DrillSpec(
          title: 'Inside-Out Dribble',
          description: 'Dribble toward a cone at half speed. At the cone, fake a crossover by rolling the ball from fingertips to the outside of your dribble hand — hesitate — then push back outside and explode past. The inside-out move creates separation without a full crossover. 20 reps each side.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_dribbling',
          skillTitles: ['Dribbling'],
          measurements: [MeasurementResult('amount', 'Reps (Right)', 1, null) as Measurement, MeasurementResult('amount', 'Reps (Left)', 2, null) as Measurement, MeasurementTarget('amount', 'Target Each Side', 3, 20, false) as Measurement]),
      _DrillSpec(
          title: 'Lane Agility Cone Drill',
          description: 'Set 4 cones at the corners of the paint. Sprint → defensive slide → sprint → defensive slide around all 4 corners. First run ball-free for pure footwork, then repeat while dribbling. A standard combine test that trains the two movement modes used most in games. Track your best dribbling time of 5 attempts.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_conditioning',
          skillTitles: [
            'Defense',
            'Conditioning'
          ],
          measurements: [
            MeasurementResult('duration', 'Best Time', 1, null) as Measurement,
            MeasurementResult('amount', 'Rounds', 2, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('duration', 'Target Time', 4, 11, true) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 5, 8, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Spider Dribble',
          description: 'Kneel in a wide stance. Dribble rapidly in this pattern: right front → left front → right back → left back (all with alternating hands). One full cycle = 1 rep. Builds extreme hand speed, ball feel, and ambidextrous coordination — especially valuable for guards. Work up to 30+ clean reps in 30 seconds.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_dribbling',
          skillTitles: ['Dribbling'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 30, false) as Measurement]),
      // ── Baseball – Additional Drills ─────────────────────────────────────────
      _DrillSpec(
          title: 'Side Toss (Hip Turn)',
          description: 'Have a partner kneel 2–3 feet to your side at hip level and toss underhand as you swing. Solo version: kneel on your back knee and toss the ball upward from your side yourself. Side toss isolates hip-to-shoulder rotation — hips must fire before hands. 30 swings per session focused entirely on sequencing.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_batting',
          skillTitles: ['Hitting'],
          measurements: [MeasurementResult('amount', 'Solid Contacts', 1, null) as Measurement, MeasurementResult('amount', 'Swings', 2, null) as Measurement, MeasurementTarget('amount', 'Target Solid', 3, 24, false) as Measurement]),
      _DrillSpec(
          title: 'One-Knee Drill',
          description: 'Drop to your back knee on a tee. Without hips to compensate, every arm-bar, casting, or wrist roll flaw becomes immediately visible. Hit 20 swings in this position then compare your hand path to your standing swing. Best used side-by-side with tee work to isolate upper body mechanics.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_batting',
          skillTitles: ['Hitting'],
          measurements: [MeasurementResult('amount', 'Quality Reps', 1, null) as Measurement, MeasurementResult('amount', 'Total Reps', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 20, false) as Measurement]),
      _DrillSpec(
          title: 'Long Toss Progression',
          description: 'Start 30 feet apart with 5 on-a-line throws. Back up 10 feet per set until accuracy or arm fatigue forces a stop. Then work back in with reduced effort. Builds arm strength progressively, teaches full extension, and highlights postural issues (collapsing = reduced distance). Log your max clean distance each session.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_throwing',
          skillTitles: ['Throwing'],
          measurements: [MeasurementResult('amount', 'Max Distance (ft)', 1, null) as Measurement, MeasurementResult('amount', 'Total Throws', 2, null) as Measurement, MeasurementTarget('amount', 'Target Distance (ft)', 3, 120, false) as Measurement]),
      _DrillSpec(
          title: 'Triangle Fielding Footwork',
          description: 'Place 3 cones in a triangle about 3 feet apart. In a fielding stance, use your feet — not body weight — to touch each cone in sequence: crossover step → lateral shuffle → drop step. 10 clockwise + 10 counter-clockwise per set. Pure footwork with no ball so you can focus entirely on the foot patterns that matter under ground balls.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_fielding',
          skillTitles: ['Ground Balls'],
          measurements: [MeasurementResult('amount', 'Clean Reps', 1, null) as Measurement, MeasurementResult('amount', 'Total Reps', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 18, false) as Measurement]),
      _DrillSpec(
          title: 'Wrist Roller & Bat Speed',
          description: 'Tie a 1–2 lb weight to a 12" broomstick. Hold out in front and roll the weight up then down by rotating wrists. 3 sets. Then take 20 dry swings with a heavy bat followed immediately by 20 with a light bat. The contrast (heavy → light) causes neuromuscular overshoot — the light bat feels faster, training the fast-twitch pattern.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_batting',
          skillTitles: ['Hitting'],
          measurements: [MeasurementResult('amount', 'Sets', 1, null) as Measurement, MeasurementResult('amount', 'Bat Speed Swings', 2, null) as Measurement, MeasurementTarget('amount', 'Target Swings', 3, 20, false) as Measurement]),
      _DrillSpec(
          title: 'Wall Target Throws',
          description: 'Tape a 12"×18" strike zone on a wall or fence at chest height. Throw from 45–60 feet using full mechanics. Immediate feedback on accuracy. Track strikes out of 20 throws. Rotate between standard arm action and 3/4 arm slot each session. Also works as a fielder\'s accuracy drill for quick-release throwing.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_throwing',
          skillTitles: ['Throwing'],
          measurements: [MeasurementResult('amount', 'Strikes', 1, null) as Measurement, MeasurementResult('amount', 'Throws', 2, null) as Measurement, MeasurementTarget('amount', 'Target Strikes', 3, 14, false) as Measurement]),
      // ── Golf – Additional Drills ─────────────────────────────────────────────
      _DrillSpec(
          title: 'Consecutive Putt Challenge',
          description: 'Place 5 balls in a line at 3 feet from the cup. You must make all 5 in a row — any miss restarts from ball 1. The enforced restart creates real pressure and trains consistency over single-putt volume. Progress: once you make 5 consecutive, move all balls back to 4 feet.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_putting',
          skillTitles: ['Putt'],
          measurements: [MeasurementResult('amount', 'Best Consecutive', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Streak', 3, 5, false) as Measurement]),
      _DrillSpec(
          title: 'Lag Putting Ladder',
          description: 'Set targets at 10, 20, 30, and 40 feet. Hit 3 putts to each distance trying to stop within a 3-foot circle. Track how many of 12 finish inside the circle. Lag putting eliminates 3-putts far more effectively than short-putt practice — most amateurs lose more shots to distance control than to direction.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_putting',
          skillTitles: ['Putt'],
          measurements: [MeasurementResult('amount', 'In Zone', 1, null) as Measurement, MeasurementResult('amount', 'Total Putts', 2, null) as Measurement, MeasurementTarget('amount', 'Target In Zone', 3, 9, false) as Measurement]),
      _DrillSpec(
          title: 'Short Iron Bump-and-Run',
          description: 'Use a 7- or 8-iron instead of a wedge for chips. Narrow stance, ball near right heel, use a putting-length stroke. Ball lands 1–2 feet onto the green and rolls out. Track how many of 10 finish within 3 feet. Eliminates the fear of thinning wedge chips and teaches using the ground as a tool.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_short_game',
          skillTitles: ['Chip'],
          measurements: [MeasurementResult('amount', 'Within 3 Feet', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Within 3ft', 3, 7, false) as Measurement]),
      _DrillSpec(
          title: 'Impact Bag Drill',
          description: 'Swing against a heavy bag, folded pillow, or commercial impact bag placed at ball position. Make a full swing and hold the impact position for 3 seconds — you will immediately feel whether hands are ahead (correct) or flipping (incorrect). The tactile resistance makes impact position tangible in a way mirrors cannot. 20 held reps.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_iron_play',
          skillTitles: ['Iron Play'],
          measurements: [MeasurementResult('amount', 'Clean Impacts', 1, null) as Measurement, MeasurementResult('amount', 'Total Reps', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 16, false) as Measurement]),
      _DrillSpec(
          title: 'Headcover Avoid (Draw Path)',
          description: 'Place a headcover 6–8 inches outside the ball on the far side. Swing on an inside-out path — if the club strikes it, your path was over-the-top. Trains the in-to-out swing path that produces a controlled draw and eliminates the slice. 20 slow-motion practice swings before 10 at full speed with a 7-iron.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_driving',
          skillTitles: ['Drive'],
          measurements: [MeasurementResult('amount', 'Clean Swings', 1, null) as Measurement, MeasurementResult('amount', 'Total Swings', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 16, false) as Measurement]),
      _DrillSpec(
          title: 'Pause at the Top',
          description: 'Make a full backswing then pause completely for a 2-second count before starting down. The pause forces a complete shoulder turn, exposes incomplete rotation, and stops the most common amateur fault: rushing from the top. Alternate 5 paused swings with 5 normal to feel the contrast. 20 total swings.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_driving',
          skillTitles: ['Drive', 'Iron Play'],
          measurements: [MeasurementResult('amount', 'Quality Reps', 1, null) as Measurement, MeasurementResult('amount', 'Total Reps', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 20, false) as Measurement]),
      // ── Soccer – Additional Drills ───────────────────────────────────────────
      _DrillSpec(
          title: 'Inside-Outside Touch Roll',
          description: 'Trap the ball under your right foot. Roll it left with the inside, then push it back right with the outside — tight 8-inch zone, ball always close. Switch foot every 30 seconds. Builds the neurological feel for three foot surfaces in rapid succession, the foundation of tight dribbling under pressure.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_dribbling',
          skillTitles: ['Ball Control'],
          measurements: [MeasurementResult('amount', 'Touches', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Touches', 3, 80, false) as Measurement]),
      _DrillSpec(
          title: 'T-Cone Sprint & Dribble',
          description: 'Set 4 cones in a T: start, 10 yards ahead, 5 yards left, 5 yards right. Sprint → shuffle left → shuffle right → backpedal to start. First run ball-free, then repeat dribbling. Track your best dribbling time of 5 attempts. A standard fitness test that also trains the change-of-direction + ball control combo.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_dribbling',
          skillTitles: ['Dribbling', 'Fitness'],
          measurements: [MeasurementResult('duration', 'Best Time (dribbling)', 1, null) as Measurement, MeasurementResult('amount', 'Rounds', 2, null) as Measurement, MeasurementTarget('duration', 'Target Time', 3, 12, true) as Measurement]),
      _DrillSpec(
          title: 'Target Wall Shooting',
          description: 'Mark 4 targets (top-left, top-right, bottom-left, bottom-right) on a wall in a 6×4 foot rectangle. Call a target before each shot. Shoot from 10 yards with both feet equally. 20 shots per side. Develops precision, both-foot confidence, and the ability to pick a spot under pressure.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_shooting',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Targets Hit', 1, null) as Measurement, MeasurementResult('amount', 'Shots on Target', 2, null) as Measurement, MeasurementResult('amount', 'Attempts', 3, null) as Measurement, MeasurementTarget('amount', 'Target Hits', 4, 28, false) as Measurement]),
      _DrillSpec(
          title: 'Box Touch Patterns',
          description: 'Set 4 cones in a 5×5 yard square. Dribble to each cone in sequence using a different move at each: outside cut → inside cut → step-over → drag-back. Rotate which move you use at each cone each lap. Keeps the brain engaged and builds the ability to chain moves together rather than executing them in isolation.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_dribbling',
          skillTitles: ['Dribbling', 'Ball Control'],
          measurements: [MeasurementResult('amount', 'Laps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Laps', 3, 10, false) as Measurement]),
      _DrillSpec(
          title: 'Coever Step-Over',
          description: 'The foundation of European youth skill development. Step the right foot over the ball right-to-left, then push it away with the outside of the right foot. Repeat left-to-right with the left foot. Build speed over 30 seconds then switch. Named after Dutch coach Wiel Coerver — these patterns form the base of all modern 1v1 skill work.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_dribbling',
          skillTitles: ['Dribbling'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 60, false) as Measurement]),
      _DrillSpec(
          title: 'Long Passing Accuracy',
          description: 'Mark a 2×2 meter target square on a wall or fence at 15–20 meters. Use a proper driven low pass: planted foot beside the ball, locked ankle, low follow-through. Track hits per foot. Gradually move back as accuracy improves. Long passing is the most undervalued technical skill — every field position needs it.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_passing',
          skillTitles: ['Passing'],
          measurements: [MeasurementResult('amount', 'On Target', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Hits', 3, 12, false) as Measurement]),
      // ── Weight Training – Additional Drills ──────────────────────────────────
      _DrillSpec(
          title: 'Glute Bridge',
          description:
              'Lie on your back, feet flat, knees bent. Drive heels into floor and squeeze glutes to raise hips until body forms a straight line from shoulders to knees. Hold the top for 2 seconds. Lower under control. Progress: single-leg, then elevate shoulders on a bench for full hip thrust range. The most accessible posterior-chain builder requiring zero equipment.',
          activityTitle: 'Weight Training',
          drillTypeId: 'weight_bodyweight',
          skillTitles: ['Legs', 'Full Body'],
          measurements: [MeasurementResult('amount', 'Sets', 1, null) as Measurement, MeasurementResult('amount', 'Reps', 2, null) as Measurement, MeasurementResult('rir', 'RIR', 3, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 4, 15, false) as Measurement, MeasurementTarget('rir', 'Target RIR', 5, 2, false) as Measurement]),
      _DrillSpec(
          title: 'Pike Push-up',
          description: 'Start in a downward-dog position — hips high, body forming an inverted V. Bend elbows and lower the top of your head toward the floor between your hands, then press back up. Directly loads the anterior deltoid and triceps with zero equipment. Progress by elevating feet on a chair toward a handstand push-up.',
          activityTitle: 'Weight Training',
          drillTypeId: 'weight_bodyweight',
          skillTitles: ['Shoulders'],
          measurements: [MeasurementResult('amount', 'Sets', 1, null) as Measurement, MeasurementResult('amount', 'Reps', 2, null) as Measurement, MeasurementResult('rir', 'RIR', 3, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 4, 12, false) as Measurement, MeasurementTarget('rir', 'Target RIR', 5, 2, false) as Measurement]),
      _DrillSpec(
          title: 'Chair Tricep Dip',
          description: 'Grip the seat edge of a sturdy chair, body suspended with legs straight (or bent for easier). Lower until elbows reach 90°, then press back up. Triceps power the lockout phase of every push and press. Dips isolate them purely. Track clean reps — full range, no shoulder shrug.',
          activityTitle: 'Weight Training',
          drillTypeId: 'weight_bodyweight',
          skillTitles: ['Arms', 'Chest'],
          measurements: [MeasurementResult('amount', 'Sets', 1, null) as Measurement, MeasurementResult('amount', 'Reps', 2, null) as Measurement, MeasurementResult('rir', 'RIR', 3, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 4, 12, false) as Measurement, MeasurementTarget('rir', 'Target RIR', 5, 2, false) as Measurement]),
      _DrillSpec(
          title: 'Dumbbell Bicep Curl',
          description: 'Stand tall, dumbbells at sides. Without moving the upper arm, curl the weight while supinating your wrist (palm turns up). Squeeze at the top for 1 second, lower in 3 counts. The slow eccentric causes more hypertrophy than the curl itself. Alternate arms or both together.',
          activityTitle: 'Weight Training',
          drillTypeId: 'weight_isolation',
          skillTitles: [
            'Arms'
          ],
          measurements: [
            MeasurementResult('amount', 'Sets', 1, null) as Measurement,
            MeasurementResult('amount', 'Reps', 2, null) as Measurement,
            MeasurementResult('amount', 'Weight (kg)', 3, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 4, null) as Measurement,
            MeasurementResult('rir', 'RIR', 5, null) as Measurement,
            MeasurementTarget('amount', 'Target Reps', 6, 12, false) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 7, 6, false) as Measurement,
            MeasurementTarget('rir', 'Target RIR', 8, 2, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Dumbbell Overhead Press',
          description: 'Sit on a chair, dumbbells at shoulder height, elbows at 90°. Press straight up until arms are nearly extended, then lower slowly. Seated eliminates lower-back compensation. Trains the entire shoulder complex plus stabilizing rotator cuff. Log weight per hand to track progress independently per side.',
          activityTitle: 'Weight Training',
          drillTypeId: 'weight_compound',
          skillTitles: [
            'Shoulders',
            'Full Body'
          ],
          measurements: [
            MeasurementResult('amount', 'Sets', 1, null) as Measurement,
            MeasurementResult('amount', 'Reps', 2, null) as Measurement,
            MeasurementResult('amount', 'Weight (kg)', 3, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 4, null) as Measurement,
            MeasurementResult('rir', 'RIR', 5, null) as Measurement,
            MeasurementTarget('amount', 'Target Reps', 6, 10, false) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 7, 7, false) as Measurement,
            MeasurementTarget('rir', 'Target RIR', 8, 2, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Hollow Body Hold',
          description:
              'Lie on your back, arms extended overhead. Lift shoulders, head, and legs simultaneously until only your lower back contacts the floor — a shallow "banana" shape. Press lower back firmly into the floor throughout. The hollow body is the foundational gymnastics core pattern and directly transfers to pressing, pulling, and overhead strength.',
          activityTitle: 'Weight Training',
          drillTypeId: 'weight_bodyweight',
          skillTitles: ['Core', 'Full Body'],
          measurements: [MeasurementResult('amount', 'Sets', 1, null) as Measurement, MeasurementResult('duration', 'Hold Time', 2, null) as Measurement, MeasurementTarget('duration', 'Target Hold', 3, 30, false) as Measurement]),
      // ── Tennis ──────────────────────────────────────────────────────────────────
      _DrillSpec(
          title: 'Serve Consistency (Flat)',
          description:
              'Stand at the baseline and serve 20 balls to the deuce service box using a flat serve. Focus on ball toss consistency (same spot every time), trophy position pause, and full pronation through contact. Track first serves in. The serve is the one shot in tennis you control entirely — poor serve mechanics waste every training session around it.',
          activityTitle: 'Tennis',
          drillTypeId: 'tennis_serve',
          skillTitles: ['Serve'],
          measurements: [MeasurementResult('amount', 'First Serves In', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target In', 3, 16, false) as Measurement]),
      _DrillSpec(
          title: 'Kick Serve to T',
          description:
              'Hit 20 kick (topspin) serves targeting the T of the ad court. The kick serve requires a further ball toss to the left and behind the head, heavy upward brush at contact, and a strong leg drive. Track serves that land within 3 feet of the T. The kick serve is the most effective second serve in the game because it kicks high and away from a right-handed receiver.',
          activityTitle: 'Tennis',
          drillTypeId: 'tennis_serve',
          skillTitles: ['Serve'],
          measurements: [MeasurementResult('amount', 'On Target', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target On T', 3, 14, false) as Measurement]),
      _DrillSpec(
          title: 'Cross-Court Forehand Feeds',
          description:
              'Feed yourself from a ball hopper or have a partner feed to your forehand side. Hit 30 cross-court forehands with an emphasis on: unit turn (shoulders turn before arms move), contact in front of the hip, and brushing up to create topspin. Track hits that land in the opposite service box. Cross-court is the highest percentage groundstroke — practice it the most.',
          activityTitle: 'Tennis',
          drillTypeId: 'tennis_groundstroke',
          skillTitles: ['Forehand'],
          measurements: [MeasurementResult('amount', 'In Zone', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target In Zone', 3, 24, false) as Measurement]),
      _DrillSpec(
          title: 'Two-Handed Backhand Targets',
          description:
              'Feed to your backhand wing and drive cross-court to targets placed at the baseline corners. Focus on: coil the shoulders on the takeback, front shoulder drops at contact point, both hands through the ball. Hit 30 and track zoned balls. The two-handed backhand is the most common weakness — consistent zoned reps fix that faster than anything else.',
          activityTitle: 'Tennis',
          drillTypeId: 'tennis_groundstroke',
          skillTitles: ['Backhand'],
          measurements: [MeasurementResult('amount', 'In Zone', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target In Zone', 3, 22, false) as Measurement]),
      _DrillSpec(
          title: 'Wall Forehand Rally',
          description:
              'Stand 6–8 feet from a wall and rally continuously forehand-only. The wall returns immediately — there is no time to reset a bad position. Aim for a best consecutive rally streak. Start slow (full swing, controlled), then speed up as consistency improves. 15 minutes of wall work trains reflexes faster than any partner drill because the ball comes back immediately.',
          activityTitle: 'Tennis',
          drillTypeId: 'tennis_groundstroke',
          skillTitles: ['Forehand'],
          measurements: [MeasurementResult('amount', 'Best Streak', 1, null) as Measurement, MeasurementResult('amount', 'Total Hits', 2, null) as Measurement, MeasurementTarget('amount', 'Target Streak', 3, 30, false) as Measurement]),
      _DrillSpec(
          title: 'Approach Volley Finish',
          description:
              'Start at the baseline. Hit an approach shot down the line (or simulate one), sprint to the net, and finish with a put-away volley or overhead. Focus on split step timing as the opponent contacts the ball, and low-to-high volley punch. Do 20 reps. Trains the most common point-ending pattern in serve-and-volley and aggressive baseline play.',
          activityTitle: 'Tennis',
          drillTypeId: 'tennis_volley',
          skillTitles: ['Volley'],
          measurements: [MeasurementResult('amount', 'Clean Finishes', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 14, false) as Measurement]),
      _DrillSpec(
          title: 'Spider Drill (Tennis)',
          description: 'Place 5 balls at: both doubles alleys, both service T intersections, and the center baseline. Sprint from the center mark to collect each ball and carry it back before sprinting to the next. Time all 5. A standard speed-endurance test used at ATP combine testing — also the best all-around court coverage conditioning drill.',
          activityTitle: 'Tennis',
          drillTypeId: 'tennis_footwork',
          skillTitles: [
            'Footwork'
          ],
          measurements: [
            MeasurementResult('duration', 'Completion Time', 1, null) as Measurement,
            MeasurementResult('amount', 'Rounds', 2, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('duration', 'Target Time', 4, 60, true) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 5, 8, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Lateral Shuffle Baseline',
          description:
              'Stand at the center mark. Shuffle to the doubles alley and back, then to the opposite alley — that is one rep. Keep hips low, weight forward, feet never crossing. 15 round trips per set. Develops the lateral speed and endurance needed to recover to the center after every groundstroke — the most important off-ball movement pattern in tennis.',
          activityTitle: 'Tennis',
          drillTypeId: 'tennis_footwork',
          skillTitles: [
            'Footwork'
          ],
          measurements: [
            MeasurementResult('amount', 'Round Trips', 1, null) as Measurement,
            MeasurementResult('duration', 'Time', 2, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('amount', 'Target Round Trips', 4, 15, false) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 5, 7, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Shadow Swing Mechanics',
          description: 'No ball, racket only. In front of a mirror, take 10 slow-motion forehands, 10 slow-motion backhands, and 10 slow-motion volleys. Freeze at contact on each — check grip pressure, contact point depth, and racket face angle. Then 10 each at full speed. Pure muscle-memory rehearsal of correct patterns before any live ball work.',
          activityTitle: 'Tennis',
          drillTypeId: 'tennis_groundstroke',
          skillTitles: ['Forehand', 'Backhand'],
          measurements: [MeasurementResult('amount', 'Quality Reps', 1, null) as Measurement, MeasurementResult('amount', 'Total Reps', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 30, false) as Measurement]),
      _DrillSpec(
          title: 'Drop-Feed Slice Backhand',
          description: 'Drop a ball and slice it low into the service box cross-court. Focus on: edge-first swing path, contact slightly out front, brushing under the ball. Hit 25. The slice backhand is the most underutilised shot in recreational tennis and is elite-level effective as a defensive reset, low approach shot, and wide-angle winner.',
          activityTitle: 'Tennis',
          drillTypeId: 'tennis_groundstroke',
          skillTitles: ['Backhand'],
          measurements: [MeasurementResult('amount', 'In Zone', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target In Zone', 3, 18, false) as Measurement]),
      // ── Running ─────────────────────────────────────────────────────────────────
      _DrillSpec(
          title: '400m Repeats',
          description: 'Run 400 meters at your 5K race pace or slightly faster, followed by a 2-minute walking rest. Repeat 4–6 times. The cornerstone of speed development for middle- and long-distance runners. Log your split time for each rep — the standard is that your last rep should be within 5 seconds of your first. If it is not, you started too fast.',
          activityTitle: 'Running',
          drillTypeId: 'running_interval',
          skillTitles: [
            'Intervals'
          ],
          measurements: [
            MeasurementResult('amount', 'Distance (m)', 1, 400) as Measurement,
            MeasurementResult('duration', 'Split Time', 2, null) as Measurement,
            MeasurementResult('amount', 'Reps', 3, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 4, null) as Measurement,
            MeasurementTarget('duration', 'Target Split', 5, null, true) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 6, 8, false) as Measurement
          ]),
      _DrillSpec(
          title: '30-Second Strides',
          description:
              'After an easy run, do 4–6 strides of 30 seconds at 90% max effort on a flat surface. Come to a complete stop, walk 60–90 seconds, then repeat. Strides are not sprints — the goal is smooth, relaxed fast running with perfect form, not maximum output. They train the neuromuscular system to fire at high turnover without accumulating fatigue. Every distance runner should finish every easy run with strides.',
          activityTitle: 'Running',
          drillTypeId: 'running_sprint',
          skillTitles: ['Sprints'],
          measurements: [MeasurementResult('amount', 'Distance (m)', 1, null) as Measurement, MeasurementResult('duration', 'Best Time', 2, null) as Measurement, MeasurementResult('amount', 'Reps', 3, null) as Measurement, MeasurementTarget('duration', 'Target Time', 4, null, true) as Measurement]),
      _DrillSpec(
          title: 'Tempo Run (20 min)',
          description:
              'Run at your "comfortably hard" pace — conversational but demanding. This is approximately 85–90% of max heart rate, or about 30 seconds per mile slower than your 5K race pace. For 20 continuous minutes. The tempo run is the single most evidence-backed training method for improving lactate threshold, which is the primary predictor of distance running performance.',
          activityTitle: 'Running',
          drillTypeId: 'running_tempo',
          skillTitles: [
            'Tempo'
          ],
          measurements: [
            MeasurementResult('amount', 'Distance (km)', 1, null) as Measurement,
            MeasurementResult('duration', 'Total Time', 2, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('duration', 'Target Time', 4, 1200, true) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 5, 8, false) as Measurement
          ]),
      _DrillSpec(
          title: 'A-Skip Drill',
          description:
              'Drive your knee up to hip height while skipping forward — opposite arm swings in sync. Keep the knee of your drive leg at 90°, landing on the ball of your foot directly under your hips. Do 20 meters × 4 reps. The A-skip reinforces high knee drive, proper arm swing, and foot strike mechanics — the three technical elements that directly determine running efficiency and injury risk.',
          activityTitle: 'Running',
          drillTypeId: 'running_drill',
          skillTitles: ['Sprints'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 4, false) as Measurement]),
      _DrillSpec(
          title: 'B-Skip (Leg Extension)',
          description:
              'Same as the A-skip but extend the drive leg fully forward at the peak of the knee drive, then paw the foot back under your hip before landing. This exaggerated movement trains the backward "paw" action of the fast-twitch hamstrings during the support phase of sprinting — the single biggest mechanical difference between fast and slow runners.',
          activityTitle: 'Running',
          drillTypeId: 'running_drill',
          skillTitles: ['Sprints'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 4, false) as Measurement]),
      _DrillSpec(
          title: 'Hill Repeats',
          description:
              'Find a hill with a 6–8% grade and about 100 meters of usable length. Sprint uphill at maximum effort, walk back down, rest 60 seconds. Repeat 6–10 times. Hill sprints are the safest form of speed training — the incline reduces impact force and forces proper dorsiflexion and forward lean. They build both speed and lactate threshold simultaneously.',
          activityTitle: 'Running',
          drillTypeId: 'running_sprint',
          skillTitles: ['Hills', 'Sprints'],
          measurements: [MeasurementResult('amount', 'Distance (m)', 1, 100) as Measurement, MeasurementResult('duration', 'Best Time', 2, null) as Measurement, MeasurementResult('amount', 'Reps', 3, null) as Measurement, MeasurementTarget('duration', 'Target Time', 4, null, true) as Measurement]),
      _DrillSpec(
          title: '800m Intervals (2×2)',
          description: 'Run 800 meters at 10K race effort, rest 3 minutes, repeat twice. The 2×2 structure (2 reps, 2 minutes per 400m pace) is a classic Jack Daniels-based aerobic interval workout. It pushes VO2max adaptation without the fatigue of longer intervals. Log your split time for both reps — they should be within 3 seconds of each other.',
          activityTitle: 'Running',
          drillTypeId: 'running_interval',
          skillTitles: [
            'Intervals'
          ],
          measurements: [
            MeasurementResult('amount', 'Distance (m)', 1, 800) as Measurement,
            MeasurementResult('duration', 'Split Time', 2, null) as Measurement,
            MeasurementResult('amount', 'Reps', 3, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 4, null) as Measurement,
            MeasurementTarget('duration', 'Target Split', 5, null, true) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 6, 8, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Easy Recovery Run',
          description:
              'Run at a fully conversational pace — you should be able to speak in full sentences. 20–40 minutes. RPE 4–5. Most runners run their easy days too fast. Easy runs should be run at 60–70% of max heart rate. Their purpose is blood flow, aerobic base, and glycogen replenishment — not fitness stimulus. Running them too hard sabotages the quality of subsequent hard sessions.',
          activityTitle: 'Running',
          drillTypeId: 'running_tempo',
          skillTitles: [
            'Recovery'
          ],
          measurements: [
            MeasurementResult('amount', 'Distance (km)', 1, null) as Measurement,
            MeasurementResult('duration', 'Total Time', 2, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 4, 5, false) as Measurement,
            MeasurementTarget('duration', 'Target Duration', 5, 1800, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Butt Kicks',
          description:
              'Jog in place or forward while kicking your heels up toward your glutes with each stride. Keep your thighs vertical. 20 meters × 4 reps. Butt kicks train the hamstring recovery phase of the running cycle — the speed at which your heel recovers toward your glutes after push-off determines stride frequency, which (along with stride length) determines pace.',
          activityTitle: 'Running',
          drillTypeId: 'running_drill',
          skillTitles: ['Sprints'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 4, false) as Measurement]),
      _DrillSpec(
          title: '5K Time Trial',
          description:
              'Run 5 kilometers as fast as possible on a flat, measured course. The 5K time trial is the standard benchmark for recreational and competitive runners alike. Run the first kilometer conservatively, settle into goal pace at 1K, and negative-split the last 2K if possible. Log your net time and compare against previous attempts to track fitness gains.',
          activityTitle: 'Running',
          drillTypeId: 'running_tempo',
          skillTitles: [
            'Distance',
            'Tempo'
          ],
          measurements: [
            MeasurementResult('amount', 'Distance (km)', 1, 5) as Measurement,
            MeasurementResult('duration', 'Total Time', 2, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('duration', 'Target Time', 4, null, true) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 5, 9, false) as Measurement
          ]),
      // ── Volleyball ──────────────────────────────────────────────────────────────
      _DrillSpec(
          title: 'Serving Zones (Float & Topspin)',
          description:
              'Choose 4 target zones on the opposite side of the net: short-left, short-right, deep-left, deep-right. Serve 5 to each zone for 20 total. Alternate float serves (no spin, drops unpredictably) with topspin jump serves on each zone. Track how many land in the called zone. Zone serving matters more than raw power — serving to the rotation seam ruins opponent systems.',
          activityTitle: 'Volleyball',
          drillTypeId: 'volleyball_serve',
          skillTitles: ['Serve'],
          measurements: [MeasurementResult('amount', 'Zone Hits', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Zone Hits', 3, 14, false) as Measurement]),
      _DrillSpec(
          title: 'Platform Pass Against a Wall',
          description:
              'Stand 4 feet from a wall, serve posture (platform arms, knees bent, weight forward). Pass the ball against the wall and platform-control the return continuously. The wall gives immediate feedback — any arm swing creates an uncontrollable bounce. Track your best consecutive streak per session. Goal: 30+ without moving your feet. Passing mechanics are the #1 skill separator in volleyball.',
          activityTitle: 'Volleyball',
          drillTypeId: 'volleyball_pass',
          skillTitles: ['Pass'],
          measurements: [MeasurementResult('amount', 'Best Streak', 1, null) as Measurement, MeasurementResult('amount', 'Total Passes', 2, null) as Measurement, MeasurementTarget('amount', 'Target Streak', 3, 30, false) as Measurement]),
      _DrillSpec(
          title: 'Setting Target Drill',
          description:
              'Toss the ball to yourself (or have a partner toss). Set the ball against a wall or into a hoop suspended at the setter\'s target height (about 1 foot above and 1 foot inside the antenna). Track consecutive sets that hit the target window. Focus on: footprints under the ball before contact, simultaneous hand contact, high follow-through. Consistent target setting is the single biggest factor in the quality of an entire team\'s offense.',
          activityTitle: 'Volleyball',
          drillTypeId: 'volleyball_setting',
          skillTitles: ['Set'],
          measurements: [MeasurementResult('amount', 'Target Hits', 1, null) as Measurement, MeasurementResult('amount', 'Total Sets', 2, null) as Measurement, MeasurementTarget('amount', 'Target Hits', 3, 18, false) as Measurement]),
      _DrillSpec(
          title: 'Tossed-Ball Attack (Approach & Arm Swing)',
          description:
              'Have a partner set or toss a ball at an attackable height and location. Practice your 4-step approach (right-left-right-left for right handers): last two steps are a quick 1-2 to generate vertical jump, arms swing back and forward explosively. Hit 20 from left side, 20 from right side. Track kills (balls that land in bounds and would not be dug). Footwork consistency accounts for 80% of attack height.',
          activityTitle: 'Volleyball',
          drillTypeId: 'volleyball_attack',
          skillTitles: ['Spike'],
          measurements: [MeasurementResult('amount', 'Kills', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Kills', 3, 30, false) as Measurement]),
      _DrillSpec(
          title: 'Wall Set Streak',
          description: 'Stand 5 feet from a wall and repeatedly set the ball against it to yourself without letting it drop. Use perfect hand technique — spread fingers, thumbs at forehead level, contact with finger pads only. Target 50 consecutive reps without error. Then move sideways 2 feet and set at a slight angle to a different wall zone each time.',
          activityTitle: 'Volleyball',
          drillTypeId: 'volleyball_setting',
          skillTitles: ['Set'],
          measurements: [MeasurementResult('amount', 'Best Streak', 1, null) as Measurement, MeasurementResult('amount', 'Total Sets', 2, null) as Measurement, MeasurementTarget('amount', 'Target Streak', 3, 50, false) as Measurement]),
      _DrillSpec(
          title: 'Pancake Dive (Floor Defense)',
          description:
              'Have a partner roll or toss balls to your left and right at a range that forces a dive. Extend one arm flat along the floor (pancake) and let the ball bounce off the back of your hand — the play keeps the ball alive even when a proper platform pass is impossible. 15 reps each side. The pancake is the signature defensive skill in elite volleyball and virtually never practiced at recreational levels.',
          activityTitle: 'Volleyball',
          drillTypeId: 'volleyball_pass',
          skillTitles: ['Defense'],
          measurements: [MeasurementResult('amount', 'Controlled Saves', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Saves', 3, 10, false) as Measurement]),
      _DrillSpec(
          title: 'Jump Rope (Volleyball Plyos)',
          description:
              '3 rounds of: 30 seconds standard jump, 15 seconds single-leg left, 15 seconds single-leg right, 30 seconds double-under attempts. Rest 60 seconds between rounds. Volleyball requires repeated explosive vertical jumps throughout a 5-set match — unilateral jump rope builds the single-leg landing strength and ankle stiffness that protects against the most common volleyball injury (ankle sprain).',
          activityTitle: 'Volleyball',
          drillTypeId: 'volleyball_attack',
          skillTitles: ['Block', 'Spike'],
          measurements: [MeasurementResult('amount', 'Rounds', 1, null) as Measurement, MeasurementResult('duration', 'Duration', 2, null) as Measurement, MeasurementTarget('amount', 'Target Rounds', 3, 3, false) as Measurement]),
      _DrillSpec(
          title: 'Float Serve Mechanics',
          description:
              'Contact a stationary ball held in front of your body (no arm swing). Practice only the wrist snap and arm stop — the float serve gets its unpredictable movement from the complete absence of spin at contact, which requires stopping the arm immediately at impact (not following through). 20 contact reps with no ball, then 20 full serves. The float serve is more effective than a topspin jump serve at most recreational and amateur levels.',
          activityTitle: 'Volleyball',
          drillTypeId: 'volleyball_serve',
          skillTitles: ['Serve'],
          measurements: [MeasurementResult('amount', 'In Bounds', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target In', 3, 16, false) as Measurement]),
      _DrillSpec(
          title: 'Overhead Pass (Serve Receive Posture)',
          description:
              'Practice overhead digging of high balls — a skill critical for back-row defense. Toss the ball high in front of you and contact it above your head with a setting-like motion, but with a firmer push. Keep elbows at eye level. 20 reps each session. High serves and tips over the block require this skill, which is distinctly different from a standard set.',
          activityTitle: 'Volleyball',
          drillTypeId: 'volleyball_pass',
          skillTitles: ['Pass', 'Defense'],
          measurements: [MeasurementResult('amount', 'Controlled', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Controlled', 3, 16, false) as Measurement]),
      _DrillSpec(
          title: 'Block Footwork (Box Drill)',
          description:
              'Stand at the net. Side-step 2 steps left, 2 steps right, then shuffle to the right antenna and back to center each rep. On each shuffle, explode up for a simulated block before coming down and shuffling to the next spot. 10 rep sequences. Trains the quick-step → explosive vertical sequence that every middle blocker and outside hitter needs. No ball required.',
          activityTitle: 'Volleyball',
          drillTypeId: 'volleyball_attack',
          skillTitles: ['Block'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 10, false) as Measurement]),
      // ── Martial Arts ────────────────────────────────────────────────────────────
      _DrillSpec(
          title: 'Jab-Cross-Hook-Cross (1-2-3-2)',
          description:
              'The most fundamental boxing combination. From southpaw or orthodox stance: snap jab (extend, retract immediately), drive cross off back foot, hook with front hand (elbow at shoulder height, pivot the front foot), drive cross again. Each punch should return to guard before the next fires. 30 seconds on, 30 off, 5 rounds. The 1-2-3-2 is the backbone of every boxing offensive system.',
          activityTitle: 'Martial Arts',
          drillTypeId: 'ma_combination',
          skillTitles: ['Combinations', 'Striking'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 50, false) as Measurement]),
      _DrillSpec(
          title: 'Round Kicks (Thai Style)',
          description:
              'Walk your rear hip through the kick — the Muay Thai round kick is a full-rotation hip-driven strike, not a leg swing. The shin (not the foot) is the contact surface. Do 20 each side at heavy bag or on air: step at 45°, pivot hip and shoulder together, return to stance. Focus on hip rotation, not leg speed — rotation is the power source.',
          activityTitle: 'Martial Arts',
          drillTypeId: 'ma_combination',
          skillTitles: ['Kicks'],
          measurements: [MeasurementResult('amount', 'Reps (Right)', 1, null) as Measurement, MeasurementResult('amount', 'Reps (Left)', 2, null) as Measurement, MeasurementTarget('amount', 'Target Each Side', 3, 20, false) as Measurement]),
      _DrillSpec(
          title: 'Heavy Bag Rounds',
          description:
              'Work the heavy bag for 3-minute rounds using structured work: Round 1 — jabs and movement only. Round 2 — 2-3 punch combinations with body shots. Round 3 — power rounds, max-effort combinations. Rest 1 minute between rounds. Track total rounds and RPE. Heavy bag rounds develop punch output, conditioning, and combination flow simultaneously.',
          activityTitle: 'Martial Arts',
          drillTypeId: 'ma_bag_work',
          skillTitles: [
            'Striking',
            'Combinations',
            'Conditioning'
          ],
          measurements: [
            MeasurementResult('amount', 'Rounds', 1, null) as Measurement,
            MeasurementResult('duration', 'Round Duration', 2, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('amount', 'Target Rounds', 4, 3, false) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 5, 8, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Shadowboxing (Technical)',
          description:
              'Shadowbox for 3 rounds focusing on: Round 1 — pure movement (footwork angles, pivots, slips, ducks, no punching). Round 2 — jab-led combinations with eye on imaginary opponent\'s hips. Round 3 — counter-only (slip, parry, then counter). Shadow is where you can practice the technical details that get lost during bag or sparring work. The best fighters in the world shadow more than they spar.',
          activityTitle: 'Martial Arts',
          drillTypeId: 'ma_bag_work',
          skillTitles: [
            'Striking',
            'Footwork',
            'Defense'
          ],
          measurements: [
            MeasurementResult('amount', 'Rounds', 1, null) as Measurement,
            MeasurementResult('duration', 'Round Duration', 2, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('amount', 'Target Rounds', 4, 3, false) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 5, 6, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Defensive Slipping (Wall Mirror)',
          description:
              'Stand arms-length from a wall, guard up. Practice slipping left (roll off the center line left to avoid a right hand), then right. Do not lean — shift your weight to the outside foot and drop the head to the outside, never past your knee. 20 slips each side. Slipping is the highest-percentage defensive technique in boxing-based styles — it creates simultaneous defense and counter position.',
          activityTitle: 'Martial Arts',
          drillTypeId: 'ma_footwork',
          skillTitles: ['Defense', 'Footwork'],
          measurements: [MeasurementResult('amount', 'Reps (Left)', 1, null) as Measurement, MeasurementResult('amount', 'Reps (Right)', 2, null) as Measurement, MeasurementTarget('amount', 'Target Each Side', 3, 20, false) as Measurement]),
      _DrillSpec(
          title: 'Box Footwork (4 Corners)',
          description:
              'Set 4 cones in a 2-foot square. Starting at cone 1, move to each corner using only on-ball footwork: step-slide from 1→2, pivot 90° and slide 2→3, back-step 3→4, diagonal return 4→1. Repeat 10 times. Boxing/Muay Thai footwork is a physical skill entirely separate from striking — most practitioners spend 95% of time on output and almost none on movement.',
          activityTitle: 'Martial Arts',
          drillTypeId: 'ma_footwork',
          skillTitles: ['Footwork'],
          measurements: [MeasurementResult('amount', 'Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 10, false) as Measurement]),
      _DrillSpec(
          title: 'Kick Shield Cardio Circuit',
          description:
              '5 rounds of 1 minute: alternating round kicks (each side) + 10 push-kicks (teep) + 10 punches. Rest 30 seconds. The teep (push kick) is an essential range-management tool in Muay Thai, kickboxing, and karate that is almost never isolated in solo training. Builds hip flexor power, balance on support leg, and kick volume endurance simultaneously.',
          activityTitle: 'Martial Arts',
          drillTypeId: 'ma_conditioning',
          skillTitles: [
            'Kicks',
            'Conditioning'
          ],
          measurements: [
            MeasurementResult('duration', 'Duration', 1, null) as Measurement,
            MeasurementResult('amount', 'Rounds', 2, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('duration', 'Target Duration', 4, 300, false) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 5, 8, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Double-End Bag Timing',
          description:
              'If no double-end bag: tie a tennis ball on a 3-foot elastic cord anchored between two fixed points at head height. Hit it with a jab and let it return, timing your slip and jab again. Track your consecutive clean contacts (hit → slip → hit). The double-end bag trains reactive timing, counter-punching, and rhythm — skills that a heavy bag cannot teach because it does not move back.',
          activityTitle: 'Martial Arts',
          drillTypeId: 'ma_bag_work',
          skillTitles: [
            'Striking',
            'Defense'
          ],
          measurements: [
            MeasurementResult('amount', 'Best Streak', 1, null) as Measurement,
            MeasurementResult('duration', 'Round Duration', 2, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('amount', 'Target Streak', 4, 20, false) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 5, 7, false) as Measurement
          ]),
      _DrillSpec(
          title: '1-2 Speed Burst (Partner Mirror)',
          description:
              'Stand opposite a mirror or partner. Throw a jab-cross as fast as possible (max speed, not power), reset guard fully, repeat. 20 bursts per minute for 3 minutes. The speed-burst drill isolates raw hand speed and the snap-return of the punch, which are trainable neurological qualities. Power follows speed — never train them simultaneously in this context.',
          activityTitle: 'Martial Arts',
          drillTypeId: 'ma_combination',
          skillTitles: ['Striking', 'Combinations'],
          measurements: [MeasurementResult('amount', 'Bursts', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Bursts', 3, 60, false) as Measurement]),
      _DrillSpec(
          title: 'Burpee Boxing Circuit',
          description:
              '10 burpees → 10 jab-cross combos (max effort) → 10 more burpees → 10 uppercut-hook combos. Rest 90 seconds. That is 1 round. Complete 4 rounds. Simulates the anaerobic demand of a competitive round — explosive output, brief recovery, explosive output again. The burpee transitions train re-engagement of the striking position from a compromised state.',
          activityTitle: 'Martial Arts',
          drillTypeId: 'ma_conditioning',
          skillTitles: [
            'Conditioning',
            'Combinations'
          ],
          measurements: [
            MeasurementResult('duration', 'Duration', 1, null) as Measurement,
            MeasurementResult('amount', 'Rounds', 2, null) as Measurement,
            MeasurementResult('rpe', 'RPE (1–10)', 3, null) as Measurement,
            MeasurementTarget('duration', 'Target Duration', 4, 600, false) as Measurement,
            MeasurementTarget('rpe', 'Target RPE', 5, 9, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Teep (Push Kick) Line',
          description:
              'From your fighting stance, extend your lead leg straight into the target with the heel of your foot — not the toes. Your support leg should be slightly bent, hip driving through at contact, not swinging the leg. 20 reps each side. The teep is the #1 range-management tool in Muay Thai and the most commonly ignored kick in solo training.',
          activityTitle: 'Martial Arts',
          drillTypeId: 'ma_combination',
          skillTitles: ['Kicks', 'Footwork'],
          measurements: [MeasurementResult('amount', 'Reps (Lead)', 1, null) as Measurement, MeasurementResult('amount', 'Reps (Rear)', 2, null) as Measurement, MeasurementTarget('amount', 'Target Each Side', 3, 20, false) as Measurement]),
      // ── Pickleball ──────────────────────────────────────────────────────────────
      _DrillSpec(
          title: 'Cross-Court Dink Rally',
          description:
              'Stand at the kitchen line and dink cross-court continuously against a wall or with a partner. The dink must be soft enough to land in the opponent\'s kitchen — no higher than ankle height over the net. Track your best consecutive rally streak. In pickleball at all levels above beginners, most rallies are decided by who errors first in a dink exchange — not the subsequent speed-up.',
          activityTitle: 'Pickleball',
          drillTypeId: 'pk_dink',
          skillTitles: ['Dink'],
          measurements: [MeasurementResult('amount', 'Best Streak', 1, null) as Measurement, MeasurementResult('amount', 'Total Dinks', 2, null) as Measurement, MeasurementTarget('amount', 'Target Streak', 3, 30, false) as Measurement]),
      _DrillSpec(
          title: 'Serve Deep to Zones',
          description: 'Mark two target zones on the opponent\'s side: backhand corner and center T. Hit 5 serves to each zone, alternating, for 20 total. A deep serve to the backhand corner is statistically the highest-percentage serve in recreational pickleball — it pushes the returner back and forces a weaker, shorter return that you can attack.',
          activityTitle: 'Pickleball',
          drillTypeId: 'pk_serve',
          skillTitles: ['Serve'],
          measurements: [MeasurementResult('amount', 'On Target', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target On Target', 3, 14, false) as Measurement]),
      _DrillSpec(
          title: 'Third Shot Drop Solo (Bounce Feed)',
          description:
              'Bounce a ball on the ground near the baseline, let it rise, and hit a soft arcing shot into the kitchen. The drop must clear the net by at least 6 inches and land softly in the non-volley zone. Hit 30. This is the most important and most underused shot in pickleball — it neutralizes the opponents\' net advantage after the serve and allow you to advance to the kitchen yourself.',
          activityTitle: 'Pickleball',
          drillTypeId: 'pk_third_shot',
          skillTitles: ['Third Shot'],
          measurements: [MeasurementResult('amount', 'In Kitchen', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target In Kitchen', 3, 20, false) as Measurement]),
      _DrillSpec(
          title: 'Erne Approach (Poach Practice)',
          description:
              'Practice the Erne — jump or step around the net post, plant outside the court, and volley a ball that was going cross-court. Start from the kitchen line, sidestep to the sideline, and simulate the poach volley with a firm continental grip punch. Do 10 reps each side. Advanced kitchen-line execution of the Erne wins more points per attempt than almost any other shot in bangers\' and dink players\' games alike.',
          activityTitle: 'Pickleball',
          drillTypeId: 'pk_drive',
          skillTitles: ['Volley', 'Footwork'],
          measurements: [MeasurementResult('amount', 'Clean Attempts', 1, null) as Measurement, MeasurementResult('amount', 'Total Reps', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 7, false) as Measurement]),
      _DrillSpec(
          title: 'Wall Dink Mechanics',
          description:
              'Stand 7 feet from a wall and dink softly against it, controlling each return. The wall hit should be gentle — if it comes back fast, you hit too hard. Focus on a compact continental grip stroke, reset wrist, and paddle face slightly open. Track best consecutive streak. Develops the touch, wrist control, and timing that define elite kitchen play.',
          activityTitle: 'Pickleball',
          drillTypeId: 'pk_dink',
          skillTitles: ['Dink'],
          measurements: [MeasurementResult('amount', 'Best Streak', 1, null) as Measurement, MeasurementResult('amount', 'Total Dinks', 2, null) as Measurement, MeasurementTarget('amount', 'Target Streak', 3, 20, false) as Measurement]),
      _DrillSpec(
          title: 'Speed-Up Attack Reset',
          description:
              'Have a partner or machine feed balls to your forehand at mid-court height. Drive the ball hard cross-court (the speed-up), then immediately reset your stance for the expected counter. Do 20 reps. In pickleball, the speed-up is most effective when the opponent is square and close to the net — not when they are in a defensive posture. This drill trains both the attack and the recovery.',
          activityTitle: 'Pickleball',
          drillTypeId: 'pk_drive',
          skillTitles: ['Drive', 'Volley'],
          measurements: [MeasurementResult('amount', 'Successful Attacks', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Successful', 3, 14, false) as Measurement]),
      _DrillSpec(
          title: 'Overhead Smash Practice',
          description:
              'Toss a ball high in the air (or have a partner lob) and track it above your hitting shoulder. Rotate shoulders, keep paddle scratching-your-back position, and snap through contact. Deliver to open-court zones. Hit 20. The overhead is the highest-percentage point-winner in pickleball when executed correctly — yet almost never practiced solo.',
          activityTitle: 'Pickleball',
          drillTypeId: 'pk_drive',
          skillTitles: ['Drive'],
          measurements: [MeasurementResult('amount', 'Winners', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Winners', 3, 14, false) as Measurement]),
      _DrillSpec(
          title: 'Serve Return Deep Placement',
          description:
              'Practice the return of serve by bouncing a ball and hitting it deep down the middle or cross-court. Keep the return low and deep — do not attack unless the serve lands short. Hit 20 to each zone. Returning deep and down the middle removes the serving team\'s angle advantage, neutralising the third-shot opportunity that a short return creates.',
          activityTitle: 'Pickleball',
          drillTypeId: 'pk_serve',
          skillTitles: ['Serve'],
          measurements: [MeasurementResult('amount', 'Deep in Zone', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Deep', 3, 14, false) as Measurement]),
      _DrillSpec(
          title: 'Footwork to the Kitchen',
          description:
              'Start at the baseline. Serve or simulate a serve, then split-step and advance to the kitchen in 3 steps, arriving just as a simulated third shot drops. Repeat 20 times. Transitioning from baseline to kitchen is a choreographed movement pattern — arriving too early or too late is the most common positioning error in pickleball. Timing the split step and advance is a trainable skill.',
          activityTitle: 'Pickleball',
          drillTypeId: 'pk_third_shot',
          skillTitles: ['Footwork', 'Third Shot'],
          measurements: [MeasurementResult('amount', 'Timed Arrivals', 1, null) as Measurement, MeasurementResult('amount', 'Total Reps', 2, null) as Measurement, MeasurementTarget('amount', 'Target Timed', 3, 16, false) as Measurement]),
      _DrillSpec(
          title: 'Around the Post (ATP) Practice',
          description:
              'Stand near the sideline at or past the kitchen line. Have a partner hit a wide angled dink or pass. Let the ball travel past the net post and hit it around the post — below net level is legal on an ATP. Do 10 reps each side. The ATP is the single most crowd-pleasing play in pickleball and is completely legal yet practiced by almost no recreational players, because it requires specific approach footwork.',
          activityTitle: 'Pickleball',
          drillTypeId: 'pk_drive',
          skillTitles: ['Drive', 'Footwork'],
          measurements: [MeasurementResult('amount', 'Clean ATPs', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 6, false) as Measurement]),
      // ── Lacrosse ────────────────────────────────────────────────────────────────
      _DrillSpec(
          title: 'Wall Ball (Dominant Hand)',
          description:
              'Stand 10–15 feet from a concrete or brick wall. Throw → catch → throw in a continuous rhythm, dominant hand only. Focus on catching across your body and throwing with a full overhand motion — not sidearm. Start with 100 reps at slow rhythm, then 50 at fast rhythm. Wall ball is the foundation of all lacrosse development. Most college programs require 500 wall ball reps per day during off-season.',
          activityTitle: 'Lacrosse',
          drillTypeId: 'lax_wall_ball',
          skillTitles: ['Catching', 'Passing'],
          measurements: [MeasurementResult('amount', 'Catches', 1, null) as Measurement, MeasurementResult('amount', 'Throws', 2, null) as Measurement, MeasurementTarget('amount', 'Target Catches', 3, 100, false) as Measurement]),
      _DrillSpec(
          title: 'Wall Ball (Off Hand)',
          description:
              'Same as dominant-hand wall ball but using your non-dominant hand exclusively. The single most impactful individual skill investment in lacrosse. A player who can throw and catch equally well with both hands cannot be defended by shadowing their strong hand — which is the primary defensive strategy used against single-handed players at every level above recreational.',
          activityTitle: 'Lacrosse',
          drillTypeId: 'lax_wall_ball',
          skillTitles: ['Catching', 'Passing'],
          measurements: [MeasurementResult('amount', 'Catches', 1, null) as Measurement, MeasurementResult('amount', 'Throws', 2, null) as Measurement, MeasurementTarget('amount', 'Target Catches', 3, 100, false) as Measurement]),
      _DrillSpec(
          title: 'Quick Stick Wall Ball',
          description:
              'After a catch, release the ball back to the wall in under 1 second — no cradling between reps. This trains the "quick stick" skill used inside the crease where there is no time to wind up. 50 reps dominant hand, 50 off hand. Quick stick percentage is a key differentiator between midfield and attack players at the collegiate and professional levels.',
          activityTitle: 'Lacrosse',
          drillTypeId: 'lax_wall_ball',
          skillTitles: ['Catching', 'Passing'],
          measurements: [MeasurementResult('amount', 'Quick Catches', 1, null) as Measurement, MeasurementResult('amount', 'Throws', 2, null) as Measurement, MeasurementTarget('amount', 'Target Quick', 3, 50, false) as Measurement]),
      _DrillSpec(
          title: 'Target Gate Shooting',
          description:
              'Place tape targets at the four corners of the goal (or pipe-corner targets). Call a corner before each shot and try to hit it with an overhand shot from 10–12 yards. 20 shots dominant hand. The overhand shot driven to the pipe corner is the lowest-percentage shot for a goalie to save — it has a high arc, late velocity, and forces the goalkeeper to move both arms in opposite directions.',
          activityTitle: 'Lacrosse',
          drillTypeId: 'lax_shooting',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'On Target', 1, null) as Measurement, MeasurementResult('amount', 'Shots', 2, null) as Measurement, MeasurementTarget('amount', 'Target On Target', 3, 14, false) as Measurement]),
      _DrillSpec(
          title: 'Sidearm & Underhand Shots',
          description:
              'Practice 20 sidearm (low, flat trajectory aimed at the post) and 20 underhand (scooping backhand motion, aimed at the low opposite pipe) shots from 8 yards. These are the two shots goalies find hardest to read because the release point and trajectory are different from the overhand. The sidearm low-corner and underhand are the primary finishers used in the crease.',
          activityTitle: 'Lacrosse',
          drillTypeId: 'lax_shooting',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'On Target', 1, null) as Measurement, MeasurementResult('amount', 'Shots', 2, null) as Measurement, MeasurementTarget('amount', 'Target On Target', 3, 28, false) as Measurement]),
      _DrillSpec(
          title: 'Box Lacrosse Cradling',
          description:
              'Cradle the ball through a tight figure-8 pattern around cones spaced 1 foot apart. The box-lacrosse style tight cradle — elbow close to the body, top hand doing most of the work — is the essential technique for protecting the ball in traffic. Do 5 laps clockwise, 5 counter-clockwise. Used by every top NCAA and NHL-level player as a foundational possession skill.',
          activityTitle: 'Lacrosse',
          drillTypeId: 'lax_cradling',
          skillTitles: ['Cradling'],
          measurements: [MeasurementResult('amount', 'Laps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Laps', 3, 10, false) as Measurement]),
      _DrillSpec(
          title: 'Ground Ball Scoop Sprint',
          description:
              'Roll a ball 10 yards ahead, sprint to it, and scoop it in stride using the correct technique: bent knees, low lead hand below the ball, pushing the stick head through and under, finishing in a sprint posture. 15 reps each hand. Ground ball percentage is one of the highest-correlated statistics with winning lacrosse — most games are decided by ground ball differentials.',
          activityTitle: 'Lacrosse',
          drillTypeId: 'lax_ground_ball',
          skillTitles: ['Ground Balls'],
          measurements: [MeasurementResult('amount', 'Clean Scoops', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 13, false) as Measurement]),
      _DrillSpec(
          title: 'Skip Pass Wall Ball',
          description:
              'Instead of throwing directly at the wall, throw at the floor 5 feet in front of the wall at a 45° angle so the ball bounces up unpredictably. Catch it with soft hands and return it. Skip passes, ground balls, and errant feeds all produce unpredictable bounces — this drill trains the hand-eye reaction that separates players who can handle bad passes from those who cannot.',
          activityTitle: 'Lacrosse',
          drillTypeId: 'lax_wall_ball',
          skillTitles: ['Catching'],
          measurements: [MeasurementResult('amount', 'Catches', 1, null) as Measurement, MeasurementResult('amount', 'Throws', 2, null) as Measurement, MeasurementTarget('amount', 'Target Catches', 3, 40, false) as Measurement]),
      _DrillSpec(
          title: 'Dodging Footwork (Split Dodge)',
          description:
              'Place a cone 10 yards ahead. Sprint toward it, plant your lead foot hard, cross over the planted foot, switch hands simultaneously, and explode the other direction. The split dodge — a hard plant + hand switch + burst — is the most effective dodge against even-footed defenders at all levels. 15 reps each side. Hand-switch timing (matching footstep) is the entire skill.',
          activityTitle: 'Lacrosse',
          drillTypeId: 'lax_cradling',
          skillTitles: ['Footwork', 'Cradling'],
          measurements: [MeasurementResult('amount', 'Reps (Right)', 1, null) as Measurement, MeasurementResult('amount', 'Reps (Left)', 2, null) as Measurement, MeasurementTarget('amount', 'Target Each Side', 3, 15, false) as Measurement]),
      _DrillSpec(
          title: 'Behind-the-Back Feed',
          description:
              'Stand 6 feet from the wall. Cradle to one shoulder, reach the stick behind your back so the head exits on the other side of your body, and fire the pass. Catch the return normally. 30 reps. The BTB pass is not a trick — it is a practical dodging tool used when a defender takes your strong side and you are driving toward the crease. Practiced from close range so the mechanics can be exact.',
          activityTitle: 'Lacrosse',
          drillTypeId: 'lax_wall_ball',
          skillTitles: ['Passing'],
          measurements: [MeasurementResult('amount', 'Catches', 1, null) as Measurement, MeasurementResult('amount', 'Throws', 2, null) as Measurement, MeasurementTarget('amount', 'Target Catches', 3, 20, false) as Measurement]),
      // ── Gymnastics ──────────────────────────────────────────────────────────────
      _DrillSpec(
          title: 'Handstand Wall Hold',
          description:
              'Kick up to a handstand with your heels against the wall. Body straight (no arching), ribcage in, glutes squeezed, wrists under shoulders, fingers spread. Hold without relying on the wall — use it only as a safety catch. Track your best unsupported hold within the kick-up. The handstand is the most fundamental gymnastics and calisthenics skill — it develops wrist strength, shoulder stability, and total-body tension patterns that transfer to every other overhead movement.',
          activityTitle: 'Gymnastics',
          drillTypeId: 'gym_hold',
          skillTitles: ['Handstand', 'Balance', 'Strength'],
          measurements: [MeasurementResult('duration', 'Best Free Hold', 1, null) as Measurement, MeasurementResult('amount', 'Sets', 2, null) as Measurement, MeasurementTarget('duration', 'Target Hold', 3, 10, false) as Measurement]),
      _DrillSpec(
          title: 'Wall-Assisted Handstand Push-up',
          description:
              'Kick up to a wall handstand. Lower your head toward the floor under control, then press back to lockout. Keep elbows tracking inward — no flare. If full range is too hard, place books under your hands and lower to the books. Track clean reps per set. The HSPU is the highest upper-body strength skill in calisthenics that requires no equipment other than a wall.',
          activityTitle: 'Gymnastics',
          drillTypeId: 'gym_skill_reps',
          skillTitles: [
            'Strength',
            'Handstand'
          ],
          measurements: [
            MeasurementResult('amount', 'Clean Reps', 1, null) as Measurement,
            MeasurementResult('amount', 'Total Attempts', 2, null) as Measurement,
            MeasurementResult('rir', 'RIR', 3, null) as Measurement,
            MeasurementTarget('amount', 'Target Clean', 4, 5, false) as Measurement,
            MeasurementTarget('rir', 'Target RIR', 5, 2, false) as Measurement
          ]),
      _DrillSpec(
          title: 'L-Sit Hold (Chairs/Floor)',
          description:
              'Place two chairs shoulder-width apart or use the floor. Support on straight arms, compress your core, extend legs parallel to the floor. Hold. Your goal is a 10-second hold with legs completely parallel. Progress: tuck L-sit → one-leg extended → full L-sit → L-sit to V-sit. The L-sit trains scapular depression, hip flexor strength, and tricep lockout simultaneously — the three prerequisites for ring work.',
          activityTitle: 'Gymnastics',
          drillTypeId: 'gym_hold',
          skillTitles: ['Core', 'Strength'],
          measurements: [MeasurementResult('duration', 'Best Hold', 1, null) as Measurement, MeasurementResult('amount', 'Sets', 2, null) as Measurement, MeasurementTarget('duration', 'Target Hold', 3, 10, false) as Measurement]),
      _DrillSpec(
          title: 'Forward Roll Progression',
          description:
              'Tuck chin to chest, place hands shoulder-width apart, and roll forward — shoulders contact the floor, not the head. Stand at the end without using your hands. Do 10 clean rolls. Progress to dive rolls (a small forward jump into the roll). The forward roll is the foundational tumbling skill and the correct way to absorb a fall in any discipline. Chin-to-chest discipline is what prevents neck injuries.',
          activityTitle: 'Gymnastics',
          drillTypeId: 'gym_skill_reps',
          skillTitles: [
            'Balance',
            'Core'
          ],
          measurements: [
            MeasurementResult('amount', 'Clean Reps', 1, null) as Measurement,
            MeasurementResult('amount', 'Total Attempts', 2, null) as Measurement,
            MeasurementResult('rir', 'RIR', 3, null) as Measurement,
            MeasurementTarget('amount', 'Target Clean', 4, 10, false) as Measurement,
            MeasurementTarget('rir', 'Target RIR', 5, 3, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Pancake Stretch (Hip Flexor Opening)',
          description:
              'Sit on the floor with legs spread as far as possible. Hinge forward at the hips — not the waist — walking your hands forward until your forearms rest on the floor. Hold 60 seconds, breathing into the groin. Repeat 3 times. The pancake is the most important gymnastic flexibility position — it is required for press handstands, straddle planches, and splits, and it is trainable at any age if approached progressively.',
          activityTitle: 'Gymnastics',
          drillTypeId: 'gym_flexibility',
          skillTitles: ['Flexibility'],
          measurements: [MeasurementResult('duration', 'Hold Time', 1, null) as Measurement, MeasurementResult('amount', 'Sets', 2, null) as Measurement, MeasurementTarget('duration', 'Target Hold', 3, 60, false) as Measurement]),
      _DrillSpec(
          title: 'Tuck Planche Hold',
          description:
              'From a push-up position, lean forward until shoulders are over or past the wrists and lift your feet by compressing your tuck. Hold. This is the first step in the planche progression — the most advanced push strength skill in gymnastics. A 5-second clean tuck hold requires months of shoulder and wrist conditioning. Progress: tuck → advanced tuck → straddle → full planche.',
          activityTitle: 'Gymnastics',
          drillTypeId: 'gym_hold',
          skillTitles: ['Strength', 'Balance'],
          measurements: [MeasurementResult('duration', 'Best Hold', 1, null) as Measurement, MeasurementResult('amount', 'Sets', 2, null) as Measurement, MeasurementTarget('duration', 'Target Hold', 3, 5, false) as Measurement]),
      _DrillSpec(
          title: 'Arch & Hollow Body Alternation',
          description:
              'Lie face-down, arch into a Superman position (arms and legs off floor), hold 2 seconds. Flip to your back, press into hollow body (arms overhead, legs low, lower back pressed into floor), hold 2 seconds. Alternate 10 rounds. These two shapes are the foundations of every gymnastics skill — bar work, rings, floor, and vault all require rapid cycling between these two tension states.',
          activityTitle: 'Gymnastics',
          drillTypeId: 'gym_conditioning',
          skillTitles: ['Core', 'Conditioning'],
          measurements: [MeasurementResult('amount', 'Sets', 1, null) as Measurement, MeasurementResult('amount', 'Reps', 2, null) as Measurement, MeasurementResult('rir', 'RIR', 3, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 4, 10, false) as Measurement, MeasurementTarget('rir', 'Target RIR', 5, 2, false) as Measurement]),
      _DrillSpec(
          title: 'Jefferson Curl (Loaded Spinal Flexion)',
          description:
              'Stand on a box or step holding a light weight. Round forward one vertebra at a time from the top of the spine down — the controlled opposite of a deadlift. Reach the lowest comfortable point then return one vertebra at a time. 3 × 8. Develops spinal mobility and hamstring flexibility simultaneously. Controversial name, uncontroversially effective — used by elite gymnasts, acrobats, and martial artists globally for back health and posterior chain mobility.',
          activityTitle: 'Gymnastics',
          drillTypeId: 'gym_flexibility',
          skillTitles: ['Flexibility', 'Strength'],
          measurements: [MeasurementResult('amount', 'Sets', 1, null) as Measurement, MeasurementResult('amount', 'Reps', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 8, false) as Measurement]),
      _DrillSpec(
          title: 'Ring Row Progression',
          description:
              'Set gym rings (or TRX/table rings improvised at home) at hip height. Grip rings, walk feet forward until body is at 45°, and row up. As you get stronger, walk feet further forward to lower the angle. Progress to feet-elevated, then to feet-at-ring-level (inverted row, parallel to floor). The ring row is the most complete bodyweight pulling skill — trains biceps, rear delts, rhomboids, and stabilising rotator cuff simultaneously.',
          activityTitle: 'Gymnastics',
          drillTypeId: 'gym_skill_reps',
          skillTitles: [
            'Strength',
            'Core'
          ],
          measurements: [
            MeasurementResult('amount', 'Clean Reps', 1, null) as Measurement,
            MeasurementResult('amount', 'Total Attempts', 2, null) as Measurement,
            MeasurementResult('rir', 'RIR', 3, null) as Measurement,
            MeasurementTarget('amount', 'Target Clean', 4, 10, false) as Measurement,
            MeasurementTarget('rir', 'Target RIR', 5, 2, false) as Measurement
          ]),
      _DrillSpec(
          title: 'Bridge Hold (Thoracic Spine)',
          description:
              'Lie on your back, place hands by your ears, and push up into a full bridge/backbend. Hold for 20 seconds. If you cannot lock out your arms, do a table bridge (hips only) or use a block under your hands. Thoracic spine extension mobility is the limiting factor in every overhead gymnastics skill — front walkovers, handstands, back handsprings all require this range of motion.',
          activityTitle: 'Gymnastics',
          drillTypeId: 'gym_flexibility',
          skillTitles: ['Flexibility', 'Balance'],
          measurements: [MeasurementResult('duration', 'Hold Time', 1, null) as Measurement, MeasurementResult('amount', 'Sets', 2, null) as Measurement, MeasurementTarget('duration', 'Target Hold', 3, 20, false) as Measurement]),
      _DrillSpec(
          title: 'Crow Pose to Frog Stand',
          description:
              'Squat down, place hands flat on the floor, and lean forward until your knees rest on the backs of your arms. Hold without your feet touching. This is crow pose (yoga) / frog stand (calisthenics). It requires wrist pronation mobility, scapular depression strength, and the ability to shift weight over your hands — all prerequisites for the L-sit and planche. Track hold time.',
          activityTitle: 'Gymnastics',
          drillTypeId: 'gym_hold',
          skillTitles: ['Balance', 'Core', 'Strength'],
          measurements: [MeasurementResult('duration', 'Best Hold', 1, null) as Measurement, MeasurementResult('amount', 'Sets', 2, null) as Measurement, MeasurementTarget('duration', 'Target Hold', 3, 15, false) as Measurement]),
      // ── Guitar ──────────────────────────────────────────────────────────────────
      _DrillSpec(
          title: 'Chromatic Scale (Metronome)',
          description:
              'Set a metronome to 60 BPM. Play the chromatic scale (1-2-3-4 on each string, ascending and descending all 6 strings) using alternate picking — strictly down-up-down-up. One note per click. When you can play cleanly at a given tempo for 2 minutes without errors, bump the metronome up by 4 BPM. Chromatic scale with a metronome is the single most efficient fretting-hand independence and picking synchronisation drill in guitar technique.',
          activityTitle: 'Guitar',
          drillTypeId: 'guitar_scale',
          skillTitles: ['Scales', 'Picking'],
          measurements: [MeasurementResult('amount', 'BPM Achieved', 1, null) as Measurement, MeasurementResult('amount', 'Clean Runs', 2, null) as Measurement, MeasurementResult('amount', 'Total Runs', 3, null) as Measurement, MeasurementTarget('amount', 'Target BPM', 4, 120, false) as Measurement]),
      _DrillSpec(
          title: 'Pentatonic Box 1 (Position Practice)',
          description:
              'The minor pentatonic box 1 pattern is the most-used scale in rock, blues, country, and pop improvisation. Practice ascending and descending in position using alternate picking at 70 BPM. Track clean runs (no fret buzz, no string skip, every note sounds clearly). Aim for 10 consecutive clean runs before increasing tempo. Start in Am position at the 5th fret.',
          activityTitle: 'Guitar',
          drillTypeId: 'guitar_scale',
          skillTitles: ['Scales', 'Picking'],
          measurements: [MeasurementResult('amount', 'BPM Achieved', 1, null) as Measurement, MeasurementResult('amount', 'Clean Runs', 2, null) as Measurement, MeasurementResult('amount', 'Total Runs', 3, null) as Measurement, MeasurementTarget('amount', 'Target BPM', 4, 100, false) as Measurement]),
      _DrillSpec(
          title: 'G–C–D–Em Chord Rotation',
          description:
              'Set a metronome to 60 BPM, 4 counts per chord. Rotate: G → C → D → Em → G. Focus on two things: (1) all fingers pressing down simultaneously, not one at a time, and (2) fretting hand in position before the chord change — no panic-scrambling. Track changes per minute and consecutive clean changes. These four chords appear in thousands of pop and rock songs.',
          activityTitle: 'Guitar',
          drillTypeId: 'guitar_chord',
          skillTitles: ['Chords'],
          measurements: [MeasurementResult('amount', 'Changes / Min', 1, null) as Measurement, MeasurementResult('amount', 'Best Streak (clean)', 2, null) as Measurement, MeasurementTarget('amount', 'Target Changes / Min', 3, 30, false) as Measurement]),
      _DrillSpec(
          title: 'Barre Chord (F Major) Practice',
          description:
              'The F major barre chord stops more players from advancing than any other technique. Place your index finger across all 6 strings at the 1st fret, add the remaining fingers for an E-shape barre. Strike each string individually to find dead spots, adjust pressure and angle until all 6 ring. 20 reps: press → strum → release → press again. Track clean strums where all 6 strings sound cleanly.',
          activityTitle: 'Guitar',
          drillTypeId: 'guitar_chord',
          skillTitles: ['Chords'],
          measurements: [MeasurementResult('amount', 'Clean Strums', 1, null) as Measurement, MeasurementResult('amount', 'Total Strums', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 16, false) as Measurement]),
      _DrillSpec(
          title: 'Spider Exercise (Independence)',
          description:
              'This is not a real musical pattern — it\'s a pure technical exercise. On the low E string: finger 1 plays fret 5, finger 2 plays fret 6, finger 3 plays fret 7, finger 4 plays fret 8. Lift each finger individually after placing it, then ascend to string 1 (high E) and descend back. Use alternate picking. 5 minutes per session at 60 BPM. Builds fretting-hand independence, especially for the weak ring and pinky fingers.',
          activityTitle: 'Guitar',
          drillTypeId: 'guitar_technique',
          skillTitles: ['Picking', 'Scales'],
          measurements: [MeasurementResult('amount', 'BPM Achieved', 1, null) as Measurement, MeasurementResult('amount', 'Clean Sets', 2, null) as Measurement, MeasurementTarget('amount', 'Target BPM', 3, 90, false) as Measurement]),
      _DrillSpec(
          title: 'String Skipping Arpeggios',
          description:
              'Play a simple triad arpeggio skipping strings: low E (root) → G string (third) → B string (fifth) → high E (root). No adjacent string strumming — strict alternate picking with proper muting of the skipped string with the pick hand thumb or palm. Track clean arpeggios at current tempo. String skipping is the hardest right-hand technique to develop cleanly and directly trains picking precision.',
          activityTitle: 'Guitar',
          drillTypeId: 'guitar_technique',
          skillTitles: ['Picking'],
          measurements: [MeasurementResult('amount', 'BPM Achieved', 1, null) as Measurement, MeasurementResult('amount', 'Clean Arpeggios', 2, null) as Measurement, MeasurementTarget('amount', 'Target BPM', 3, 80, false) as Measurement]),
      _DrillSpec(
          title: 'Hammer-On / Pull-Off Legato',
          description:
              'On one string: pick the first note, hammer-on the second (sound it by fretting pressure only — no pick), pull-off the third (flick off to sound the lower note). Do this on a pentatonic box pattern without picking any internal notes — only the first note of each string is picked. 5 minutes. Legato technique allows the guitar to sound smooth and vocal — the dominant technique in Jeff Beck, Guthrie Govan, and Joe Satriani\'s playing.',
          activityTitle: 'Guitar',
          drillTypeId: 'guitar_technique',
          skillTitles: ['Picking', 'Scales'],
          measurements: [MeasurementResult('amount', 'BPM Achieved', 1, null) as Measurement, MeasurementResult('amount', 'Clean Runs', 2, null) as Measurement, MeasurementTarget('amount', 'Target BPM', 3, 90, false) as Measurement]),
      _DrillSpec(
          title: 'Alternate Picking Triplets',
          description:
              'On one string only, pick 3 notes per beat (triplet feel) using strict alternate picking at 60 BPM. The key rule: every beat downstroke starts with a downstroke — this requires mental triplet subdivision, not just picking fast. Track clean runs of 4 bars. This is the metronome-feel drill used by John Petrucci, Paul Gilbert, and Guthrie Govan — it trains both picking precision and rhythmic subdivision simultaneously.',
          activityTitle: 'Guitar',
          drillTypeId: 'guitar_technique',
          skillTitles: ['Picking', 'Rhythm'],
          measurements: [MeasurementResult('amount', 'BPM Achieved', 1, null) as Measurement, MeasurementResult('amount', 'Clean 4-Bar Runs', 2, null) as Measurement, MeasurementTarget('amount', 'Target BPM', 3, 100, false) as Measurement]),
      _DrillSpec(
          title: 'One Song — Daily Run-Through',
          description:
              'Pick a song from your repertoire or one you are currently learning. Play it once from start to finish, no stopping — catch-all rule: even if you make a mistake, keep going. Record a quality score (1–10) after each run. The no-stop rule is non-negotiable: stopping at mistakes trains stopping. Quality judged on: rhythmic accuracy, dynamics (loud/soft variation), and tone. Daily run-throughs reveal patterns of consistent error locations that isolated practice misses.',
          activityTitle: 'Guitar',
          drillTypeId: 'guitar_repertoire',
          skillTitles: ['Rhythm', 'Chords', 'Scales'],
          measurements: [MeasurementResult('amount', 'Run-throughs', 1, null) as Measurement, MeasurementResult('amount', 'Quality (1–10)', 2, null) as Measurement, MeasurementTarget('amount', 'Target Quality', 3, 8, false) as Measurement]),
      _DrillSpec(
          title: 'Strumming Rhythm Patterns',
          description:
              'Using an A–D–E chord loop, play through 5 different strumming patterns each session, 2 minutes per pattern: (1) D D D D, (2) D DU DU D, (3) DU DU DU DU, (4) D-skip-U-DU DU, (5) D-skip-skip-U DU. Set metronome to 80 BPM. The goal is perfect pattern consistency — every strum landing exactly on the click. Rhythm guitar is a physical discipline as much as a musical one.',
          activityTitle: 'Guitar',
          drillTypeId: 'guitar_repertoire',
          skillTitles: ['Strumming', 'Rhythm', 'Chords'],
          measurements: [MeasurementResult('amount', 'Patterns Completed', 1, null) as Measurement, MeasurementResult('amount', 'Quality (1–10)', 2, null) as Measurement, MeasurementTarget('amount', 'Target Patterns', 3, 5, false) as Measurement]),
    ];

// ─────────────────────────────────────────────────────────────────────────────
// ROUTINES
// ─────────────────────────────────────────────────────────────────────────────

/// The Firestore collection reference for the current user's routines.
CollectionReference<Map<String, dynamic>> _routinesRef() {
  final uid = auth.currentUser!.uid;
  return FirebaseFirestore.instance.collection('routines').doc(uid).collection('routines');
}

/// Stream of all routines for the current user, ordered by creation date.
Stream<QuerySnapshot<Map<String, dynamic>>> routinesStream() => _routinesRef().orderBy('created_at', descending: false).snapshots();

/// Returns the number of routines the current user has saved.
Future<int> routineCount() async {
  final snap = await _routinesRef().count().get();
  return snap.count ?? 0;
}

/// Saves a new [Routine] (and its ordered drills subcollection) to Firestore.
/// Returns the new [DocumentReference].
Future<DocumentReference> saveRoutine(Routine routine) async {
  final docRef = _routinesRef().doc();
  await docRef.set(routine.toMap());
  if (routine.drills != null) {
    for (final rd in routine.drills!) {
      await docRef.collection('drills').doc().set(rd.toMap());
    }
  }
  return docRef;
}

/// Overwrites an existing routine document and rebuilds its drills subcollection.
Future<void> updateRoutine(Routine routine) async {
  final ref = routine.reference!;
  await ref.update({
    'title': routine.title,
    'description': routine.description,
  });
  // Replace drills subcollection.
  final oldDrills = await ref.collection('drills').get();
  for (final doc in oldDrills.docs) {
    await doc.reference.delete();
  }
  if (routine.drills != null) {
    for (final rd in routine.drills!) {
      await ref.collection('drills').doc().set(rd.toMap());
    }
  }
}

/// Deletes a routine and all its drills subcollection documents.
Future<void> deleteRoutine(DocumentReference routineRef) async {
  final drillsSnap = await routineRef.collection('drills').get();
  for (final doc in drillsSnap.docs) {
    await doc.reference.delete();
  }
  await routineRef.delete();
}

/// Loads the [RoutineDrill] subcollection for a given routine reference.
Future<List<RoutineDrill>> loadRoutineDrills(DocumentReference routineRef) async {
  final snap = await routineRef.collection('drills').orderBy('order').get();
  return snap.docs.cast<DocumentSnapshot<Map<String, dynamic>>>().map(RoutineDrill.fromSnapshot).toList();
}
