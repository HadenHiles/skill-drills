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
  Stream<List<session_model.Session>>? _recentSessionsStream;
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
      _recentSessionsStream = FirebaseFirestore.instance.collection('sessions').doc(uid).collection('sessions').orderBy('started_at', descending: true).limit(3).snapshots().map((snap) => snap.docs
          .map((d) => session_model.Session.fromSnapshot(
                d as DocumentSnapshot<Map<String, dynamic>>,
              ))
          .toList());
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleQuickStart() async {
    if (sessionService.isRunning) {
      if (!mounted) return;
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
            _pickActivityAndStart();
          },
          isDangerous: false,
          icon: Icons.swap_horiz_rounded,
        ),
      );
      return;
    }
    await _pickActivityAndStart();
  }

  Future<void> _pickActivityAndStart() async {
    if (!mounted) return;
    final activity = await showModalBottomSheet<Activity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ActivityPickerSheet(),
    );
    if (activity == null || !mounted) return;

    final terminology = ActivityTerminology.defaultsFor(activity.title);
    sessionService.start(
      title: SessionService.defaultSessionTitle(),
      activityTitle: activity.title,
      activityIcon: activity.icon,
      setsLabel: activity.setsLabel.isNotEmpty ? activity.setsLabel : terminology.setsLabel,
      repsLabel: activity.repsLabel.isNotEmpty ? activity.repsLabel : terminology.repsLabel,
    );
    widget.sessionPanelController?.open();
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

            // Recent Sessions section
            if (_recentSessionsStream != null) ..._buildRecentSessionsSection(),

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

  List<Widget> _buildRecentSessionsSection() {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: SkillDrillsSpacing.sm),
        child: Text(
          'Recent Sessions'.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
        ),
      ),
      StreamBuilder<List<session_model.Session>>(
        stream: _recentSessionsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          }
          final sessions = snap.data ?? [];
          if (sessions.isEmpty) return const SizedBox.shrink();
          return Column(
            children: sessions.map((s) => _RecentSessionCard(session: s)).toList(),
          );
        },
      ),
      const SizedBox(height: SkillDrillsSpacing.xl),
    ];
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

// ─────────────────────────────────────────────────────────────────────────────

class _RecentSessionCard extends StatelessWidget {
  const _RecentSessionCard({required this.session});

  final session_model.Session session;

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '—';
    final d = Duration(seconds: seconds);
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: SkillDrillsSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SkillDrillsSpacing.md, vertical: SkillDrillsSpacing.sm),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withAlpha(18),
                borderRadius: SkillDrillsRadius.smBorderRadius,
              ),
              child: Icon(Icons.history_rounded, size: 22, color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(width: SkillDrillsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontFamily: 'Choplin'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    children: [
                      _Chip(label: _dateLabel(session.startedAt)),
                      _Chip(label: _formatTime(session.startedAt)),
                      _Chip(label: _formatDuration(session.durationSeconds)),
                      _Chip(
                        label: '${session.drillCount} drill${session.drillCount == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity picker bottom sheet – shown when starting an empty session.
// Never caches the selection; always starts fresh each time.
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityPickerSheet extends StatefulWidget {
  const _ActivityPickerSheet();

  @override
  State<_ActivityPickerSheet> createState() => _ActivityPickerSheetState();
}

class _ActivityPickerSheetState extends State<_ActivityPickerSheet> {
  List<Activity> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final snap = await FirebaseFirestore.instance.collection('activities').doc(uid).collection('activities').orderBy('title').get();
    if (!mounted) return;
    setState(() {
      _activities = snap.docs.map(Activity.fromSnapshot).where((a) => a.isActive).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(SkillDrillsRadius.lg)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: SkillDrillsRadius.fullBorderRadius,
              ),
            ),
          ),
          Text(
            'Choose Activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'Choplin',
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'What are you training today?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 32), child: CircularProgressIndicator()))
          else if (_activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No active activities found.\nAdd activities in your profile first.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ...(_activities.map(
              (a) => InkWell(
                onTap: () => Navigator.of(context).pop(a),
                borderRadius: SkillDrillsRadius.mdBorderRadius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withAlpha(18),
                          borderRadius: SkillDrillsRadius.smBorderRadius,
                        ),
                        child: Center(
                          child: Text(a.icon, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          a.title ?? '',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontFamily: 'Choplin',
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Theme.of(context).colorScheme.onPrimary),
                    ],
                  ),
                ),
              ),
            )),
        ],
      ),
    );
  }
}
