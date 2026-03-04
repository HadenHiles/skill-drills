import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skilldrills/login.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/settings.dart';
import 'package:skilldrills/services/auth.dart';
import 'package:skilldrills/services/subscription.dart';
import 'package:skilldrills/tabs/profile/settings/activities.dart';
import 'package:skilldrills/theme/settings_state_notifier.dart';
import 'package:skilldrills/widgets/basic_title.dart';

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

    _loadSettings();
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

  //Loading counter value on start
  _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool vibrate = prefs.getBool('vibrate') ?? false; // Provide default if null
    bool darkMode = prefs.getBool('dark_mode') ?? false; // Provide default if null

    setState(() {
      _vibrate = vibrate;
      _darkMode = darkMode;
      settings.vibrate = vibrate; // Update the settings object
      settings.darkMode = darkMode; // Update the settings object
    });
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
                    color: Theme.of(context).colorScheme.onPrimary,
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
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onToggle: (bool value) async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    setState(() {
                      _vibrate = value;
                      settings.vibrate = value;
                      prefs.setBool('vibrate', value);
                    });

                    if (context.mounted) {
                      Provider.of<SettingsStateNotifier>(context, listen: false).updateSettings(Settings(value, _darkMode));
                    }
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
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onToggle: (bool value) async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    setState(() {
                      _darkMode = value;
                      settings.darkMode = value;
                      prefs.setBool('dark_mode', value);
                    });

                    if (context.mounted) {
                      Provider.of<SettingsStateNotifier>(context, listen: false).updateSettings(Settings(_vibrate, value));
                    }
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
                    color: Theme.of(context).colorScheme.onPrimary,
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
                            color: Theme.of(context).colorScheme.primary,
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
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: (_) => presentCustomerCenter(),
                  ),
                ] else
                  SettingsTile(
                    title: Text(
                      'Upgrade to Skill Drills Pro',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    description: Text(
                      'Unlock unlimited activities, routines & analytics',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    leading: Icon(
                      Icons.star_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: (_) => presentPaywall(),
                  ),
                SettingsTile(
                  title: Text('Restore Purchases', style: Theme.of(context).textTheme.bodyLarge),
                  leading: Icon(
                    Icons.restore_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: (_) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final info = await restorePurchases();
                    final restored = info != null && info.entitlements.active.containsKey(kProEntitlement);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          restored ? 'Pro subscription restored!' : 'No active subscription found.',
                        ),
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
