import 'package:flutter/material.dart';
import 'package:skilldrills/theme/theme.dart';

class Routines extends StatefulWidget {
  const Routines({super.key});

  @override
  State<Routines> createState() => _RoutinesState();
}

class _RoutinesState extends State<Routines> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withAlpha(18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_note_rounded,
                    size: 52,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                const SizedBox(height: SkillDrillsSpacing.lg),
                Text(
                  'No Routines Yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SkillDrillsSpacing.sm),
                Text(
                  'Build ordered drill sequences to run through in a session. Routines are coming soon.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SkillDrillsSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: SkillDrillsSpacing.md, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withAlpha(14),
                    borderRadius: BorderRadius.circular(SkillDrillsRadius.md),
                    border: Border.all(color: Theme.of(context).colorScheme.tertiary.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Theme.of(context).colorScheme.tertiary),
                      const SizedBox(width: 6),
                      Text(
                        'Free plan includes 3 saved routines',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.tertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SkillDrillsSpacing.xl),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.add),
                  label: const Text('New Routine'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
