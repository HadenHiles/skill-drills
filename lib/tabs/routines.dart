import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/firestore/routine.dart';
import 'package:skilldrills/models/firestore/skill_drill_user.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/services/factory.dart' as firestore_factory;
import 'package:skilldrills/services/subscription.dart';
import 'package:skilldrills/tabs/routines/routine_item.dart';
import 'package:skilldrills/theme/theme.dart';
import 'package:skilldrills/widgets/paywall_screen.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

class Routines extends StatefulWidget {
  const Routines({super.key});

  @override
  State<Routines> createState() => _RoutinesState();
}

class _RoutinesState extends State<Routines> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  SkillDrillsUser? _currentUser;
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
    _loadUser();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final uid = _auth.currentUser!.uid;
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('users').doc(uid).get(),
      hasActiveSubscription(),
    ]);
    final doc = results[0] as DocumentSnapshot;
    final isPro = results[1] as bool;
    if (mounted) {
      setState(() {
        if (doc.exists) _currentUser = SkillDrillsUser.fromSnapshot(doc as DocumentSnapshot<Map<String, dynamic>>);
        _isPro = isPro || (_currentUser?.isPremium ?? false);
      });
    }
  }

  // ── Activity switching ───────────────────────────────────────────────────────

  /// Ensures [activityTitle] is the active activity, applying the free-tier
  /// auto-swap if needed. Call before opening a routine to guarantee the
  /// session will be locked to the correct activity.
  Future<void> _ensureActivityActive(String activityTitle) async {
    final uid = _auth.currentUser!.uid;
    final activitiesRef = FirebaseFirestore.instance
        .collection('activities')
        .doc(uid)
        .collection('activities');

    // Already the primary active activity — nothing to do.
    if (activityTitle == activeActivityNotifier.primary?.title) return;

    final snap = await activitiesRef.where('title', isEqualTo: activityTitle).limit(1).get();
    if (snap.docs.isEmpty) return;

    final actDoc = snap.docs.first as DocumentSnapshot<Map<String, dynamic>>;
    final activity = Activity.fromSnapshot(actDoc);

    if (activity.isActive) {
      // Already in the active set but not primary — bump timestamp.
      await actDoc.reference.update({kActivityLastActivatedAtField: FieldValue.serverTimestamp()});
      return;
    }

    if (!_isPro) {
      final activeSnap = await activitiesRef.where('is_active', isEqualTo: true).get();
      final active = activeSnap.docs
          .map((d) => Activity.fromSnapshot(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      if (active.length >= kFreeActiveActivityLimit) {
        final oldest = active.reduce((a, b) {
          final ta = a.lastActivatedAt;
          final tb = b.lastActivatedAt;
          if (ta == null) return a;
          if (tb == null) return b;
          return ta.isBefore(tb) ? a : b;
        });
        final oldRef = activitiesRef.doc(oldest.reference!.id);
        final batch = FirebaseFirestore.instance.batch();
        batch.update(oldRef, {'is_active': false});
        batch.update(actDoc.reference, {
          'is_active': true,
          kActivityLastActivatedAtField: FieldValue.serverTimestamp(),
        });
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          final controller = ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              content: Text(
                  '"${oldest.title}" was deactivated to make room. Upgrade to Pro for unlimited active activities.'),
              action: SnackBarAction(
                label: 'Upgrade',
                onPressed: () => navigatorKey.currentState!.push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                ),
              ),
            ),
          );
          Future.delayed(const Duration(seconds: 5), () => controller.close());
        }
        return;
      }
    }

    await actDoc.reference.update({
      'is_active': true,
      kActivityLastActivatedAtField: FieldValue.serverTimestamp(),
    });
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  void _deleteRoutine(Routine routine) {
    firestore_factory.deleteRoutine(routine.reference!);
  }

  // ── Tier helpers ─────────────────────────────────────────────────────────────

  void _showUpgradeDialog() {
    dialog(
      context,
      SkillDrillsDialog(
        'Routine Limit Reached',
        Text(
          'Free plan users can save up to ${SkillDrillsUser.freeRoutineLimit} routines per activity.\n\nUpgrade to Pro for unlimited routines across all activities.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        'Not Now',
        () => Navigator.of(context).pop(),
        'Upgrade',
        () {
          Navigator.of(context).pop();
          navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
        },
        icon: Icons.workspace_premium_rounded,
        isDangerous: false,
      ),
    );
  }

  // ── Build helpers ────────────────────────────────────────────────────────────

  /// Inline tier chip shown in each activity section header for free users.
  Widget _buildActivityTierChip(int routineCount) {
    if (_isPro) return const SizedBox.shrink();
    final atLimit = routineCount >= SkillDrillsUser.freeRoutineLimit;
    final color = atLimit ? SkillDrillsColors.warning : Theme.of(context).colorScheme.tertiary;
    return GestureDetector(
      onTap: atLimit ? _showUpgradeDialog : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: SkillDrillsRadius.fullBorderRadius,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (atLimit) ...[Icon(Icons.lock_outline_rounded, size: 11, color: color), const SizedBox(width: 3)],
            Text(
              '$routineCount / ${SkillDrillsUser.freeRoutineLimit}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty-state placeholder shown when there are no routines.
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: SkillDrillsSpacing.lg),
            Text(
              'No Routines Yet',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SkillDrillsSpacing.sm),
            Text(
              'Build ordered drill sequences to run through during a session.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SkillDrillsSpacing.lg),
            if (!_isPro) ...[
              Text(
                'Free plan: up to ${SkillDrillsUser.freeRoutineLimit} routines per activity',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.50),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SkillDrillsSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineList(
    BuildContext context,
    List<DocumentSnapshot<Map<String, dynamic>>> snapshots,
  ) {
    if (snapshots.isEmpty) return _buildEmptyState(context);

    final routines = <Routine>[];
    for (final doc in snapshots) {
      final r = Routine.fromSnapshot(doc);
      r.id = doc.id;
      routines.add(r);
    }

    // Eagerly load drills subcollection for subtitle count.
    for (final r in routines) {
      if (r.drills == null) {
        r.reference!.collection('drills').orderBy('order').get().then((snap) {
          final drills = snap.docs.cast<DocumentSnapshot<Map<String, dynamic>>>().map(RoutineDrill.fromSnapshot).toList();
          if (mounted) setState(() => r.drills = drills);
        });
      }
    }

    // Group by activityTitle, preserving insertion order (Firestore returns
    // by created_at asc, so within each group routines are oldest-first).
    final Map<String, List<Routine>> grouped = {};
    for (final r in routines) {
      final key = r.activityTitle ?? 'General';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    final activityKeys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      itemCount: activityKeys.length,
      itemBuilder: (ctx, gi) {
        final actTitle = activityKeys[gi];
        final groupRoutines = grouped[actTitle]!;
        final groupCount = groupRoutines.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Activity section header ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SkillDrillsSpacing.md,
                SkillDrillsSpacing.sm,
                SkillDrillsSpacing.md,
                4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      actTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontFamily: 'Choplin',
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                    ),
                  ),
                  _buildActivityTierChip(groupCount),
                ],
              ),
            ),
            // ── Routine items ────────────────────────────────────────
            ...groupRoutines.map(
              (r) => RoutineItem(
                routine: r,
                deleteCallback: _deleteRoutine,
                onBeforeOpen: r.activityTitle != null
                    ? () => _ensureActivityActive(r.activityTitle!)
                    : null,
              ),
            ),
            const SizedBox(height: SkillDrillsSpacing.sm),
          ],
        );
      },
    );
  }

  Widget _buildStream(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore_factory.routinesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyState(context);
        }
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(context);
        }
        return _buildRoutineList(
          context,
          snapshot.data!.docs.cast<DocumentSnapshot<Map<String, dynamic>>>(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: _buildStream(context),
      ),
    );
  }
}
