import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/models/firestore/activity.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/tabs/profile/settings/activity_detail.dart';
import 'package:skilldrills/widgets/app_list_item.dart';

class ActivityItem extends StatefulWidget {
  const ActivityItem({super.key, this.sport, this.deleteCallback, this.toggleCallback});

  final Activity? sport;
  final Function? deleteCallback;
  final Function? toggleCallback;

  @override
  State<ActivityItem> createState() => _ActivityItemState();
}

class _ActivityItemState extends State<ActivityItem> {
  @override
  Widget build(BuildContext context) {
    final sport = widget.sport!;
    final terminologyHint = '${sport.drillLabel}s · ${sport.setsLabel} · ${sport.repsLabel}';
    return AppListItem(
      title: sport.title!,
      subtitle: terminologyHint,
      leading: Text(sport.icon, style: const TextStyle(fontSize: 24)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: sport.isActive,
            onChanged: (v) => widget.toggleCallback?.call(widget.sport, v),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            splashRadius: 20,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () {
              dialog(
                context,
                SkillDrillsDialog(
                  "Delete \"${widget.sport!.title}\"?",
                  Text(
                    "Are you sure you want to delete this activity?\n\nThis action cannot be undone.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  null,
                  () => Navigator.of(context).pop(),
                  "Delete",
                  () {
                    widget.deleteCallback!(widget.sport);
                    Navigator.of(context).pop();
                  },
                ),
              );
            },
          ),
        ],
      ),
      onTap: () {
        navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) {
          return ActivityDetail(sport: widget.sport);
        }));
      },
    );
  }
}
