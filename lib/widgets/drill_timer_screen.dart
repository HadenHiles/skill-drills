import 'package:flutter/material.dart';
import 'package:skilldrills/models/firestore/timer_mode.dart';
import 'package:skilldrills/services/session.dart';
import 'package:skilldrills/theme/theme.dart';

/// Full-screen timer overlay for drill countdowns or stopwatches.
///
/// Displays in full-screen mode with controls to pause/resume/stop.
/// Dismissible by tapping the close button or swiping down.
class DrillTimerScreen extends StatefulWidget {
  const DrillTimerScreen({
    super.key,
    required this.drillIndex,
    required this.drillTitle,
    required this.mode,
    this.initialSeconds,
    this.targetSeconds,
  });

  final int drillIndex;
  final String drillTitle;
  final TimerMode mode;
  final int? initialSeconds; // countdown starting value
  final int? targetSeconds; // stopwatch target (optional)

  @override
  State<DrillTimerScreen> createState() => _DrillTimerScreenState();
}

class _DrillTimerScreenState extends State<DrillTimerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _start() {
    final sessionService = SessionService.of(context);
    if (widget.mode == TimerMode.countdown && widget.initialSeconds != null) {
      sessionService.startDrillCountdown(widget.drillIndex, widget.initialSeconds!);
    } else if (widget.mode == TimerMode.stopwatch) {
      sessionService.startDrillStopwatch(widget.drillIndex);
    }
    setState(() => _hasStarted = true);
  }

  void _pauseResume() {
    final sessionService = SessionService.of(context);
    if (sessionService.drillTimerRunning) {
      sessionService.pauseDrillTimer();
    } else {
      sessionService.resumeDrillTimer();
    }
    setState(() {});
  }

  void _stop() {
    final sessionService = SessionService.of(context);
    sessionService.stopDrillTimer();
    Navigator.of(context).pop();
  }

  String _formatTime(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final millis = (d.inMilliseconds % 1000) ~/ 100;
    if (minutes > 0) {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}.${millis}';
    }
    return '${seconds}.${millis}s';
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionService = SessionService.of(context);
    return AnimatedBuilder(
      animation: sessionService,
      builder: (context, _) {
        final isCountdown = widget.mode == TimerMode.countdown;
        final remaining = sessionService.drillCountdownRemaining;
        final elapsed = sessionService.drillElapsed ?? Duration.zero;
        final isRunning = sessionService.drillTimerRunning;
        final isComplete = isCountdown && remaining != null && remaining == 0;

        // Calculate progress for countdown
        double progress = 0.0;
        if (isCountdown && widget.initialSeconds != null && remaining != null) {
          progress = 1.0 - (remaining / widget.initialSeconds!);
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: Stack(
              children: [
                // Close button
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    onPressed: _stop,
                    icon: Icon(Icons.close_rounded, size: 32, color: theme.colorScheme.onSurface.withAlpha(180)),
                  ),
                ),

                // Main timer display
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Drill title
                        Text(
                          widget.drillTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontFamily: 'Choplin',
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isCountdown ? 'Countdown Timer' : 'Stopwatch',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Timer display
                        if (!_hasStarted)
                          // Show initial value before starting
                          AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, child) => Transform.scale(
                              scale: _pulseAnim.value,
                              child: child,
                            ),
                            child: Text(
                              isCountdown ? _formatCountdown(widget.initialSeconds ?? 0) : '0.0s',
                              style: TextStyle(
                                fontSize: 84,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Choplin',
                                color: theme.primaryColor,
                              ),
                            ),
                          )
                        else if (isComplete)
                          // Countdown complete
                          Text(
                            'DONE!',
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Choplin',
                              color: SkillDrillsColors.success,
                            ),
                          )
                        else
                          // Running timer
                          AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, child) {
                              // Pulse only when running
                              if (!isRunning) return child!;
                              return Transform.scale(scale: _pulseAnim.value, child: child);
                            },
                            child: Text(
                              isCountdown ? _formatCountdown(remaining ?? 0) : _formatTime(elapsed),
                              style: TextStyle(
                                fontSize: 84,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Choplin',
                                color: theme.primaryColor,
                              ),
                            ),
                          ),

                        if (isCountdown && widget.initialSeconds != null && _hasStarted && !isComplete) ...[
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 280,
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: theme.dividerColor,
                              valueColor: AlwaysStoppedAnimation(theme.primaryColor),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],

                        if (widget.mode == TimerMode.stopwatch && widget.targetSeconds != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Target: ${_formatCountdown(widget.targetSeconds!)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],

                        const SizedBox(height: 64),

                        // Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_hasStarted)
                              // Start button
                              ElevatedButton.icon(
                                onPressed: _start,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, size: 32),
                                label: const Text(
                                  'Start',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Choplin'),
                                ),
                              )
                            else if (!isComplete) ...[
                              // Pause/Resume button
                              IconButton(
                                onPressed: _pauseResume,
                                iconSize: 64,
                                icon: Icon(
                                  isRunning ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                                  color: theme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Stop button
                              IconButton(
                                onPressed: _stop,
                                iconSize: 64,
                                icon: Icon(
                                  Icons.stop_circle_rounded,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ] else
                              // Done - close button
                              ElevatedButton(
                                onPressed: _stop,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SkillDrillsColors.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                ),
                                child: const Text(
                                  'Close',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Choplin'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
