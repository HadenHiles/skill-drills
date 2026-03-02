import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/theme/theme.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class Start extends StatefulWidget {
  const Start({super.key, this.sessionPanelController});

  final PanelController? sessionPanelController;

  @override
  State<Start> createState() => _StartState();
}

class _StartState extends State<Start> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleStartSession() {
    if (!sessionService.isRunning!) {
      sessionService.start();
      widget.sessionPanelController?.open();
    } else {
      dialog(
        context,
        SkillDrillsDialog(
          "Override current session?",
          const Text(
            "Starting a new session will override your existing one.\n\nWould you like to continue?",
            textAlign: TextAlign.center,
          ),
          "Cancel",
          () => Navigator.of(context).pop(),
          "Continue",
          () {
            sessionService.reset();
            Navigator.of(context).pop();
            sessionService.start();
            widget.sessionPanelController?.open();
          },
          isDangerous: false,
          icon: Icons.swap_horiz_rounded,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(SkillDrillsSpacing.md, SkillDrillsSpacing.lg, SkillDrillsSpacing.md, SkillDrillsSpacing.xxl),
          children: [
            // Section label
            Padding(
              padding: const EdgeInsets.only(bottom: SkillDrillsSpacing.sm),
              child: Text(
                'Quick Start'.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            ),

            // Start button card
            Card(
              child: InkWell(
                onTap: _handleStartSession,
                borderRadius: SkillDrillsRadius.mdBorderRadius,
                child: Padding(
                  padding: const EdgeInsets.all(SkillDrillsSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withAlpha(20),
                          borderRadius: SkillDrillsRadius.smBorderRadius,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 32,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: SkillDrillsSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Empty Session',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'Choplin'),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Start a free-form session and add drills as you go',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: SkillDrillsSpacing.xl),

            // Routines section label
            Padding(
              padding: const EdgeInsets.only(bottom: SkillDrillsSpacing.sm),
              child: Text(
                'My Routines'.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            ),

            // Routines empty state
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SkillDrillsSpacing.xl),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 40,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(height: SkillDrillsSpacing.sm),
                    Text(
                      'No routines yet',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Save drill sequences as routines for quick access here',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
