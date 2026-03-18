import 'package:flutter/material.dart';
import 'package:skilldrills/theme/theme.dart';

/// Per-activity brand colors used to skin the entire app when a specific
/// activity is active.
///
/// Colors are chosen to feel thematically appropriate for each skill domain
/// and remain accessible with white foreground text (WCAG AA contrast ratio).
class ActivityColors {
  ActivityColors._();

  static const Map<String, Color> _map = {
    'Hockey': Color(0xFF1565C0), // steel / ice blue
    'Basketball': Color(0xFFF4511E), // deep orange
    'Baseball': Color(0xFFD32F2F), // red
    'Golf': Color(0xFF2E7D32), // fairway green
    'Soccer': Color(0xFF1B5E20), // grass green (dark)
    'Weight Training': Color(0xFFBF360C), // iron rust
    'Tennis': Color(0xFF558B2F), // court lime-green
    'Running': Color(0xFFE64A19), // energetic coral
    'Volleyball': Color(0xFFF9A825), // sandy amber
    'Martial Arts': Color(0xFFC62828), // crimson
    'Pickleball': Color(0xFF00695C), // teal
    'Lacrosse': Color(0xFF283593), // navy
    'Gymnastics': Color(0xFF6A1B9A), // deep purple
    'Guitar': Color(0xFF4527A0), // electric indigo
    'Chess': Color(0xFF37474F), // dark slate
    'Swimming': Color(0xFF0277BD), // ocean blue
    'Yoga': Color(0xFF7B1FA2), // lavender purple
    'Cycling': Color(0xFFF57F17), // amber / safety yellow
    'Football': Color(0xFF4E342E), // leather brown
    'Piano': Color(0xFF1A237E), // midnight navy
    'Custom': SkillDrillsColors.brandBlue,
  };

  /// Returns the accent color for [title], or [SkillDrillsColors.brandBlue] if
  /// the activity title is unrecognised or `null`.
  static Color forActivity(String? title) => _map[title?.trim()] ?? SkillDrillsColors.brandBlue;
}
