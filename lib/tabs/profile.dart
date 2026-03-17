import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/services/subscription.dart';
import 'package:skilldrills/theme/theme.dart';
import 'package:skilldrills/widgets/user_avatar.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;

  bool _isPro = false;
  StreamSubscription<dynamic>? _customerInfoSub;

  // ── Stats streams ────────────────────────────────────────────────────────
  Stream<int>? _sessionCountStream;
  Stream<int>? _totalTimeStream;
  Stream<int>? _drillsDoneStream;
  Stream<int>? _streakCountStream;
  Stream<int>? _pbCountStream;

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
    _initStats();
  }

  Future<void> _initStats() async {
    final uid = user!.uid;
    final sessRef = FirebaseFirestore.instance.collection('sessions').doc(uid).collection('sessions');

    _sessionCountStream = sessRef.snapshots().map((s) => s.size);
    _totalTimeStream = sessRef.snapshots().map((s) {
      int total = 0;
      for (final doc in s.docs) {
        final v = doc.data()['duration_seconds'];
        if (v != null) total += (v as num).toInt();
      }
      return total;
    });
    _drillsDoneStream = sessRef.snapshots().map((s) {
      int total = 0;
      for (final doc in s.docs) {
        final drs = doc.data()['drill_results'] as List?;
        if (drs != null) total += drs.length;
      }
      return total;
    });

    final isPro = await hasActiveSubscription();
    if (mounted) {
      setState(() {
        _isPro = isPro;
        if (isPro) _initProStreams(uid);
      });
    }

    _customerInfoSub = customerInfoStream.listen((info) {
      final nowPro = info.entitlements.active.containsKey(kProEntitlement);
      if (mounted && nowPro != _isPro) {
        setState(() {
          _isPro = nowPro;
          if (nowPro) _initProStreams(uid);
        });
      }
    });
  }

  void _initProStreams(String uid) {
    _streakCountStream = FirebaseFirestore.instance.collection('streaks').doc(uid).collection('streaks').snapshots().map((s) => s.docs.where((d) => ((d.data()['current_streak'] as int?) ?? 0) > 0).length);
    _pbCountStream = FirebaseFirestore.instance.collection('personal_bests').doc(uid).collection('bests').snapshots().map((s) => s.size);
    setState(() {});
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  void dispose() {
    _customerInfoSub?.cancel();
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
                          const SizedBox(height: 6),
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
                            builder: (context, snapshot) {
                              final data = snapshot.data?.data();
                              final isPremium = (data?['tier'] as String? ?? 'free') == 'premium';
                              return _TierBadge(isPremium: isPremium);
                            },
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
            StreamBuilder<int>(
              stream: _sessionCountStream,
              builder: (context, sessSnap) {
                return StreamBuilder<int>(
                  stream: _totalTimeStream,
                  builder: (context, timeSnap) {
                    return StreamBuilder<int>(
                      stream: _drillsDoneStream,
                      builder: (context, drillSnap) {
                        final sessions = sessSnap.data ?? 0;
                        final totalTime = _formatTime(timeSnap.data ?? 0);
                        final drills = drillSnap.data ?? 0;
                        return Row(
                          children: [
                            Expanded(child: _StatCard(label: 'Sessions', value: '$sessions', icon: Icons.timer_rounded)),
                            const SizedBox(width: SkillDrillsSpacing.sm),
                            Expanded(child: _StatCard(label: 'Total Time', value: totalTime, icon: Icons.access_time_rounded)),
                            const SizedBox(width: SkillDrillsSpacing.sm),
                            Expanded(child: _StatCard(label: 'Drills Done', value: '$drills', icon: Icons.fitness_center_rounded)),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),

            // ── Pro stats row ──────────────────────────────────────────
            if (_isPro) ...[
              const SizedBox(height: SkillDrillsSpacing.sm),
              StreamBuilder<int>(
                stream: _streakCountStream,
                builder: (context, streakSnap) {
                  return StreamBuilder<int>(
                    stream: _pbCountStream,
                    builder: (context, pbSnap) {
                      return Row(
                        children: [
                          Expanded(child: _StatCard(label: 'Active Streaks', value: '${streakSnap.data ?? 0}', icon: Icons.local_fire_department_rounded)),
                          const SizedBox(width: SkillDrillsSpacing.sm),
                          Expanded(child: _StatCard(label: 'Personal Bests', value: '${pbSnap.data ?? 0}', icon: Icons.emoji_events_rounded)),
                        ],
                      );
                    },
                  );
                },
              ),
            ],

            // ── Pro streaks section ────────────────────────────────────
            if (_isPro) ...[
              const SizedBox(height: SkillDrillsSpacing.md),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('streaks').doc(user!.uid).collection('streaks').snapshots(),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) return const SizedBox.shrink();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(SkillDrillsSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔥 Streaks',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'Choplin'),
                          ),
                          const SizedBox(height: SkillDrillsSpacing.sm),
                          ...docs.map((doc) {
                            final data = doc.data()! as Map<String, dynamic>;
                            final title = (data['activity_title'] as String?) ?? '';
                            final current = (data['current_streak'] as int?) ?? 0;
                            final longest = (data['longest_streak'] as int?) ?? 0;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(title),
                              subtitle: Text('Longest: $longest ${longest == 1 ? 'day' : 'days'}'),
                              trailing: Text(
                                '🔥 $current',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'Choplin'),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
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

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isPremium ? SkillDrillsColors.energyOrange : theme.colorScheme.onPrimary.withAlpha(90);
    final bg = isPremium ? SkillDrillsColors.energyOrange.withAlpha(22) : theme.colorScheme.onPrimary.withAlpha(14);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(SkillDrillsRadius.sm),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPremium ? Icons.workspace_premium_rounded : Icons.person_rounded,
                size: 11,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                isPremium ? 'Premium' : 'Free',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
