import 'package:flutter/material.dart';
import 'package:skilldrills/theme/theme.dart';

/// A reusable, themed list-item card used across all list screens.
///
/// Features a coloured left accent bar, clean typography hierarchy, and a
/// full-card [InkWell] tap ripple. Pass [trailing] for action buttons (e.g.
/// delete), [leading] for icons/avatars, and [subtitle] for secondary text.
///
/// Example:
/// ```dart
/// AppListItem(
///   title: 'Morning Passing Drill',
///   subtitle: 'Accuracy, Footwork',
///   trailing: IconButton(icon: Icon(Icons.delete_outline), onPressed: …),
///   onTap: () { … },
/// )
/// ```
class AppListItem extends StatelessWidget {
  const AppListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.accentColor,
    this.contentPadding,
  });

  /// Primary label text.
  final String title;

  /// Optional secondary label shown below [title].
  final String? subtitle;

  /// Optional widget placed to the left of the content (icon, avatar, etc.).
  final Widget? leading;

  /// Optional widget placed to the right of the content (icon button, etc.).
  final Widget? trailing;

  /// Called when the item is tapped. Passing `null` disables tap feedback.
  final VoidCallback? onTap;

  /// Colour of the left accent bar. Defaults to [SkillDrillsColors.brandBlue].
  final Color? accentColor;

  /// Override the inner content padding.
  /// Defaults to `EdgeInsets.symmetric(horizontal: 14, vertical: 14)`.
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = contentPadding ??
        const EdgeInsets.symmetric(
          horizontal: SkillDrillsSpacing.md,
          vertical: 14,
        );

    return Card(
      // Card shape/color/elevation come from the global CardTheme.
      child: ClipRRect(
        borderRadius: SkillDrillsRadius.mdBorderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: SkillDrillsRadius.mdBorderRadius,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left accent bar ──────────────────────────────────────
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: accentColor ?? SkillDrillsColors.brandBlue,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(SkillDrillsRadius.md),
                      bottomLeft: Radius.circular(SkillDrillsRadius.md),
                    ),
                  ),
                ),

                // ── Content ───────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: effectivePadding,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: SkillDrillsSpacing.sm),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (subtitle != null && subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: SkillDrillsSpacing.xs),
                          trailing!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
