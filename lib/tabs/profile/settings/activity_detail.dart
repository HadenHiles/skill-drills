import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/firestore/skill.dart';
import 'package:skilldrills/widgets/basic_title.dart';

import 'category_item.dart';

final FirebaseAuth auth = FirebaseAuth.instance;
final user = FirebaseAuth.instance.currentUser;

class ActivityDetail extends StatefulWidget {
  const ActivityDetail({super.key, this.sport});

  final Activity? sport;

  @override
  State<ActivityDetail> createState() => _ActivityDetailState();
}

class _ActivityDetailState extends State<ActivityDetail> {
  final _formKey = GlobalKey<FormState>();
  final titleFieldController = TextEditingController();

  // ── Terminology controllers ────────────────────────────────────────────────
  final _drillLabelCtrl = TextEditingController();
  final _setsLabelCtrl = TextEditingController();
  final _repsLabelCtrl = TextEditingController();

  final _categoryFormKey = GlobalKey<FormState>();
  final categoryTitleFieldController = TextEditingController();
  bool _validateCategoryTitle = true;
  FocusNode? _categoryTitleFocusNode;

  List<Skill> _categories = [];
  int? _editingCategoryIndex;

  final AutovalidateMode _autoValidateMode = AutovalidateMode.onUserInteraction;

  @override
  void initState() {
    super.initState();
    final sport = widget.sport!;
    titleFieldController.text = sport.title!;

    // Pre-fill terminology with existing values (or activity defaults).
    _drillLabelCtrl.text = sport.drillLabel;
    _setsLabelCtrl.text = sport.setsLabel;
    _repsLabelCtrl.text = sport.repsLabel;

    if (sport.reference != null) {
      sport.reference!.collection('skills').get().then((snapshots) {
        List<Skill> categories = [];
        for (var doc in snapshots.docs) {
          categories.add(Skill.fromSnapshot(doc));
        }
        setState(() {
          _categories = categories;
        });
      });
    }

    _categoryTitleFocusNode = FocusNode();
    _categoryTitleFocusNode!.addListener(() {
      if (!_categoryTitleFocusNode!.hasFocus) {
        setState(() {
          _validateCategoryTitle = false;
          _editingCategoryIndex = null;
          categoryTitleFieldController.clear();
          _categoryTitleFocusNode!.unfocus();
        });
      } else {
        _validateCategoryTitle = true;
      }
    });
  }

  // ── Terminology helpers ───────────────────────────────────────────────────

  /// Resets all three terminology controllers to the defaults for the current title.
  void _resetTerminologyToDefaults() {
    final currentTitle = titleFieldController.text.trim();
    final defaults = ActivityTerminology.defaultsFor(currentTitle.isNotEmpty ? currentTitle : widget.sport!.title);
    setState(() {
      _drillLabelCtrl.text = defaults.drillLabel;
      _setsLabelCtrl.text = defaults.setsLabel;
      _repsLabelCtrl.text = defaults.repsLabel;
    });
  }

  String _effectiveDrillLabel() {
    final v = _drillLabelCtrl.text.trim();
    return v.isNotEmpty ? v : ActivityTerminology.defaultsFor(titleFieldController.text.trim()).drillLabel;
  }

  String _effectiveSetsLabel() {
    final v = _setsLabelCtrl.text.trim();
    return v.isNotEmpty ? v : ActivityTerminology.defaultsFor(titleFieldController.text.trim()).setsLabel;
  }

  String _effectiveRepsLabel() {
    final v = _repsLabelCtrl.text.trim();
    return v.isNotEmpty ? v : ActivityTerminology.defaultsFor(titleFieldController.text.trim()).repsLabel;
  }

  // ── Skills list ────────────────────────────────────────────────────────────

