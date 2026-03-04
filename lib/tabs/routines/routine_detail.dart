import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/firestore/drill.dart';
import 'package:skilldrills/models/firestore/routine.dart';
import 'package:skilldrills/models/firestore/skill_drill_user.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/services/factory.dart' as firestore_factory;
import 'package:skilldrills/tabs/drills/drill_detail.dart';
import 'package:skilldrills/theme/theme.dart';
import 'package:skilldrills/widgets/basic_title.dart';
import 'package:skilldrills/widgets/paywall_screen.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

class RoutineDetail extends StatefulWidget {
  const RoutineDetail({super.key, this.routine});

  /// When non-null the screen opens in edit mode pre-populated with this routine.
  final Routine? routine;

  @override
  State<RoutineDetail> createState() => _RoutineDetailState();
}

class _RoutineDetailState extends State<RoutineDetail> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  /// The ordered list of drills the user has added to this routine.
  final List<RoutineDrill> _selectedDrills = [];

  /// Active activities available to assign to this routine.
  List<Activity> _activeActivities = [];

  /// Total activity count (active + inactive) — used for the "X of Y active" hint.
  int _totalActivityCount = 0;

  /// The activity this routine belongs to.
  Activity? _selectedActivity;
  bool _activityError = false;

  /// Terminology labels drawn from [_selectedActivity].
  String _drillLabel = 'Drill';
  String _setsLabel = 'Sets';
  String _repsLabel = 'Reps';

  /// Full drill library (all activities); filtered to [_selectedActivity] in the picker.
  List<Drill> _allDrills = [];
  bool _loadingDrills = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // Pre-populate form when editing; default title for new routines
    if (widget.routine != null) {
      _titleCtrl.text = widget.routine!.title;
      _descCtrl.text = widget.routine!.description;
      if (widget.routine!.drills != null) {
        _selectedDrills.addAll(widget.routine!.drills!);
      }
    } else {
      _titleCtrl.text = '${_weekdayName(DateTime.now().weekday)} Routine';
    }

    _loadData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// Returns the English weekday name for a given [DateTime.weekday] value (1 = Monday).
  static String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }

  Future<void> _loadData() async {
    final uid = _auth.currentUser!.uid;

    // Load active activities and all drills in parallel.
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('activities').doc(uid).collection('activities').orderBy('title').get(),
      FirebaseFirestore.instance.collection('drills').doc(uid).collection('drills').orderBy('title').get(),
    ]);

    final actSnap = results[0];
    final drillSnap = results[1];

    final allActivities = actSnap.docs.map((d) => Activity.fromSnapshot(d)).toList();
    final activities = allActivities.where((a) => a.isActive).toList();

    final drills = drillSnap.docs.cast<DocumentSnapshot<Map<String, dynamic>>>().map(Drill.fromSnapshot).toList();

    if (mounted) {
      setState(() {
        _totalActivityCount = allActivities.length;
        _activeActivities = activities;
        _allDrills = drills;
        _loadingDrills = false;

        // Pre-select activity when editing.
        if (widget.routine?.activityTitle != null) {
          try {
            _selectedActivity = activities.firstWhere(
              (a) => a.title == widget.routine!.activityTitle,
            );
          } catch (_) {
            // Activity may have been deactivated; keep null so user re-picks.
          }
        }
        // Sync terminology from pre-selected activity.
        if (_selectedActivity != null) {
          _drillLabel = _selectedActivity!.drillLabel;
          _setsLabel = _selectedActivity!.setsLabel;
          _repsLabel = _selectedActivity!.repsLabel;
        }
      });
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Enforce free-tier routine limit on new routine creation only
    if (widget.routine?.reference == null) {
      final uid = _auth.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final user = SkillDrillsUser.fromSnapshot(userDoc);
        if (!user.isPremium) {
          final count = await firestore_factory.routineCount();
          if (count >= SkillDrillsUser.freeRoutineLimit) {
            if (mounted) {
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
                  () {
                    Navigator.of(context).pop();
                    navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
                  },
                  icon: Icons.workspace_premium_rounded,
                  isDangerous: false,
                ),
              );
            }
            return;
          }
        }
      }
    }

    // Validate activity selection
    if (_selectedActivity == null) {
      setState(() => _activityError = true);
      return;
    }

    setState(() => _saving = true);

    // Re-number drills by current list order
    final orderedDrills = _selectedDrills.asMap().entries.map((e) {
      return RoutineDrill(e.value.drillId, e.value.title, e.key + 1);
    }).toList();

    try {
      if (widget.routine?.reference != null) {
        // Update existing
        final updated = Routine(
          _titleCtrl.text.trim(),
          _descCtrl.text.trim(),
          activityTitle: _selectedActivity!.title,
          drillLabel: _selectedActivity!.drillLabel,
          drills: orderedDrills,
        )..reference = widget.routine!.reference;
        await firestore_factory.updateRoutine(updated);
      } else {
        // Create new
        final newRoutine = Routine(
          _titleCtrl.text.trim(),
          _descCtrl.text.trim(),
          activityTitle: _selectedActivity!.title,
          drillLabel: _selectedActivity!.drillLabel,
          drills: orderedDrills,
          createdAt: DateTime.now(),
        );
        await firestore_factory.saveRoutine(newRoutine);
      }
      if (mounted) navigatorKey.currentState!.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save routine. Please try again.')),
        );
      }
    }
  }

  // ── Add drills picker ───────────────────────────────────────────────────────

  /// Navigate to DrillDetail, and if the user creates a new drill, auto-add
  /// it to the routine's drill list.
  Future<void> _createAndAddDrill() async {
    final Drill? created = await navigatorKey.currentState!.push<Drill>(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, _) => const DrillDetail(),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (ctx, anim, _, child) {
          final slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );

    if (created?.reference != null) {
      setState(() {
        _allDrills.add(created!);
        // Only auto-add to the routine if the drill belongs to this activity.
        if (_selectedActivity == null || created.activity?.title == _selectedActivity!.title) {
          _selectedDrills.add(RoutineDrill(
            created.reference!.id,
            created.title!,
            _selectedDrills.length + 1,
          ));
        }
      });
    }
  }

  // ── Activity picker ─────────────────────────────────────────────────────────

  void _showActivityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SkillDrillsRadius.lg)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SkillDrillsSpacing.md),
              child: Text('Choose Activity', style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activeActivities.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (ctx, i) {
                final activity = _activeActivities[i];
                final selected = _selectedActivity?.title == activity.title;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: SkillDrillsSpacing.md,
                    vertical: 4,
                  ),
                  title: Text(activity.title ?? ''),
                  trailing: selected ? const Icon(Icons.check_rounded, color: SkillDrillsColors.brandBlue) : null,
                  onTap: () {
                    final changed = _selectedActivity?.title != activity.title;
                    setState(() {
                      _selectedActivity = activity;
                      _activityError = false;
                      _drillLabel = activity.drillLabel;
                      _setsLabel = activity.setsLabel;
                      _repsLabel = activity.repsLabel;
                      // Clear drills when activity changes — they belong to the old activity.
                      if (changed) _selectedDrills.clear();
                    });
                    Navigator.of(ctx).pop();
                  },
                );
              },
            ),
            // Show "N of X active" hint only when some activities are inactive.
            if (_totalActivityCount > 0 && _activeActivities.length < _totalActivityCount)
              Padding(
                padding: const EdgeInsets.fromLTRB(SkillDrillsSpacing.md, 10, SkillDrillsSpacing.md, 4),
                child: Text(
                  '${_activeActivities.length} of $_totalActivityCount activities active · Manage in Settings',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.50),
                      ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _showDrillPicker() {
    // Drills already in the routine (by id)
    final addedIds = _selectedDrills.map((d) => d.drillId).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SkillDrillsRadius.lg),
        ),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            // Filter drills to the selected activity, then exclude already-added ones.
            final available = _allDrills.where((d) => _selectedActivity == null || d.activity?.title == _selectedActivity!.title).where((d) => !addedIds.contains(d.reference!.id)).toList();

            return Column(
              children: [
                // Handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SkillDrillsSpacing.md),
                  child: Text(
                    'Add a $_drillLabel',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),

                // ── Create new drill shortcut ──────────────────────────
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: SkillDrillsSpacing.md,
                    vertical: 2,
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: SkillDrillsColors.brandBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: SkillDrillsColors.brandBlue,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Create New $_drillLabel',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Build a new ${_drillLabel.toLowerCase()} and add it here'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _createAndAddDrill();
                  },
                ),
                const Divider(height: 1),

                Expanded(
                  child: available.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(SkillDrillsSpacing.xl),
                            child: Text(
                              !_allDrills.any((d) => d.activity?.title == _selectedActivity?.title) ? 'No ${_drillLabel.toLowerCase()}s for this activity yet. Use "Create New $_drillLabel" above to build one.' : 'All ${_drillLabel.toLowerCase()}s for this activity have already been added.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: available.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (ctx, i) {
                            final drill = available[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: SkillDrillsSpacing.md,
                                vertical: 4,
                              ),
                              title: Text(drill.title ?? ''),
                              subtitle: drill.description != null && drill.description!.isNotEmpty
                                  ? Text(
                                      drill.description!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: const Icon(Icons.add_circle_outline_rounded),
                              onTap: () {
                                setState(() {
                                  _selectedDrills.add(RoutineDrill(
                                    drill.reference!.id,
                                    drill.title!,
                                    _selectedDrills.length + 1,
                                  ));
                                });
                                Navigator.of(ctx).pop();
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Sets / Reps editor ───────────────────────────────────────────────────────

  void _showSetsRepsEditor(int drillIndex) {
    final rd = _selectedDrills[drillIndex];
    final setsCtrl = TextEditingController(text: rd.sets?.toString() ?? '');
    final repsCtrl = TextEditingController(text: rd.reps?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SkillDrillsRadius.lg)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: SkillDrillsSpacing.md,
            right: SkillDrillsSpacing.md,
            top: SkillDrillsSpacing.md,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + SkillDrillsSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                rd.title,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Set $_setsLabel and $_repsLabel for this ${_drillLabel.toLowerCase()}.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _NumberStepField(
                      controller: setsCtrl,
                      label: _setsLabel,
                      hint: 'e.g. 3',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NumberStepField(
                      controller: repsCtrl,
                      label: _repsLabel,
                      hint: 'e.g. 10',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final sets = int.tryParse(setsCtrl.text.trim());
                      final reps = int.tryParse(repsCtrl.text.trim());
                      setState(() {
                        _selectedDrills[drillIndex] = RoutineDrill(
                          rd.drillId,
                          rd.title,
                          rd.order,
                          sets: sets,
                          reps: reps,
                        );
                      });
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── UI sections ─────────────────────────────────────────────────────────────

  Widget _buildInfoSection() {
    final hasActivity = _selectedActivity != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SkillDrillsSpacing.md,
        SkillDrillsSpacing.md,
        SkillDrillsSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Routine Info',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: SkillDrillsSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SkillDrillsSpacing.md,
                vertical: SkillDrillsSpacing.md,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                        border: InputBorder.none,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                        border: InputBorder.none,
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                    const SizedBox(height: 8),
                    // ── Activity picker row ──────────────────────────
                    InkWell(
                      onTap: _loadingDrills ? null : _showActivityPicker,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Activity',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                          border: InputBorder.none,
                          errorText: _activityError ? 'Please select an activity' : null,
                          suffixIcon: Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 26,
                            color: _activityError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                        isEmpty: !hasActivity,
                        child: Text(
                          hasActivity ? (_selectedActivity!.title ?? '') : '',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrillsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SkillDrillsSpacing.md,
        SkillDrillsSpacing.lg,
        SkillDrillsSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_drillLabel}s',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        letterSpacing: 0.8,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: (_loadingDrills || _selectedActivity == null) ? null : _showDrillPicker,
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add $_drillLabel'),
              ),
            ],
          ),
          const SizedBox(height: SkillDrillsSpacing.sm),
          if (_selectedDrills.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SkillDrillsSpacing.lg),
                child: Row(
                  children: [
                    Icon(
                      Icons.playlist_add_rounded,
                      size: 28,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: SkillDrillsSpacing.md),
                    Expanded(
                      child: Text(
                        _selectedActivity == null ? 'Select an activity above before adding ${_drillLabel.toLowerCase()}s.' : 'No ${_drillLabel.toLowerCase()}s added yet.\nTap "Add $_drillLabel" to build your routine.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedDrills.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _selectedDrills.removeAt(oldIndex);
                    _selectedDrills.insert(newIndex, item);
                  });
                },
                itemBuilder: (ctx, i) {
                  final rd = _selectedDrills[i];
                  final setsText = rd.sets != null ? '${rd.sets}' : '—';
                  final repsText = rd.reps != null ? '${rd.reps}' : '—';
                  return ListTile(
                    key: ValueKey('${rd.drillId}_$i'),
                    contentPadding: const EdgeInsets.only(
                      left: SkillDrillsSpacing.md,
                      right: 4,
                    ),
                    onTap: () => _showSetsRepsEditor(i),
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: SkillDrillsColors.brandBlue.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: SkillDrillsColors.brandBlue,
                          ),
                        ),
                      ),
                    ),
                    title: Text(rd.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: GestureDetector(
                      onTap: () => _showSetsRepsEditor(i),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            _SetsRepsChip(
                              label: _setsLabel,
                              value: setsText,
                              onTap: () => _showSetsRepsEditor(i),
                            ),
                            const SizedBox(width: 6),
                            _SetsRepsChip(
                              label: _repsLabel,
                              value: repsText,
                              onTap: () => _showSetsRepsEditor(i),
                            ),
                          ],
                        ),
                      ),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 20,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedDrills.removeAt(i);
                            });
                          },
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle_rounded, size: 22),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            collapsedHeight: 65,
            expandedHeight: 65,
            backgroundColor: Theme.of(context).colorScheme.surface,
            floating: false,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.only(top: 10),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 28,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              child: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                centerTitle: false,
                title: BasicTitle(
                  title: widget.routine != null ? widget.routine!.title : 'New Routine',
                ),
                background: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                child: _saving
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.check,
                          size: 28,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        onPressed: _save,
                      ),
              ),
            ],
          ),
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: SkillDrillsSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoSection(),
              _buildDrillsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

