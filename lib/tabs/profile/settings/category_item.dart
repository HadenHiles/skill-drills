import 'package:flutter/material.dart';
import 'package:skilldrills/models/firestore/skill.dart';
import 'package:skilldrills/widgets/app_list_item.dart';

class CategoryItem extends StatefulWidget {
  const CategoryItem({super.key, this.category, this.editCallback, this.deleteCallback});

  final Skill? category;
  final Function? editCallback;
  final Function? deleteCallback;

  @override
  State<CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<CategoryItem> {
  @override
  Widget build(BuildContext context) {
    return AppListItem(
      title: widget.category!.title,
      trailing: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        splashRadius: 20,
        icon: Icon(
          Icons.delete_outline_rounded,
          size: 20,
          color: Theme.of(context).iconTheme.color,
        ),
        onPressed: () => widget.deleteCallback!(widget.category),
      ),
      onTap: () => widget.editCallback!(widget.category),
    );
  }
}
