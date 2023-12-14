import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserAvatar extends StatelessWidget {
  UserAvatar({super.key, this.radius, this.backgroundColor});

  final User? user = FirebaseAuth.instance.currentUser;
  final double? radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (user!.providerData[0].photoURL != null) {
      return FittedBox(
        fit: BoxFit.contain,
        child: CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(
            FirebaseAuth.instance.currentUser!.providerData[0].photoURL!,
          ),
          backgroundColor: backgroundColor,
        ),
      );
    } else {
      return FittedBox(
        fit: BoxFit.contain,
        child: CircleAvatar(
          radius: radius,
          backgroundImage: const AssetImage("assets/images/avatar.png"),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }
}
