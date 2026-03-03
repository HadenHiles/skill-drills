import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_picker_plus/flutter_picker_plus.dart';
import 'package:select_dialog/select_dialog.dart';
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
  const DrillDetail({super.key, this.drill});

  final Drill? drill;

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

    // Load the activities first
    FirebaseFirestore.instance.collection("activities").doc(auth.currentUser!.uid).collection("activities").get().then((snapshot) async {
      List<Activity> activities = [];
      if (snapshot.docs.isNotEmpty) {
        await Future.forEach(snapshot.docs, (doc) async {
          Activity a = Activity.fromSnapshot(doc);
          await _getCategories(doc.reference).then((categories) {
            a.skills = categories;

            if (widget.drill?.reference != null && a == widget.drill!.activity) {
              setState(() {
                _activity!.skills = a.skills;
              });
            }

            activities.add(a);
          });
        }).then((_) {
          setState(() {
            _activities = activities;
            _activity = _activity;
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

                      if (_activity!.title!.isNotEmpty && _selectedCategories!.isEmpty) {
                        hasErrors = true;
                        setState(() {
                          _categoryError = true;
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

                          newDoc.set(Drill(
                            _titleFieldController.text.trim(),
                            _descriptionFieldController.text.trim(),
                            _activity,
                            _drillType,
                          ).toMap());

                          for (var m in measurements) {
                            newDoc.collection('measurements').doc().set(m.toMap());
                          }

                          for (var c in _selectedCategories!) {
                            newDoc.collection('skills').doc().set(c.toMap());
                          }

                          navigatorKey.currentState!.pop();
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

  Widget _buildSectionHeader(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SkillDrillsSpacing.md,
        SkillDrillsSpacing.lg,
        SkillDrillsSpacing.md,
        SkillDrillsSpacing.sm,
      ),
      child: Row(
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
                      cursorColor: Theme.of(context).colorScheme.onPrimary,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Wall passes, Scale runs, Free throws',
                        hintStyle: Theme.of(context).textTheme.bodyMedium,
                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
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
                      cursorColor: Theme.of(context).colorScheme.onPrimary,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Optional — what does this drill practice?',
                        hintStyle: Theme.of(context).textTheme.bodyMedium,
                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
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
                  onTap: () {
                    SelectDialog.showModal<Activity>(
                      context,
                      label: 'Choose Activity',
                      items: _activities,
                      showSearchBox: false,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      alwaysShowScrollBar: true,
                      selectedValue: _activity,
                      itemBuilder: (BuildContext context, Activity activity, bool isSelected) {
                        return Container(
                          decoration: !isSelected
                              ? null
                              : BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: Theme.of(context).colorScheme.secondary.withAlpha(18),
                                  border: Border.all(color: Theme.of(context).colorScheme.secondary),
                                ),
                          child: ListTile(
                            selected: isSelected,
                            tileColor: Theme.of(context).colorScheme.surface,
                            title: Text(activity.title ?? '', style: Theme.of(context).textTheme.bodyLarge),
                          ),
                        );
                      },
                      emptyBuilder: (context) => Center(
                        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
                      ),
                      onChange: (selected) async {
                        await _getCategories(selected.reference!).then((cats) {
                          selected.skills = cats;
                          setState(() {
                            _activityError = false;
                            _activity = selected;
                            _selectedCategories = [];
                            _drill = Drill(_drill!.title, _drill!.description, selected, _drill!.drillType);
                          });
                        });
                      },
                    );
                  },
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
                              onTap: () {
                                SelectDialog.showModal<Skill>(
                                  context,
                                  label: 'Choose Skill(s)',
                                  items: _activity!.skills,
                                  showSearchBox: false,
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  alwaysShowScrollBar: true,
                                  multipleSelectedValues: _selectedCategories,
                                  itemBuilder: (BuildContext context, Skill category, bool isSelected) {
                                    return Container(
                                      decoration: !isSelected
                                          ? null
                                          : BoxDecoration(
                                              borderRadius: BorderRadius.circular(5),
                                              color: Theme.of(context).colorScheme.secondary.withAlpha(18),
                                              border: Border.all(color: Theme.of(context).colorScheme.secondary),
                                            ),
                                      child: ListTile(
                                        selected: isSelected,
                                        tileColor: Theme.of(context).colorScheme.surface,
                                        title: Text(category.title, style: Theme.of(context).textTheme.bodyLarge),
                                        trailing: isSelected ? const Icon(Icons.check) : null,
                                      ),
                                    );
                                  },
                                  onMultipleItemsChange: (List<Skill> selected) {
                                    setState(() {
                                      _categoryError = false;
                                      _selectedCategories = selected;
                                      Activity a = Activity(_activity!.title, null);
                                      a.skills = selected;
                                      _drill = Drill(_drill!.title, _drill!.description, a, _drill!.drillType);
                                    });
                                  },
                                  okButtonBuilder: (context, onPressed) {
                                    return Align(
                                      alignment: Alignment.centerRight,
                                      child: FloatingActionButton(onPressed: onPressed, mini: true, child: const Icon(Icons.check)),
                                    );
                                  },
                                );
                              },
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
        _buildSectionHeader(Icons.tune_rounded, 'Drill Type'),
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
                        _buildTypeGroupLabel(curated.isEmpty ? 'Drill Types' : 'Universal', theme),
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

  Widget _buildDrillTypeItem(DrillType dt, ThemeData theme) {
    final isSelected = _drillType?.id == dt.id;
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
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SkillDrillsSpacing.md,
          vertical: 14,
        ),
        color: isSelected ? Theme.of(context).colorScheme.secondary.withAlpha(12) : null,
        child: Row(
          children: [
            AnimatedContainer(
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
            const SizedBox(width: SkillDrillsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dt.title ?? '',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? theme.colorScheme.secondary : null,
                    ),
                  ),
                  if (dt.descriptor?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(dt.descriptor!, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            if (_drillTypeError && _drillType == null) Icon(Icons.error_outline_rounded, size: 16, color: theme.colorScheme.error),
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
