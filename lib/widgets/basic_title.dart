import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class BasicTitle extends StatelessWidget {
  const BasicTitle({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: AutoSizeText(
        title!.toUpperCase(),
        style: TextStyle(
          fontSize: 22,
          color: Theme.of(context).textTheme.displayLarge!.color,
          fontFamily: "Choplin",
          fontWeight: FontWeight.w900,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        minFontSize: 12,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
