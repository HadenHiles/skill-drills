import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:skilldrills/models/onboarding_preferences.dart';
import 'package:skilldrills/onboarding/welcome_screen.dart';
import 'package:skilldrills/services/haptics.dart';
import 'package:skilldrills/services/subscription.dart';
import 'package:skilldrills/widgets/paywall_screen.dart';
import 'package:skilldrills/session.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/services/session.dart';
import 'package:skilldrills/services/utility.dart';
import 'package:skilldrills/tabs/drills.dart';
import 'package:skilldrills/tabs/history.dart';
import 'package:skilldrills/tabs/profile.dart';
import 'package:skilldrills/tabs/routines.dart';
import 'package:skilldrills/services/factory.dart';
import 'package:skilldrills/tabs/Start.dart';
import 'package:skilldrills/theme/theme.dart';
import 'package:skilldrills/tabs/drills/drill_detail.dart';
import 'package:skilldrills/tabs/routines/routine_detail.dart';
import 'package:skilldrills/tabs/profile/settings/settings.dart';
import 'package:skilldrills/widgets/basic_title.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:skilldrills/nav_tab.dart';

final PanelController sessionPanelController = PanelController();

// This is the stateful widget that the main application instantiates.
class Nav extends StatefulWidget {
  /// When `true`, the RevenueCat paywall is presented on the first frame if
  /// the user does not already hold the Pro entitlement.  Set to `true` after
  /// a fresh sign-in or sign-up.
  final bool showPaywall;

  const Nav({super.key, this.showPaywall = false});

  @override
  State<Nav> createState() => _NavState();
}

/// This is the private State class that goes with MyStatefulWidget.
class _NavState extends State<Nav> {
  final lightLogo = SizedBox(
    height: 60,
    child: SvgPicture.asset(
      'assets/images/logo/SkillDrills.svg',
      semanticsLabel: 'Skill Drills',
    ),
  );

  // State variables
  PanelState _sessionPanelState = PanelState.CLOSED;
  double _bottomNavOffsetPercentage = 0;

  Widget? _title;
  List<Widget>? _actions;
  int _selectedIndex = 2;
  bool _showLogoToolbar = true;

