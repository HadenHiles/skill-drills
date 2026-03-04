import 'package:duration_picker/duration_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/session.dart' as session_model;
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/tabs/session/add_drill_sheet.dart';
import 'package:skilldrills/theme/theme.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────

class Session extends StatefulWidget {
  const Session({super.key, required this.sessionPanelController});

  final PanelController sessionPanelController;

  @override
  State<Session> createState() => _SessionState();
}

class _SessionState extends State<Session> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late PageController _pageController;
  final ScrollController _tabScrollCtrl = ScrollController();
  int _lastDrillCount = 0;
  int _lastDrillIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pageController = PageController(initialPage: sessionService.currentDrillIndex);
    _lastDrillCount = sessionService.drillResults.length;
    _lastDrillIndex = sessionService.currentDrillIndex;
    sessionService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    sessionService.removeListener(_onServiceChanged);
    _pulseCtrl.dispose();
    _pageController.dispose();
    _tabScrollCtrl.dispose();
    super.dispose();
  }

  // Handles external currentDrillIndex changes (auto-advance) and new drills.
  void _onServiceChanged() {
    final drills = sessionService.drillResults;
    final newIndex = sessionService.currentDrillIndex;

    if (drills.length != _lastDrillCount) {
      if (drills.length > _lastDrillCount && _pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.animateToPage(
              drills.length - 1,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          }
        });
      }
      _lastDrillCount = drills.length;
    }

    if (newIndex != _lastDrillIndex) {
      if (_pageController.hasClients) {
        final currentPage = _pageController.page?.round() ?? -1;
        if (currentPage != newIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                newIndex,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTabIntoView(newIndex));
      _lastDrillIndex = newIndex;
    }
  }

  void _scrollTabIntoView(int index) {
    if (!_tabScrollCtrl.hasClients) return;
    const tabWidth = 56.0;
    final offset = (index * tabWidth - 60.0).clamp(
      0.0,
      _tabScrollCtrl.position.maxScrollExtent,
    );
    _tabScrollCtrl.animateTo(
      offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _addDrill() {
    showAddDrillSheet(
      context,
      nextOrder: sessionService.drillResults.length,
      onDrillAdded: (drillResult) => sessionService.addDrill(drillResult),
    );
  }

  void _cancelSession() {
    dialog(
      context,
      SkillDrillsDialog(
        'Cancel Session?',
        const Text('Your session progress will be lost.', textAlign: TextAlign.center),
        'Keep Going',
        () => Navigator.of(context).pop(),
        'Cancel Session',
        () {
          sessionService.reset();
          Navigator.of(context).pop();
          widget.sessionPanelController.close();
        },
        isDangerous: true,
        icon: Icons.cancel_outlined,
      ),
    );
  }

  void _finishSession() {
    final drills = sessionService.drillResults;
    final title = sessionService.sessionTitle ?? 'Session';
    dialog(
      context,
      SkillDrillsDialog(
        'Finish Session?',
        Text(
          drills.isNotEmpty ? 'Great work! This session will be saved with ${drills.length} drill${drills.length == 1 ? '' : 's'}.' : 'No drills were added. Save this session anyway?',
          textAlign: TextAlign.center,
        ),
        'Not Yet',
        () => Navigator.of(context).pop(),
        'Save & Finish',
        () async {
          Navigator.of(context).pop();
          await sessionService.finishSession();
          widget.sessionPanelController.close();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('"$title" saved!'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ));
          }
        },
        isDangerous: false,
        icon: Icons.check_circle_outline_rounded,
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _initials(String title) {
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  static String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionService,
      builder: (context, _) {
        final drills = sessionService.drillResults;
        return Column(
          children: [
            // Live status badge + timer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: SkillDrillsColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Session in progress',
                    style: TextStyle(
                      color: SkillDrillsColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Choplin',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(sessionService.currentDuration ?? Duration.zero),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Choplin',
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),

            // Drill tab bar
            if (drills.isNotEmpty) _buildDrillTabBar(context, drills),

            // Rest timer countdown banner
            if (sessionService.restCountdown != null) _buildRestTimerBanner(context),

            // Main content: empty state or per-drill PageView
            Expanded(
              child: drills.isEmpty
                  ? _buildEmptyState(context)
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: drills.length,
                      onPageChanged: (index) {
                        _lastDrillIndex = index;
                        sessionService.setCurrentDrillIndex(index);
                        _scrollTabIntoView(index);
                      },
                      itemBuilder: (context, i) => _DrillPage(
                        drillResult: drills[i],
                        drillIndex: i,
                        onRemove: () => sessionService.removeDrill(i),
                      ),
                    ),
            ),

            _buildBottomBar(context),
          ],
        );
      },
    );
  }

  // ── Drill tab bar ─────────────────────────────────────────────────────────

  Widget _buildDrillTabBar(BuildContext context, List<session_model.DrillResult> drills) {
    final active = sessionService.currentDrillIndex;
    return SizedBox(
      height: 68,
      child: ListView.builder(
        controller: _tabScrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: drills.length + 1,
        itemBuilder: (context, i) {
          if (i == drills.length) {
            // "+" add-drill tab
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: _addDrill,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).primaryColor.withAlpha(12),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withAlpha(80),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.add_rounded, color: Theme.of(context).primaryColor, size: 20),
                ),
              ),
            );
          }

          final drill = drills[i];
          final isActive = i == active;
          final isDone = drill.allSetsComplete;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: drill.drillTitle,
              child: GestureDetector(
                onTap: () {
                  _lastDrillIndex = i;
                  sessionService.setCurrentDrillIndex(i);
                  _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? SkillDrillsColors.success.withAlpha(30)
                        : isActive
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).primaryColor.withAlpha(18),
                    border: Border.all(
                      color: isDone
                          ? SkillDrillsColors.success
                          : isActive
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).dividerColor,
                      width: isActive || isDone ? 2.0 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? Icon(Icons.check_rounded, color: SkillDrillsColors.success, size: 20)
                        : Text(
                            _initials(drill.drillTitle),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Choplin',
                              color: isActive ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Rest timer banner ─────────────────────────────────────────────────────

  Widget _buildRestTimerBanner(BuildContext context) {
    final s = sessionService.restCountdown!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withAlpha(20),
          borderRadius: SkillDrillsRadius.smBorderRadius,
          border: Border.all(color: Theme.of(context).primaryColor.withAlpha(60)),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 16, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              'Rest: ${_formatCountdown(s)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Choplin',
                  ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: sessionService.clearRestCountdown,
              child: Icon(Icons.close_rounded, size: 16, color: Theme.of(context).primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SkillDrillsSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, size: 44, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: SkillDrillsSpacing.md),
            Text('No drills yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'Choplin')),
            const SizedBox(height: 4),
            Text(
              'Tap "Add Drill" below to log your first drill',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    final drills = sessionService.drillResults;
    final saving = sessionService.saving;
    return Container(
      padding: const EdgeInsets.fromLTRB(SkillDrillsSpacing.md, SkillDrillsSpacing.sm, SkillDrillsSpacing.md, SkillDrillsSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          if (drills.isEmpty)
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Drill'),
                onPressed: saving ? null : _addDrill,
              ),
            )
          else ...[
            Expanded(
              flex: 1,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error.withAlpha(120)),
                ),
                onPressed: saving ? null : _cancelSession,
                child: const Text('Cancel', style: TextStyle(fontFamily: 'Choplin', fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: SkillDrillsSpacing.sm),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: saving ? null : _finishSession,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Finish Session', style: TextStyle(fontFamily: 'Choplin', fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-drill page (one page in the PageView)
// ─────────────────────────────────────────────────────────────────────────────

class _DrillPage extends StatelessWidget {
  const _DrillPage({
    required this.drillResult,
    required this.drillIndex,
    required this.onRemove,
  });

  final session_model.DrillResult drillResult;
  final int drillIndex;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final sets = drillResult.setResults;
    final hasMeasurements = drillResult.measurementResults.isNotEmpty;
    final setLabel = drillResult.setsLabel.endsWith('s') ? drillResult.setsLabel.substring(0, drillResult.setsLabel.length - 1) : drillResult.setsLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Activity badge + 3-dot menu
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              _ActivityBadge(
                icon: drillResult.activityIcon,
                label: drillResult.activityTitle,
              ),
              const Spacer(),
              _DrillMenu(drillIndex: drillIndex, onRemove: onRemove),
            ],
          ),
        ),
        // Drill title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Text(
            drillResult.drillTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'Choplin',
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),

        // Column headers
        if (hasMeasurements)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _SetRowHeader(measurements: drillResult.measurementResults),
          ),
        const Divider(height: 1),

        // Set rows
        Expanded(
          child: sets.isEmpty
              ? Center(
                  child: Text(
                    'No sets yet — tap "Add $setLabel" below',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: sets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, setIndex) => _SetRow(
                    drillIndex: drillIndex,
                    setIndex: setIndex,
                    setResult: sets[setIndex],
                    hasMeasurements: hasMeasurements,
                  ),
                ),
        ),

        // Add set button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('Add $setLabel'),
              onPressed: () => sessionService.addSet(drillIndex),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3-dot drill menu
// ─────────────────────────────────────────────────────────────────────────────

enum _DrillMenuAction { restTimer, remove }

class _DrillMenu extends StatelessWidget {
  const _DrillMenu({required this.drillIndex, required this.onRemove});

  final int drillIndex;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final drill = sessionService.drillResults[drillIndex];
    return PopupMenuButton<_DrillMenuAction>(
      icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).colorScheme.onPrimary),
      onSelected: (action) {
        switch (action) {
          case _DrillMenuAction.restTimer:
            _showRestTimerDialog(context, drill.restTimerSeconds);
          case _DrillMenuAction.remove:
            onRemove();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _DrillMenuAction.restTimer,
          child: Row(children: [
            Icon(Icons.timer_outlined, size: 18),
            SizedBox(width: 10),
            Text('Set Rest Timer'),
          ]),
        ),
        PopupMenuItem(
          value: _DrillMenuAction.remove,
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 10),
            Text('Remove Drill', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ],
    );
  }

  void _showRestTimerDialog(BuildContext context, int? currentSeconds) {
    const presets = <int?>[null, 30, 60, 90, 120, 180, 300];
    int? selected = currentSeconds;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Rest Timer', style: TextStyle(fontFamily: 'Choplin')),
          content: RadioGroup<int?>(
            groupValue: selected,
            onChanged: (v) => setDialogState(() => selected = v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: presets.map((s) {
                return RadioListTile<int?>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(s == null ? 'None' : _fmtPreset(s)),
                  value: s,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                sessionService.setDrillRestTimer(drillIndex, selected);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtPreset(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    if (m > 0 && sec > 0) return '${m}m ${sec}s';
    if (m > 0) return '$m min';
    return '${sec}s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Set row header (column labels)
// ─────────────────────────────────────────────────────────────────────────────

class _SetRowHeader extends StatelessWidget {
  const _SetRowHeader({required this.measurements});

  final List<dynamic> measurements;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            '#',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
          ),
        ),
        ...measurements.map((m) {
          final label = (m.label as String?)?.isNotEmpty == true
              ? m.label as String
              : m.type == 'duration'
                  ? 'Time'
                  : 'Value';
          return Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
            ),
          );
        }),
        const SizedBox(width: 42),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Set row
// ─────────────────────────────────────────────────────────────────────────────

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.drillIndex,
    required this.setIndex,
    required this.setResult,
    required this.hasMeasurements,
  });

  final int drillIndex;
  final int setIndex;
  final session_model.SetResult setResult;
  final bool hasMeasurements;

  @override
  Widget build(BuildContext context) {
    final isComplete = setResult.isComplete;
    return Dismissible(
      key: ValueKey('set_${drillIndex}_$setIndex'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: SkillDrillsColors.error.withAlpha(180),
          borderRadius: SkillDrillsRadius.smBorderRadius,
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
      ),
      onDismissed: (_) => sessionService.removeSet(drillIndex, setIndex),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Set number
            SizedBox(
              width: 36,
              child: Text(
                '${setIndex + 1}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Choplin',
                      color: isComplete ? Theme.of(context).disabledColor : null,
                    ),
              ),
            ),
            // Measurement inputs (dimmed + blocked when set is complete)
            if (hasMeasurements)
              ...List.generate(setResult.measurementResults.length, (mi) {
                final m = setResult.measurementResults[mi];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AbsorbPointer(
                      absorbing: isComplete,
                      child: Opacity(
                        opacity: isComplete ? 0.4 : 1.0,
                        child: _buildInput(context, m, mi),
                      ),
                    ),
                  ),
                );
              })
            else
              const Expanded(child: SizedBox()),
            // Done checkbox
            SizedBox(
              width: 42,
              child: Checkbox(
                value: isComplete,
                onChanged: (_) => sessionService.toggleSetComplete(drillIndex, setIndex),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context, dynamic measurement, int measIndex) {
    switch (measurement.type as String) {
      case 'duration':
        return _DurationInput(
          value: measurement.value != null ? Duration(seconds: (measurement.value as num).toInt()) : Duration.zero,
          onChanged: (d) => sessionService.updateSetMeasurementValue(drillIndex, setIndex, measIndex, d.inSeconds),
        );
      case 'rpe':
        return _ChipInput(
          values: List.generate(10, (i) => i + 1),
          selected: measurement.value?.toInt(),
          onSelected: (v) => sessionService.updateSetMeasurementValue(drillIndex, setIndex, measIndex, v),
        );
      case 'rir':
        return _ChipInput(
          values: List.generate(6, (i) => i),
          selected: measurement.value?.toInt(),
          onSelected: (v) => sessionService.updateSetMeasurementValue(drillIndex, setIndex, measIndex, v),
        );
      default: // 'amount'
        return _AmountInput(
          value: measurement.value?.toInt() ?? 0,
          onChanged: (v) => sessionService.updateSetMeasurementValue(drillIndex, setIndex, measIndex, v),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity badge
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withAlpha(18),
        borderRadius: SkillDrillsRadius.fullBorderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Amount input (+/- stepper with tap-to-enter for larger numbers)
// ─────────────────────────────────────────────────────────────────────────────

class _AmountInput extends StatelessWidget {
  const _AmountInput({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: SkillDrillsRadius.smBorderRadius,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CountBtn(icon: Icons.remove, onTap: value > 0 ? () => onChanged(value - 1) : null),
          GestureDetector(
            onTap: () => _editDialog(context),
            child: SizedBox(
              width: 38,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontFamily: 'Choplin',
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          _CountBtn(icon: Icons.add, onTap: () => onChanged(value + 1)),
        ],
      ),
    );
  }

  void _editDialog(BuildContext context) {
    final ctrl = TextEditingController(text: value > 0 ? '$value' : '');
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter value'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              onChanged(int.tryParse(ctrl.text) ?? 0);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _CountBtn extends StatelessWidget {
  const _CountBtn({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: SkillDrillsRadius.smBorderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Icon(icon, size: 16, color: onTap != null ? Theme.of(context).primaryColor : Theme.of(context).disabledColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Duration input (tap to open picker)
// ─────────────────────────────────────────────────────────────────────────────

class _DurationInput extends StatelessWidget {
  const _DurationInput({required this.value, required this.onChanged});

  final Duration value;
  final ValueChanged<Duration> onChanged;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours.toString().padLeft(2, '0')}:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showDurationPicker(
          context: context,
          initialTime: value == Duration.zero ? const Duration(minutes: 1) : value,
          baseUnit: BaseUnit.second,
        );
        if (result != null) onChanged(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: SkillDrillsRadius.smBorderRadius,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _format(value),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: 'Choplin',
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.timer_outlined, size: 13, color: Theme.of(context).colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip (RPE / RIR) input
// ─────────────────────────────────────────────────────────────────────────────

class _ChipInput extends StatelessWidget {
  const _ChipInput({required this.values, this.selected, required this.onSelected});

  final List<int> values;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: values.map((v) {
        final isSel = v == selected;
        return GestureDetector(
          onTap: () => onSelected(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isSel ? Theme.of(context).primaryColor : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: SkillDrillsRadius.xsBorderRadius,
              border: Border.all(
                color: isSel ? Theme.of(context).primaryColor : Theme.of(context).dividerColor,
              ),
            ),
            child: Center(
              child: Text(
                '$v',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSel ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
