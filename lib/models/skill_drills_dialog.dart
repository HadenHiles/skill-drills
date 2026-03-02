import 'package:flutter/material.dart';

class SkillDrillsDialog {
  final String? title;
  final Widget? body;
  final String? cancelText;
  final VoidCallback? cancelCallback;
  final String? continueText;
  final VoidCallback? continueCallback;

  /// Optional icon shown at the top of the dialog.
  /// When omitted, a default icon is chosen based on [isDangerous].
  final IconData? icon;

  /// When `true` (default) the action button and icon use the error/red colour
  /// palette. Set to `false` for neutral or informational dialogs.
  final bool isDangerous;

  SkillDrillsDialog(
    this.title,
    this.body,
    this.cancelText,
    this.cancelCallback,
    this.continueText,
    this.continueCallback, {
    this.icon,
    this.isDangerous = true,
  });
}
