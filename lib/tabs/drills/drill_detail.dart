import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_picker_plus/flutter_picker_plus.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/firestore/skill.dart';
import 'package:skilldrills/models/firestore/drill.dart';
import 'package:skilldrills/models/firestore/drill_type.dart';
import 'package:skilldrills/models/firestore/measurement.dart';
import 'package:skilldrills/models/firestore/measurement_target.dart';
import 'package:skilldrills/widgets/basic_title.dart';
import 'package:skilldrills/services/utility.dart';
import 'package:skilldrills/theme/theme.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

class DrillDetail extends StatefulWidget {
  const DrillDetail({super.key, this.drill, this.initialActivity});

  final Drill? drill;

  /// When set, the Activity selector is pre-populated with this value.
  /// Used when launching DrillDetail from an active session.
  final Activity? initialActivity;

  @override
  State<DrillDetail> createState() => _DrillDetailState();
}

class _DrillDetailState extends State<DrillDetail> {
  final _formKey = GlobalKey<FormState>();
  final _titleFieldController = TextEditingController();
  final _descriptionFieldController = TextEditingController();
  final _timerTextController = TextEditingController();

  Drill? _drill = Drill("", "", Activity("", null), null);

  List<Activity>? _activities;
  Activity? _activity = Activity("", null);
  bool _activityError = false;

  List<Skill>? _selectedCategories = [];
  bool _categoryError = false;

  List<DrillType>? _drillTypes;
  DrillType? _drillType;
  bool _drillTypeError = false;

  Widget? _targetFields;

