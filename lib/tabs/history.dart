import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/models/firestore/routine.dart';
import 'package:skilldrills/models/firestore/session.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/services/factory.dart' as firestore_factory;
import 'package:skilldrills/theme/theme.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

// ─────────────────────────────────────────────────────────────────────────────

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  late final Stream<List<Session>> _sessionsStream;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();

    final uid = _auth.currentUser!.uid;
    _sessionsStream = FirebaseFirestore.instance.collection('sessions').doc(uid).collection('sessions').orderBy('started_at', descending: true).snapshots().map((snap) => snap.docs.map((d) => Session.fromSnapshot(d as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _deleteSession(Session session) async {
    dialog(
      context,
      SkillDrillsDialog(
        'Delete Session?',
        Text(
          'Delete "${session.title}"? This cannot be undone.',
          textAlign: TextAlign.center,
        ),
        'Cancel',
        () => Navigator.of(context).pop(),
        'Delete',
        () async {
          await session.reference?.delete();
          if (mounted) Navigator.of(context).pop();
        },
        isDangerous: true,
        icon: Icons.delete_outline_rounded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: StreamBuilder<List<Session>>(
          stream: _sessionsStream,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final sessions = snap.data!;
            if (sessions.isEmpty) return _buildEmptyState(context);
            return _buildList(context, sessions);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: SkillDrillsSpacing.lg),
            Text(
              'No Sessions Yet',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SkillDrillsSpacing.sm),
            Text(
              'Your completed sessions will appear here. Start a session from the home tab to begin tracking.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Session> sessions) {
    final Map<String, List<Session>> grouped = {};
    for (final s in sessions) {
      final key = _dateKey(s.startedAt);
      grouped.putIfAbsent(key, () => []).add(s);
    }
    final keys = grouped.keys.toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final key = keys[i];
                final group = grouped[key]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                      child: Text(
                        key,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                      ),
                    ),
                    ...group.map((s) => _SessionCard(
                          session: s,
                          onDelete: () => _deleteSession(s),
                        )),
                  ],
                );
              },
              childCount: keys.length,
            ),
          ),
        ),
      ],
    );
  }

  String _dateKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    if (diff < 7) {
      return '${_weekday(dt.weekday).toUpperCase()}, ${_monthDay(dt)}';
    }
    return _fullDate(dt).toUpperCase();
  }

  String _weekday(int w) {
    const d = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return d[(w - 1).clamp(0, 6)];
  }

  String _monthDay(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _fullDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Card
// ─────────────────────────────────────────────────────────────────────────────

class _SessionCard extends StatefulWidget {
  const _SessionCard({required this.session, required this.onDelete});

  final Session session;
  final VoidCallback onDelete;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;
  bool _savingRoutine = false;

  Future<void> _createRoutineFromSession() async {
    final session = widget.session;
    if (session.drillResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No drills in this session to save as a routine.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final titleCtrl = TextEditingController(text: session.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Routine', style: TextStyle(fontFamily: 'Choplin')),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Routine name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final routineTitle = titleCtrl.text.trim().isEmpty ? session.title : titleCtrl.text.trim();
    final firstDrill = session.drillResults.first;
    final activityTitle = firstDrill.activityTitle.isNotEmpty ? firstDrill.activityTitle : null;

    final drills = session.drillResults.asMap().entries.map((e) {
      return RoutineDrill(e.value.drillId, e.value.drillTitle, e.key + 1);
    }).toList();

    final routine = Routine(
      routineTitle,
      '',
      activityTitle: activityTitle,
      drills: drills,
      createdAt: DateTime.now(),
    );

    if (mounted) setState(() => _savingRoutine = true);
    try {
      await firestore_factory.saveRoutine(routine);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"$routineTitle" saved as a routine!'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _savingRoutine = false);
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '—';
    final d = Duration(seconds: seconds);
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: SkillDrillsRadius.mdBorderRadius,
            child: Padding(
              padding: const EdgeInsets.all(SkillDrillsSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontFamily: 'Choplin',
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _StatChip(icon: Icons.access_time_rounded, label: _formatTime(session.startedAt)),
                      _StatChip(icon: Icons.timer_outlined, label: _formatDuration(session.durationSeconds)),
                      _StatChip(
                        icon: Icons.fitness_center_rounded,
                        label: '${session.drillCount} drill${session.drillCount == 1 ? '' : 's'}',
                      ),
                      if (session.routineTitle != null) _StatChip(icon: Icons.event_note_rounded, label: session.routineTitle!),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && session.drillResults.isNotEmpty) ...[
            Divider(color: Theme.of(context).dividerColor, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(SkillDrillsSpacing.md, 8, SkillDrillsSpacing.md, SkillDrillsSpacing.sm),
              child: Column(
                children: [
                  ...session.drillResults.map((d) => _DrillResultTile(drillResult: d)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: _savingRoutine ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.event_note_rounded, size: 16),
                        label: const Text('Save as Routine'),
                        onPressed: _savingRoutine ? null : _createRoutineFromSession,
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Delete session'),
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Theme.of(context).colorScheme.onPrimary),
        const SizedBox(width: 3),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DrillResultTile extends StatelessWidget {
  const _DrillResultTile({required this.drillResult});

  final DrillResult drillResult;

  String _formatMeasurement(dynamic m) {
    if (m.value == null) return '—';
    if (m.type == 'duration') {
      final d = Duration(seconds: (m.value as num).toInt());
      final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return d.inHours >= 1 ? '${d.inHours}:$mins:$secs' : '$mins:$secs';
    }
    return '${m.value}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(drillResult.activityIcon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  drillResult.drillTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (drillResult.sets != null || drillResult.reps != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withAlpha(18),
                    borderRadius: SkillDrillsRadius.fullBorderRadius,
                  ),
                  child: Text(
                    _setsRepsText(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
          if (drillResult.measurementResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 4),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: drillResult.measurementResults.map((m) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${m.label}: ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                      ),
                      Text(
                        _formatMeasurement(m),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _setsRepsText() {
    if (drillResult.sets != null && drillResult.reps != null) {
      return '${drillResult.sets} ${drillResult.setsLabel} × ${drillResult.reps} ${drillResult.repsLabel}';
    }
    if (drillResult.sets != null) return '${drillResult.sets} ${drillResult.setsLabel}';
    if (drillResult.reps != null) return '${drillResult.reps} ${drillResult.repsLabel}';
    return '';
  }
}
