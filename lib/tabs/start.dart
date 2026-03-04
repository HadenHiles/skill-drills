import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/firestore/routine.dart';
import 'package:skilldrills/models/firestore/session.dart' as session_model;
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/services/session.dart';
import 'package:skilldrills/theme/theme.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class Start extends StatefulWidget {
  const Start({super.key, this.sessionPanelController});

  final PanelController? sessionPanelController;

  @override
  State<Start> createState() => _StartState();
}

class _StartState extends State<Start> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  Stream<List<Routine>>? _routinesStream;
  final Map<String, bool> _loadingRoutines = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _routinesStream = FirebaseFirestore.instance.collection('routines').doc(uid).collection('routines').orderBy('title').snapshots().map((snap) => snap.docs.map((d) => Routine.fromSnapshot(d)).toList());
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleQuickStart() {
    if (!sessionService.isRunning) {
      sessionService.start(title: SessionService.defaultSessionTitle());
      widget.sessionPanelController?.open();
    } else {
      dialog(
        context,
        SkillDrillsDialog(
          'Override current session?',
          const Text(
            'Starting a new session will override your existing one.\n\nWould you like to continue?',
            textAlign: TextAlign.center,
          ),
          'Cancel',
          () => Navigator.of(context).pop(),
          'Continue',
          () {
            sessionService.reset();
            Navigator.of(context).pop();
            sessionService.start(title: SessionService.defaultSessionTitle());
            widget.sessionPanelController?.open();
          },
          isDangerous: false,
          icon: Icons.swap_horiz_rounded,
        ),
      );
    }
  }

  Future<void> _startFromRoutine(Routine routine) async {
    final routineId = routine.reference?.id;
    if (routineId == null) return;

    if (mounted) setState(() => _loadingRoutines[routineId] = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Load the drills subcollection
      final drillsSnap = await FirebaseFirestore.instance.collection('routines').doc(uid).collection('routines').doc(routineId).collection('drills').orderBy('order').get();

      final routineDrills = drillsSnap.docs.map((d) => RoutineDrill.fromSnapshot(d)).toList();

      // Use activity terminology from cached defaults (avoids extra Firestore join)
      final activityTitle = routine.activityTitle ?? 'General';
      final terminology = ActivityTerminology.defaultsFor(activityTitle);
      final activityIcon = ActivityTerminology.iconFor(activityTitle);

      // Build DrillResults
      final results = <session_model.DrillResult>[];
      for (var i = 0; i < routineDrills.length; i++) {
        final rd = routineDrills[i];
        final drillResult = await buildDrillResultForSession(
          drillId: rd.drillId,
          drillTitle: rd.title,
          activityTitle: activityTitle,
          activityIcon: activityIcon,
          setsLabel: terminology.setsLabel,
          repsLabel: terminology.repsLabel,
          order: i,
          sets: rd.sets,
          reps: rd.reps,
        );
        results.add(drillResult);
      }

      if (sessionService.isRunning) {
        if (!mounted) return;
        final confirmed = await _confirmOverride(context);
        if (!confirmed) {
          if (mounted) setState(() => _loadingRoutines.remove(routineId));
          return;
        }
        sessionService.reset();
      }

      sessionService.start(
        title: routine.title,
        routineId: routineId,
        routineTitle: routine.title,
      );
      for (final r in results) {
        sessionService.addDrill(r);
      }
      widget.sessionPanelController?.open();
    } finally {
      if (mounted) setState(() => _loadingRoutines.remove(routineId));
    }
  }

  Future<bool> _confirmOverride(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Override current session?'),
        content: const Text(
          'Starting a new session will override your existing one.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(SkillDrillsSpacing.md, SkillDrillsSpacing.lg, SkillDrillsSpacing.md, SkillDrillsSpacing.xxl),
          children: [
            // Quick Start section
            Padding(
              padding: const EdgeInsets.only(bottom: SkillDrillsSpacing.sm),
              child: Text(
                'Quick Start'.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            ),
            Card(
              child: InkWell(
                onTap: _handleQuickStart,
                borderRadius: SkillDrillsRadius.mdBorderRadius,
                child: Padding(
                  padding: const EdgeInsets.all(SkillDrillsSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withAlpha(20),
                          borderRadius: SkillDrillsRadius.smBorderRadius,
                        ),
                        child: Icon(Icons.play_arrow_rounded, size: 32, color: Theme.of(context).colorScheme.secondary),
                      ),
                      const SizedBox(width: SkillDrillsSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Empty Session', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'Choplin')),
                            const SizedBox(height: 2),
                            Text(
                              'Start a free-form session and add drills as you go',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: SkillDrillsSpacing.xl),

            // Routines section
            Padding(
              padding: const EdgeInsets.only(bottom: SkillDrillsSpacing.sm),
              child: Text(
                'My Routines'.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            ),
            _buildRoutinesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutinesSection() {
    if (_routinesStream == null) {
      return _emptyRoutinesCard();
    }
    return StreamBuilder<List<Routine>>(
      stream: _routinesStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        }
        final routines = snap.data ?? [];
        if (routines.isEmpty) return _emptyRoutinesCard();
        return Column(
          children: routines
              .map((r) => _RoutineCard(
                    routine: r,
                    loading: _loadingRoutines[r.reference?.id] == true,
                    onStart: () => _startFromRoutine(r),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _emptyRoutinesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SkillDrillsSpacing.xl),
        child: Column(
          children: [
            Icon(Icons.event_note_rounded, size: 40, color: Theme.of(context).colorScheme.onPrimary),
            const SizedBox(height: SkillDrillsSpacing.sm),
            Text('No routines yet', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Save drill sequences as routines for quick access here',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.loading, required this.onStart});

  final Routine routine;
  final bool loading;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final subtitle = routine.activityTitle?.isNotEmpty == true
        ? routine.activityTitle!
        : routine.description.isNotEmpty
            ? routine.description
            : '${routine.drillLabel}s';
    return Card(
      margin: const EdgeInsets.only(bottom: SkillDrillsSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(SkillDrillsSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withAlpha(18),
                borderRadius: SkillDrillsRadius.smBorderRadius,
              ),
              child: Icon(Icons.playlist_play_rounded, size: 24, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: SkillDrillsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(routine.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontFamily: 'Choplin')),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: SkillDrillsSpacing.sm),
            SizedBox(
              width: 80,
              child: ElevatedButton(
                onPressed: loading ? null : onStart,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Start', style: TextStyle(fontFamily: 'Choplin', fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
