import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
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

  /// Whether the current user holds an active Pro subscription.
  /// Defaults to `true` (optimistic) until the first check resolves so the
  /// UI doesn't flash a limit-reached banner on fast devices.
  bool _isPro = true;
  StreamSubscription<CustomerInfo>? _subscriptionListener;

  /// Number of currently active activities derived from the latest snapshot.
  int get _activeCount => _activitiesSnapshot.map(Activity.fromSnapshot).where((a) => a.isActive).length;

  @override
  void initState() {
    super.initState();
    _initSubscriptionState();
  }

  /// Fetches the initial subscription state and subscribes to live updates so
  /// the nudge banner and lock states stay in sync without a restart.
  Future<void> _initSubscriptionState() async {
    final isPro = await hasActiveSubscription();
    if (mounted) setState(() => _isPro = isPro);

    _subscriptionListener = customerInfoStream.listen((info) {
      final nowPro = info.entitlements.active.containsKey(kProEntitlement);
      if (mounted) setState(() => _isPro = nowPro);
    });
  }

  @override
  void dispose() {
    _subscriptionListener?.cancel();
    super.dispose();
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
    final activeCount = snapshot.map(Activity.fromSnapshot).where((a) => a.isActive).length;
    final atLimit = !_isPro && activeCount >= kFreeActiveActivityLimit;

    List<ActivityItem> items = snapshot.map((data) {
      final activity = Activity.fromSnapshot(data);
      return ActivityItem(
        sport: activity,
        deleteCallback: _deleteActivity,
        toggleCallback: _toggleActive,
        // Show the "upgrade to unlock" indicator on inactive items when the
        // user is not pro and has already reached the active limit.
        isLockedByPlan: atLimit && !activity.isActive,
      );
    }).toList();

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
  /// **Free-tier behaviour when enabling:**
  /// Instead of showing a hard block, the system automatically deactivates the
  /// activity that was activated the longest ago (determined by
  /// [kActivityLastActivatedAtField]) and activates the requested one.  A
  /// snackbar informs the user of the swap and nudges them toward Pro.
  ///
  /// This makes it structurally impossible for a free user to have more than
  /// [kFreeActiveActivityLimit] active activities simultaneously — they can
  /// swap freely, but never accumulate extras.
  Future<void> _toggleActive(Activity activity, bool isActive) async {
    final uid = auth.currentUser!.uid;
    final actRef = FirebaseFirestore.instance.collection('activities').doc(uid).collection('activities').doc(activity.reference!.id);

    if (isActive) {
      // Activities currently active, excluding the one being enabled.
      final otherActive = _activitiesSnapshot.map(Activity.fromSnapshot).where((a) => a.isActive && a.reference?.id != activity.reference?.id).toList();

      if (!_isPro && otherActive.length >= kFreeActiveActivityLimit) {
        // Auto-deactivate the activity that was activated the longest ago.
        final oldest = _findOldestActivated(otherActive);
        if (oldest != null) {
          final oldRef = FirebaseFirestore.instance.collection('activities').doc(uid).collection('activities').doc(oldest.reference!.id);

          final batch = FirebaseFirestore.instance.batch();
          batch.update(oldRef, {'is_active': false});
          batch.update(actRef, {
            'is_active': true,
            kActivityLastActivatedAtField: FieldValue.serverTimestamp(),
          });
          await batch.commit();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '"${oldest.title}" was deactivated to make room. '
                  'Upgrade to Pro for unlimited active activities.',
                ),
                action: SnackBarAction(
                  label: 'Upgrade',
                  onPressed: () => navigatorKey.currentState!.push(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  ),
                ),
              ),
            );
          }
          return;
        }
      }

      // Within the free limit (or user is Pro): just activate.
      await actRef.update({
        'is_active': true,
        kActivityLastActivatedAtField: FieldValue.serverTimestamp(),
      });
    } else {
      await actRef.update({'is_active': false});
    }
  }

  /// Returns the [Activity] from [activities] whose [Activity.lastActivatedAt]
  /// is the earliest, treating `null` as older than any real timestamp.
  Activity? _findOldestActivated(List<Activity> activities) {
    if (activities.isEmpty) return null;
    return activities.reduce((oldest, a) {
      if (oldest.lastActivatedAt == null) return oldest;
      if (a.lastActivatedAt == null) return a;
      return a.lastActivatedAt!.isBefore(oldest.lastActivatedAt!) ? a : oldest;
    });
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

  /// Nudge banner shown when the user is on the free plan and has reached the
  /// activity limit.  Tapping "Upgrade" opens the paywall.
  Widget _buildFreeLimitBanner(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    children: [
                      TextSpan(
                        text: 'Free plan: ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: 'up to $kFreeActiveActivityLimit active activities. '
                            'Tap to upgrade and unlock all.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
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
            if (!_isPro && _activeCount >= kFreeActiveActivityLimit) _buildFreeLimitBanner(context),
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
