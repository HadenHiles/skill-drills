import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/firestore/skill.dart';
import 'package:skilldrills/services/subscription.dart';
import 'package:skilldrills/theme/activity_theme.dart';
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

  // ── Appearance state ──────────────────────────────────────────────────────
  late String _icon;
  int? _customColor;

  // ── Pro subscription state ────────────────────────────────────────────────
  bool _isPro = true; // optimistic default prevents flash
  StreamSubscription<CustomerInfo>? _subscriptionListener;

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

    // Appearance
    _icon = sport.icon;
    _customColor = sport.customColor;

    // Pre-fill terminology with existing values (or activity defaults).
    _drillLabelCtrl.text = sport.drillLabel;
    _setsLabelCtrl.text = sport.setsLabel;
    _repsLabelCtrl.text = sport.repsLabel;

    _initSubscriptionState();

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

  // ── Pro subscription helpers ──────────────────────────────────────────────

  Future<void> _initSubscriptionState() async {
    final isPro = await hasActiveSubscription();
    if (mounted) setState(() => _isPro = isPro);
    _subscriptionListener = customerInfoStream.listen((info) {
      final nowPro = info.entitlements.active.containsKey(kProEntitlement);
      if (mounted) setState(() => _isPro = nowPro);
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
        icon: _icon,
        customColor: _customColor,
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
        "icon": _icon,
        if (_customColor != null) "custom_color": _customColor,
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
                    color: Theme.of(context).colorScheme.onSurface,
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
                  "Customize how drills, sets, and reps are labelled for this activity.",
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

              // ── Appearance ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text("Appearance", style: Theme.of(context).textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                child: Text(
                  "Choose an icon for this activity.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                ),
              ),
              // Icon emoji picker
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _AppearanceIconRow(
                  icon: _icon,
                  onChanged: (v) => setState(() => _icon = v),
                ),
              ),
              const SizedBox(height: 20),
              // Color swatch grid — Pro only
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _AppearanceColorPicker(
                  selectedColor: _customColor != null ? Color(_customColor!) : null,
                  isPro: _isPro,
                  onSelected: (c) => setState(() => _customColor = c?.toARGB32()),
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
    _subscriptionListener?.cancel();
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

// ── Appearance: icon row ──────────────────────────────────────────────────────

/// A row containing a preview chip and a text field for the activity emoji icon.
class _AppearanceIconRow extends StatefulWidget {
  const _AppearanceIconRow({required this.icon, required this.onChanged});

  final String icon;
  final ValueChanged<String> onChanged;

  @override
  State<_AppearanceIconRow> createState() => _AppearanceIconRowState();
}

class _AppearanceIconRowState extends State<_AppearanceIconRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.icon);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _isSingleEmoji(String v) {
    if (v.isEmpty) return false;
    // Dart's runes give Unicode code points; a single "visual" emoji may
    // comprise multiple code points (e.g. skin tone modifiers, ZWJ sequences).
    // We accept any non-empty single-grapheme-cluster string as a valid icon.
    // Simple heuristic: ≤ 8 code points and the length in runes is ≥ 1.
    return v.runes.isNotEmpty && v.runes.length <= 8;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Preview chip
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              widget.icon,
              style: const TextStyle(fontSize: 26, height: 1.0),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _ctrl,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Icon (emoji)',
              helperText: 'Enter a single emoji',
              counterText: '',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 22, height: 1.3),
            onChanged: (v) {
              if (_isSingleEmoji(v.trim())) {
                widget.onChanged(v.trim());
              }
            },
          ),
        ),
      ],
    );
  }
}

// ── Appearance: color swatch picker ──────────────────────────────────────────

/// A grid of color swatches that Pro users can tap to set the activity accent.
/// Free users see the swatches dimmed with a Pro upgrade prompt.
class _AppearanceColorPicker extends StatelessWidget {
  const _AppearanceColorPicker({
    required this.selectedColor,
    required this.isPro,
    required this.onSelected,
  });

  final Color? selectedColor;
  final bool isPro;
  final ValueChanged<Color?> onSelected;

  @override
  Widget build(BuildContext context) {
    final swatches = ActivityColors.pickerSwatches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Accent color", style: Theme.of(context).textTheme.bodyLarge),
            if (!isPro) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Pro',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isPro ? 'Choose a custom accent colour for this activity.' : 'Upgrade to Pro to set a custom accent colour.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: isPro ? 1.0 : 0.35,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // "None" swatch — clears custom colour, reverts to default
              _SwatchTile(
                color: null,
                isSelected: selectedColor == null,
                isEnabled: isPro,
                onTap: isPro ? () => onSelected(null) : null,
              ),
              for (final c in swatches)
                _SwatchTile(
                  color: c,
                  isSelected: selectedColor?.toARGB32() == c.toARGB32(),
                  isEnabled: isPro,
                  onTap: isPro ? () => onSelected(c) : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SwatchTile extends StatelessWidget {
  const _SwatchTile({
    required this.color,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final Color? color;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isNone = color == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isNone ? Colors.transparent : color,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
            width: isSelected ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isNone
            ? Center(
                child: Icon(
                  Icons.block_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              )
            : isSelected
                ? const Center(
                    child: Icon(Icons.check_rounded, size: 18, color: Colors.white),
                  )
                : null,
      ),
    );
  }
}
