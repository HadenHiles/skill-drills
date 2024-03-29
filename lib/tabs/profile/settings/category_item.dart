import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skilldrills/models/firestore/category.dart';

final user = FirebaseAuth.instance.currentUser;

class CategoryItem extends StatefulWidget {
  const CategoryItem({super.key, this.category, this.editCallback, this.deleteCallback});

  final Category? category;
  final Function? editCallback;
  final Function? deleteCallback;

  @override
  State<CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<CategoryItem> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 5, left: 5, right: 5),
      color: Theme.of(context).cardTheme.color,
      elevation: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ListTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category!.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 28,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                onPressed: () {
                  widget.deleteCallback!(widget.category);
                },
                icon: Icon(
                  Icons.delete,
                  color: Theme.of(context).iconTheme.color,
                  size: 20,
                ),
              ),
            ],
          ),
          onTap: () {
            widget.editCallback!(widget.category);
          },
        ),
      ),
    );
  }
}
