import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/drill.dart';
import 'package:skilldrills/models/firestore/routine.dart';
import 'package:skilldrills/models/firestore/skill_drill_user.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/services/factory.dart' as firestore_factory;
import 'package:skilldrills/tabs/drills/drill_detail.dart';
import 'package:skilldrills/theme/theme.dart';
import 'package:skilldrills/widgets/basic_title.dart';

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

  /// Full drill library for the picker.
  List<Drill> _allDrills = [];
  bool _loadingDrills = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // Pre-populate form when editing
    if (widget.routine != null) {
      _titleCtrl.text = widget.routine!.title;
      _descCtrl.text = widget.routine!.description;
      if (widget.routine!.drills != null) {
        _selectedDrills.addAll(widget.routine!.drills!);
      }
    }

    _loadDrills();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDrills() async {
    final uid = _auth.currentUser!.uid;
    final snap = await FirebaseFirestore.instance.collection('drills').doc(uid).collection('drills').orderBy('title').get();
    final drills = snap.docs.cast<DocumentSnapshot<Map<String, dynamic>>>().map(Drill.fromSnapshot).toList();
    if (mounted) {
      setState(() {
        _allDrills = drills;
        _loadingDrills = false;
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
                  () => Navigator.of(context).pop(), // TODO: navigate to paywall
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
          drills: orderedDrills,
        )..reference = widget.routine!.reference;
        await firestore_factory.updateRoutine(updated);
      } else {
        // Create new
        final newRoutine = Routine(
          _titleCtrl.text.trim(),
          _descCtrl.text.trim(),
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
        _selectedDrills.add(RoutineDrill(
          created.reference!.id,
          created.title!,
          _selectedDrills.length + 1,
        ));
      });
    }
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
            final available = _allDrills.where((d) => !addedIds.contains(d.reference!.id)).toList();

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
                    'Add a Drill',
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
                  title: const Text(
                    'Create New Drill',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Build a new drill and add it here'),
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
                              'All your existing drills have already been added.',
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

  // ── UI sections ─────────────────────────────────────────────────────────────

  Widget _buildInfoSection() {
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
                vertical: SkillDrillsSpacing.sm,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: InputBorder.none,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const Divider(height: 1),
                    TextFormField(
                      controller: _descCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: InputBorder.none,
                      ),
                      maxLines: 2,
                      minLines: 1,
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
                  'Drills',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        letterSpacing: 0.8,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: _loadingDrills ? null : _showDrillPicker,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Drill'),
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
                        'No drills added yet.\nTap "Add Drill" to build your routine.',
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
                  return ListTile(
                    key: ValueKey('${rd.drillId}_$i'),
                    contentPadding: const EdgeInsets.only(
                      left: SkillDrillsSpacing.md,
                      right: 4,
                    ),
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: SkillDrillsColors.energyOrange.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: SkillDrillsColors.energyOrange,
                          ),
                        ),
                      ),
                    ),
                    title: Text(rd.title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
