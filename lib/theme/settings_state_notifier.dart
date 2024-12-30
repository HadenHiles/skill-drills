import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skilldrills/models/settings.dart';

class SettingsStateNotifier extends ChangeNotifier {
  Settings _settings = Settings(false, false); // Initialize with defaults

  Settings get settings => _settings;

  Future<void> updateSettings(Settings newSettings) async {
    _settings = newSettings;
    notifyListeners(); // Notify listeners of the change

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibrate', _settings.vibrate);
    await prefs.setBool('dark_mode', _settings.darkMode);
  }
}
