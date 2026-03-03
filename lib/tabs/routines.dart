import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/models/firestore/routine.dart';
import 'package:skilldrills/models/firestore/skill_drill_user.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/services/factory.dart' as firestore_factory;
import 'package:skilldrills/tabs/routines/routine_item.dart';
import 'package:skilldrills/theme/theme.dart';

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
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _currentUser = SkillDrillsUser.fromSnapshot(doc);
      });
    }
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
          'Free plan users can save up to ${SkillDrillsUser.freeRoutineLimit} routines.\n\nUpgrade to Premium for unlimited routines.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        'Not Now',
        () => Navigator.of(context).pop(),
        'Upgrade',
        () => Navigator.of(context).pop(), // TODO: navigate to paywall
        icon: Icons.workspace_premium_rounded,
        isDangerous: false,
      ),
    );
  }

  // ── Build helpers ────────────────────────────────────────────────────────────

  /// Builds the tier badge shown to free-plan users.
  Widget _buildTierBadge(int routineCount) {
    final isPremium = _currentUser?.isPremium ?? false;
    if (isPremium) return const SizedBox.shrink();

    final atLimit = routineCount >= SkillDrillsUser.freeRoutineLimit;
    final color = atLimit ? SkillDrillsColors.warning : Theme.of(context).colorScheme.tertiary;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        SkillDrillsSpacing.md,
        SkillDrillsSpacing.sm,
        SkillDrillsSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: SkillDrillsSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SkillDrillsRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            atLimit ? Icons.lock_outline_rounded : Icons.info_outline_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              atLimit ? 'You\'ve reached the ${SkillDrillsUser.freeRoutineLimit}-routine free plan limit. Upgrade for unlimited.' : 'Free plan: $routineCount / ${SkillDrillsUser.freeRoutineLimit} routines',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          if (atLimit)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: color,
                ),
                onPressed: _showUpgradeDialog,
                child: const Text('Upgrade'),
              ),
            ),
        ],
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
                color: SkillDrillsColors.energyOrange.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_note_rounded,
                size: 52,
                color: SkillDrillsColors.energyOrange,
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
            _buildTierBadge(0),
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

    // Eagerly load drills subcollection for each routine (for subtitle count)
    for (final r in routines) {
      r.reference!.collection('drills').orderBy('order').get().then((snap) {
        final drills = snap.docs.cast<DocumentSnapshot<Map<String, dynamic>>>().map(RoutineDrill.fromSnapshot).toList();
        if (mounted) {
          setState(() {
            r.drills = drills;
          });
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTierBadge(routines.length),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: routines.length,
            itemBuilder: (ctx, i) => RoutineItem(
              routine: routines[i],
              deleteCallback: _deleteRoutine,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStream(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore_factory.routinesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
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
