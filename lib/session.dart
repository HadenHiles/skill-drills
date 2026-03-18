import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duration_picker/duration_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/models/firestore/drill.dart';
import 'package:skilldrills/models/firestore/drill_note.dart';
import 'package:skilldrills/models/firestore/measurement.dart';
import 'package:skilldrills/models/firestore/personal_best.dart';
import 'package:skilldrills/models/firestore/session.dart' as session_model;
import 'package:skilldrills/models/firestore/skill.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/services/subscription.dart';
import 'package:skilldrills/services/utility.dart';
import 'package:skilldrills/tabs/session/add_drill_sheet.dart';
import 'package:skilldrills/theme/theme.dart';
import 'package:skilldrills/widgets/paywall_screen.dart';
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

  bool _isPro = false;
  StreamSubscription<dynamic>? _customerInfoSub;

  // Temporary "Add Drill" button highlight when a fresh empty session opens.
  bool _highlightAddDrill = false;
  bool _wasRunning = false;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pageController = PageController(initialPage: sessionService.currentDrillIndex);
    _lastDrillCount = sessionService.drillResults.length;
    _lastDrillIndex = sessionService.currentDrillIndex;
    _wasRunning = sessionService.isRunning;
    sessionService.addListener(_onServiceChanged);
    _initProStatus();
  }

  Future<void> _initProStatus() async {
    final isPro = await hasActiveSubscription();
    if (mounted) setState(() => _isPro = isPro);
    _customerInfoSub = customerInfoStream.listen((info) {
      final nowPro = info.entitlements.active.containsKey(kProEntitlement);
      if (mounted) setState(() => _isPro = nowPro);
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    sessionService.removeListener(_onServiceChanged);
    _customerInfoSub?.cancel();
    _pulseCtrl.dispose();
    _pageController.dispose();
    _tabScrollCtrl.dispose();
    super.dispose();
  }

  // Handles external currentDrillIndex changes (auto-advance) and new drills.
  void _onServiceChanged() {
    final drills = sessionService.drillResults;
    final newIndex = sessionService.currentDrillIndex;

    // Detect session start with no drills → briefly highlight "Add Drill".
    final nowRunning = sessionService.isRunning;
    if (nowRunning && !_wasRunning && drills.isEmpty) {
      _highlightTimer?.cancel();
      setState(() => _highlightAddDrill = true);
      _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _highlightAddDrill = false);
      });
    }
    if (!nowRunning && _wasRunning) {
      _highlightTimer?.cancel();
      if (mounted) setState(() => _highlightAddDrill = false);
    }
    _wasRunning = nowRunning;

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
    // Dismiss the onboarding highlight the moment the user responds to it.
    if (_highlightAddDrill) {
      _highlightTimer?.cancel();
      setState(() => _highlightAddDrill = false);
    }
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
          final newPbs = await sessionService.finishSession();
          widget.sessionPanelController.close();
          if (mounted) {
            if (_isPro && newPbs.isNotEmpty) {
              _showPbSummary(context, newPbs);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('"$title" saved!'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ));
            }
          }
        },
        isDangerous: false,
        icon: Icons.check_circle_outline_rounded,
      ),
    );
  }

  void _showPbSummary(BuildContext context, List<PersonalBest> pbs) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PbSummarySheet(pbs: pbs),
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
                        isPro: _isPro,
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
      height: 92,
      child: ListView.builder(
        controller: _tabScrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        itemCount: drills.length + 1,
        itemBuilder: (context, i) {
          if (i == drills.length) {
            // "+" add-drill tab
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: _addDrill,
                child: SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16), // align circle with drill circles
                      Container(
                        width: 44,
                        height: 44,
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
                      const SizedBox(height: 2),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Choplin',
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
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
                child: SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Number label
                      Text(
                        '#${i + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Choplin',
                          color: isDone
                              ? SkillDrillsColors.success
                              : isActive
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context).colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Circle
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
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
                      const SizedBox(height: 2),
                      // Drill name label
                      Text(
                        drill.drillTitle,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Choplin',
                          color: isDone
                              ? SkillDrillsColors.success
                              : isActive
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context).colorScheme.onSurface.withAlpha(150),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
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

  Widget _buildEmptyState(BuildContext context) => const _EmptyDrillsState();

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
          if (drills.isEmpty)
            Expanded(
              flex: 2,
              child: _highlightAddDrill
                  ? AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) => Transform.scale(
                        scale: 1.0 + (_pulseAnim.value - 0.7) * 0.06,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).primaryColor.withAlpha(
                                      ((_pulseAnim.value - 0.7) / 0.3 * 200).round().clamp(0, 255),
                                    ),
                                blurRadius: 18 + 14 * _pulseAnim.value,
                                spreadRadius: 3 + 3 * _pulseAnim.value,
                              ),
                            ],
                          ),
                          child: child!,
                        ),
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Drill'),
                        onPressed: saving ? null : _addDrill,
                      ),
                    )
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Drill'),
                      onPressed: saving ? null : _addDrill,
                    ),
            )
          else
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
    required this.isPro,
    required this.onRemove,
  });

  final session_model.DrillResult drillResult;
  final int drillIndex;
  final bool isPro;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // Fire-and-forget: populate the cache so the info sheet opens instantly.
    _prefetchDrillDetailsIfNeeded(drillResult.drillId);

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
              _DrillMenu(drillIndex: drillIndex, isPro: isPro, onRemove: onRemove),
            ],
          ),
        ),
        // Drill title + info button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  drillResult.drillTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'Choplin',
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                tooltip: 'Drill details',
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                ),
                onPressed: () => _showDrillDetails(context, drillResult),
              ),
            ],
          ),
        ),

        // Notes section — pinned routine notes + session notes
        if (isPro && drillResult.notes.isNotEmpty) _DrillNotesSection(drillIndex: drillIndex, notes: drillResult.notes),
        if (!isPro && drillResult.notes.isNotEmpty) _ProNotesUpsell(),

        // Column headers — only show when there are sets to display
        if (hasMeasurements && sets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _SetRowHeader(measurements: drillResult.measurementResults),
          ),
        if (sets.isNotEmpty) const Divider(height: 1),

        // Set rows + Add set button (inline, right below last set)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            itemCount: sets.isEmpty ? 2 : sets.length + 1,
            itemBuilder: (context, index) {
              // Empty state message (only when no sets)
              if (sets.isEmpty && index == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No ${setLabel}s yet',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                );
              }
              // "Add set" button — last item always
              // When sets is empty, itemCount=2 so add button is at index 1 (not sets.length=0)
              if (index == (sets.isEmpty ? 1 : sets.length)) {
                return Padding(
                  padding: EdgeInsets.only(top: sets.isEmpty ? 0 : 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text('Add $setLabel'),
                      onPressed: () => sessionService.addSet(drillIndex),
                    ),
                  ),
                );
              }
              // Set row with divider between rows
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index > 0) const Divider(height: 1),
                  _SetRow(
                    drillIndex: drillIndex,
                    setIndex: index,
                    setResult: sets[index],
                    hasMeasurements: hasMeasurements,
                    activityTitle: drillResult.activityTitle,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3-dot drill menu
// ─────────────────────────────────────────────────────────────────────────────

enum _DrillMenuAction { addNote, restTimer, remove }

class _DrillMenu extends StatelessWidget {
  const _DrillMenu({required this.drillIndex, required this.isPro, required this.onRemove});

  final int drillIndex;
  final bool isPro;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final drill = sessionService.drillResults[drillIndex];
    return PopupMenuButton<_DrillMenuAction>(
      icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).colorScheme.onSurface.withAlpha(130)),
      onSelected: (action) {
        switch (action) {
          case _DrillMenuAction.addNote:
            if (isPro) {
              _showAddNoteSheet(context);
            } else {
              navigatorKey.currentState!.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen()));
            }
          case _DrillMenuAction.restTimer:
            _showRestTimerDialog(context, drill.restTimerSeconds);
          case _DrillMenuAction.remove:
            onRemove();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _DrillMenuAction.addNote,
          child: Row(children: [
            Icon(isPro ? Icons.sticky_note_2_outlined : Icons.lock_outline_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 10),
            Text(isPro ? 'Add Note' : 'Add Note (Pro)'),
          ]),
        ),
        const PopupMenuDivider(),
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

  void _showAddNoteSheet(BuildContext context) {
    final ctrl = TextEditingController();
    bool isPinned = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(SkillDrillsRadius.lg))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: SkillDrillsSpacing.md,
            right: SkillDrillsSpacing.md,
            top: SkillDrillsSpacing.md,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + SkillDrillsSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Text('Add Session Note', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Notes are visible during this session. Pin them to carry forward to future sessions.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                maxLines: 4,
                minLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Felt strong today, increase weight next time…',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(SkillDrillsRadius.sm),
                onTap: () => setSheet(() => isPinned = !isPinned),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        size: 18,
                        color: isPinned ? SkillDrillsColors.brandBlue : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pin to future sessions',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isPinned ? SkillDrillsColors.brandBlue : null,
                              ),
                        ),
                      ),
                      Text(
                        isPinned ? 'On' : 'Off',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isPinned ? SkillDrillsColors.brandBlue : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) return;
                      sessionService.addNoteToDrill(drillIndex, DrillNote.session(text, isPinned: isPinned));
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Add Note'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drill notes section (shown between title and set column headers)
// ─────────────────────────────────────────────────────────────────────────────

