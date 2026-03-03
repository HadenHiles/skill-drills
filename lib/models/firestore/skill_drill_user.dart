import 'package:cloud_firestore/cloud_firestore.dart';

/// SkillDrillsUser – extended Firebase Auth profile stored in Firestore.
///
/// [tier] – subscription level: 'free' or 'premium'.
///
/// Free-tier limits (enforced in the UI and checked before writes):
/// - [freeActiveActivityLimit]: max 2 activities active at a time.
/// - [freeRoutineLimit]: max 3 saved routines.
class SkillDrillsUser {
  final String? displayName;
  final String? email;
  final String? photoURL;
  final String tier; // 'free' | 'premium'
  DocumentReference? reference;

  bool get isPremium => tier == 'premium';

  static const int freeActiveActivityLimit = 2;
  static const int freeRoutineLimit = 3;

  SkillDrillsUser(this.displayName, this.email, this.photoURL, {this.tier = 'free'});

  SkillDrillsUser.fromMap(Map<String, dynamic>? map, {this.reference})
      : assert(map!['displayName'] != null),
        assert(map!['email'] != null),
        displayName = map!['displayName'],
        email = map['email'],
        photoURL = map['photoURL'] as String?,
        tier = (map['tier'] as String?) ?? 'free';

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'tier': tier,
    };
  }

  SkillDrillsUser.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) : this.fromMap(snapshot.data(), reference: snapshot.reference);
}
