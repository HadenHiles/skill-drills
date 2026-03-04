import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/firestore/drill.dart';
import 'package:skilldrills/models/firestore/session.dart' as session_model;
import 'package:skilldrills/services/session.dart';
import 'package:skilldrills/tabs/drills/drill_detail.dart';
import 'package:skilldrills/theme/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the Add Drill bottom sheet. When the user selects a drill the sheet
/// fetches its measurement subcollection, builds a [session_model.DrillResult],
/// and calls [onDrillAdded].
Future<void> showAddDrillSheet(
  BuildContext context, {
  required ValueChanged<session_model.DrillResult> onDrillAdded,
  required int nextOrder,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddDrillSheet(
      onDrillAdded: onDrillAdded,
      nextOrder: nextOrder,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _AddDrillSheet extends StatefulWidget {
  const _AddDrillSheet({
    required this.onDrillAdded,
    required this.nextOrder,
  });

  final ValueChanged<session_model.DrillResult> onDrillAdded;
  final int nextOrder;

  @override
  State<_AddDrillSheet> createState() => _AddDrillSheetState();
}

class _AddDrillSheetState extends State<_AddDrillSheet> {
  final _searchCtrl = TextEditingController();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  List<Activity> _activities = [];
  List<Drill> _drills = [];
  String _query = '';

  /// Drill IDs currently loading (awaiting measurement fetch).
  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('activities').doc(_uid).collection('activities').orderBy('title').get(),
      FirebaseFirestore.instance.collection('drills').doc(_uid).collection('drills').orderBy('title').get(),
    ]);

    if (!mounted) return;

    final activities = results[0].docs.map(Activity.fromSnapshot).where((a) => a.isActive).toList();

    final drills = results[1].docs.cast<DocumentSnapshot<Map<String, dynamic>>>().map(Drill.fromSnapshot).toList();

    setState(() {
      _activities = activities;
      _drills = drills;
    });
  }

  // ── Drill selection ─────────────────────────────────────────────────────────

  Future<void> _selectDrill(Drill drill, Activity activity) async {
    final drillId = drill.reference!.id;
    setState(() => _loading.add(drillId));

    try {
      final drillResult = await buildDrillResultForSession(
        drillId: drillId,
        drillTitle: drill.title!,
        activityTitle: activity.title!,
        activityIcon: activity.icon,
        setsLabel: activity.setsLabel,
        repsLabel: activity.repsLabel,
        order: widget.nextOrder,
      );

      if (mounted) {
        widget.onDrillAdded(drillResult);
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _loading.remove(drillId));
    }
  }

  // ── Create new drill ───────────────────────────────────────────────────────

  Future<void> _createNewDrill() async {
    final newDrill = await navigatorKey.currentState!.push<Drill?>(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, _) => const DrillDetail(),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (ctx, anim, _, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );

    if (!mounted) return;

    if (newDrill != null && newDrill.reference != null && newDrill.activity != null) {
      // Auto-add the newly created drill directly to the session
      await _selectDrill(newDrill, newDrill.activity!);
    } else {
      // Refresh the list so the new drill appears for manual selection
      _load();
    }
  }

  // ── Filtered data ───────────────────────────────────────────────────────────

  List<Drill> _drillsFor(String activityTitle) {
    return _drills.where((d) {
      final matchActivity = d.activity?.title == activityTitle;
      if (!matchActivity) return false;
      if (_query.isEmpty) return true;
      return (d.title?.toLowerCase().contains(_query) ?? false) || (d.description?.toLowerCase().contains(_query) ?? false);
    }).toList();
  }

  bool get _hasResults => _activities.any((a) => _drillsFor(a.title!).isNotEmpty);

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(SkillDrillsRadius.lg),
            ),
          ),
          child: Column(
            children: [
              // ── Sheet handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: SkillDrillsRadius.fullBorderRadius,
                  ),
                ),
              ),

              // ── Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Text(
                      'Add a Drill',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontFamily: 'Choplin',
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // ── Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search drills…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                  ),
                ),
              ),

              // ── List
              Expanded(
                child: _activities.isEmpty
                    ? _buildEmptyState()
                    : !_hasResults && _query.isNotEmpty
                        ? _buildNoResults()
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.only(bottom: 32),
                            itemCount: _activities.length + 1, // +1 for "Create new drill"
                            itemBuilder: (context, i) {
                              if (i == 0) {
                                return _buildCreateDrillTile(context);
                              }
                              final activity = _activities[i - 1];
                              final sectionDrills = _drillsFor(activity.title!);
                              if (sectionDrills.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return _ActivitySection(
                                activity: activity,
                                drills: sectionDrills,
                                loading: _loading,
                                onSelect: _selectDrill,
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateDrillTile(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _createNewDrill,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withAlpha(18),
                    borderRadius: SkillDrillsRadius.smBorderRadius,
                  ),
                  child: Icon(Icons.add_rounded, color: Theme.of(context).primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Create a new drill',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).primaryColor, size: 20),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fitness_center_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(height: SkillDrillsSpacing.sm),
              Text(
                'No drills yet',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Create your first drill to add it to this session',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SkillDrillsSpacing.lg),
              OutlinedButton.icon(
                onPressed: _createNewDrill,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create a new drill'),
              ),
            ],
          ),
        ),
      );

  Widget _buildNoResults() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 40, color: Theme.of(context).colorScheme.onPrimary),
              const SizedBox(height: 8),
              Text(
                'No drills match "$_query"',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.activity,
    required this.drills,
    required this.loading,
    required this.onSelect,
  });

  final Activity activity;
  final List<Drill> drills;
  final Set<String> loading;
  final Future<void> Function(Drill, Activity) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Text(
                activity.icon,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                activity.title!.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
              ),
            ],
          ),
        ),
        ...drills.map((drill) => _DrillTile(
              drill: drill,
              activity: activity,
              isLoading: loading.contains(drill.reference?.id ?? ''),
              onTap: () => onSelect(drill, activity),
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DrillTile extends StatelessWidget {
  const _DrillTile({
    required this.drill,
    required this.activity,
    required this.isLoading,
    required this.onTap,
  });

  final Drill drill;
  final Activity activity;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withAlpha(18),
                borderRadius: SkillDrillsRadius.smBorderRadius,
              ),
              child: Center(
                child: Text(
                  activity.icon,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drill.title ?? '',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (drill.description?.isNotEmpty == true)
                    Text(
                      drill.description!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Trailing
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.add_circle_outline_rounded,
                size: 22,
                color: Theme.of(context).primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}
