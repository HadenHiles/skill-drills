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

  final _categoryFormKey = GlobalKey<FormState>();
  final categoryTitleFieldController = TextEditingController();
  bool _validateCategoryTitle = true;
  FocusNode? _categoryTitleFocusNode;

  List<Skill> _categories = [];
  int? _editingCategoryIndex;

  final AutovalidateMode _autoValidateMode = AutovalidateMode.onUserInteraction;

  @override
  void initState() {
    titleFieldController.text = widget.sport!.title!;

    if (widget.sport!.reference != null) {
      widget.sport!.reference!.collection('skills').get().then((snapshots) {
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

    super.initState();
  }

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
            children: categoryItems,
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 20),
                child: const Center(
                  child: Text(
                    "No skills yet",
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
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
                  title: BasicTitle(title: widget.sport!.title!),
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
                    onPressed: widget.sport!.reference == null
                        ? () {
                            if (_formKey.currentState!.validate()) {
                              // Create the activity
                              Activity a = Activity(
                                titleFieldController.text.toString().trim(),
                                user!.uid,
                              );
                              DocumentReference activity = FirebaseFirestore.instance.collection("activities").doc(user!.uid).collection("activities").doc();
                              a.id = activity.id;
                              a.skills = _categories;
                              activity.set(a.toMap());

                              // Add the categories for the activity
                              for (var c in _categories) {
                                DocumentReference category = activity.collection('skills').doc();
                                c.id = category.id;
                                category.set(c.toMap());
                              }

                              Navigator.of(context).pop();
                            }
                          }
                        : () {
                            if (_formKey.currentState!.validate()) {
                              // Setup updates for the top level activity
                              Map<String, dynamic> activityMap = {
                                "title": titleFieldController.text.toString().trim(),
                                "created_by": user!.uid,
                              };

                              FirebaseFirestore.instance.runTransaction((transaction) async {
                                transaction.update(
                                  widget.sport!.reference!,
                                  activityMap,
                                );

                                // Remove the old categories
                                widget.sport!.reference!.collection('skills').get().then((snapshots) {
                                  for (var doc in snapshots.docs) {
                                    doc.reference.delete();
                                  }

                                  // Save the updated categories
                                  for (var c in _categories) {
                                    DocumentReference category = FirebaseFirestore.instance.collection("activities").doc(user!.uid).collection("activities").doc(widget.sport!.id).collection('skills').doc();
                                    c.id = category.id;
                                    category.set(c.toMap());
                                  }
                                });

                                navigatorKey.currentState!.pop();
                              });
                            }
                          },
                  ),
                ),
              ],
            ),
          ];
        },
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Form(
                    key: _formKey,
                    autovalidateMode: _autoValidateMode,
                    child: Column(
                      children: [
                        TextFormField(
                          autovalidateMode: _autoValidateMode,
                          validator: (String? value) {
                            if (value!.isEmpty) {
                              return 'Enter a title';
                            } else if (value.isNotEmpty && !RegExp(r"^[a-zA-Z0-9 -/_']+$").hasMatch(value)) {
                              return 'Remove special characters';
                            }
                            return null;
                          },
                          controller: titleFieldController,
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Skills",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    "Tap a skill to edit",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Column(
                children: [
                  Form(
                    key: _categoryFormKey,
                    autovalidateMode: _autoValidateMode,
                    child: Column(
                      children: [
                        TextFormField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (String? value) {
                            if (value!.isEmpty && _validateCategoryTitle) {
                              return 'Please enter a skill name';
                            } else if (value.isNotEmpty && !RegExp(r"^[a-zA-Z0-9 -/_']+$").hasMatch(value)) {
                              return 'No special characters are allowed';
                            }

                            return null;
                          },
                          controller: categoryTitleFieldController,
                          focusNode: _categoryTitleFocusNode,
                          cursorColor: Theme.of(context).colorScheme.onPrimary,
                          decoration: InputDecoration(
                              labelText: _editingCategoryIndex != null ? "Edit Skill" : "Add Skill",
                              labelStyle: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 14,
                              ),
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
                              )),
                          onFieldSubmitted: (value) {
                            if (_categoryFormKey.currentState!.validate()) {
                              _saveSkill(value);
                            }
                          },
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.only(top: 5),
                child: _buildCategoryList(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    titleFieldController.dispose();
    categoryTitleFieldController.dispose();
    _categoryTitleFocusNode!.dispose();
    super.dispose();
  }
}
