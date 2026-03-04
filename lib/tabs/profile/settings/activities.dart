import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/services/factory.dart';
import 'package:skilldrills/services/subscription.dart';
import 'package:skilldrills/tabs/profile/settings/activity_detail.dart';
import 'package:skilldrills/tabs/profile/settings/activity_item.dart';
import 'package:skilldrills/widgets/basic_title.dart';
import 'package:skilldrills/widgets/paywall_screen.dart';

final FirebaseAuth auth = FirebaseAuth.instance;
final user = FirebaseAuth.instance.currentUser;

class ActivitiesSettings extends StatefulWidget {
  const ActivitiesSettings({super.key});

  @override
  State<ActivitiesSettings> createState() => _ActivitiesSettingsState();
}

class _ActivitiesSettingsState extends State<ActivitiesSettings> {
  /// Latest snapshot of all activities — kept in state so [_toggleActive]
  /// can count how many are currently active without an extra Firestore read.
  List<DocumentSnapshot<Map<String, dynamic>>> _activitiesSnapshot = [];

  @override
  void initState() {
    super.initState();
  }

  Widget _buildActivities(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("activities").doc(auth.currentUser!.uid).collection("activities").orderBy('title', descending: false).snapshots(),
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

          final docs = snapshot.data!.docs.cast<DocumentSnapshot<Map<String, dynamic>>>();
          // Keep a local copy so _toggleActive can count active items.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _activitiesSnapshot = docs);
          });
          return _buildActivityList(context, docs);
        });
  }

  Widget _buildActivityList(BuildContext context, List<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
    List<ActivityItem> items = snapshot
        .map((data) => ActivityItem(
              sport: Activity.fromSnapshot(data),
              deleteCallback: _deleteActivity,
              toggleCallback: _toggleActive,
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
                "There are no activities to display",
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          );
  }

  /// Toggles the [isActive] flag on [activity].
  ///
  /// When enabling an activity, checks whether the user has already reached
  /// [kFreeActiveActivityLimit] active activities and, if so, verifies they
  /// hold an active subscription before allowing the change.  Non-subscribed
  /// users who are at the limit are shown an upgrade prompt instead.
  Future<void> _toggleActive(Activity activity, bool isActive) async {
    if (isActive) {
      final activeCount = _activitiesSnapshot.map((doc) => Activity.fromSnapshot(doc)).where((a) => a.isActive && a.reference?.id != activity.reference?.id).length;

      if (activeCount >= kFreeActiveActivityLimit) {
        final subscribed = await hasActiveSubscription();
        if (!subscribed) {
          if (!mounted) return;
          dialog(
            context,
            SkillDrillsDialog(
              "Upgrade to unlock more",
              Text(
                "Free accounts can have up to $kFreeActiveActivityLimit active activities.\n\nUpgrade to a paid plan to unlock unlimited active activities.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              "Not now",
              () => Navigator.of(context).pop(),
              "Upgrade",
              () {
                Navigator.of(context).pop();
                navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
              },
            ),
          );
          return;
        }
      }
    }

    FirebaseFirestore.instance.collection('activities').doc(auth.currentUser!.uid).collection('activities').doc(activity.reference!.id).update({'is_active': isActive});
  }

  void _deleteActivity(Activity activity) {
    FirebaseFirestore.instance.collection("activities").doc(auth.currentUser!.uid).collection("activities").doc(activity.reference!.id).get().then((doc) {
      doc.reference.collection('skills').get().then((catSnapshots) {
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
                  title: Row(
                    children: [
                      const BasicTitle(title: "Activities"),
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
                        return ActivityDetail(sport: Activity("New Activity", user?.uid));
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
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.all(25),
                ),
                child: const Text(
                  "Reset to defaults",
                  style: TextStyle(fontSize: 20),
                ),
                onPressed: () {
                  dialog(
                    context,
                    SkillDrillsDialog(
                      "Reset Activities?",
                      const Text(
                        "This will restore all default activities and their terminology.\n\nThis can't be undone.",
                        textAlign: TextAlign.center,
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
