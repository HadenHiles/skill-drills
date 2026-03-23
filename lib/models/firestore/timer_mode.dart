/// Defines how time is tracked for drills with duration measurements.
///
/// - [none]: No timer functionality (e.g., count-only drills)
/// - [stopwatch]: Track elapsed time — user records how long they took
/// - [countdown]: Count down from a target duration — terminates when time expires
enum TimerMode {
  none,
  stopwatch,
  countdown;

  static TimerMode fromString(String? value) {
    switch (value) {
      case 'stopwatch':
        return TimerMode.stopwatch;
      case 'countdown':
        return TimerMode.countdown;
      default:
        return TimerMode.none;
    }
  }

  String toFirestore() {
    switch (this) {
      case TimerMode.stopwatch:
        return 'stopwatch';
      case TimerMode.countdown:
        return 'countdown';
      case TimerMode.none:
        return 'none';
    }
  }

  String get displayName {
    switch (this) {
      case TimerMode.stopwatch:
        return 'Stopwatch';
      case TimerMode.countdown:
        return 'Countdown';
      case TimerMode.none:
        return 'None';
    }
  }

  String get description {
    switch (this) {
      case TimerMode.stopwatch:
        return 'Track how long you take (e.g., sprint time, lap time)';
      case TimerMode.countdown:
        return 'Count down from a target duration (e.g., plank hold, timed round)';
      case TimerMode.none:
        return 'No timer needed';
    }
  }
}
