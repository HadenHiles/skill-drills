import 'package:flutter/services.dart';
import 'package:skilldrills/main.dart';
import 'package:vibration/vibration.dart';

// ── Nav tap ───────────────────────────────────────────────────────────────────

/// Light haptic for tab-bar navigation.
///
/// Uses amplitude-controlled vibration when available, falls back to
/// [HapticFeedback.selectionClick] on devices without amplitude control
/// (e.g. iOS, older Android).
Future<void> hapticNavTap() async {
  if (!settings.vibrate) return;
  final hasAmplitude = await Vibration.hasAmplitudeControl();
  if (hasAmplitude) {
    Vibration.vibrate(duration: 50, amplitude: 50);
  } else {
    HapticFeedback.selectionClick();
  }
}

// ── Rest-timer complete ───────────────────────────────────────────────────────

/// Two-pulse pattern played when a rest timer reaches zero:
///   1 000 ms vibrate → 330 ms pause → 1 500 ms vibrate
Future<void> hapticRestComplete() async {
  if (!settings.vibrate) return;
  final hasVibrator = await Vibration.hasVibrator();
  if (!hasVibrator) return;
  // pattern: [initial delay, duration, pause, duration, ...]
  Vibration.vibrate(pattern: [0, 1000, 330, 1500]);
}
