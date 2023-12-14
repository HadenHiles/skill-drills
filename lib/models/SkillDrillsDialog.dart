import 'package:flutter/material.dart';

class SkillDrillsDialog {
  final String? title;
  final Widget? body;
  final String? cancelText;
  final VoidCallback? cancelCallback;
  final String? continueText;
  final VoidCallback? continueCallback;

  SkillDrillsDialog(this.title, this.body, this.cancelText, this.cancelCallback, this.continueText, this.continueCallback);
}