  Widget _buildCategoryList(BuildContext context) {
    List<CategoryItem> categoryItems = _categories
        .map((data) => CategoryItem(
              category: data,
              editCallback: _editSkill,
              deleteCallback: _removeSkill,
            ))
        .toList();

    return categoryItems.isNotEmpty
        ? ListView(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: categoryItems,
          )
        : Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Text("No skills yet", style: Theme.of(context).textTheme.bodyMedium),
            ),
          );
  }

  void _saveSkill(String value) {
    if (_categories.isNotEmpty && _editingCategoryIndex != null) {
      setState(() {
        _categories[_editingCategoryIndex!] = Skill(value);
        _editingCategoryIndex = null;
      });
    } else {
      setState(() {
        _categories.add(Skill(value));
      });
    }
    categoryTitleFieldController.clear();
    FocusScope.of(context).unfocus();
  }

  void _editSkill(Skill category) {
    int editIndex = _categories.indexWhere((cat) => cat == category);
    setState(() {
      _editingCategoryIndex = editIndex;
    });
    categoryTitleFieldController.text = category.title;
    _categoryTitleFocusNode!.requestFocus();
  }

  void _removeSkill(Skill category) {
    setState(() {
      _categories.remove(category);
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  void _onCreate() {
    if (_formKey.currentState!.validate()) {
      Activity a = Activity(
        titleFieldController.text.toString().trim(),
        user!.uid,
        drillLabel: _effectiveDrillLabel(),
        setsLabel: _effectiveSetsLabel(),
        repsLabel: _effectiveRepsLabel(),
      );
      DocumentReference activity = FirebaseFirestore.instance.collection("activities").doc(user!.uid).collection("activities").doc();
      a.id = activity.id;
      a.skills = _categories;
      activity.set(a.toMap());

      for (var c in _categories) {
        DocumentReference category = activity.collection('skills').doc();
        c.id = category.id;
        category.set(c.toMap());
      }

      Navigator.of(context).pop();
    }
  }

  void _onUpdate() {
    if (_formKey.currentState!.validate()) {
      Map<String, dynamic> activityMap = {
        "title": titleFieldController.text.toString().trim(),
        "created_by": user!.uid,
        "drill_label": _effectiveDrillLabel(),
        "sets_label": _effectiveSetsLabel(),
        "reps_label": _effectiveRepsLabel(),
      };

      FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(widget.sport!.reference!, activityMap);

        widget.sport!.reference!.collection('skills').get().then((snapshots) {
          for (var doc in snapshots.docs) {
            doc.reference.delete();
          }

          for (var c in _categories) {
            DocumentReference category = FirebaseFirestore.instance.collection("activities").doc(user!.uid).collection("activities").doc(widget.sport!.id).collection('skills').doc();
            c.id = category.id;
            category.set(c.toMap());
          }
        });

        navigatorKey.currentState!.pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.sport!.reference != null;
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
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
                child: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  titlePadding: null,
                  centerTitle: false,
                  title: BasicTitle(title: widget.sport!.title!),
                  background: Container(color: Theme.of(context).scaffoldBackgroundColor),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: IconButton(
                    icon: Icon(Icons.check, size: 28, color: Theme.of(context).colorScheme.secondary),
                    onPressed: isEditing ? _onUpdate : _onCreate,
                  ),
                ),
              ],
            ),
          ];
        },
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Title ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autoValidateMode,
                  child: TextFormField(
                    autovalidateMode: _autoValidateMode,
                    validator: (String? value) {
                      if (value!.isEmpty) return 'Enter a title';
                      if (value.isNotEmpty && !RegExp(r"^[a-zA-Z0-9 \-/_']+$").hasMatch(value)) {
                        return 'Remove special characters';
                      }
                      return null;
                    },
                    controller: titleFieldController,
                    decoration: const InputDecoration(
                      labelText: "Title",
                    ),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),

              // ── Terminology ───────────────────────────────────────────────
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("Terminology", style: Theme.of(context).textTheme.titleLarge),
                    TextButton.icon(
                      onPressed: _resetTerminologyToDefaults,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text("Reset to defaults"),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                child: Text(
                  "Customise how drills, sets, and reps are labelled for this activity.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _TerminologyField(
                      controller: _drillLabelCtrl,
                      label: "Drill label (singular)",
                      hint: ActivityTerminology.defaultsFor(titleFieldController.text.trim()).drillLabel,
                      icon: Icons.fitness_center_rounded,
                      helperText: 'e.g. "Drill", "Exercise", "Skill", "Piece"',
                    ),
                    const SizedBox(height: 12),
                    _TerminologyField(
                      controller: _setsLabelCtrl,
                      label: "Sets label",
                      hint: ActivityTerminology.defaultsFor(titleFieldController.text.trim()).setsLabel,
                      icon: Icons.repeat_rounded,
                      helperText: 'e.g. "Sets", "Rounds", "Intervals", "Passes"',
                    ),
                    const SizedBox(height: 12),
                    _TerminologyField(
                      controller: _repsLabelCtrl,
                      label: "Reps label",
                      hint: ActivityTerminology.defaultsFor(titleFieldController.text.trim()).repsLabel,
                      icon: Icons.loop_rounded,
                      helperText: 'e.g. "Reps", "Laps", "Times"',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // ── Skills ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Skills", style: Theme.of(context).textTheme.titleLarge),
                    Text("Tap a skill to edit", style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _categoryFormKey,
                  autovalidateMode: _autoValidateMode,
                  child: TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (String? value) {
                      if (value!.isEmpty && _validateCategoryTitle) return 'Please enter a skill name';
                      if (value.isNotEmpty && !RegExp(r"^[a-zA-Z0-9 \-/_']+$").hasMatch(value)) {
                        return 'No special characters are allowed';
                      }
                      return null;
                    },
                    controller: categoryTitleFieldController,
                    focusNode: _categoryTitleFocusNode,
                    decoration: InputDecoration(
                      labelText: _editingCategoryIndex != null ? "Edit Skill" : "Add Skill",
                      suffixIcon: IconButton(
                        icon: Icon(
                          _editingCategoryIndex != null ? Icons.check_circle : Icons.add_circle,
                          color: Theme.of(context).primaryColor,
                          size: 22,
                        ),
                        onPressed: () {
                          if (_categoryFormKey.currentState!.validate()) {
                            _saveSkill(categoryTitleFieldController.text.toString().trim());
                          }
                        },
                      ),
                    ),
                    onFieldSubmitted: (value) {
                      if (_categoryFormKey.currentState!.validate()) {
                        _saveSkill(value);
                      }
                    },
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildCategoryList(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    titleFieldController.dispose();
    _drillLabelCtrl.dispose();
    _setsLabelCtrl.dispose();
    _repsLabelCtrl.dispose();
    categoryTitleFieldController.dispose();
    _categoryTitleFocusNode!.dispose();
    super.dispose();
  }
}

// ── Reusable terminology text field ──────────────────────────────────────────

class _TerminologyField extends StatelessWidget {
  const _TerminologyField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