  /// Subscription to [customerInfoStream] used to enforce the free-tier
  /// activity limit whenever the user's entitlement state changes (e.g. a
  /// subscription lapses while the app is in the foreground).
  StreamSubscription<CustomerInfo>? _subscriptionEnforcementListener;
  static final List<NavTab> _tabs = [
    NavTab(
      title: const BasicTitle(title: "Profile"),
      actions: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          child: IconButton(
            icon: const Icon(
              Icons.settings,
              size: 28,
            ),
            onPressed: () {
              navigatorKey.currentState!.push(
                PageRouteBuilder(
                  pageBuilder: (ctx, anim, _) => const ProfileSettings(),
                  transitionDuration: const Duration(milliseconds: 320),
                  transitionsBuilder: (ctx, anim, _, child) => FadeTransition(
                    opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
      ],
      body: const Profile(),
    ),
    const NavTab(
      title: BasicTitle(title: "History"),
      body: History(),
    ),
    NavTab(
      title: const BasicTitle(title: "Start"),
      body: Start(
        sessionPanelController: sessionPanelController,
      ),
    ),
    NavTab(
      title: const BasicTitle(title: "Drills"),
      actions: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          child: IconButton(
            icon: const Icon(
              Icons.add,
              size: 28,
            ),
            onPressed: () {
              navigatorKey.currentState!.push(
                PageRouteBuilder(
                  pageBuilder: (ctx, anim, _) => const DrillDetail(),
                  transitionDuration: const Duration(milliseconds: 320),
                  transitionsBuilder: (ctx, anim, _, child) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
                    return FadeTransition(
                      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
      body: const Drills(),
    ),
    NavTab(
      title: const BasicTitle(title: "Routines"),
      actions: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          child: IconButton(
            icon: const Icon(
              Icons.add,
              size: 28,
            ),
            onPressed: () {
              navigatorKey.currentState!.push(
                PageRouteBuilder(
                  pageBuilder: (ctx, anim, _) => const RoutineDetail(),
                  transitionDuration: const Duration(milliseconds: 320),
                  transitionsBuilder: (ctx, anim, _, child) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
                    return FadeTransition(
                      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
      body: const Routines(),
    ),
  ];

  void _onItemTapped(int index) async {
    if (index != _selectedIndex) hapticNavTap();

    setState(() {
      _selectedIndex = index;
      _title = index == 2 ? lightLogo : _tabs[index].title;
      _actions = _tabs[index].actions;
      _showLogoToolbar = (_tabs[index].title is Container) || index == 2;
    });
  }

  @override
  void initState() {
    super.initState();

    setState(() {
      _title = lightLogo;
      _actions = [];
    });

    bootstrap();

    // Listen for subscription state changes and enforce the activity limit
    // immediately when the user's Pro entitlement becomes inactive (e.g. on
    // subscription lapse or cancellation while the app is open).
    _subscriptionEnforcementListener = customerInfoStream.listen((info) {
      final isPro = info.entitlements.active.containsKey(kProEntitlement);
      if (!isPro) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) enforceActivityLimit(uid);
      }
    });

    // Show the custom paywall on first frame after a fresh sign-in / sign-up,
    // but only if the user isn't already subscribed.
    if (widget.showPaywall) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final alreadyPro = await hasActiveSubscription();
        if (!alreadyPro) {
          navigatorKey.currentState!
              .push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const PaywallScreen(showSkip: true),
            ),
          )
              .then((_) async {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            final seen = await OnboardingPreferences.hasSeenWelcome(uid: uid);
            if (!seen && navigatorKey.currentState != null) {
              navigatorKey.currentState!.push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => const WelcomeScreen(initialPage: 1),
                ),
              );
            }
          });
        } else {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final seen = await OnboardingPreferences.hasSeenWelcome(uid: uid);
          if (!seen && navigatorKey.currentState != null) {
            navigatorKey.currentState!.push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const WelcomeScreen(initialPage: 1),
              ),
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _subscriptionEnforcementListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isInitialSeeding,
      builder: (context, seeding, _) {
        if (seeding) return _buildSeedingScreen(context);
        return _buildMainScaffold(context);
      },
    );
  }

  Widget _buildMainScaffold(BuildContext context) {
    return SessionServiceProvider(
      service: sessionService,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: sessionService, // listen to ChangeNotifier
          builder: (context, child) {
            return SlidingUpPanel(
              backdropEnabled: true,
              controller: sessionPanelController,
              maxHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
              minHeight: (sessionService.isRunning == true) ? 65 : 0,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              onPanelOpened: () {
                setState(() {
                  _sessionPanelState = PanelState.OPEN;
                });
              },
              onPanelClosed: () {
                setState(() {
                  _sessionPanelState = PanelState.CLOSED;
                });
              },
              onPanelSlide: (double offset) {
                setState(() {
                  _bottomNavOffsetPercentage = offset;
                });
              },
              panel: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Column(
                  children: [
                    Material(
                      color: Theme.of(context).primaryColor,
                      child: ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                sessionService.sessionTitle ?? SessionService.defaultSessionTitle(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: "Choplin",
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  printDuration(sessionService.currentDuration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: "Choplin",
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: InkWell(
                          child: Icon(
                            _sessionPanelState == PanelState.CLOSED ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
                        onTap: () {
                          if (sessionPanelController.isPanelClosed) {
                            sessionPanelController.open();
                            setState(() {
                              _sessionPanelState = PanelState.OPEN;
                            });
                          } else {
                            sessionPanelController.close();
                            setState(() {
                              _sessionPanelState = PanelState.CLOSED;
                            });
                          }
                        },
                      ), // ListTile
                    ), // Material
                    Expanded(
                      child: Session(
                        sessionPanelController: sessionPanelController,
                      ),
                    ),
                  ],
                ),
              ),
              body: NestedScrollView(
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      collapsedHeight: _showLogoToolbar ? 100 : 65,
                      expandedHeight: _showLogoToolbar ? 200.0 : 140,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      iconTheme: Theme.of(context).iconTheme,
                      actionsIconTheme: Theme.of(context).iconTheme,
                      floating: true,
                      pinned: true,
                      flexibleSpace: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _showLogoToolbar ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.surface,
                        ),
                        child: FlexibleSpaceBar(
                          collapseMode: CollapseMode.parallax,
                          titlePadding: _showLogoToolbar ? const EdgeInsets.only(left: 10, right: 10, bottom: 20, top: 20) : null,
                          centerTitle: _showLogoToolbar ? true : false,
                          title: _title,
                          background: Container(
                            color: _showLogoToolbar ? Theme.of(context).primaryColor : Theme.of(context).scaffoldBackgroundColor,
                          ),
                        ),
                      ),
                      actions: _actions,
                    ),
                  ];
                },
                body: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    child: child,
                  ),
                  child: Container(
                    key: ValueKey(_selectedIndex),
                    // Always pad the bottom so content isn't hidden behind the
                    // bottom nav bar or the session panel.  NestedScrollView
                    // doesn't inherit the Scaffold's bottom inset automatically,
                    // so we apply it explicitly here for every tab at once.
                    padding: EdgeInsets.only(
                      bottom: _sessionPanelState == PanelState.OPEN ? 100 : kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom,
                    ),
                    child: _tabs.elementAt(_selectedIndex),
                  ),
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: SizedOverflowBox(
          alignment: AlignmentDirectional.topCenter,
          size: Size.fromHeight(AppBar().preferredSize.height - (AppBar().preferredSize.height * _bottomNavOffsetPercentage)),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add),
                label: 'Start',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.timer),
                label: 'Drills',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event_note),
                label: 'Routines',
              ),
            ],
            currentIndex: _selectedIndex,
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
            unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }

  Widget _buildSeedingScreen(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: color.withAlpha(18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.construction_rounded, size: 52, color: color),
                ),
                const SizedBox(height: SkillDrillsSpacing.lg),
                Text(
                  'Building Your Library\u2026',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SkillDrillsSpacing.sm),
                Text(
                  'Setting up your activities, drill templates, and default drills.\nThis only happens once.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SkillDrillsSpacing.lg),
                ValueListenableBuilder<BootstrapProgress>(
                  valueListenable: bootstrapProgress,
                  builder: (context, progress, _) {
                    return Column(
                      children: [
                        _SeedProgressRow(label: 'Activities & Skills', stage: progress.activities),
                        const SizedBox(height: SkillDrillsSpacing.sm),
                        _SeedProgressRow(label: 'Drill Templates', stage: progress.drillTypes),
                        const SizedBox(height: SkillDrillsSpacing.sm),
                        if (progress.drills == BootstrapStage.loading) const _SeedDrillsProgressWidget() else _SeedProgressRow(label: 'Default Drills', stage: progress.drills),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seeding screen helpers (used only during first-install / data-reset)
// ─────────────────────────────────────────────────────────────────────────────

class _SeedProgressRow extends StatelessWidget {
  final String label;
  final BootstrapStage stage;

  const _SeedProgressRow({required this.label, required this.stage});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
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
            valueColor: AlwaysStoppedAnimation<Color>(isDone ? color : (isLoading ? color : Colors.transparent)),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

class _SeedDrillsProgressWidget extends StatefulWidget {
  const _SeedDrillsProgressWidget();

  @override
  State<_SeedDrillsProgressWidget> createState() => _SeedDrillsProgressWidgetState();
}

class _SeedDrillsProgressWidgetState extends State<_SeedDrillsProgressWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
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
                      if (progress.activityName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(progress.activityName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ],
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
              secondChild: _buildDetails(context, progress, color),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetails(BuildContext context, DrillSeedProgress progress, Color color) {
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