class _DrillNotesSection extends StatelessWidget {
  const _DrillNotesSection({required this.drillIndex, required this.notes});

  final int drillIndex;
  final List<DrillNote> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(SkillDrillsRadius.sm),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: notes.asMap().entries.map((e) {
          final i = e.key;
          final note = e.value;
          final isRoutineNote = note.source == 'routine';
          return Padding(
            padding: EdgeInsets.only(bottom: i < notes.length - 1 ? 6 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    isRoutineNote ? Icons.format_list_bulleted_rounded : Icons.circle,
                    size: isRoutineNote ? 12 : 5,
                    color: isRoutineNote ? Theme.of(context).primaryColor.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.text,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                          height: 1.4,
                        ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => sessionService.toggleNotePin(drillIndex, i),
                  child: Tooltip(
                    message: note.isPinned ? 'Pinned — carries to next session' : 'Tap to pin',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                      child: Icon(
                        note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        size: 13,
                        color: note.isPinned ? SkillDrillsColors.brandBlue : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => sessionService.deleteNote(drillIndex, i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    child: Icon(Icons.close_rounded, size: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post-session personal bests summary sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PbSummarySheet extends StatelessWidget {
  const _PbSummarySheet({required this.pbs});

  final List<PersonalBest> pbs;

  String _formatValue(PersonalBest pb) {
    if (pb.measurementType == 'duration') {
      final d = Duration(seconds: pb.bestValue.toInt());
      final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return d.inHours >= 1 ? '${d.inHours}:$mins:$secs' : '$mins:$secs';
    }
    return '${pb.bestValue}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: SkillDrillsRadius.lgBorderRadius,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SkillDrillsSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              Text(
                pbs.length == 1 ? 'New Personal Best!' : '${pbs.length} New Personal Bests!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: 'Choplin'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'You crushed your previous records.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SkillDrillsSpacing.md),
              ...pbs.map(
                (pb) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_rounded, size: 16, color: SkillDrillsColors.energyOrange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${pb.drillTitle} · ${pb.measurementLabel}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        _formatValue(pb),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).primaryColor,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: SkillDrillsSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Keep it up! 💪', style: TextStyle(fontFamily: 'Choplin', fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pro-only notes upsell (shown to free users in place of notes section)
// ─────────────────────────────────────────────────────────────────────────────

class _ProNotesUpsell extends StatelessWidget {
  const _ProNotesUpsell();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(SkillDrillsRadius.sm),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: GestureDetector(
        onTap: () => navigatorKey.currentState!.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen())),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Session notes are a Pro feature. Upgrade to unlock.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Set row header (column labels)
// ─────────────────────────────────────────────────────────────────────────────

class _SetRowHeader extends StatelessWidget {
  const _SetRowHeader({required this.measurements});

  final List<dynamic> measurements;

  static String _labelFor(dynamic m) {
    if ((m.label as String?)?.isNotEmpty == true) return m.label as String;
    return (m.type as String?) == 'duration' ? 'Time' : 'Value';
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
        );

    Expanded labelCell(dynamic m) => Expanded(
          child: Text(
            _labelFor(m),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        );

    if (measurements.length <= 3) {
      return Row(children: [
        SizedBox(width: 36, child: Text('#', textAlign: TextAlign.center, style: style)),
        ...measurements.map(labelCell),
        const SizedBox(width: 42),
      ]);
    }

    // Grid: 2 labels per row
    final rows = <Widget>[];
    for (var i = 0; i < measurements.length; i += 2) {
      final chunk = measurements.sublist(i, (i + 2).clamp(0, measurements.length));
      rows.add(Padding(
        padding: EdgeInsets.only(top: i > 0 ? 3 : 0),
        child: Row(children: [
          ...chunk.map(labelCell),
          if (chunk.length == 1) const Expanded(child: SizedBox()),
        ]),
      ));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 36, child: Text('#', textAlign: TextAlign.center, style: style)),
      Expanded(child: Column(children: rows)),
      const SizedBox(width: 42),
    ]);
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
    required this.activityTitle,
  });

  final int drillIndex;
  final int setIndex;
  final session_model.SetResult setResult;
  final bool hasMeasurements;
  final String activityTitle;

  @override
  Widget build(BuildContext context) {
    final isComplete = setResult.isComplete;
    final measurements = setResult.measurementResults;

    // ── Shared sub-widgets ──────────────────────────────────────────────────────
    final setNumWidget = SizedBox(
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
    );

    final doneCheckbox = SizedBox(
      width: 42,
      child: Checkbox(
        value: isComplete,
        onChanged: (checked) {
          if (isComplete) {
            sessionService.toggleSetComplete(drillIndex, setIndex);
            return;
          }
          final allFilled = measurements.isEmpty || measurements.every((m) => m.value != null && !(m.type == 'duration' && m.value == 0));
          if (!allFilled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Enter all values before marking this set as done'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
          sessionService.toggleSetComplete(drillIndex, setIndex);
        },
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );

    Widget inputCell(int mi) {
      final m = measurements[mi];
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
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    Widget rowContent;
    if (!hasMeasurements || measurements.length <= 3) {
      rowContent = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          setNumWidget,
          if (hasMeasurements) ...List.generate(measurements.length, inputCell) else const Expanded(child: SizedBox()),
          doneCheckbox,
        ],
      );
    } else {
      // ≥ 4 measurements: 2-per-row grid — keeps inputs legible on narrower screens
      final gridRows = <Widget>[];
      for (var i = 0; i < measurements.length; i += 2) {
        final end = (i + 2).clamp(0, measurements.length);
        gridRows.add(Padding(
          padding: EdgeInsets.only(top: i > 0 ? 4 : 0),
          child: Row(children: [
            for (var mi = i; mi < end; mi++) inputCell(mi),
            if ((end - i) == 1) const Expanded(child: SizedBox()),
          ]),
        ));
      }
      rowContent = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          setNumWidget,
          Expanded(child: Column(children: gridRows)),
          doneCheckbox,
        ],
      );
    }

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
        child: rowContent,
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
        // Weight Training drills with legacy 'rpe' measurements are surfaced as RIR.
        final effectiveType = activityTitle == 'Weight Training' ? 'rir' : 'rpe';
        return _ScaleInput(
          type: effectiveType,
          selected: measurement.value?.toInt(),
          onSelected: (v) => sessionService.updateSetMeasurementValue(drillIndex, setIndex, measIndex, v),
        );
      case 'rir':
        return _ScaleInput(
          type: 'rir',
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
// Empty drills state – cycles through active activity icons every 5 s
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyDrillsState extends StatefulWidget {
  const _EmptyDrillsState();

  @override
  State<_EmptyDrillsState> createState() => _EmptyDrillsStateState();
}

class _EmptyDrillsStateState extends State<_EmptyDrillsState> with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  Timer? _timer;

  List<String> _icons = [];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.value = 1.0;
    sessionService.addListener(_onSessionChanged);
    // Only cycle through all icons when no specific activity has been chosen
    if (sessionService.preferredActivityIcon == null) {
      _loadIcons();
    }
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (sessionService.preferredActivityIcon != null) {
      // A specific activity was selected — stop cycling
      _timer?.cancel();
      _timer = null;
    } else if (_icons.isNotEmpty && _timer == null) {
      // Activity selection was cleared — resume cycling
      _startTimer();
    }
    setState(() {});
  }

  Future<void> _loadIcons() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance.collection('activities').doc(uid).collection('activities').get();
    final icons = snap.docs.map((d) => Activity.fromSnapshot(d)).where((a) => a.isActive).map((a) => a.icon).toList();
    if (!mounted || icons.isEmpty) return;
    setState(() => _icons = icons);
    // Don't start cycling if an activity was chosen while we were loading
    if (sessionService.preferredActivityIcon == null) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _fadeCtrl.reverse();
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _icons.length);
      _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    sessionService.removeListener(_onSessionChanged);
    _timer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If an activity has been chosen, always show its icon; otherwise cycle.
    final icon = sessionService.preferredActivityIcon ?? (_icons.isNotEmpty ? _icons[_index] : null);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SkillDrillsSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: icon != null ? Text(icon, style: const TextStyle(fontSize: 40)) : Icon(Icons.add_rounded, size: 44, color: Theme.of(context).primaryColor),
                ),
              ),
            ),
            const SizedBox(height: SkillDrillsSpacing.md),
            Text(
              'No drills yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'Choplin'),
            ),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CountBtn(icon: Icons.remove, onTap: value > 0 ? () => onChanged(value - 1) : null),
          Flexible(
            child: GestureDetector(
              onTap: () => _editDialog(context),
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
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
            Icon(Icons.timer_outlined, size: 13, color: Theme.of(context).colorScheme.onSurface.withAlpha(130)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scale (RPE / RIR) input — compact tap-target that opens a color-coded picker
// ─────────────────────────────────────────────────────────────────────────────

class _ScaleInput extends StatelessWidget {
  const _ScaleInput({
    required this.type,
    this.selected,
    required this.onSelected,
  });

  /// 'rpe' (1–10, low=easy) or 'rir' (0–5, high=easy).
  final String type;
  final int? selected;
  final ValueChanged<int> onSelected;

  String get _label => type == 'rir' ? 'RIR' : 'RPE';

  /// HSL colour: green (easy) → yellow → red (hard).
  Color _colorFor(int v) {
    final double t;
    if (type == 'rpe') {
      t = (v - 1) / 9.0;
    } else {
      t = (5 - v) / 5.0;
    }
    final hue = 120.0 * (1.0 - t);
    return HSLColor.fromAHSL(1.0, hue, 0.72, 0.42).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final v = selected;
    final color = v != null ? _colorFor(v) : null;
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: color?.withAlpha(30) ?? Theme.of(context).scaffoldBackgroundColor,
          borderRadius: SkillDrillsRadius.smBorderRadius,
          border: Border.all(color: color ?? Theme.of(context).dividerColor),
        ),
        child: Center(
          child: Text(
            // Show just the number when selected — column headers already
            // identify the measurement type (RIR / RPE).
            v != null ? '$v' : _label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Choplin',
              fontWeight: FontWeight.w700,
              color: color ?? Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ScalePicker(
        label: _label,
        type: type,
        selected: selected,
        colorFor: _colorFor,
        onSelected: (v) {
          onSelected(v);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Drill-details pre-load cache
// ─────────────────────────────────────────────────────────────────────────────
//
// Populated in the background as soon as a drill's page is first rendered so
// that the info sheet opens instantly without a loading spinner.

class _CachedDrillDetails {
  final Drill drill;
  final List<Measurement> measurements;
  final List<Skill> skills;
  _CachedDrillDetails(this.drill, this.measurements, this.skills);
}

final Map<String, _CachedDrillDetails> _drillDetailsCache = {};

/// Fetches the full drill document, measurements, and skills from Firestore and
/// stores them in [_drillDetailsCache] keyed by [drillId]. Safe to call many
/// times — subsequent calls for an already-cached ID are no-ops.
Future<void> _prefetchDrillDetailsIfNeeded(String drillId) async {
  if (_drillDetailsCache.containsKey(drillId)) return;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  try {
    final drillRef = FirebaseFirestore.instance.collection('drills').doc(uid).collection('drills').doc(drillId);
    final results = await Future.wait([
      drillRef.get(),
      drillRef.collection('measurements').orderBy('order').get(),
      drillRef.collection('skills').get(),
    ]);
    final drillSnap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final measureSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final skillsSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    if (!drillSnap.exists) return;
    _drillDetailsCache[drillId] = _CachedDrillDetails(
      Drill.fromSnapshot(drillSnap),
      measureSnap.docs.map(Measurement.fromSnapshot).toList(),
      skillsSnap.docs.map(Skill.fromSnapshot).toList(),
    );
  } catch (_) {
    // Ignore prefetch errors — the sheet will fall back to on-demand fetching.
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drill details sheet
// ─────────────────────────────────────────────────────────────────────────────

void _showDrillDetails(BuildContext context, session_model.DrillResult drillResult) {
  final cached = _drillDetailsCache[drillResult.drillId];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DrillDetailsSheet(
      drillResult: drillResult,
      preloadedDrill: cached?.drill,
      preloadedMeasurements: cached?.measurements,
      preloadedSkills: cached?.skills,
    ),
  );
}

class _DrillDetailsSheet extends StatefulWidget {
  const _DrillDetailsSheet({
    required this.drillResult,
    this.preloadedDrill,
    this.preloadedMeasurements,
    this.preloadedSkills,
  });

  final session_model.DrillResult drillResult;

  /// Pre-fetched data. When supplied the sheet skips the Firestore fetch and
  /// renders content immediately with no loading state.
  final Drill? preloadedDrill;
  final List<Measurement>? preloadedMeasurements;
  final List<Skill>? preloadedSkills;

  @override
  State<_DrillDetailsSheet> createState() => _DrillDetailsSheetState();
}

class _DrillDetailsSheetState extends State<_DrillDetailsSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  Drill? _drill;
  List<Measurement> _measurements = [];
  List<Skill> _skills = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    if (widget.preloadedDrill != null) {
      // Data was pre-fetched when the drill page was first rendered — use it
      // directly so the sheet opens with no loading spinner.
      _drill = widget.preloadedDrill;
      _measurements = widget.preloadedMeasurements ?? [];
      _skills = widget.preloadedSkills ?? [];
      _loading = false;
    } else {
      _fetchDetails();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Not signed in';
          });
        }
        return;
      }
      final drillRef = FirebaseFirestore.instance.collection('drills').doc(uid).collection('drills').doc(widget.drillResult.drillId);

      final results = await Future.wait([
        drillRef.get(),
        drillRef.collection('measurements').orderBy('order').get(),
        drillRef.collection('skills').get(),
      ]);

      if (!mounted) return;

      final drillSnap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final measureSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final skillsSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;

      if (!drillSnap.exists) {
        setState(() {
          _loading = false;
          _error = 'Drill details not found';
        });
        return;
      }

      setState(() {
        _drill = Drill.fromSnapshot(drillSnap);
        _measurements = measureSnap.docs.map(Measurement.fromSnapshot).toList();
        _skills = skillsSnap.docs.map(Skill.fromSnapshot).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load details';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(SkillDrillsRadius.lg)),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: SkillDrillsRadius.fullBorderRadius,
                  ),
                ),
              ),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                )
              else
                Flexible(child: _buildContent(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final drill = _drill!;
    final resultMeasurements = _measurements.where((m) => m.role == 'result').toList();
    final targetMeasurements = _measurements.where((m) => m.role == 'target').toList();
    final description = drill.description?.trim() ?? '';
    final drillTypeDescriptor = drill.drillType?.descriptor?.trim() ?? '';
    final drillTypeTitle = drill.drillType?.title?.trim() ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActivityBadge(
            icon: widget.drillResult.activityIcon,
            label: widget.drillResult.activityTitle,
          ),
          const SizedBox(height: 8),
          Text(
            widget.drillResult.drillTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'Choplin',
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (_skills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _skills
                  .map(
                    (s) => Chip(
                      label: Text(
                        s.title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Choplin',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Theme.of(context).primaryColor.withAlpha(18),
                      side: BorderSide(color: Theme.of(context).primaryColor.withAlpha(60)),
                      shape: RoundedRectangleBorder(borderRadius: SkillDrillsRadius.fullBorderRadius),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (drillTypeTitle.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                ),
                const SizedBox(width: 6),
                Text(
                  drillTypeTitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Choplin',
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                      ),
                ),
              ],
            ),
            if (drillTypeDescriptor.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(drillTypeDescriptor, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
          if (resultMeasurements.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Measurements',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Choplin',
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                  ),
            ),
            const SizedBox(height: 8),
            ...resultMeasurements.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      m.type == 'duration'
                          ? Icons.timer_outlined
                          : m.type == 'rpe' || m.type == 'rir'
                              ? Icons.speed_rounded
                              : Icons.straighten_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.label.isNotEmpty ? m.label : _typeLabel(m.type),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      _typeLabel(m.type),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(110),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (targetMeasurements.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Targets',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Choplin',
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                  ),
            ),
            const SizedBox(height: 8),
            ...targetMeasurements.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      t.reverse ? Icons.arrow_downward_rounded : Icons.flag_outlined,
                      size: 14,
                      color: Theme.of(context).primaryColor.withAlpha(160),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.label.isNotEmpty ? t.label : (t.type == 'duration' ? 'Time Goal' : 'Goal'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (t.target != null)
                      Text(
                        _formatTarget(t),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Choplin',
                              color: Theme.of(context).primaryColor,
                            ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'duration':
        return 'Time';
      case 'rpe':
        return 'RPE';
      case 'rir':
        return 'RIR';
      default:
        return 'Amount';
    }
  }

  static String _formatTarget(Measurement t) {
    if (t.target == null) return '—';
    if (t.type == 'duration') return printDuration(Duration(seconds: t.target!.toInt()));
    return t.target!.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ScalePicker extends StatefulWidget {
  const _ScalePicker({
    required this.label,
    required this.type,
    required this.selected,
    required this.colorFor,
    required this.onSelected,
  });

  final String label;
  final String type;
  final int? selected;
  final Color Function(int) colorFor;
  final ValueChanged<int> onSelected;

  @override
  State<_ScalePicker> createState() => _ScalePickerState();
}

class _ScalePickerState extends State<_ScalePicker> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // RIR: show 5 (very easy/green) first, 0 (to failure/red) last.
  // RPE: show 1 (very easy) first, 10 (maximum effort) last.
  List<int> get _values => widget.type == 'rir'
      ? List.generate(6, (i) => 5 - i) // 5, 4, 3, 2, 1, 0
      : List.generate(10, (i) => i + 1); // 1..10

  String get _hint {
    if (widget.type == 'rpe') return '1 = very easy  ·  10 = maximum effort';
    return '0 = to failure  ·  5+ = very easy';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(SkillDrillsRadius.lg)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: SkillDrillsRadius.fullBorderRadius,
                  ),
                ),
              ),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'Choplin',
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                _hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                children: _values.map((v) {
                  final isSelected = v == widget.selected;
                  final color = widget.colorFor(v);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: GestureDetector(
                        onTap: () => widget.onSelected(v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 54,
                          decoration: BoxDecoration(
                            color: isSelected ? color : color.withAlpha(38),
                            borderRadius: SkillDrillsRadius.smBorderRadius,
                            border: Border.all(
                              color: isSelected ? color : color.withAlpha(100),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withAlpha(90),
                                      blurRadius: 6,
                                      spreadRadius: 0,
                                    )
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              // For RIR, the top value (5) is labelled "5+" to
                              // convey "5 or more reps in reserve" (very fresh).
                              widget.type == 'rir' && v == 5 ? '5+' : '$v',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Choplin',
                                color: isSelected ? Colors.white : color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
