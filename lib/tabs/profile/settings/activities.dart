import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/activity.dart';
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
    return ValueListenableBuilder<bool>(
      valueListenable: isBootstrapping,
      builder: (context, bootstrapping, _) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("activities").doc(auth.currentUser!.uid).collection("activities").orderBy('title', descending: false).snapshots(),
          builder: (context, snapshot) {
            // Show bootstrap progress UI while the library is being built.
            if (bootstrapping && (!snapshot.hasData || snapshot.data!.docs.isEmpty)) {
              return _buildBootstrappingState(context);
            }

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
          },
        );
      },
    );
  }

  Widget _buildBootstrappingState(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.construction_rounded, size: 52, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              'Building Your Library…',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Setting up your activities and drills.\nThis only happens once.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<BootstrapProgress>(
              valueListenable: bootstrapProgress,
              builder: (context, progress, _) {
                return Column(
                  children: [
                    _BootstrapProgressRow(
                      label: 'Activities & Skills',
                      stage: progress.activities,
                      color: color,
                    ),
                    const SizedBox(height: 12),
                    _BootstrapProgressRow(
                      label: 'Drill Templates',
                      stage: progress.drillTypes,
                      color: color,
                    ),
                    const SizedBox(height: 12),
                    if (progress.drills == BootstrapStage.loading)
                      _DrillSeedProgressWidget(color: color)
                    else
                      _BootstrapProgressRow(
                        label: 'Default Drills',
                        stage: progress.drills,
                        color: color,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
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
                    color: Theme.of(context).colorScheme.onSurface,
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
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-activity drill seed progress widget
// ─────────────────────────────────────────────────────────────────────────────

class _DrillSeedProgressWidget extends StatefulWidget {
  final Color color;
  const _DrillSeedProgressWidget({required this.color});

  @override
  State<_DrillSeedProgressWidget> createState() => _DrillSeedProgressWidgetState();
}

class _DrillSeedProgressWidgetState extends State<_DrillSeedProgressWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return ValueListenableBuilder<DrillSeedProgress>(
      valueListenable: drillSeedProgress,
      builder: (context, progress, _) {
        final fraction = progress.drillsTotal > 0 ? progress.drillsDone / progress.drillsTotal : 0.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Default Drills',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                      ),
                      if (progress.activityName.isNotEmpty) ...[const SizedBox(height: 2), Text(progress.activityName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(progress.activityName),
                tween: Tween<double>(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_expanded ? 'Less' : 'More', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
                  Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: color),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildDetails(context, progress),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetails(BuildContext context, DrillSeedProgress progress) {
    final color = widget.color;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final activity in progress.completedActivities)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(activity, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          if (progress.activityName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: color)),
                  const SizedBox(width: 6),
                  Text(
                    '${progress.activityName} — ${progress.drillsDone} of ${progress.drillsTotal}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bootstrap progress row – label + linear progress bar + status icon
// ─────────────────────────────────────────────────────────────────────────────

class _BootstrapProgressRow extends StatelessWidget {
  final String label;
  final BootstrapStage stage;
  final Color color;

  const _BootstrapProgressRow({
    required this.label,
    required this.stage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = stage == BootstrapStage.done;
    final isLoading = stage == BootstrapStage.loading;
    final isPending = stage == BootstrapStage.pending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isPending ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38) : Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: isDone
                  ? Icon(Icons.check_circle_rounded, key: const ValueKey('done'), size: 18, color: color)
                  : isLoading
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: color),
                        )
                      : SizedBox(key: const ValueKey('pending'), width: 18, height: 18),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: isDone ? 1.0 : (isPending ? 0.0 : null),
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(
              isDone ? color : (isLoading ? color : Colors.transparent),
            ),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
