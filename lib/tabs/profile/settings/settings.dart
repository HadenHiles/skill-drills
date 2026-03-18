import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:skilldrills/login.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/settings.dart';
import 'package:skilldrills/services/auth.dart';
import 'package:skilldrills/services/export.dart';
import 'package:skilldrills/services/factory.dart';
import 'package:skilldrills/services/subscription.dart';
import 'package:skilldrills/tabs/profile/settings/activities.dart';
import 'package:skilldrills/theme/settings_state_notifier.dart';
import 'package:skilldrills/widgets/basic_title.dart';
import 'package:skilldrills/widgets/paywall_screen.dart';

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  // State settings values
  bool _vibrate = settings.vibrate;
  bool _darkMode = settings.darkMode;

  // Subscription state
  bool? _isPro;
  StreamSubscription<dynamic>? _customerInfoSub;

  @override
  void initState() {
    super.initState();

    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    final isPro = await hasActiveSubscription();
    if (mounted) setState(() => _isPro = isPro);

    // Keep the UI in sync with live subscription state changes.
    _customerInfoSub = customerInfoStream.listen((info) {
      if (mounted) {
        setState(() {
          _isPro = info.entitlements.active.containsKey(kProEntitlement);
        });
      }
    });
  }

  @override
  void dispose() {
    _customerInfoSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              collapsedHeight: 65,
              expandedHeight: 65,
              backgroundColor: Theme.of(context).colorScheme.primary,
              floating: true,
              pinned: true,
              leading: Container(
                margin: const EdgeInsets.only(top: 10),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 28,
                  ),
                  onPressed: () {
                    navigatorKey.currentState!.pop();
                  },
                ),
              ),
              flexibleSpace: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  titlePadding: null,
                  centerTitle: false,
                  title: const BasicTitle(title: "Settings"),
                  background: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
              actions: const [],
            ),
          ];
        },
        body: SettingsList(
          sections: [
            SettingsSection(
              title: Text(
                'General',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              tiles: [
                SettingsTile.switchTile(
                  initialValue: _vibrate,
                  title: Text(
                    'Vibration',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  leading: Icon(
                    Icons.vibration,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onToggle: (bool value) {
                    setState(() {
                      _vibrate = value;
                      settings.vibrate = value;
                    });
                    Provider.of<SettingsStateNotifier>(context, listen: false).updateSettings(Settings(value, _darkMode));
                  },
                ),
                SettingsTile.switchTile(
                  initialValue: _darkMode,
                  title: Text(
                    'Dark Mode',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  leading: Icon(
                    Icons.brightness_2,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onToggle: (bool value) {
                    setState(() {
                      _darkMode = value;
                      settings.darkMode = value;
                    });
                    Provider.of<SettingsStateNotifier>(context, listen: false).updateSettings(Settings(_vibrate, value));
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text(
                'Personalize',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              tiles: [
                SettingsTile(
                  title: Text("Activities", style: Theme.of(context).textTheme.bodyLarge),
                  description: Text(
                    'Manage activities, skills & terminology',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  leading: Icon(
                    Icons.directions_run_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: (BuildContext context) {
                    navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) {
                      return const ActivitiesSettings();
                    }));
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text(
                'Skill Drills Pro',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              tiles: [
                if (_isPro == true) ...[
                  SettingsTile(
                    title: Text(
                      'You\'re a Pro member!',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    leading: Icon(
                      Icons.verified,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SettingsTile(
                    title: Text('Manage Subscription', style: Theme.of(context).textTheme.bodyLarge),
                    description: Text(
                      'Cancel, change plan, or request support',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    leading: Icon(
                      Icons.manage_accounts_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: (_) => presentCustomerCenter(),
                  ),
                ] else
                  SettingsTile(
                    title: Text(
                      'Upgrade to Skill Drills Pro',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    description: Text(
                      'Unlock unlimited activities, routines & analytics',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    leading: Icon(
                      Icons.star_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: (_) => navigatorKey.currentState!.push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const PaywallScreen(),
                      ),
                    ),
                  ),
                SettingsTile(
                  title: Text('Restore Purchases', style: Theme.of(context).textTheme.bodyLarge),
                  leading: Icon(
                    Icons.restore_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: (_) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final result = await restorePurchases();
                    final String message;
                    if (result.errorMessage != null) {
                      message = result.errorMessage!;
                    } else if (result.info != null && result.info!.entitlements.active.containsKey(kProEntitlement)) {
                      message = 'Pro subscription restored!';
                    } else {
                      message = 'No active subscription found.';
                    }
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(message),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  },
                ),
              ],
            ),
            SettingsSection(
              title: Text(
                'Account',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              tiles: [
                SettingsTile(
                  title: Text(
                    _isPro == true ? 'Export Session History' : 'Export Session History',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _isPro == true ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                  ),
                  description: Text(
                    _isPro == true ? 'Download your complete session history as a CSV file' : 'Pro feature — upgrade to export your session data',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  leading: Icon(
                    _isPro == true ? Icons.download_rounded : Icons.lock_outline_rounded,
                    color: _isPro == true ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  onPressed: (ctx) async {
                    if (_isPro != true) {
                      showDialog<void>(
                        context: ctx,
                        builder: (_) => AlertDialog(
                          title: const Text('Pro Feature'),
                          content: const Text(
                            'Data export is a Pro feature. Upgrade to export your complete session history as CSV.',
                            textAlign: TextAlign.center,
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                navigatorKey.currentState!.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen()));
                              },
                              child: const Text('Upgrade'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(ctx);
                    try {
                      await exportSessionHistory();
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
                    }
                  },
                ),
                SettingsTile(
                  title: Text(
                    'Restore Default Data',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: Theme.of(context).textTheme.bodyLarge!.fontSize,
                    ),
                  ),
                  description: Text(
                    'Deletes and re-seeds all factory activities, drill types and drills. Your routines and session history are kept.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  leading: Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.error),
                  onPressed: (BuildContext context) async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Restore Default Data?'),
                        content: const Text(
                          'This will delete and re-create all factory activities, drill types and drills for your account.\n\nYour routines and session history will not be affected.',
                          textAlign: TextAlign.center,
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text('Restore', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    if (!context.mounted) return;
                    // Fire in the background — progress is shown on the Drills
                    // and Activities screens via isBootstrapping / bootstrapProgress.
                    // ignore: unawaited_futures
                    resetAllData();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Restoring your library in the background…'),
                      duration: Duration(seconds: 3),
                    ));
                  },
                ),
                SettingsTile(
                  title: Text(
                    'Logout',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: Theme.of(context).textTheme.bodyLarge!.fontSize,
                    ),
                  ),
                  leading: Icon(
                    Icons.logout,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: (BuildContext context) async {
                    await logoutRevenueCatUser();
                    await signOut();

                    navigatorKey.currentState!.pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const Login(),
                      ),
                      (route) => false,
                    );
                  },
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
