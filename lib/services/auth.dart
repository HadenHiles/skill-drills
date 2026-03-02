import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:password_strength/password_strength.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

Future<UserCredential> signInWithGoogle() async {
  // google_sign_in 7.x: use singleton instance and authenticate()
  final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();
  final GoogleSignInAuthentication googleAuth = googleUser.authentication;
  final OAuthCredential credential = GoogleAuthProvider.credential(
    idToken: googleAuth.idToken,
  );
  return await auth.signInWithCredential(credential);
}

Future<void> signOut() async {
  await auth.signOut();
}

bool emailVerified() {
  auth.currentUser!.reload();
  return auth.currentUser!.emailVerified;
}

bool validEmail(String email) {
  return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
}

bool validPassword(String pass) {
  return estimatePasswordStrength(pass) > 0.7;
}
