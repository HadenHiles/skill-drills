import 'package:flutter/material.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/models/SkillDrillsDialog.dart';
import 'package:skilldrills/services/dialogs.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class Start extends StatefulWidget {
  const Start({super.key, this.sessionPanelController});

  final PanelController? sessionPanelController;

  @override
  _StartState createState() => _StartState();
}

class _StartState extends State<Start> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Text(
              "Quick start".toUpperCase(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          MaterialButton(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 50),
            color: Theme.of(context).colorScheme.secondary,
            textColor: Theme.of(context).colorScheme.onSecondary,
            onPressed: () {
              if (!sessionService.isRunning!) {
                sessionService.start();
                widget.sessionPanelController!.open();
              } else {
                dialog(
                  context,
                  SkillDrillsDialog(
                    "Override current session?",
                    Text(
                      "Starting a new session will override your existing one.\n\nWould you like to continue?",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    "Cancel",
                    () {
                      Navigator.of(context).pop();
                    },
                    "Continue",
                    () {
                      sessionService.reset();
                      Navigator.of(context).pop();
                      sessionService.start();
                    },
                  ),
                );
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Start empty session".toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondary,
                    fontSize: 18,
                    fontFamily: "Choplin",
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 50, bottom: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "My Routines".toUpperCase(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
