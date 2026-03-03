import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/firestore/skill.dart';
import 'package:skilldrills/models/firestore/drill.dart';
import 'package:skilldrills/models/firestore/drill_type.dart';
import 'package:skilldrills/models/firestore/measurement.dart';
import 'package:skilldrills/models/firestore/measurement_target.dart';
import 'package:skilldrills/models/firestore/measurement_result.dart';
import 'package:skilldrills/models/firestore/skill_drill_user.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

// ─────────────────────────────────────────────────────────────────────────────
// Bootstrap entry point (called from Nav.initState)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> bootstrap() async {
  addUser();
  await Future.wait([bootstrapActivities(), bootstrapDrillTypes()]);
  await bootstrapDrills();
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

Future<void> bootstrapActivities() async {
  final snapshot = await FirebaseFirestore.instance.collection("activities").doc(auth.currentUser!.uid).collection("activities").get();
  if (snapshot.docs.isEmpty) {
    await resetActivities();
  }
}

Future<void> resetActivities() async {
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
  };
  for (var entry in activitySkills.entries) {
    final a = Activity(entry.key, null);
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
// DRILL TYPES  (6 universal + 4 per activity × 6 activities = 30 total)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> bootstrapDrillTypes() async {
  final uid = auth.currentUser!.uid;
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
          MeasurementTarget('duration', 'Target Time', 2, null, true) as Measurement,
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
          MeasurementTarget('duration', 'Target Time', 3, null, true) as Measurement,
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
          MeasurementTarget('amount', 'Target Strikes', 3, null, false) as Measurement,
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
          MeasurementTarget('amount', 'Target Weight (kg)', 4, null, false) as Measurement,
          MeasurementTarget('amount', 'Target Reps', 5, null, false) as Measurement,
        ],
      DrillType('weight_isolation', 'Isolation Exercise', 'Single-joint dumbbell or cable exercise', 0, 28, activityKey: 'Weight Training')
        ..measurements = [
          MeasurementResult('amount', 'Sets', 1, null) as Measurement,
          MeasurementResult('amount', 'Reps', 2, null) as Measurement,
          MeasurementResult('amount', 'Weight (kg)', 3, null) as Measurement,
          MeasurementTarget('amount', 'Target Reps', 4, null, false) as Measurement,
        ],
      DrillType('weight_bodyweight', 'Bodyweight Exercise', 'No-equipment exercise — push-ups, pull-ups, dips, etc.', 0, 29, activityKey: 'Weight Training')
        ..measurements = [
          MeasurementResult('amount', 'Sets', 1, null) as Measurement,
          MeasurementResult('amount', 'Reps', 2, null) as Measurement,
          MeasurementTarget('amount', 'Target Reps', 3, null, false) as Measurement,
        ],
      DrillType('weight_cardio', 'Cardio', 'Aerobic conditioning with duration and optional distance', 0, 30, activityKey: 'Weight Training')
        ..measurements = [
          MeasurementResult('duration', 'Duration', 1, null) as Measurement,
          MeasurementResult('amount', 'Distance (km)', 2, null) as Measurement,
          MeasurementTarget('duration', 'Target Duration', 3, null, false) as Measurement,
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

  final actSnap = await FirebaseFirestore.instance.collection('activities').doc(uid).collection('activities').get();
  final Map<String, Activity> activityMap = {};
  for (var doc in actSnap.docs) {
    final a = Activity.fromSnapshot(doc);
    final skillSnap = await doc.reference.collection('skills').get();
    a.skills = skillSnap.docs.map((s) => Skill.fromSnapshot(s)).toList();
    activityMap[a.title!] = a;
  }

  final dtSnap = await FirebaseFirestore.instance.collection('drill_types').doc(uid).collection('drill_types').get();
  final Map<String, DrillType> drillTypeMap = {};
  for (var doc in dtSnap.docs) {
    final dt = DrillType.fromSnapshot(doc);
    final mSnap = await doc.reference.collection('measurements').orderBy('order').get();
    dt.measurements = mSnap.docs.map((m) => Measurement.fromSnapshot(m)).toList();
    drillTypeMap[dt.id!] = dt;
  }

  Skill? findSkill(String activityTitle, String skillTitle) {
    try {
      return activityMap[activityTitle]?.skills?.firstWhere((s) => s.title == skillTitle);
    } catch (_) {
      return null;
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
    await newRef.set(Drill(spec.title, spec.description, actSnap2, drillType).toMap());
    for (final m in spec.measurements) {
      await newRef.collection('measurements').doc().set(m.toMap());
    }
    for (final s in skills) {
      await newRef.collection('skills').doc().set(s.toMap());
    }
  }
}

List<_DrillSpec> _defaultDrillSpecs() => [
      // ── Hockey
      _DrillSpec(
          title: '5-Hole Shooting',
          description: 'Alternate shots targeting the five-hole from the top of the circles. Focus on quick release and accuracy.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_shot_accuracy',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Goals Scored', 1, null) as Measurement, MeasurementResult('amount', 'Shots Taken', 2, null) as Measurement, MeasurementTarget('amount', 'Target Goals', 3, 15, false) as Measurement]),
      _DrillSpec(
          title: 'Figure 8 Stickhandling',
          description: 'Weave the puck in a figure 8 around two cones, alternating backhand/forehand each lap.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_stickhandling',
          skillTitles: ['Stickhandling'],
          measurements: [MeasurementResult('amount', 'Laps / Reps', 1, null) as Measurement, MeasurementResult('duration', 'Time', 2, null) as Measurement, MeasurementTarget('amount', 'Target Laps', 3, 20, false) as Measurement]),
      _DrillSpec(
          title: 'Edge Work Circles',
          description: 'Inside and outside edge work around all five face-off circles. Lower completion time is better.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_skating_time',
          skillTitles: ['Skating'],
          measurements: [MeasurementResult('duration', 'Completion Time', 1, null) as Measurement, MeasurementTarget('duration', 'Target Time', 2, 90, true) as Measurement]),
      _DrillSpec(
          title: 'Cross-Ice Passes',
          description: 'Pass tape-to-tape across the neutral zone with a partner or rebounder. Focus on weight and accuracy.',
          activityTitle: 'Hockey',
          drillTypeId: 'hockey_passing',
          skillTitles: ['Passing'],
          measurements: [MeasurementResult('amount', 'Passes Made', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Passes', 3, 40, false) as Measurement]),
      // ── Basketball
      _DrillSpec(
          title: 'Free Throw Streak',
          description: 'Shoot free throws focusing on consistent form and follow-through. Track makes out of 50 attempts.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_free_throw',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Makes', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Makes', 3, 40, false) as Measurement]),
      _DrillSpec(
          title: 'Mikan Drill',
          description: 'Alternating layups from each side without the ball touching the floor between shots. 20 attempts.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_shooting',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Makes', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Makes', 3, 18, false) as Measurement]),
      _DrillSpec(
          title: 'Cone Dribble Circuit',
          description: 'Dribble through a cone slalom alternating dominant and off-hand. Track time and cones hit.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_dribbling',
          skillTitles: ['Dribbling'],
          measurements: [MeasurementResult('duration', 'Completion Time', 1, null) as Measurement, MeasurementResult('amount', 'Errors', 2, null) as Measurement, MeasurementTarget('duration', 'Target Time', 3, 30, true) as Measurement]),
      _DrillSpec(
          title: '5-Spot Shooting Chart',
          description: '5 shots from 5 spots around the 3-point arc. Goal is 15 makes out of 25 total attempts.',
          activityTitle: 'Basketball',
          drillTypeId: 'basketball_shooting',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Makes', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Makes', 3, 15, false) as Measurement]),
      // ── Baseball
      _DrillSpec(
          title: 'Tee Work',
          description: 'Swing off the tee targeting solid contact at different heights and plate positions. 30 swings per set.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_batting',
          skillTitles: ['Hitting'],
          measurements: [MeasurementResult('amount', 'Solid Hits', 1, null) as Measurement, MeasurementResult('amount', 'Swings', 2, null) as Measurement, MeasurementTarget('amount', 'Target Hits', 3, 24, false) as Measurement]),
      _DrillSpec(
          title: 'Soft Toss',
          description: 'Partner-fed soft toss into the hitting zone. Focus on staying back and driving through the ball.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_batting',
          skillTitles: ['Hitting'],
          measurements: [MeasurementResult('amount', 'Solid Hits', 1, null) as Measurement, MeasurementResult('amount', 'Swings', 2, null) as Measurement, MeasurementTarget('amount', 'Target Hits', 3, 25, false) as Measurement]),
      _DrillSpec(
          title: 'Long Toss',
          description: 'Progressive distance throwing to build arm strength and accuracy. Start at 30 ft, extend to max.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_throwing',
          skillTitles: ['Throwing'],
          measurements: [MeasurementResult('amount', 'On Target', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Throws', 3, 17, false) as Measurement]),
      _DrillSpec(
          title: 'Ground Ball Work',
          description: 'Fielding ground balls hit directly and to backhand/forehand. Focus on staying low and clean transfers.',
          activityTitle: 'Baseball',
          drillTypeId: 'baseball_fielding',
          skillTitles: ['Ground Balls'],
          measurements: [MeasurementResult('amount', 'Clean Fielded', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Clean', 3, 17, false) as Measurement]),
      // ── Golf
      _DrillSpec(
          title: 'Gate Putting',
          description: 'Place two tees as a gate just wider than the ball and roll putts through from 3, 6, and 10 feet.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_putting',
          skillTitles: ['Putt'],
          measurements: [MeasurementResult('amount', 'Makes', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Makes', 3, 24, false) as Measurement]),
      _DrillSpec(
          title: '100-Ball Chip Challenge',
          description: 'Hit 20 chips from 5 different lies. Count balls finishing within a club-length of the hole.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_short_game',
          skillTitles: ['Chip'],
          measurements: [MeasurementResult('amount', 'In Zone', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target In Zone', 3, 14, false) as Measurement]),
      _DrillSpec(
          title: 'Fairway Target Drive',
          description: 'Drive to targets in the fairway, tracking which side you land on. 10 drives per session.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_driving',
          skillTitles: ['Drive'],
          measurements: [MeasurementResult('amount', 'Fairways Hit', 1, null) as Measurement, MeasurementResult('amount', 'Drives', 2, null) as Measurement, MeasurementTarget('amount', 'Target Fairways', 3, 7, false) as Measurement]),
      _DrillSpec(
          title: '9-Club Iron Challenge',
          description: 'One shot with each iron to a flagstick. Track proximity and greens hit in regulation.',
          activityTitle: 'Golf',
          drillTypeId: 'golf_iron_play',
          skillTitles: ['Approach'],
          measurements: [MeasurementResult('amount', 'Greens Hit', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Greens', 3, 6, false) as Measurement]),
      // ── Soccer
      _DrillSpec(
          title: 'Juggling Challenge',
          description: 'Keep the ball in the air using alternating feet. Track your best consecutive streak each session.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_juggling',
          skillTitles: ['Ball Control'],
          measurements: [MeasurementResult('amount', 'Best Streak', 1, null) as Measurement, MeasurementTarget('amount', 'Target Streak', 2, 20, false) as Measurement]),
      _DrillSpec(
          title: 'Wall Passing Drill',
          description: 'One-touch and two-touch passes against a wall. Focus on weight, accuracy, and first touch.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_passing',
          skillTitles: ['Passing'],
          measurements: [MeasurementResult('amount', 'Successful', 1, null) as Measurement, MeasurementResult('amount', 'Attempts', 2, null) as Measurement, MeasurementTarget('amount', 'Target Passes', 3, 45, false) as Measurement]),
      _DrillSpec(
          title: 'Cone Slalom Dribble',
          description: 'Dribble through 10 cones using inside and outside of both feet at pace. Track time and errors.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_dribbling',
          skillTitles: ['Dribbling'],
          measurements: [MeasurementResult('duration', 'Completion Time', 1, null) as Measurement, MeasurementResult('amount', 'Errors', 2, null) as Measurement, MeasurementTarget('duration', 'Target Time', 3, 25, true) as Measurement]),
      _DrillSpec(
          title: 'Shooting on Target',
          description: 'Strike on goal from various positions targeting corners and zones. 20 attempts per session.',
          activityTitle: 'Soccer',
          drillTypeId: 'soccer_shooting',
          skillTitles: ['Shooting'],
          measurements: [MeasurementResult('amount', 'Goals', 1, null) as Measurement, MeasurementResult('amount', 'Shots on Target', 2, null) as Measurement, MeasurementResult('amount', 'Attempts', 3, null) as Measurement, MeasurementTarget('amount', 'Target Goals', 4, 12, false) as Measurement]),
      // ── Weight Training
      _DrillSpec(title: 'Back Squat', description: 'Barbell back squat focusing on depth below parallel and maintaining a neutral spine.', activityTitle: 'Weight Training', drillTypeId: 'weight_compound', skillTitles: [
        'Legs'
      ], measurements: [
        MeasurementResult('amount', 'Sets', 1, null) as Measurement,
        MeasurementResult('amount', 'Reps', 2, null) as Measurement,
        MeasurementResult('amount', 'Weight (kg)', 3, null) as Measurement,
        MeasurementTarget('amount', 'Target Weight (kg)', 4, null, false) as Measurement,
        MeasurementTarget('amount', 'Target Reps', 5, 5, false) as Measurement
      ]),
      _DrillSpec(title: 'Barbell Bench Press', description: 'Flat barbell bench press for chest, shoulder, and tricep development.', activityTitle: 'Weight Training', drillTypeId: 'weight_compound', skillTitles: [
        'Chest'
      ], measurements: [
        MeasurementResult('amount', 'Sets', 1, null) as Measurement,
        MeasurementResult('amount', 'Reps', 2, null) as Measurement,
        MeasurementResult('amount', 'Weight (kg)', 3, null) as Measurement,
        MeasurementTarget('amount', 'Target Weight (kg)', 4, null, false) as Measurement,
        MeasurementTarget('amount', 'Target Reps', 5, 8, false) as Measurement
      ]),
      _DrillSpec(title: 'Deadlift', description: 'Conventional deadlift for posterior chain strength. Keep the bar close and drive through the floor.', activityTitle: 'Weight Training', drillTypeId: 'weight_compound', skillTitles: [
        'Back'
      ], measurements: [
        MeasurementResult('amount', 'Sets', 1, null) as Measurement,
        MeasurementResult('amount', 'Reps', 2, null) as Measurement,
        MeasurementResult('amount', 'Weight (kg)', 3, null) as Measurement,
        MeasurementTarget('amount', 'Target Weight (kg)', 4, null, false) as Measurement,
        MeasurementTarget('amount', 'Target Reps', 5, 5, false) as Measurement
      ]),
      _DrillSpec(title: 'Overhead Press', description: 'Standing barbell shoulder press. Brace the core and keep the bar over mid-foot.', activityTitle: 'Weight Training', drillTypeId: 'weight_compound', skillTitles: [
        'Shoulders'
      ], measurements: [
        MeasurementResult('amount', 'Sets', 1, null) as Measurement,
        MeasurementResult('amount', 'Reps', 2, null) as Measurement,
        MeasurementResult('amount', 'Weight (kg)', 3, null) as Measurement,
        MeasurementTarget('amount', 'Target Weight (kg)', 4, null, false) as Measurement,
        MeasurementTarget('amount', 'Target Reps', 5, 8, false) as Measurement
      ]),
      _DrillSpec(
          title: 'Pull-ups',
          description: 'Bodyweight pull-ups for back and bicep development. Use a resistance band for assistance if needed.',
          activityTitle: 'Weight Training',
          drillTypeId: 'weight_bodyweight',
          skillTitles: ['Back'],
          measurements: [MeasurementResult('amount', 'Sets', 1, null) as Measurement, MeasurementResult('amount', 'Reps', 2, null) as Measurement, MeasurementTarget('amount', 'Target Reps', 3, 10, false) as Measurement]),
    ];
