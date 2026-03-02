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
  Widget? _preview;

  @override
  void initState() {
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
            _preview = _buildPreview(_drill!);
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
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              collapsedHeight: 65,
              expandedHeight: 65,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Form(
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
                                labelText: "Title",
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _drill = Drill(value, _drill!.description, _drill!.activity, _drill!.drillType);
                                });
                              },
                            ),
                            TextFormField(
                              controller: _descriptionFieldController,
                              cursorColor: Theme.of(context).colorScheme.onPrimary,
                              decoration: InputDecoration(
                                labelText: "Description",
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              minLines: 4,
                              maxLines: 6,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _drill = Drill(_drill!.title, value, _drill!.activity, _drill!.drillType);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 20,
                  ),
                  leading: Text("Activity", style: Theme.of(context).textTheme.bodyLarge),
                  trailing: _activities == null
                      ? SizedBox(
                          height: 25,
                          width: 25,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      : Text(
                          _activity!.title!.isNotEmpty ? _activity!.title! : "choose",
                          style: TextStyle(
                            color: !_activityError ? Theme.of(context).colorScheme.onPrimary : Colors.red,
                            fontSize: 14,
                          ),
                        ),
                  onLongPress: () {
                    setState(() {
                      _activityError = false;
                      _activity = Activity("", null);
                      _selectedCategories = [];

                      setState(() {
                        _drill = Drill(_drill!.title, _drill!.description, Activity("", null), _drill!.drillType);
                      });
                    });
                  },
                  onTap: _activities == null
                      ? null
                      : () {
                          SelectDialog.showModal<Activity>(
                            context,
                            label: "Choose Activity",
                            items: _activities,
                            showSearchBox: false,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            alwaysShowScrollBar: true,
                            selectedValue: _activity,
                            itemBuilder: (BuildContext context, Activity activity, bool isSelected) {
                              return Container(
                                decoration: !isSelected
                                    ? null
                                    : BoxDecoration(
                                        borderRadius: BorderRadius.circular(5),
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                child: ListTile(
                                  selected: isSelected,
                                  tileColor: Theme.of(context).colorScheme.primary,
                                  title: Text(
                                    activity.title ?? "",
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              );
                            },
                            emptyBuilder: (context) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ],
                              );
                            },
                            onChange: (selected) async {
                              await _getCategories(selected.reference!).then((cats) async {
                                selected.skills = cats;

                                setState(() {
                                  _activityError = false;
                                  _activity = selected;
                                  _selectedCategories = [];

                                  setState(() {
                                    _drill = Drill(_drill!.title, _drill!.description, selected, _drill!.drillType);
                                  });
                                });
                              });
                            },
                          );
                        },
                ),
                (_activity!.skills?.length ?? 0) < 1
                    ? Container()
                    : ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 20,
                        ),
                        leading: Text(_selectedCategories!.length <= 1 ? "Skill" : "Skills", style: Theme.of(context).textTheme.bodyLarge),
                        trailing: Text(
                          _selectedCategories!.isNotEmpty ? _outputCategories() : "choose",
                          style: TextStyle(
                            color: !_categoryError ? Theme.of(context).colorScheme.onPrimary : Colors.red,
                            fontSize: 14,
                          ),
                        ),
                        onLongPress: () {
                          setState(() {
                            _categoryError = false;
                            _selectedCategories = [];
                            Activity a = Activity(_activity!.title, null);
                            a.skills = [];
                            _drill = Drill(_drill!.title, _drill!.description, a, _drill!.drillType);
                          });
                        },
                        onTap: () {
                          SelectDialog.showModal<Skill>(
                            context,
                            label: "Choose Skill(s)",
                            items: _activity!.skills,
                            showSearchBox: false,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            alwaysShowScrollBar: true,
                            multipleSelectedValues: _selectedCategories,
                            itemBuilder: (BuildContext context, Skill category, bool isSelected) {
                              return Container(
                                decoration: !isSelected
                                    ? null
                                    : BoxDecoration(
                                        borderRadius: BorderRadius.circular(5),
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                child: ListTile(
                                  selected: isSelected,
                                  tileColor: Theme.of(context).colorScheme.primary,
                                  title: Text(
                                    category.title,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
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
                                child: FloatingActionButton(
                                  onPressed: onPressed,
                                  mini: true,
                                  child: const Icon(Icons.check),
                                ),
                              );
                            },
                          );
                        },
                      ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 20,
                  ),
                  leading: Text("Type", style: Theme.of(context).textTheme.bodyLarge),
                  trailing: _drillTypes == null
                      ? SizedBox(
                          height: 25,
                          width: 25,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      : Text(
                          _drillType != null ? _drillType!.title! : "choose",
                          style: TextStyle(
                            color: !_drillTypeError ? Theme.of(context).colorScheme.onPrimary : Colors.red,
                            fontSize: 14,
                          ),
                        ),
                  onLongPress: () {
                    setState(() {
                      _drillTypeError = false;
                      _drillType = null;
                      _drill = Drill(_drill!.title, _drill!.description, _drill!.activity, null);
                    });
                  },
                  onTap: _drillTypes == null
                      ? null
                      : () {
                          SelectDialog.showModal<DrillType>(
                            context,
                            label: "Choose Type",
                            items: _drillTypes,
                            showSearchBox: false,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            alwaysShowScrollBar: true,
                            selectedValue: _drillType,
                            itemBuilder: (BuildContext context, DrillType drillType, bool isSelected) {
                              return Container(
                                decoration: !isSelected
                                    ? null
                                    : BoxDecoration(
                                        borderRadius: BorderRadius.circular(5),
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                child: ListTile(
                                  selected: isSelected,
                                  tileColor: Theme.of(context).colorScheme.primary,
                                  title: Text(
                                    drillType.title ?? "",
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  subtitle: Text(
                                    drillType.descriptor!,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              );
                            },
                            emptyBuilder: (context) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Theme.of(context).primaryColor,
                                  )
                                ],
                              );
                            },
                            onChange: (selected) async {
                              Drill d = Drill(_titleFieldController.text, _descriptionFieldController.text, _activity, selected);

                              setState(() {
                                _drillTypeError = false;
                                _drillType = selected;
                                // Deep copy so per-drill target edits never mutate the shared DrillType template
                                d.measurements = selected.measurements?.map((m) => Measurement(m.role, m.type, m.label, m.order, m.value, m.target, m.reverse)).toList();
                                d.skills = _selectedCategories;
                                _drill = d;
                                _targetFields = _buildDefaultTargetFields(d);
                                _preview = _buildPreview(d);
                              });
                            },
                          );
                        },
                ),
                _drillType?.timerInSeconds == null
                    ? Container()
                    : Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: TextField(
                              controller: _timerTextController,
                              keyboardType: TextInputType.number,
                              scrollPadding: const EdgeInsets.all(5),
                              style: Theme.of(context).textTheme.bodyLarge,
                              decoration: InputDecoration(
                                labelText: "Default Duration",
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
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                                    // You get your duration here
                                    Duration duration = Duration(hours: picker.getSelectedValues()[0], minutes: picker.getSelectedValues()[1], seconds: picker.getSelectedValues()[2]);

                                    _timerTextController.text = printDuration(duration);

                                    setState(() {
                                      _drillType!.timerInSeconds = duration.inSeconds;
                                    });
                                  },
                                ).showDialog(context);
                              },
                            ),
                          ),
                        ],
                      ),
                _drillType == null
                    ? Container()
                    : Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        child: _targetFields,
                      ),
              ],
            ),
            _preview == null
                ? Container()
                : ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 20,
                    ),
                    tileColor: Theme.of(context).colorScheme.primary,
                    title: Container(
                      margin: const EdgeInsets.only(left: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 5),
                            child: _drill!.title!.isNotEmpty
                                ? Text(
                                    "Preview of \"${_drill!.title}\"",
                                    style: Theme.of(context).textTheme.titleLarge,
                                  )
                                : Text(
                                    "Preview of \"(No Title)\"",
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                          ),
                          Text(_drill!.drillType!.descriptor!, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    trailing: InkWell(
                      onTap: _showPreview,
                      child: Icon(
                        Icons.keyboard_arrow_up,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    onTap: _showPreview,
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
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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

  void _showPreview() {
    setState(() {
      _preview = _buildPreview(_drill!);
    });
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      builder: (BuildContext context) {
        return _preview!;
      },
    );
  }

  Widget _buildPreview(Drill drill) {
    Map<int, TextEditingController> measurementTextControllers = {};
    List<Widget> measurementFields = [];

    // Use the drill's own measurements (which carry per-drill targets)
    drill.measurements?.asMap().forEach((i, m) {
      measurementTextControllers.putIfAbsent(i, () => TextEditingController());

      // Pre-fill target values using role and num? types
      if (m.role == 'target' && m.target != null) {
        switch (m.type) {
          case 'amount':
            measurementTextControllers[i]!.text = m.target!.toInt().toString();
            break;
          case 'duration':
            measurementTextControllers[i]!.text = printDuration(Duration(seconds: m.target!.toInt()));
            break;
          default:
        }
      }

      // Switch on type, not on metric
      switch (m.type) {
        case 'amount':
          measurementFields.add(
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: TextField(
                  controller: measurementTextControllers[i],
                  keyboardType: TextInputType.number,
                  scrollPadding: const EdgeInsets.all(5),
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: m.label,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );

          break;
        case "duration":
          measurementFields.add(
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: TextField(
                  controller: measurementTextControllers[i],
                  keyboardType: TextInputType.number,
                  scrollPadding: const EdgeInsets.all(5),
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: m.label,
                    labelStyle: TextStyle(
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
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                        // You get your duration here
                        Duration duration = Duration(hours: picker.getSelectedValues()[0], minutes: picker.getSelectedValues()[1], seconds: picker.getSelectedValues()[2]);

                        measurementTextControllers[i]!.text = printDuration(duration);
                      },
                    ).showDialog(context);
                  },
                ),
              ),
            ),
          );

          break;
        default:
      }
    });

    String drillTitle = drill.title!.isNotEmpty ? drill.title! : "(No Title)";

    Widget preview = GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
      },
      child: AbsorbPointer(
        child: SizedBox(
          height: 200,
          child: Card(
            color: Theme.of(context).colorScheme.primary,
            elevation: 1,
            margin: const EdgeInsets.all(0),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 5),
                                child: Text("Preview of \"$drillTitle\"", style: Theme.of(context).textTheme.titleLarge),
                              ),
                              Text(drill.drillType!.descriptor!, style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                          InkWell(
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                    height: 40,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              drillTitle,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Text(
                              _outputCategories(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: measurementFields,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return preview;
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    _titleFieldController.dispose();
    super.dispose();
  }
}
