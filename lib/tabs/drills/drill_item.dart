import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/skill_drills_dialog.dart';
import 'package:skilldrills/models/firestore/skill.dart';
import 'package:skilldrills/models/firestore/drill.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:skilldrills/tabs/drills/drill_detail.dart';
import 'package:skilldrills/tabs/history/drill_stats_screen.dart';
import 'package:skilldrills/widgets/app_list_item.dart';

final user = FirebaseAuth.instance.currentUser;

class DrillItem extends StatefulWidget {
  const DrillItem({super.key, required this.drill, required this.deleteCallback, this.isPro = false});

  final Drill drill;
  final Function deleteCallback;
  final bool isPro;

  @override
  State<DrillItem> createState() => _DrillItemState();
}

class _DrillItemState extends State<DrillItem> {
  List<Skill> _categories = [];

  @override
  void initState() {
    FirebaseFirestore.instance.collection('drills').doc(user!.uid).collection('drills').doc(widget.drill.reference!.id).collection('skills').get().then((cSnap) {
      List<Skill> categories = [];

      for (var m in cSnap.docs) {
        categories.add(Skill.fromSnapshot(m));
      }

      setState(() {
        _categories = categories;
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppListItem(
      title: widget.drill.title!,
      subtitle: _outputCategories(_categories),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats button (navigates to DrillStatsScreen for all users; gated internally).
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            splashRadius: 18,
            icon: Icon(
              Icons.bar_chart_rounded,
              size: 18,
              color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.7),
            ),
            onPressed: () => navigatorKey.currentState!.push(
              MaterialPageRoute(
                builder: (_) => DrillStatsScreen(
                  drillId: widget.drill.reference!.id,
                  drillTitle: widget.drill.title!,
                ),
              ),
            ),
          ),
          // Pro: pin/unpin + delete popup; free: just delete icon.
          if (widget.isPro)
            PopupMenuButton<_DrillMenuAction>(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_vert_rounded, size: 20, color: Theme.of(context).iconTheme.color),
              onSelected: (action) {
                switch (action) {
                  case _DrillMenuAction.togglePin:
                    _togglePin();
                  case _DrillMenuAction.delete:
                    _confirmDelete(context);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _DrillMenuAction.togglePin,
                  child: Row(
                    children: [
                      Icon(
                        widget.drill.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(widget.drill.isPinned ? 'Unpin' : 'Pin to top'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _DrillMenuAction.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                  ),
                ),
              ],
            )
          else
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              splashRadius: 20,
              icon: Icon(Icons.delete_outline_rounded, size: 20, color: Theme.of(context).iconTheme.color),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      onTap: () {
        navigatorKey.currentState!.push(
          PageRouteBuilder(
            pageBuilder: (ctx, anim, secondaryAnim) => DrillDetail(drill: widget.drill),
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

  void _togglePin() {
    final ref = widget.drill.reference;
    if (ref == null) return;
    final newPinned = !widget.drill.isPinned;
    ref.update({'is_pinned': newPinned});
  }

  void _confirmDelete(BuildContext context) {
    dialog(
      context,
      SkillDrillsDialog(
        "Delete \"${widget.drill.title}\"?",
        Text(
          "Are you sure you want to delete this drill?\n\nThis action cannot be undone.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        null,
        () => Navigator.of(context).pop(),
        "Delete",
        () {
          widget.deleteCallback(widget.drill);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  String _outputCategories(List<Skill> categories) {
    String catString = "";

    categories.asMap().forEach((i, c) {
      catString += (i != categories.length - 1 && categories.length != 1) ? "${c.title}, " : c.title;
    });

    return catString;
  }
}

enum _DrillMenuAction { togglePin, delete }
