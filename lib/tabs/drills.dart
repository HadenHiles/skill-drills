import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/firestore/drill.dart';
import 'package:skilldrills/services/factory.dart';
import 'package:skilldrills/services/subscription.dart';
import 'package:skilldrills/tabs/drills/drill_item.dart';
import 'package:skilldrills/theme/theme.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

// ─────────────────────────────────────────────────────────────────────────────
// Activity emoji map (mirrors onboarding picker)
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> _activityEmoji = {
  'Hockey': '🏒',
  'Basketball': '🏀',
  'Baseball': '⚾',
  'Golf': '⛳',
  'Soccer': '⚽',
  'Weight Training': '🏋️',
  'Tennis': '🎾',
  'Running': '🏃',
  'Volleyball': '🏐',
  'Martial Arts': '🥋',
  'Pickleball': '🏓',
  'Lacrosse': '🥍',
  'Gymnastics': '🤸',
  'Guitar': '🎸',
};

// ─────────────────────────────────────────────────────────────────────────────
// Drills tab
// ─────────────────────────────────────────────────────────────────────────────

class Drills extends StatefulWidget {
  const Drills({super.key});

  @override
  State<Drills> createState() => _DrillsState();
}

class _DrillsState extends State<Drills> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isPro = false;
  StreamSubscription<dynamic>? _customerInfoSub;

  /// Expanded state per activity title. Defaults to true (open).
  final Map<String, bool> _expanded = {};

  bool _isExpanded(String title) => _expanded[title] ?? false;

  void _toggle(String title) => setState(() => _expanded[title] = !_isExpanded(title));

  // ── Streams ──────────────────────────────────────────────────────────────
  // These MUST be late final fields, not getters. StreamBuilder compares stream
  // identity on every build — if a new Stream object is returned each time,
  // StreamBuilder cancels the old subscription and re-subscribes, which resets
  // it to ConnectionState.waiting and shows the loading spinner forever.

  late final Stream<List<Activity>> _activitiesStream;
  late final Stream<List<Drill>> _drillsStream;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final uid = auth.currentUser!.uid;
    _activitiesStream = FirebaseFirestore.instance.collection('activities').doc(uid).collection('activities').orderBy('title').snapshots().map((s) => s.docs.map(Activity.fromSnapshot).where((a) => a.isActive).toList());
    _drillsStream = FirebaseFirestore.instance.collection('drills').doc(uid).collection('drills').orderBy('title').snapshots().map((s) => s.docs.map((d) => Drill.fromSnapshot(d as DocumentSnapshot<Map<String, dynamic>>)).toList());
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
    _initProStatus();
  }

  Future<void> _initProStatus() async {
    final isPro = await hasActiveSubscription();
    if (mounted) setState(() => _isPro = isPro);
    _customerInfoSub = customerInfoStream.listen((info) {
      if (mounted) setState(() => _isPro = info.entitlements.active.containsKey(kProEntitlement));
    });
  }

  @override
  void dispose() {
    _customerInfoSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isBootstrapping,
      builder: (context, bootstrapping, _) {
        return StreamBuilder<List<Activity>>(
          stream: _activitiesStream,
          builder: (context, actSnap) {
            return StreamBuilder<List<Drill>>(
              stream: _drillsStream,
              builder: (context, drillSnap) {
                if (!actSnap.hasData || !drillSnap.hasData) {
                  return _loadingState(context, bootstrapping);
                }

                final activities = actSnap.data!;
                final drills = drillSnap.data!;

                // Group drills by activity title, restricted to active activities
                final Map<String, List<Drill>> grouped = {
                  for (final a in activities) a.title!: [],
                };
                for (final d in drills) {
                  final t = d.activity?.title;
                  if (t != null && grouped.containsKey(t)) grouped[t]!.add(d);
                }

                // During bootstrap hide sections that are still empty so the
                // list doesn't jump around as drills trickle in.
                final visible = bootstrapping ? activities.where((a) => grouped[a.title!]!.isNotEmpty).toList() : activities;

                final total = visible.fold<int>(0, (s, a) => s + grouped[a.title!]!.length);

                if (total == 0 && bootstrapping) {
                  return _loadingState(context, true);
                }
                if (visible.isEmpty) return _emptyState(context);

                return _groupedList(context, visible, grouped, bootstrapping);
              },
            );
          },
        );
      },
    );
  }

  // ── Grouped list ──────────────────────────────────────────────────────────

  Widget _groupedList(
    BuildContext context,
    List<Activity> activities,
    Map<String, List<Drill>> grouped,
    bool bootstrapping,
  ) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final activity = activities[i];
                final title = activity.title!;
                final sectionDrills = grouped[title]!;
                final open = _isExpanded(title);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: _ActivitySection(
                    activityTitle: title,
                    drills: sectionDrills,
                    expanded: open,
                    onHeaderTap: () => _toggle(title),
                    deleteCallback: _deleteDrill,
                    isPro: _isPro,
                    uid: auth.currentUser!.uid,
                  ),
                );
              },
              childCount: activities.length,
            ),
          ),
        ),
        if (!bootstrapping)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Only active activities are shown.\nManage them in Profile → Settings.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35)),
              ),
            ),
          ),
      ],
    );
  }

  // ── Loading / empty ───────────────────────────────────────────────────────

  Widget _loadingState(BuildContext context, bool bootstrapping) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                bootstrapping ? Icons.construction_rounded : Icons.fitness_center_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: SkillDrillsSpacing.lg),
            Text(
              bootstrapping ? 'Building Your Library…' : 'Loading Drills…',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SkillDrillsSpacing.sm),
            Text(
              bootstrapping ? 'Setting up your default drill templates.\nThis only happens once.' : 'Hang tight…',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SkillDrillsSpacing.lg),
            if (bootstrapping)
              ValueListenableBuilder<BootstrapProgress>(
                valueListenable: bootstrapProgress,
                builder: (context, progress, _) {
                  return Column(
                    children: [
                      _BootstrapProgressRow(label: 'Activities & Skills', stage: progress.activities),
                      const SizedBox(height: SkillDrillsSpacing.sm),
                      _BootstrapProgressRow(label: 'Drill Templates', stage: progress.drillTypes),
                      const SizedBox(height: SkillDrillsSpacing.sm),
                      if (progress.drills == BootstrapStage.loading) const _DrillSeedProgressWidget() else _BootstrapProgressRow(label: 'Default Drills', stage: progress.drills),
                    ],
                  );
                },
              )
            else
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fitness_center_rounded, size: 52, color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(height: SkillDrillsSpacing.lg),
            Text('No Drills Yet', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: SkillDrillsSpacing.sm),
            Text('Tap the + button to create your first drill', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  void _deleteDrill(Drill drill) {
    final ref = FirebaseFirestore.instance.collection('drills').doc(auth.currentUser!.uid).collection('drills').doc(drill.reference!.id);

    ref.get().then((doc) {
      doc.reference.collection('measurements').get().then((snap) {
        for (var d in snap.docs) {
          d.reference.delete();
        }
      });
      doc.reference.collection('skills').get().then((snap) {
        for (var d in snap.docs) {
          d.reference.delete();
        }
      });
      doc.reference.delete();
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity section – header + animated body in one card
// ─────────────────────────────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  final String activityTitle;
  final List<Drill> drills;
  final bool expanded;
  final VoidCallback onHeaderTap;
  final Function deleteCallback;
  final bool isPro;
  final String uid;

  const _ActivitySection({
    required this.activityTitle,
    required this.drills,
    required this.expanded,
    required this.onHeaderTap,
    required this.deleteCallback,
    required this.isPro,
    required this.uid,
  });

  Future<void> _reorderPinned(List<Drill> pinned, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex--;
    final reordered = List.of(pinned);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < reordered.length; i++) {
      if (reordered[i].reference != null) {
        batch.update(reordered[i].reference!, {'sort_order': i});
      }
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final emoji = _activityEmoji[activityTitle] ?? '🏅';

    return Material(
      color: colorScheme.surface,
      borderRadius: SkillDrillsRadius.mdBorderRadius,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          InkWell(
            onTap: onHeaderTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      activityTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontFamily: 'Choplin',
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  // Drill count badge
                  if (drills.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: SkillDrillsColors.brandBlue.withValues(alpha: 0.12),
                        borderRadius: SkillDrillsRadius.fullBorderRadius,
                      ),
                      child: Text(
                        '${drills.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: SkillDrillsColors.brandBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Animated chevron
                  AnimatedRotation(
                    turns: expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 22,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Animated body ────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: colorScheme.onSurface.withValues(alpha: 0.07),
                      ),
                      if (drills.isEmpty) _emptyGroup(context),
                      if (isPro) _buildProDrillList(context) else _buildFreeDrillList(context),
                      if (drills.isNotEmpty) const SizedBox(height: 6),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeDrillList(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < drills.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DrillItem(drill: drills[i], deleteCallback: deleteCallback, isPro: isPro),
          ),
          if (i < drills.length - 1) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
        ],
      ],
    );
  }

  Widget _buildProDrillList(BuildContext context) {
    final pinned = drills.where((d) => d.isPinned).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final unpinned = drills.where((d) => !d.isPinned).toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pinned.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'PINNED',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Theme.of(context).primaryColor,
                  ),
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) => _reorderPinned(pinned, oldIndex, newIndex),
            children: [
              for (int i = 0; i < pinned.length; i++)
                Padding(
                  key: ValueKey(pinned[i].reference!.id),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, right: 2),
                          child: Icon(Icons.drag_handle_rounded, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.35)),
                        ),
                      ),
                      Expanded(
                        child: DrillItem(drill: pinned[i], deleteCallback: deleteCallback, isPro: isPro),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (unpinned.isNotEmpty) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: colorScheme.onSurface.withValues(alpha: 0.07)),
        ],
        for (int i = 0; i < unpinned.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DrillItem(drill: unpinned[i], deleteCallback: deleteCallback, isPro: isPro),
          ),
          if (i < unpinned.length - 1) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: colorScheme.onSurface.withValues(alpha: 0.05)),
        ],
      ],
    );
  }

  Widget _emptyGroup(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35)),
          const SizedBox(width: 8),
          Text(
            'No drills yet — tap + to add one',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-activity drill seed progress widget
// ─────────────────────────────────────────────────────────────────────────────

class _DrillSeedProgressWidget extends StatefulWidget {
  const _DrillSeedProgressWidget();

  @override
  State<_DrillSeedProgressWidget> createState() => _DrillSeedProgressWidgetState();
}

class _DrillSeedProgressWidgetState extends State<_DrillSeedProgressWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return ValueListenableBuilder<DrillSeedProgress>(
      valueListenable: drillSeedProgress,
      builder: (context, progress, _) {
        final fraction = progress.drillsTotal > 0 ? progress.drillsDone / progress.drillsTotal : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Default Drills',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                      ),
                      if (progress.activityName.isNotEmpty) ...[const SizedBox(height: 2), Text(progress.activityName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(progress.activityName),
                tween: Tween<double>(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_expanded ? 'Less' : 'More', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
                  Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: color),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildDetails(context, progress, color),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetails(BuildContext context, DrillSeedProgress progress, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final activity in progress.completedActivities)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(activity, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          if (progress.activityName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: color)),
                  const SizedBox(width: 6),
                  Text(
                    '${progress.activityName} — ${progress.drillsDone} of ${progress.drillsTotal}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bootstrap progress row – label + linear progress bar + status icon
// ─────────────────────────────────────────────────────────────────────────────

class _BootstrapProgressRow extends StatelessWidget {
  final String label;
  final BootstrapStage stage;

  const _BootstrapProgressRow({required this.label, required this.stage});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    final isDone = stage == BootstrapStage.done;
    final isLoading = stage == BootstrapStage.loading;
    final isPending = stage == BootstrapStage.pending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isPending ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38) : Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: isDone
                  ? Icon(Icons.check_circle_rounded, key: const ValueKey('done'), size: 18, color: color)
                  : isLoading
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: color),
                        )
                      : SizedBox(key: const ValueKey('pending'), width: 18, height: 18),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: isDone ? 1.0 : (isPending ? 0.0 : null),
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(isDone ? color : (isLoading ? color : Colors.transparent)),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
