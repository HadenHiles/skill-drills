import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/theme/theme.dart';
import 'package:skilldrills/widgets/user_avatar.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  final int _sessionCount = 0;

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
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(SkillDrillsSpacing.md, SkillDrillsSpacing.md, SkillDrillsSpacing.md, SkillDrillsSpacing.xxl),
          children: [
            // ── Profile header card ─────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SkillDrillsSpacing.md),
                child: Row(
                  children: [
                    SizedBox(
                      height: 70,
                      width: 70,
                      child: UserAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: SkillDrillsSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user!.displayName != null && user!.displayName!.isNotEmpty ? user!.displayName! : user!.email ?? '',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: 'Choplin'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user!.email ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: SkillDrillsSpacing.md),

            // ── Stats row ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                    child: _StatCard(
                  label: 'Sessions',
                  value: '$_sessionCount',
                  icon: Icons.timer_rounded,
                )),
                const SizedBox(width: SkillDrillsSpacing.sm),
                Expanded(
                    child: _StatCard(
                  label: 'Total Time',
                  value: '0h',
                  icon: Icons.access_time_rounded,
                )),
                const SizedBox(width: SkillDrillsSpacing.sm),
                Expanded(
                    child: _StatCard(
                  label: 'Drills Done',
                  value: '0',
                  icon: Icons.fitness_center_rounded,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SkillDrillsSpacing.md, horizontal: SkillDrillsSpacing.sm),
        child: Column(
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: 'Choplin')),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
