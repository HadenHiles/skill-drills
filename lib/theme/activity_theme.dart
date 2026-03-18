import 'dart:math';

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
    // 'Custom' is intentionally omitted — falls through to brandBlue so that
    // custom/unknown activities use the default theme.
  };

  /// Returns `true` when [title] maps to a predefined activity-specific colour
  /// (i.e. it is NOT a custom/unknown activity that uses the default theme).
  static bool hasActivityTheme(String? title) => title != null && _map.containsKey(title.trim());

  /// Returns the accent color for [title], or [SkillDrillsColors.brandBlue]
  /// when the activity is custom / unknown.
  static Color forActivity(String? title) => _map[title?.trim()] ?? SkillDrillsColors.brandBlue;

  // ── Contrast adaptation ───────────────────────────────────────────────────

  /// Returns a color suitable for interactive UI elements (ElevatedButton
  /// backgrounds with white text, focus rings, selected nav icons).
  ///
  /// In **light mode** the accent is used as a button background with white
  /// foreground text.  If the accent is too light, white text will be
  /// illegible — so we darken by reducing HSL lightness until the WCAG
  /// contrast ratio ≥ 3.0 (AA, large UI components).
  ///
  /// In **dark mode** the accent appears on a dark surface
  /// (`SkillDrillsColors.darkSurface` ≈ luminance 0.0064).  If the accent is
  /// too dark it disappears — so we lighten it until CR ≥ 3.0.
  ///
  /// The **raw** accent is kept for the Start-screen header background, which
  /// is decorative and tolerates lower-contrast choices.
  static Color adaptAccentForUi(Color accent, {required bool isDarkMode}) {
    final lum = accent.computeLuminance();

    if (!isDarkMode) {
      // Light mode: accent is the button background, white text on top.
      // Contrast ratio (w/ white) = 1.05 / (lum + 0.05)
      final cr = 1.05 / (lum + 0.05);
      if (cr < 3.0) {
        final hsl = HSLColor.fromColor(accent);
        return hsl.withLightness(max(0.0, hsl.lightness - 0.25)).toColor();
      }
    } else {
      // Dark mode: accent on darkSurface (lum ≈ 0.0064 → denominator 0.0564).
      final cr = (lum + 0.05) / 0.0564;
      if (cr < 3.0) {
        final hsl = HSLColor.fromColor(accent);
        return hsl.withLightness(min(1.0, hsl.lightness + 0.30)).toColor();
      }
    }

    return accent;
  }

  // ── Color swatches for the Pro activity colour picker ────────────────────

  /// Hand-picked accessible accent swatches offered to Pro users when
  /// customising a custom activity's brand colour.
  static const List<Color> pickerSwatches = [
    Color(0xFF1565C0), // steel blue
    Color(0xFF0277BD), // ocean blue
    Color(0xFF006064), // dark cyan
    Color(0xFF00695C), // dark teal
    Color(0xFF2E7D32), // deep green
    Color(0xFF558B2F), // olive green
    Color(0xFF33691E), // lime dark
    Color(0xFFF9A825), // amber
    Color(0xFFF57F17), // dark amber
    Color(0xFFE64A19), // deep orange
    Color(0xFFBF360C), // dark orange-red
    Color(0xFFD32F2F), // red
    Color(0xFFC62828), // dark red
    Color(0xFF880E4F), // wine
    Color(0xFF6A1B9A), // deep purple
    Color(0xFF4527A0), // indigo
    Color(0xFF1A237E), // midnight navy
    Color(0xFF283593), // navy
    Color(0xFF37474F), // blue-grey slate
    Color(0xFF4E342E), // leather brown
  ];
}
