import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/tabs/profile/settings/activity_detail.dart';

final user = FirebaseAuth.instance.currentUser;

class ActivityItem extends StatefulWidget {
  const ActivityItem({super.key, this.activity, this.deleteCallback});

  final Activity? activity;
  final Function? deleteCallback;

  @override
  State<ActivityItem> createState() => _ActivityItemState();
}

class _ActivityItemState extends State<ActivityItem> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 5, left: 5, right: 5),
      color: Theme.of(context).cardTheme.color,
      elevation: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ListTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.activity!.title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 28,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                onPressed: () {
                  dialog(
                      context,
                      SkillDrillsDialog(
                        "Delete \"${widget.activity!.title}\"?",
                        Text(
                          "Are you sure you want to delete this activity?\n\nThis action cannot be undone.",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                        null,
                        () {
                          Navigator.of(context).pop();
                        },
                        "Delete",
                        () {
                          widget.deleteCallback!(widget.activity);
                          Navigator.of(context).pop();
                        },
                      ));
                },
                icon: Icon(
                  Icons.delete,
                  color: Theme.of(context).iconTheme.color,
                  size: 20,
                ),
              ),
            ],
          ),
          onTap: () {
            navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) {
              return ActivityDetail(activity: widget.activity);
            }));
          },
        ),
      ),
    );
  }
}
