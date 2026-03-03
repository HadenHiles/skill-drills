import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/firestore/routine.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/tabs/routines/routine_detail.dart';
import 'package:skilldrills/widgets/app_list_item.dart';
import 'package:skilldrills/theme/theme.dart';

class RoutineItem extends StatelessWidget {
  const RoutineItem({
    super.key,
    required this.routine,
    required this.deleteCallback,
  });

  final Routine routine;
  final Function(Routine) deleteCallback;

  @override
  Widget build(BuildContext context) {
    final drillCount = routine.drills?.length ?? 0;
    final subtitle = drillCount == 0 ? 'No drills added' : '$drillCount drill${drillCount == 1 ? '' : 's'}';

    return AppListItem(
      title: routine.title,
      subtitle: routine.description.isNotEmpty ? routine.description : subtitle,
      accentColor: SkillDrillsColors.energyOrange,
      trailing: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(
          Icons.delete_outline_rounded,
          size: 20,
          color: Theme.of(context).iconTheme.color,
        ),
        onPressed: () {
          dialog(
            context,
            SkillDrillsDialog(
              'Delete "${routine.title}"?',
              Text(
                'Are you sure you want to delete this routine?\n\nThis action cannot be undone.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              null,
              () => Navigator.of(context).pop(),
              'Delete',
              () {
                deleteCallback(routine);
                Navigator.of(context).pop();
              },
            ),
          );
        },
      ),
      onTap: () {
        navigatorKey.currentState!.push(
          PageRouteBuilder(
            pageBuilder: (ctx, anim, secondaryAnim) => RoutineDetail(routine: routine),
            transitionDuration: const Duration(milliseconds: 320),
            transitionsBuilder: (ctx, anim, secondaryAnim, child) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
              return FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                child: SlideTransition(position: slide, child: child),
              );
            },
          ),
        );
      },
    );
  }
}