/// Small tappable chip that displays a sets or reps value alongside its label.
class _SetsRepsChip extends StatelessWidget {
  const _SetsRepsChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDash = value == '—';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDash ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06) : SkillDrillsColors.brandBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(SkillDrillsRadius.full),
        ),
        child: Text(
          '$value $label',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDash ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45) : SkillDrillsColors.brandBlue,
                fontWeight: isDash ? FontWeight.normal : FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

/// An integer input field with — + stepper buttons.
class _NumberStepField extends StatefulWidget {
  const _NumberStepField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  State<_NumberStepField> createState() => _NumberStepFieldState();
}

class _NumberStepFieldState extends State<_NumberStepField> {
  void _step(int delta) {
    final current = int.tryParse(widget.controller.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 999);
    widget.controller.text = next == 0 ? '' : '$next';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Decrement
            InkWell(
              onTap: () => _step(-1),
              borderRadius: BorderRadius.circular(SkillDrillsRadius.sm),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(SkillDrillsRadius.sm),
                ),
                child: const Icon(Icons.remove, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: widget.hint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            // Increment
            InkWell(
              onTap: () => _step(1),
              borderRadius: BorderRadius.circular(SkillDrillsRadius.sm),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(SkillDrillsRadius.sm),
                ),
                child: const Icon(Icons.add, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
