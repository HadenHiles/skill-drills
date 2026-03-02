import 'package:flutter/material.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/theme/theme.dart';

/// Shows a polished, branded confirmation dialog.
///
/// Appearance adapts to the current theme brightness and [SkillDrillsDialog.isDangerous].
void dialog(BuildContext context, SkillDrillsDialog config) {
  showDialog(
    context: context,
    builder: (BuildContext ctx) => _SkillDrillsAlertDialog(config: config),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Private dialog widget
// ─────────────────────────────────────────────────────────────────────────────

class _SkillDrillsAlertDialog extends StatelessWidget {
  const _SkillDrillsAlertDialog({required this.config});

  final SkillDrillsDialog config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Action colour — red for destructive, brand blue for neutral.
    final Color actionColor = config.isDangerous ? (isDark ? SkillDrillsColors.errorDark : SkillDrillsColors.error) : SkillDrillsColors.brandBlue;

    // Icon — caller can override, otherwise we choose a sensible default.
    final IconData iconData = config.icon ?? (config.isDangerous ? Icons.delete_outline_rounded : Icons.info_outline_rounded);

    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: SkillDrillsRadius.lgBorderRadius,
      ),
      backgroundColor: theme.dialogTheme.backgroundColor,
      // Constrain maximum width so it looks right on tablets too.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon badge ───────────────────────────────────────────────
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: actionColor, size: 28),
              ),

              const SizedBox(height: 16),

              // ── Title ────────────────────────────────────────────────────
              Text(
                config.title ?? "Are you sure?",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 10),

              // ── Body ─────────────────────────────────────────────────────
              DefaultTextStyle(
                style: theme.textTheme.bodyMedium!.copyWith(height: 1.5),
                textAlign: TextAlign.center,
                child: config.body ??
                    Text(
                      "This action cannot be undone.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
              ),

              const SizedBox(height: 24),

              Divider(height: 1, thickness: 1, color: theme.dividerTheme.color),

              const SizedBox(height: 16),

              // ── Buttons ──────────────────────────────────────────────────
              Row(
                children: [
                  // Cancel — outlined / ghost
                  Expanded(
                    child: OutlinedButton(
                      onPressed: config.cancelCallback,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        side: BorderSide(
                          color: theme.dividerTheme.color ?? const Color(0xFFE2E8F0),
                        ),
                        minimumSize: const Size(0, 44),
                        shape: const RoundedRectangleBorder(
                          borderRadius: SkillDrillsRadius.smBorderRadius,
                        ),
                      ),
                      child: Text(config.cancelText ?? "Cancel"),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Action — filled
                  Expanded(
                    child: ElevatedButton(
                      onPressed: config.continueCallback ?? () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(0, 44),
                        shape: const RoundedRectangleBorder(
                          borderRadius: SkillDrillsRadius.smBorderRadius,
                        ),
                      ),
                      child: Text(config.continueText ?? "Continue"),
                    ),
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
