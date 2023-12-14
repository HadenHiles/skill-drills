import 'package:flutter/material.dart';

class NavTab extends StatefulWidget {
  const NavTab({Key? key, this.title, this.actions, this.body}) : super(key: key);

  final Widget? title;
  final List<Widget>? actions;
  final Widget? body;

  @override
  _NavTabState createState() => _NavTabState();
}

class _NavTabState extends State<NavTab> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      margin: const EdgeInsets.only(top: 40),
      child: widget.body,
    );
  }
}
