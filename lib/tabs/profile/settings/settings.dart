import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skilldrills/login.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/settings.dart';
import 'package:skilldrills/services/auth.dart';
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

  @override
  void initState() {
    super.initState();

    _loadSettings();
  }

  //Loading counter value on start
  _loadSettings() async {
    setState(() {
      _vibrate = settings.vibrate;
      _darkMode = settings.darkMode;
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
                  title: Text('Sports', style: Theme.of(context).textTheme.bodyLarge),
                  description: Text(
                    '(Activities)',
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
                'Account',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              tiles: [
                SettingsTile(
                  title: Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: Theme.of(context).textTheme.bodyLarge!.fontSize,
                    ),
                  ),
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.red,
                  ),
                  onPressed: (BuildContext context) {
                    signOut();

                    navigatorKey.currentState!.pop();
                    navigatorKey.currentState!.pushReplacement(
                      MaterialPageRoute(
                        builder: (context) {
                          return const Login();
                        },
                      ),
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
