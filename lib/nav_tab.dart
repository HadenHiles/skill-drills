import 'package:flutter/material.dart';

class NavTab extends StatefulWidget {
  const NavTab({super.key, this.title, this.actions, this.body});

  final Widget? title;
  final List<Widget>? actions;
  final Widget? body;

  @override
  State<NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<NavTab> {
  @override
  Widget build(BuildContext context) {
    return widget.body ?? const SizedBox.shrink();
  }
}