  @override
  void initState() {
    super.initState();

    // Pre-populate activity when provided (e.g. launched from a session)
    if (widget.initialActivity != null) {
      _activity = widget.initialActivity;
      _drill = Drill(_drill!.title, _drill!.description, widget.initialActivity, _drill!.drillType);
    }

    // Load active activities only
    FirebaseFirestore.instance.collection("activities").doc(auth.currentUser!.uid).collection("activities").get().then((snapshot) async {
      List<Activity> activities = [];
      if (snapshot.docs.isNotEmpty) {
        await Future.forEach(snapshot.docs, (doc) async {
          Activity a = Activity.fromSnapshot(doc);
          // Only include active activities in the picker
          if (!a.isActive) return;
          await _getCategories(doc.reference).then((categories) {
            a.skills = categories;

            final preselect = widget.initialActivity ?? widget.drill?.activity;
            if (preselect != null && a == preselect) {
              // Replace the stub with the fully-loaded activity (includes skills)
              setState(() {
                _activity = a;
                _drill = Drill(_drill!.title, _drill!.description, a, _drill!.drillType);
              });
            }

            activities.add(a);
          });
        }).then((_) {
          setState(() {
            _activities = activities;
          });
        });
      }
    });

    // If the user is editing an existing drill, pre-populate the form
    if (widget.drill?.reference != null) {
      setState(() {
        _drill = widget.drill;
        _titleFieldController.text = widget.drill!.title ?? '';
        _descriptionFieldController.text = widget.drill!.description ?? '';
        _activity = widget.drill!.activity ?? Activity('', null);
        _selectedCategories = widget.drill!.skills ?? [];
        _drillType = widget.drill!.drillType;
        if (widget.drill!.drillType != null) {
          _timerTextController.text = printDuration(Duration(seconds: widget.drill!.drillType!.timerInSeconds));
        }
      });

      // Load the drill's saved measurements (which may include per-drill targets)
      FirebaseFirestore.instance.collection('drills').doc(auth.currentUser!.uid).collection('drills').doc(widget.drill!.reference!.id).collection('measurements').orderBy('order').get().then((snapshot) async {
        List<Measurement> measures = [];
        if (snapshot.docs.isNotEmpty) {
          for (var doc in snapshot.docs) {
            measures.add(Measurement.fromSnapshot(doc));
          }

          setState(() {
            // Store on _drill only; never mutate the shared DrillType template
            _drill!.measurements = measures;
            _targetFields = _buildDefaultTargetFields(_drill!);
          });
        }
      });
    }

    // Load the drill types
    FirebaseFirestore.instance.collection('drill_types').doc(auth.currentUser!.uid).collection('drill_types').orderBy('order').get().then((snapshot) async {
      List<DrillType> drillTypes = [];
      if (snapshot.docs.isNotEmpty) {
        await Future.forEach(snapshot.docs, (doc) async {
          DrillType dt = DrillType.fromSnapshot(doc);
          await _getMeasurements(doc.reference).then((measurements) {
            dt.measurements = measurements;
            drillTypes.add(dt);
          });
        }).then((_) {
          setState(() {
            _drillTypes = drillTypes;
          });
        });
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
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
                  titlePadding: null,
                  centerTitle: false,
                  title: BasicTitle(title: widget.drill?.title ?? 'New Drill'),
                  background: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: IconButton(
                    icon: Icon(
                      Icons.check,
                      size: 28,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    onPressed: () {
                      bool hasErrors = false;
                      if (_activity!.title!.isEmpty) {
                        hasErrors = true;
                        setState(() {
                          _activityError = true;
                        });
                      }

                      if (_drill!.drillType == null) {
                        hasErrors = true;
                        setState(() {
                          _drillTypeError = true;
                        });
                      }

                      if (!hasErrors && _formKey.currentState!.validate()) {
                        // Measurements to persist: prefer the drill's own copy (which holds
                        // per-drill targets), fall back to the DrillType template.
                        final measurements = _drill!.measurements ?? _drillType!.measurements ?? <Measurement>[];

                        if (widget.drill?.reference != null) {
                          // UPDATE existing drill
                          final ref = widget.drill!.reference!;

                          ref.collection('measurements').get().then((snapshot) {
                            for (var doc in snapshot.docs) {
                              doc.reference.delete();
                            }
                            for (var m in measurements) {
                              ref.collection('measurements').doc().set(m.toMap());
                            }
                          });

                          ref.collection('skills').get().then((snapshot) {
                            for (var doc in snapshot.docs) {
                              doc.reference.delete();
                            }
                            for (var c in _selectedCategories!) {
                              ref.collection('skills').doc().set(c.toMap());
                            }
                          });

                          FirebaseFirestore.instance.runTransaction((transaction) async {
                            transaction.update(
                              ref,
                              Drill(
                                _titleFieldController.text.trim(),
                                _descriptionFieldController.text.trim(),
                                _activity,
                                _drillType,
                              ).toMap(),
                            );
                            navigatorKey.currentState!.pop();
                          });
                        } else {
                          // CREATE new drill
                          final newDoc = FirebaseFirestore.instance.collection('drills').doc(auth.currentUser!.uid).collection('drills').doc();

                          final createdDrill = Drill(
                            _titleFieldController.text.trim(),
                            _descriptionFieldController.text.trim(),
                            _activity,
                            _drillType,
                          )..reference = newDoc;

                          newDoc.set(createdDrill.toMap());

                          for (var m in measurements) {
                            newDoc.collection('measurements').doc().set(m.toMap());
                          }

                          for (var c in _selectedCategories!) {
                            newDoc.collection('skills').doc().set(c.toMap());
                          }

                          // Pop with the created Drill so callers (e.g. RoutineDetail)
                          // can receive it and add it to a routine automatically.
                          navigatorKey.currentState!.pop(createdDrill);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ];
        },
        body: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: SkillDrillsSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInfoSection(),
                    _buildCategorySection(),
                    _buildTypeSection(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                      ),
                      child: _drillType != null
                          ? Container(
                              key: const ValueKey('session-preview'),
                              child: _buildSessionPreviewSection(),
                            )
                          : const SizedBox.shrink(key: ValueKey('no-preview')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom sheet pickers ──────────────────────────────────────────────────

  void _showActivityPicker() {
    final activities = _activities ?? <Activity>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (ctx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(SkillDrillsRadius.lg),
                ),
              ),
              child: Column(
                children: [
                  // Handle
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
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
                    child: Row(
                      children: [
                        Text(
                          'Choose Activity',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontFamily: 'Choplin',
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  // List
                  Expanded(
                    child: activities.isEmpty
                        ? Center(
                            child: Text(
                              'No active activities.\nEnable some in Profile → Settings.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: activities.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: Theme.of(context).dividerColor,
                            ),
                            itemBuilder: (_, i) {
                              final activity = activities[i];
                              final isSelected = _activity?.title == activity.title;
                              return InkWell(
                                onTap: () async {
                                  Navigator.of(ctx).pop();
                                  await _getCategories(activity.reference!).then((cats) {
                                    activity.skills = cats;
                                    setState(() {
                                      _activityError = false;
                                      _activity = activity;
                                      _selectedCategories = [];
                                      _drill = Drill(_drill!.title, _drill!.description, activity, _drill!.drillType);
                                    });
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          activity.title ?? '',
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                                color: isSelected ? Theme.of(context).colorScheme.secondary : null,
                                              ),
                                        ),
                                      ),
                                      if (isSelected) Icon(Icons.check_rounded, size: 18, color: Theme.of(context).colorScheme.secondary),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSkillsPicker() {
    final skills = _activity?.skills ?? <Skill>[];
    // Work with a mutable local copy so we can preview multi-select before confirming.
    List<Skill> pending = List<Skill>.from(_selectedCategories ?? []);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.35,
              maxChildSize: 0.85,
              builder: (ctx2, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(SkillDrillsRadius.lg),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle
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
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
                        child: Row(
                          children: [
                            Text(
                              'Choose Skill(s)',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontFamily: 'Choplin',
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _categoryError = false;
                                  _selectedCategories = pending;
                                  final a = Activity(_activity!.title, null)..skills = pending;
                                  _drill = Drill(_drill!.title, _drill!.description, a, _drill!.drillType);
                                });
                                Navigator.of(ctx).pop();
                              },
                              child: const Text('Done'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                      // List
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: skills.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor),
                          itemBuilder: (_, i) {
                            final skill = skills[i];
                            final isSelected = pending.any((s) => s.title == skill.title);
                            return InkWell(
                              onTap: () {
                                setSheetState(() {
                                  if (isSelected) {
                                    pending.removeWhere((s) => s.title == skill.title);
                                  } else {
                                    pending.add(skill);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        skill.title,
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                              color: isSelected ? Theme.of(context).colorScheme.secondary : null,
                                            ),
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<Skill>> _getCategories(DocumentReference aDoc) async {
    List<Skill>? categories = [];
    return await aDoc.collection('skills').get().then((catSnapshot) async {
      for (var cDoc in catSnapshot.docs) {
        categories.add(Skill.fromSnapshot(cDoc));
      }
    }).then((_) => categories);
  }

  Future<List<Measurement>> _getMeasurements(DocumentReference dtDoc) async {
    List<Measurement>? measurements = [];
    return await dtDoc.collection('measurements').orderBy('order').get().then((measurementSnapshot) async {
      for (var mDoc in measurementSnapshot.docs) {
        measurements.add(Measurement.fromSnapshot(mDoc));
      }
    }).then((_) => measurements);
  }

  String _outputCategories() {
    String catString = "";

    _selectedCategories!.asMap().forEach((i, c) {
      catString += (i != _selectedCategories!.length - 1 && _selectedCategories!.length != 1) ? "${c.title}, " : c.title;
    });

    return catString;
  }

  Widget _buildDefaultTargetFields(Drill drill) {
    Map<int, TextEditingController> targetTextControllers = {};
    List<Widget> targetFields = [];
    // Filter by role, not type
    List<Measurement> targets = (drill.measurements ?? []).where((m) => m.role == 'target').toList();

    targets.asMap().forEach((i, t) {
      targetTextControllers.putIfAbsent(i, () => TextEditingController());

      if (t.role == 'target' && t.target != null) {
        // type drives the input widget; store/display durations as int seconds
        if (t.type == 'duration') {
          targetTextControllers[i]!.text = printDuration(Duration(seconds: t.target!.toInt()));
        } else {
          targetTextControllers[i]!.text = t.target?.toString() ?? '';
        }
      }

      // Switch on type (input widget type), not on role
      switch (t.type) {
        case 'amount':
          targetFields.add(
            SizedBox(
              width: targets.length > 1 ? MediaQuery.of(context).size.width / 2 : MediaQuery.of(context).size.width,
              child: TextField(
                controller: targetTextControllers[i],
                keyboardType: TextInputType.number,
                scrollPadding: const EdgeInsets.all(5),
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  labelText: t.label,
                  labelStyle: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                onChanged: (value) {
                  // Store as num (int), never as Duration
                  targets[i] = MeasurementTarget(t.type, t.label, t.order, num.tryParse(value), false);

                  // Update only the drill's own measurement copy, not the shared DrillType template
                  final results = (drill.measurements ?? []).where((m) => m.role == 'result').toList();
                  setState(() {
                    _drill!.measurements = [...results, ...targets];
                  });
                },
              ),
            ),
          );

          break;
        case 'duration':
          targetFields.add(
            SizedBox(
              width: targets.length > 1 ? MediaQuery.of(context).size.width / 2 : MediaQuery.of(context).size.width,
              child: TextField(
                controller: targetTextControllers[i],
                keyboardType: TextInputType.number,
                scrollPadding: const EdgeInsets.all(5),
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  labelText: t.label,
                  labelStyle: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  hintStyle: Theme.of(context).textTheme.bodyLarge,
                ),
                onTap: () {
                  const TextStyle suffixStyle = TextStyle(fontSize: 14, height: 1.5);
                  Picker(
                    adapter: NumberPickerAdapter(data: <NumberPickerColumn>[
                      const NumberPickerColumn(begin: 0, end: 24, suffix: Text(' hrs', style: suffixStyle), jump: 1),
                      const NumberPickerColumn(begin: 0, end: 59, suffix: Text(' mins', style: suffixStyle), jump: 1),
                      const NumberPickerColumn(begin: 0, end: 59, suffix: Text(' secs', style: suffixStyle), jump: 5),
                    ]),
                    height: 200,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    textStyle: Theme.of(context).textTheme.headlineSmall,
                    hideHeader: true,
                    confirmText: 'Ok',
                    confirmTextStyle: TextStyle(
                      inherit: false,
                      color: Theme.of(context).primaryColor,
                    ),
                    title: const Text('Select duration'),
                    selectedTextStyle: TextStyle(
                      color: Theme.of(context).primaryColor,
                    ),
                    onConfirm: (Picker picker, List<int> value) {
                      final duration = Duration(
                        hours: picker.getSelectedValues()[0],
                        minutes: picker.getSelectedValues()[1],
                        seconds: picker.getSelectedValues()[2],
                      );

                      targetTextControllers[i]!.text = printDuration(duration);

                      // Store as int seconds, not as a Duration object
                      targets[i] = MeasurementTarget(t.type, t.label, t.order, duration.inSeconds, false);

                      final results = (drill.measurements ?? []).where((m) => m.role == 'result').toList();
                      setState(() {
                        _drill!.measurements = [...results, ...targets];
                      });
                    },
                  ).showDialog(context);
                },
              ),
            ),
          );

          break;
        default:
      }
    });

    Widget defaultTargetFields = Column(
      children: [
        Wrap(
          direction: Axis.horizontal,
          children: targetFields,
        ),
      ],
    );

    return defaultTargetFields;
  }

  // ─── Section helpers ──────────────────────────────────────────────────────

  Widget _buildSectionHeader(IconData icon, String label, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SkillDrillsSpacing.md,
        SkillDrillsSpacing.lg,
        SkillDrillsSpacing.md,
        SkillDrillsSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: Theme.of(context).colorScheme.onPrimary),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary.withAlpha(150),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectorRow({
    required String label,
    required bool isLoading,
    String? selectedValue,
    bool hasError = false,
    VoidCallback? onTap,
    VoidCallback? onClear,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: isLoading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SkillDrillsSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            Text(label, style: theme.textTheme.bodyLarge),
            const Spacer(),
            if (isLoading)
              SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
              )
            else if (selectedValue != null) ...[
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withAlpha(18),
                    borderRadius: SkillDrillsRadius.fullBorderRadius,
                    border: Border.all(color: theme.colorScheme.secondary.withAlpha(60)),
                  ),
                  child: Text(
                    selectedValue,
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 16, color: theme.colorScheme.onPrimary),
              ),
            ] else
              Text(
                'Choose',
                style: TextStyle(
                  color: hasError ? theme.colorScheme.error : theme.colorScheme.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.edit_rounded, 'Basic Info'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SkillDrillsSpacing.md),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(SkillDrillsSpacing.md),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    TextFormField(
                      validator: (String? value) {
                        if (value!.isEmpty) {
                          return 'Please enter a title';
                        } else if (!RegExp(r"^[a-zA-Z0-9 ]+$").hasMatch(value)) {
                          return 'No special characters are allowed';
                        }
                        return null;
                      },
                      controller: _titleFieldController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Wall passes, Scale runs, Free throws',
                        hintStyle: Theme.of(context).textTheme.bodyMedium,
                      ),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      onChanged: (value) {
                        setState(() {
                          _drill = Drill(value, _drill!.description, _drill!.activity, _drill!.drillType);
                        });
                      },
                    ),
                    const SizedBox(height: SkillDrillsSpacing.sm),
                    TextFormField(
                      controller: _descriptionFieldController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Optional — what does this drill practice?',
                        hintStyle: Theme.of(context).textTheme.bodyMedium,
                      ),
                      minLines: 2,
                      maxLines: 4,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      onChanged: (value) {
                        setState(() {
                          _drill = Drill(_drill!.title, value, _drill!.activity, _drill!.drillType);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.category_rounded, 'Categorize'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SkillDrillsSpacing.md),
          child: Card(
            child: Column(
              children: [
                _buildSelectorRow(
                  label: 'Activity',
                  isLoading: _activities == null,
                  selectedValue: _activity!.title!.isNotEmpty ? _activity!.title : null,
                  hasError: _activityError,
                  onTap: () => _showActivityPicker(),
                  onClear: () {
                    setState(() {
                      _activityError = false;
                      _activity = Activity('', null);
                      _selectedCategories = [];
                      _drill = Drill(_drill!.title, _drill!.description, Activity('', null), _drill!.drillType);
                    });
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: (_activity!.skills?.length ?? 0) > 0
                      ? Column(
                          children: [
                            Divider(height: 1, color: Theme.of(context).dividerColor),
                            _buildSelectorRow(
                              label: _selectedCategories!.length <= 1 ? 'Skill' : 'Skills',
                              isLoading: false,
                              selectedValue: _selectedCategories!.isNotEmpty ? _outputCategories() : null,
                              hasError: _categoryError,
                              onTap: () => _showSkillsPicker(),
                              onClear: () {
                                setState(() {
                                  _categoryError = false;
                                  _selectedCategories = [];
                                  Activity a = Activity(_activity!.title, null);
                                  a.skills = [];
                                  _drill = Drill(_drill!.title, _drill!.description, a, _drill!.drillType);
                                });
                              },
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSection() {
    final theme = Theme.of(context);
    final hasGoals = _drill?.measurements?.any((m) => m.role == 'target') ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.tune_rounded, 'Drill Type', subtitle: 'Choose the format that matches how you measure this drill.\nTap a type to see what it tracks.'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SkillDrillsSpacing.md),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Type selection list ────────────────────────────────────
                if (_drillTypes == null)
                  const Padding(
                    padding: EdgeInsets.all(SkillDrillsSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_drillTypes!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(SkillDrillsSpacing.md),
                    child: Text('No drill types set up yet.', style: theme.textTheme.bodyMedium),
                  )
                else
                  Builder(builder: (context) {
                    final curated = _activity?.title != null ? _drillTypes!.where((dt) => dt.activityKey == _activity!.title).toList() : <DrillType>[];
                    final universal = _drillTypes!.where((dt) => dt.activityKey == null).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (curated.isNotEmpty) ...[
                          _buildTypeGroupLabel('Suggested for ${_activity!.title}', theme),
                          for (int i = 0; i < curated.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: theme.dividerColor),
                            _buildDrillTypeItem(curated[i], theme),
                          ],
                          Divider(height: 1, color: theme.dividerColor),
                        ],
                        _buildTypeGroupLabel(curated.isEmpty ? 'All Types' : 'General Purpose', theme),
                        for (int i = 0; i < universal.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: theme.dividerColor),
                          _buildDrillTypeItem(universal[i], theme),
                        ],
                      ],
                    );
                  }),
                // ── Timer ─────────────────────────────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: _drillType?.timerInSeconds != null
                      ? Column(
                          children: [
                            Divider(height: 1, color: theme.dividerColor),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                SkillDrillsSpacing.md,
                                SkillDrillsSpacing.sm,
                                SkillDrillsSpacing.md,
                                SkillDrillsSpacing.md,
                              ),
                              child: TextField(
                                controller: _timerTextController,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                                style: theme.textTheme.bodyLarge,
                                decoration: InputDecoration(
                                  labelText: 'Default Duration',
                                  hintText: 'Tap to set',
                                  hintStyle: theme.textTheme.bodyMedium,
                                  prefixIcon: Icon(Icons.timer_rounded, size: 20, color: theme.colorScheme.onPrimary),
                                  labelStyle: TextStyle(fontSize: 14, color: theme.colorScheme.onPrimary),
                                ),
                                onTap: () {
                                  const TextStyle suffixStyle = TextStyle(fontSize: 14, height: 1.5);
                                  Picker(
                                    adapter: NumberPickerAdapter(data: <NumberPickerColumn>[
                                      const NumberPickerColumn(begin: 0, end: 24, suffix: Text(' hrs', style: suffixStyle), jump: 1),
                                      const NumberPickerColumn(begin: 0, end: 59, suffix: Text(' mins', style: suffixStyle), jump: 1),
                                      const NumberPickerColumn(begin: 0, end: 59, suffix: Text(' secs', style: suffixStyle), jump: 5),
                                    ]),
                                    height: 200,
                                    backgroundColor: theme.colorScheme.surface,
                                    textStyle: theme.textTheme.headlineSmall,
                                    hideHeader: true,
                                    confirmText: 'Ok',
                                    confirmTextStyle: TextStyle(inherit: false, color: theme.primaryColor),
                                    title: const Text('Select duration'),
                                    selectedTextStyle: TextStyle(color: theme.primaryColor),
                                    onConfirm: (Picker picker, List<int> value) {
                                      final duration = Duration(
                                        hours: picker.getSelectedValues()[0],
                                        minutes: picker.getSelectedValues()[1],
                                        seconds: picker.getSelectedValues()[2],
                                      );
                                      _timerTextController.text = printDuration(duration);
                                      setState(() => _drillType!.timerInSeconds = duration.inSeconds);
                                    },
                                  ).showDialog(context);
                                },
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                // ── Goals ─────────────────────────────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: (hasGoals && _drillType != null)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(height: 1, color: theme.dividerColor),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                SkillDrillsSpacing.md,
                                SkillDrillsSpacing.md,
                                SkillDrillsSpacing.md,
                                4,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.flag_rounded, size: 13, color: theme.colorScheme.secondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'GOALS',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                SkillDrillsSpacing.md,
                                0,
                                SkillDrillsSpacing.md,
                                SkillDrillsSpacing.md,
                              ),
                              child: _targetFields,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeGroupLabel(String label, ThemeData theme) => Padding(
        padding: const EdgeInsets.fromLTRB(SkillDrillsSpacing.md, 10, SkillDrillsSpacing.md, 4),
        child: Text(
          label.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: theme.colorScheme.onPrimary.withAlpha(110),
          ),
        ),
      );

  /// Returns an icon, accent colour, and short label describing the category
  /// of a drill type. Universal types are identified by ID; sport-specific
  /// types are derived from their measurement pattern.
  static ({IconData icon, Color color, String label}) _drillTypeCategoryMeta(DrillType dt) {
    const universalMeta = <String, ({IconData icon, Color color, String label})>{
      'count': (icon: Icons.numbers_rounded, color: Color(0xFF78909C), label: 'Count'),
      'score': (icon: Icons.gps_fixed_rounded, color: Color(0xFF43A047), label: 'Accuracy'),
      'duration': (icon: Icons.timer_rounded, color: Color(0xFF1E88E5), label: 'Timed'),
      'streak': (icon: Icons.local_fire_department_rounded, color: Color(0xFFE64A19), label: 'Streak'),
      'count_duration': (icon: Icons.repeat_rounded, color: Color(0xFFFB8C00), label: 'Reps + Time'),
      'sets': (icon: Icons.fitness_center_rounded, color: Color(0xFF8E24AA), label: 'Strength'),
      'rounds': (icon: Icons.loop_rounded, color: Color(0xFF3949AB), label: 'Conditioning'),
      'pace': (icon: Icons.straighten_rounded, color: Color(0xFF00897B), label: 'Distance'),
    };
    if (dt.id != null && universalMeta.containsKey(dt.id)) return universalMeta[dt.id]!;

    // Derive category from measurement pattern for activity-specific types
    final results = (dt.measurements ?? []).where((m) => m.role == 'result').toList();
    final hasRir = results.any((m) => m.type == 'rir');
    final hasDuration = results.any((m) => m.type == 'duration');
    final hasRpe = results.any((m) => m.type == 'rpe');
    final amountCount = results.where((m) => m.type == 'amount').length;

    if (hasRir) return (icon: Icons.fitness_center_rounded, color: Color(0xFF8E24AA), label: 'Strength');
    if (hasDuration && hasRpe) return (icon: Icons.loop_rounded, color: Color(0xFF3949AB), label: 'Conditioning');
    if (hasDuration && amountCount >= 1) return (icon: Icons.repeat_rounded, color: Color(0xFFFB8C00), label: 'Reps + Time');
    if (hasDuration) return (icon: Icons.timer_rounded, color: Color(0xFF1E88E5), label: 'Timed');
    if (amountCount >= 2) return (icon: Icons.gps_fixed_rounded, color: Color(0xFF43A047), label: 'Accuracy');
    return (icon: Icons.numbers_rounded, color: Color(0xFF78909C), label: 'Count');
  }

  /// Returns a "Use when:" description for the universal drill types, providing
  /// plain-language guidance on when each template is the right choice.
  static String? _universalUseWhen(String? id) {
    const useWhen = <String, String>{
      'count': 'Use when you just want to count how many times you do something — reps, swings, cycles, touches.',
      'score': 'Use when you want to track a success rate: how many succeeded vs. how many were attempted.',
      'duration': 'Use when all you need is elapsed time — sprints, holds, time trials, timed sets.',
      'streak': 'Use when the goal is the longest unbroken run — consecutive clean reps or makes without error.',
      'count_duration': 'Use when both rep volume and total time both matter — stickhandling patterns, form drills, circuits.',
      'sets': 'Use for weight-room lifts where sets, reps, load, and proximity-to-failure are all tracked.',
      'rounds': 'Use for multi-round conditioning work where round count, round duration, and effort are logged.',
      'pace': 'Use when you need to cover a distance and track how long it takes — runs, skates, swims.',
    };
    return useWhen[id];
  }

  /// Returns an activity-specific example string for a universal drill type
  /// so users understand how the generic template applies to their sport/skill.
  /// Returns null when the activity or type combination has no specific hint.
  static String? _activityContextHint(String? activityTitle, String? drillTypeId) {
    if (activityTitle == null || drillTypeId == null) return null;
    const hints = <String, Map<String, String>>{
      'Hockey': {
        'count': 'e.g. cone reps, one-timer swings, edge cycles',
        'score': 'e.g. shots on goal out of total shots taken',
        'duration': 'e.g. sprint time trial, timed edge drill',
        'streak': 'e.g. consecutive stickhandles without losing the puck',
        'count_duration': 'e.g. stickhandling pattern reps in a set time',
        'sets': 'e.g. off-ice barbell or dumbbell strength work',
        'rounds': 'e.g. interval skating sets, bag-skate rounds',
        'pace': 'e.g. off-ice conditioning run',
      },
      'Basketball': {
        'count': 'e.g. free throw reps, ball-handling touches',
        'score': 'e.g. field goal makes / total attempts from a spot',
        'duration': 'e.g. three-quarter-court sprint, lane agility time trial',
        'streak': 'e.g. consecutive makes from the free-throw line',
        'count_duration': 'e.g. ball-handling drill reps in a timed window',
        'sets': 'e.g. weight-room strength work',
        'rounds': 'e.g. suicide sprints, court conditioning sets',
        'pace': 'e.g. off-court conditioning run',
      },
      'Baseball': {
        'count': 'e.g. dry swings, catch reps, fielding ground balls',
        'score': 'e.g. quality contacts out of total swings in the cage',
        'duration': 'e.g. 60-yard dash, first-to-third sprint time',
        'streak': 'e.g. consecutive clean catches without an error',
        'count_duration': 'e.g. tee work reps in a timed session',
        'sets': 'e.g. gym strength and conditioning',
        'rounds': 'e.g. batting-practice bucket rounds',
        'pace': 'e.g. base-running or conditioning run',
      },
      'Golf': {
        'count': 'e.g. practice swings, putting strokes from a set distance',
        'score': 'e.g. putts made out of attempts from a fixed distance',
        'duration': 'e.g. pre-round warm-up or putting-routine time',
        'streak': 'e.g. consecutive putts made without a miss',
        'count_duration': 'e.g. chipping reps in a focused time block',
        'sets': 'e.g. gym mobility or strength work',
        'rounds': 'e.g. structured 9-hole practice round',
        'pace': 'e.g. walking-round cardio or off-course conditioning',
      },
      'Soccer': {
        'count': 'e.g. juggling touches, set-piece reps, shadow-pass reps',
        'score': 'e.g. passes completed out of total attempts',
        'duration': 'e.g. agility run or sprint time trial',
        'streak': 'e.g. consecutive clean first touches without a mis-touch',
        'count_duration': 'e.g. juggling or passing reps in a timed window',
        'sets': 'e.g. gym strength work',
        'rounds': 'e.g. interval sprints, suicides, conditioning circuits',
        'pace': 'e.g. fitness run with distance and effort logged',
      },
      'Tennis': {
        'count': 'e.g. shadow-swing reps, service motion reps',
        'score': 'e.g. first serves landing in the service box out of attempts',
        'duration': 'e.g. ladder drill or agility course time trial',
        'streak': 'e.g. consecutive groundstrokes landing in the target zone',
        'count_duration': 'e.g. feed-basket rally reps in a timed window',
        'sets': 'e.g. gym strength work',
        'rounds': 'e.g. on-court fitness circuit',
        'pace': 'e.g. off-court conditioning run',
      },
      'Running': {
        'count': 'e.g. form drill reps (A-skips, high knees, strides)',
        'score': 'e.g. quality miles out of total planned miles',
        'duration': 'e.g. single timed sprint or hill repeat',
        'streak': 'e.g. consecutive clean form-drill reps without a break',
        'count_duration': 'e.g. form-drill reps in a timed session window',
        'sets': 'e.g. gym strength or cross-training work',
        'rounds': 'e.g. structured interval training sets',
        'pace': 'e.g. distance run with total time and effort logged',
      },
      'Volleyball': {
        'count': 'e.g. serve reps, arm-swing shadowing, jump reps',
        'score': 'e.g. serves landing in the called zone out of attempts',
        'duration': 'e.g. agility or footwork time trial',
        'streak': 'e.g. consecutive clean passes to the setter target',
        'count_duration': 'e.g. passing reps in a timed drill window',
        'sets': 'e.g. weight-room strength work',
        'rounds': 'e.g. conditioning sets or partner rally rounds',
        'pace': 'e.g. off-court conditioning run',
      },
      'Martial Arts': {
        'count': 'e.g. kata reps, shadow-boxing combinations',
        'score': 'e.g. clean technique reps out of total attempts',
        'duration': 'e.g. single timed round or plyometric movement drill',
        'streak': 'e.g. consecutive clean combination executions without error',
        'count_duration': 'e.g. combination reps in a timed window',
        'sets': 'e.g. gym strength and conditioning work',
        'rounds': 'e.g. bag or pad work round sets',
        'pace': 'e.g. conditioning run or roadwork',
      },
      'Pickleball': {
        'count': 'e.g. dink reps, shadow-swing reps at the kitchen line',
        'score': 'e.g. third-shot drops landing in the kitchen out of attempts',
        'duration': 'e.g. footwork agility time trial',
        'streak': 'e.g. consecutive clean crosscourt dinks without error',
        'count_duration': 'e.g. dinking or drilling reps in a timed window',
        'sets': 'e.g. off-court gym work',
        'rounds': 'e.g. partner rally or drilling sets',
        'pace': 'e.g. off-court conditioning run',
      },
      'Lacrosse': {
        'count': 'e.g. wall-ball catches, cradle reps, scoop reps',
        'score': 'e.g. clean catches out of total wall-ball throws',
        'duration': 'e.g. sprint time trial',
        'streak': 'e.g. consecutive clean wall-ball catches without a drop',
        'count_duration': 'e.g. cradle or wall-ball reps in a timed window',
        'sets': 'e.g. off-field gym work',
        'rounds': 'e.g. conditioning circuits',
        'pace': 'e.g. field conditioning run',
      },
      'Gymnastics': {
        'count': 'e.g. skill attempt reps, handstand entries, jump reps',
        'score': 'e.g. clean skill executions out of total attempts',
        'duration': 'e.g. timed static hold (planche, front lever, L-sit)',
        'streak': 'e.g. consecutive clean rep executions without a break or error',
        'count_duration': 'e.g. skill reps plus total session time',
        'sets': 'e.g. weighted or bodyweight strength sets',
        'rounds': 'e.g. conditioning circuits',
        'pace': 'e.g. off-apparatus cardio conditioning',
      },
      'Guitar': {
        'count': 'e.g. chord changes, scale runs, riff repetitions',
        'score': 'e.g. clean runs out of total attempts on a passage',
        'duration': 'e.g. focused practice time on a single technique',
        'streak': 'e.g. consecutive clean runs without a missed note',
        'count_duration': 'e.g. scale or riff reps in a focused time block',
        'sets': 'e.g. technique sets by hand position or key',
        'rounds': 'e.g. practice rotating through a chord progression or set of licks',
        'pace': 'e.g. run-through a section of a song with total time tracked',
      },
    };
    return hints[activityTitle]?[drillTypeId];
  }

  Widget _buildDrillTypeItem(DrillType dt, ThemeData theme) {
    final isSelected = _drillType?.id == dt.id;
    final meta = _drillTypeCategoryMeta(dt);

    // For universal types show a "Use when:" description; for curated types
    // show the descriptor from Firestore (which is already activity-specific).
    final isUniversal = dt.activityKey == null;
    final bodyText = isUniversal ? _universalUseWhen(dt.id) : dt.descriptor;

    // Activity-specific example only makes sense on universal types
    final contextHint = (isUniversal && _activity?.title != null) ? _activityContextHint(_activity!.title, dt.id) : null;

    // Result measurement labels shown as small chips
    final resultLabels = (dt.measurements ?? []).where((m) => m.role == 'result').map((m) => m.label).whereType<String>().toList();

    return InkWell(
      onTap: () {
        final Drill d = Drill(
          _titleFieldController.text,
          _descriptionFieldController.text,
          _activity,
          dt,
        );
        setState(() {
          _drillTypeError = false;
          _drillType = dt;
          d.measurements = dt.measurements?.map((m) => Measurement(m.role, m.type, m.label, m.order, m.value, m.target, m.reverse)).toList();
          d.skills = _selectedCategories;
          _drill = d;
          _targetFields = _buildDefaultTargetFields(d);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(
          SkillDrillsSpacing.md,
          12,
          SkillDrillsSpacing.md,
          12,
        ),
        color: isSelected ? Theme.of(context).colorScheme.secondary.withAlpha(12) : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Radio circle ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? theme.colorScheme.secondary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.secondary : theme.colorScheme.onPrimary.withAlpha(80),
                    width: isSelected ? 0 : 1.5,
                  ),
                ),
                child: isSelected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: SkillDrillsSpacing.md),
            // ── Content ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with category badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          dt.title ?? '',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? theme.colorScheme.secondary : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Category badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: meta.color.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: meta.color.withAlpha(60), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(meta.icon, size: 10, color: meta.color),
                            const SizedBox(width: 4),
                            Text(
                              meta.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: meta.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // ── Detail: only rendered when selected ─────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: isSelected
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Description / "use when" text
                              if (bodyText?.isNotEmpty ?? false) ...[
                                const SizedBox(height: 4),
                                Text(bodyText!, style: theme.textTheme.bodyMedium),
                              ],
                              // Activity-specific example (universal types only)
                              if (contextHint != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  contextHint,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: theme.colorScheme.onPrimary.withAlpha(130),
                                  ),
                                ),
                              ],
                              // Tracked fields chips
                              if (resultLabels.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      'Tracks:',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onPrimary.withAlpha(110),
                                      ),
                                    ),
                                    ...resultLabels.map(
                                      (label) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.onPrimary.withAlpha(10),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: theme.dividerColor),
                                        ),
                                        child: Text(
                                          label,
                                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            if (_drillTypeError && _drillType == null)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 2),
                child: Icon(Icons.error_outline_rounded, size: 16, color: theme.colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionPreviewSection() {
    final theme = Theme.of(context);
    final measurements = _drill?.measurements ?? _drillType?.measurements ?? <Measurement>[];
    final results = measurements.where((m) => m.role == 'result').toList();
    final targets = measurements.where((m) => m.role == 'target').toList();
    final drillTitle = (_drill?.title?.isNotEmpty ?? false) ? _drill!.title! : 'Drill Name';
    final hasTimer = (_drillType?.timerInSeconds ?? 0) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.play_circle_outline_rounded, 'Session Preview'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SkillDrillsSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: SkillDrillsSpacing.sm),
                child: Text(
                  "This is what you'll track when running this drill in a session.",
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              // Mock session card
              Container(
                decoration: BoxDecoration(
                  borderRadius: SkillDrillsRadius.mdBorderRadius,
                  border: Border.all(color: theme.dividerColor),
                  color: theme.colorScheme.surface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(SkillDrillsSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withAlpha(12),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(SkillDrillsRadius.md)),
                        border: Border(bottom: BorderSide(color: theme.dividerColor)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  drillTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'Choplin'),
                                ),
                                if (_drillType?.descriptor?.isNotEmpty ?? false) ...[
                                  const SizedBox(height: 2),
                                  Text(_drillType!.descriptor!, style: theme.textTheme.bodySmall),
                                ],
                              ],
                            ),
                          ),
                          if (hasTimer)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withAlpha(20),
                                borderRadius: SkillDrillsRadius.smBorderRadius,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer_rounded, size: 12, color: theme.colorScheme.secondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    _timerTextController.text.isNotEmpty ? _timerTextController.text : '--:--',
                                    style: TextStyle(
                                      color: theme.colorScheme.secondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Measurements
                    Padding(
                      padding: const EdgeInsets.all(SkillDrillsSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (results.isEmpty)
                            Text('No result measurements defined.', style: theme.textTheme.bodyMedium)
                          else ...[
                            Text(
                              'Metrics to track each rep:',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: SkillDrillsSpacing.sm),
                            ...results.map((m) {
                              Measurement? goalM;
                              try {
                                goalM = targets.firstWhere((t) => t.label == m.label);
                              } catch (_) {
                                goalM = null;
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: theme.scaffoldBackgroundColor,
                                        borderRadius: SkillDrillsRadius.smBorderRadius,
                                      ),
                                      child: Icon(
                                        m.type == 'duration' ? Icons.timer_rounded : Icons.pin_rounded,
                                        size: 16,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(m.label, style: theme.textTheme.bodyLarge),
                                          Text(
                                            m.type == 'duration' ? 'Enter time' : 'Enter number',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (goalM?.target != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: SkillDrillsColors.success.withAlpha(20),
                                          borderRadius: SkillDrillsRadius.fullBorderRadius,
                                          border: Border.all(color: SkillDrillsColors.success.withAlpha(80)),
                                        ),
                                        child: Text(
                                          'Goal: ${m.type == 'duration' ? printDuration(Duration(seconds: goalM!.target!.toInt())) : goalM!.target!.toInt()}',
                                          style: const TextStyle(
                                            color: SkillDrillsColors.success,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    // Mock action buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SkillDrillsSpacing.md,
                        0,
                        SkillDrillsSpacing.md,
                        SkillDrillsSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.dividerColor),
                                borderRadius: SkillDrillsRadius.smBorderRadius,
                              ),
                              child: Center(child: Text('Skip', style: theme.textTheme.bodyMedium)),
                            ),
                          ),
                          const SizedBox(width: SkillDrillsSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary,
                                borderRadius: SkillDrillsRadius.smBorderRadius,
                              ),
                              child: Center(
                                child: Text(
                                  'Log Rep',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSecondary,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Choplin',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SkillDrillsSpacing.sm),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 12, color: theme.colorScheme.onPrimary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Preview only — actual session UI may vary slightly.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    _titleFieldController.dispose();
    super.dispose();
  }
}
