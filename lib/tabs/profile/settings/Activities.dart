import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/Activity.dart';
import 'package:skilldrills/models/SkillDrillsDialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/services/factory.dart';
import 'package:skilldrills/tabs/profile/settings/ActivityDetail.dart';
import 'package:skilldrills/tabs/profile/settings/ActivityItem.dart';
import 'package:skilldrills/widgets/BasicTitle.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

class ActivitiesSettings extends StatefulWidget {
  const ActivitiesSettings({super.key});

  @override
  _ActivitiesSettingsState createState() => _ActivitiesSettingsState();
}

class _ActivitiesSettingsState extends State<ActivitiesSettings> {
  @override
  void initState() {
    super.initState();
  }

  Widget _buildActivities(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('activities').doc(auth.currentUser!.uid).collection('activities').orderBy('title', descending: false).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
              ],
            );
          }

          return _buildActivityList(context, snapshot.data!.docs.cast<DocumentSnapshot<Map<String, dynamic>>>());
        });
  }

  Widget _buildActivityList(BuildContext context, List<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
    List<ActivityItem> items = snapshot
        .map((data) => ActivityItem(
              activity: Activity.fromSnapshot(data),
              deleteCallback: _deleteActivity,
            ))
        .toList();

    return items.isNotEmpty
        ? ListView(
            padding: const EdgeInsets.only(top: 10),
            children: items,
          )
        : const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "There are no sports (activities) to display",
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          );
  }

  void _deleteActivity(Activity activity) {
    FirebaseFirestore.instance.collection('activities').doc(auth.currentUser!.uid).collection('activities').doc(activity.reference!.id).get().then((doc) {
      doc.reference.collection('categories').get().then((catSnapshots) {
        for (var cDoc in catSnapshots.docs) {
          cDoc.reference.delete();
        }
      });

      doc.reference.delete();
    });
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
                  color: Theme.of(context).colorScheme.background,
                ),
                child: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  titlePadding: null,
                  centerTitle: false,
                  title: Row(
                    children: [
                      const BasicTitle(title: "Sports"),
                      Container(
                        margin: const EdgeInsets.only(left: 10),
                        child: Text(
                          "(Activities)",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  background: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: IconButton(
                    icon: const Icon(
                      Icons.add,
                      size: 28,
                    ),
                    onPressed: () {
                      navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) {
                        return const ActivityDetail();
                      }));
                    },
                  ),
                ),
              ],
            ),
          ];
        },
        body: Column(
          children: [
            Flexible(
              child: _buildActivities(context),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(25),
                ),
                child: const Text(
                  "Reset to defaults",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.red,
                  ),
                ),
                onPressed: () {
                  dialog(
                    context,
                    SkillDrillsDialog(
                      "Reset Sports?",
                      Text(
                        "Are you sure you want to reset your sports?\n\nThis can't be undone.",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      "Cancel",
                      () {
                        Navigator.of(context).pop();
                      },
                      "Reset",
                      () {
                        resetActivities();
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
