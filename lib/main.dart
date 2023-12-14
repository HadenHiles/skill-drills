import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skilldrills/Nav.dart';
import 'package:skilldrills/services/session.dart';
import 'package:skilldrills/theme/SettingsStateNotifier.dart';
import 'package:skilldrills/theme/Theme.dart';
import 'Login.dart';
import 'models/Settings.dart';

// Setup a navigation key so that we can navigate without context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Settings settings = Settings(true, false);
final sessionService = SessionService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Load app settings
  SharedPreferences prefs = await SharedPreferences.getInstance();
  settings = Settings(
    prefs.getBool('vibrate') ?? false,
    prefs.getBool('dark_mode') ?? ThemeMode.system == ThemeMode.dark,
  );

  runApp(
    ChangeNotifierProvider<SettingsStateNotifier>(
      create: (_) => SettingsStateNotifier(),
      child: SkillDrills(),
    ),
  );
}

class SkillDrills extends StatelessWidget {
  final user = FirebaseAuth.instance.currentUser;

  SkillDrills({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // Lock device orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return Consumer<SettingsStateNotifier>(
      builder: (context, settingsState, child) {
        settings = settingsState.settings;

        return MaterialApp(
          title: 'Skill Drills',
          navigatorKey: navigatorKey,
          theme: SkillDrillsTheme.lightTheme,
          darkTheme: SkillDrillsTheme.darkTheme,
          themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.system,
          home: user != null ? const Nav() : const Login(),
        );
      },
    );
  }
}
