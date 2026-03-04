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
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionService,
      builder: (context, _) {
        final drills = sessionService.drillResults;
        return Column(
          children: [
            // Live status badge
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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

            // Drill list or empty state
            Expanded(
              child: drills.isEmpty ? _buildEmptyState(context) : _buildDrillList(context, drills),
            ),

            // Bottom action bar
            _buildBottomBar(context),
          ],
        );
      },
    );
  }

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

  Widget _buildDrillList(BuildContext context, List<session_model.DrillResult> drills) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      itemCount: drills.length + 1,
      itemBuilder: (context, i) {
        if (i == drills.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: SkillDrillsSpacing.sm),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Another Drill'),
              onPressed: _addDrill,
            ),
          );
        }
        return _DrillCard(
          drillResult: drills[i],
          drillIndex: i,
          onRemove: () => sessionService.removeDrill(i),
        );
      },
    );
  }

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
// Drill Card
// ─────────────────────────────────────────────────────────────────────────────

class _DrillCard extends StatelessWidget {
  const _DrillCard({required this.drillResult, required this.drillIndex, required this.onRemove});

  final session_model.DrillResult drillResult;
  final int drillIndex;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('drill_$drillIndex'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: SkillDrillsColors.error.withAlpha(200),
          borderRadius: SkillDrillsRadius.mdBorderRadius,
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) => onRemove(),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(SkillDrillsSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  _ActivityBadge(icon: drillResult.activityIcon, label: drillResult.activityTitle),
                  const Spacer(),
                  GestureDetector(
                    onTap: onRemove,
                    child: Icon(Icons.close_rounded, size: 18, color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                drillResult.drillTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'Choplin',
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: SkillDrillsSpacing.md),
              // Sets / Reps
              _SetsRepsRow(drillIndex: drillIndex, drillResult: drillResult),
              // Measurements
              if (drillResult.measurementResults.isNotEmpty) ...[
                const SizedBox(height: SkillDrillsSpacing.sm),
                Divider(color: Theme.of(context).dividerColor, height: 1),
                const SizedBox(height: SkillDrillsSpacing.sm),
                ...List.generate(
                  drillResult.measurementResults.length,
                  (i) => _MeasurementRow(
                    measurement: drillResult.measurementResults[i],
                    drillIndex: drillIndex,
                    measIndex: i,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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

class _SetsRepsRow extends StatelessWidget {
  const _SetsRepsRow({required this.drillIndex, required this.drillResult});

  final int drillIndex;
  final session_model.DrillResult drillResult;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CounterTile(
            label: drillResult.setsLabel,
            value: drillResult.sets,
            onChanged: (v) => sessionService.updateDrillSets(drillIndex, v),
          ),
        ),
        const SizedBox(width: SkillDrillsSpacing.sm),
        Expanded(
          child: _CounterTile(
            label: drillResult.repsLabel,
            value: drillResult.reps,
            onChanged: (v) => sessionService.updateDrillReps(drillIndex, v),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Measurement Row
// ─────────────────────────────────────────────────────────────────────────────

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({required this.measurement, required this.drillIndex, required this.measIndex});

  final dynamic measurement;
  final int drillIndex;
  final int measIndex;

  @override
  Widget build(BuildContext context) {
    final label = (measurement.label as String?)?.isNotEmpty == true
        ? measurement.label as String
        : measurement.type == 'duration'
            ? 'Time'
            : measurement.type == 'rpe'
                ? 'RPE'
                : measurement.type == 'rir'
                    ? 'RIR'
                    : 'Value';
    return Padding(
      padding: const EdgeInsets.only(bottom: SkillDrillsSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          _buildInput(context),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    switch (measurement.type as String) {
      case 'duration':
        return _DurationInput(
          value: measurement.value != null ? Duration(seconds: (measurement.value as num).toInt()) : Duration.zero,
          onChanged: (d) => sessionService.updateMeasurementValue(drillIndex, measIndex, d.inSeconds),
        );
      case 'rpe':
        return _ChipInput(
          values: List.generate(10, (i) => i + 1),
          selected: measurement.value?.toInt(),
          onSelected: (v) => sessionService.updateMeasurementValue(drillIndex, measIndex, v),
        );
      case 'rir':
        return _ChipInput(
          values: List.generate(6, (i) => i),
          selected: measurement.value?.toInt(),
          onSelected: (v) => sessionService.updateMeasurementValue(drillIndex, measIndex, v),
        );
      default: // 'amount'
        return _AmountInput(
          value: measurement.value?.toInt() ?? 0,
          onChanged: (v) => sessionService.updateMeasurementValue(drillIndex, measIndex, v),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input widgets
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
        children: [
          _CountBtn(icon: Icons.remove, onTap: value > 0 ? () => onChanged(value - 1) : null),
          GestureDetector(
            onTap: () => _editDialog(context),
            child: SizedBox(
              width: 40,
              child: Text('$value', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontFamily: 'Choplin', fontWeight: FontWeight.w700)),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 16, color: onTap != null ? Theme.of(context).primaryColor : Theme.of(context).disabledColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DurationInput extends StatelessWidget {
  const _DurationInput({required this.value, required this.onChanged});

  final Duration value;
  final ValueChanged<Duration> onChanged;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours.toString().padLeft(2, '0')}:$m:$s';
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: SkillDrillsRadius.smBorderRadius,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_format(value), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontFamily: 'Choplin', fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Icon(Icons.timer_outlined, size: 14, color: Theme.of(context).colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }
}

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
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isSel ? Theme.of(context).primaryColor : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: SkillDrillsRadius.xsBorderRadius,
              border: Border.all(
                color: isSel ? Theme.of(context).primaryColor : Theme.of(context).dividerColor,
              ),
            ),
            child: Center(
              child: Text('$v', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSel ? Colors.white : Theme.of(context).textTheme.bodySmall?.color)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CounterTile extends StatelessWidget {
  const _CounterTile({required this.label, required this.value, required this.onChanged});

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SkillDrillsSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: SkillDrillsRadius.smBorderRadius,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CountBtn(
                icon: Icons.remove,
                onTap: current > 0 ? () => onChanged(current > 1 ? current - 1 : null) : null,
              ),
              SizedBox(
                width: 28,
                child: Text(current == 0 ? '—' : '$current', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontFamily: 'Choplin', fontWeight: FontWeight.w700)),
              ),
              _CountBtn(icon: Icons.add, onTap: () => onChanged(current + 1)),
            ],
          ),
        ],
      ),
    );
  }
}
