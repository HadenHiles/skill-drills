// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:skilldrills/services/auth.dart';
import 'nav.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  // Auth variables
  final FirebaseAuth auth = FirebaseAuth.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  // static variables
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();
  final TextEditingController _signInEmail = TextEditingController();
  final TextEditingController _signInPass = TextEditingController();
  final TextEditingController _signUpEmail = TextEditingController();
  final TextEditingController _signUpPass = TextEditingController();
  final TextEditingController _signUpConfirmPass = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State variables
  bool _signedIn = FirebaseAuth.instance.currentUser != null;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //If user is signed in
    if (_signedIn) {
      return const Nav();
    }

    return Scaffold(
      key: _scaffoldKey,
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 140,
                        child: SvgPicture.asset(
                          'assets/images/logo/SkillDrills.svg',
                          semanticsLabel: 'Skill Drills',
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(
                          top: 40,
                          bottom: 120,
                        ),
                        width: 420,
                        child: const Center(
                          child: Text(
                            'Keep track of your\nimprovements in any skill',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: "Choplin",
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 60,
                        width: 360,
                        child: SignInButton(
                          Buttons.Google,
                          onPressed: () {
                            socialSignIn(context, 'google', (error) {
                              // ignore: deprecated_member_use
                              // ignore: deprecated_member_use
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              // ignore: deprecated_member_use
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  duration: const Duration(seconds: 10),
                                  action: SnackBarAction(
                                    label: "Dismiss",
                                    onPressed: () {
                                      // ignore: deprecated_member_use
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    },
                                  ),
                                ),
                              );
                            });
                          },
                        ),
                      ),
                      const Divider(
                        color: Colors.transparent,
                        height: 10,
                      ),
                      SizedBox(
                        width: 220,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(
                                top: 30,
                                bottom: 30,
                              ),
                              child: Text(
                                'Or'.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 60,
                        width: 360,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            backgroundColor: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FractionalTranslation(
                                translation: const Offset(-0.2, 0.0),
                                child: Align(
                                  alignment: const FractionalOffset(0.0, 0.0),
                                  child: SizedBox(
                                    height: 100,
                                    child: Row(
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(right: 5),
                                          height: 40,
                                          child: SvgPicture.asset(
                                            'assets/images/icons/icon.svg',
                                            semanticsLabel: 'Skill Drills',
                                            height: 40,
                                            width: 40,
                                          ),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.only(left: 5),
                                          child: const Text('Sign in with Email'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onPressed: () {
                            setState(() {
                              _hidePassword = true;
                            });

                            showDialog(
                              context: context,
                              builder: (context) {
                                return SimpleDialog(
                                  contentPadding: const EdgeInsets.all(25),
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            SizedBox(
                                              height: 50,
                                              child: SvgPicture.asset(
                                                'assets/images/logo/SkillDrillsDark.svg',
                                                semanticsLabel: 'Skill Drills',
                                                width: 120,
                                              ),
                                            ),
                                            const Text(
                                              'SIGN IN',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          ],
                                        ),
                                        Form(
                                          key: _signInFormKey,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: TextFormField(
                                                  controller: _signInEmail,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Email',
                                                  ),
                                                  keyboardType: TextInputType.emailAddress,
                                                  validator: (String? value) {
                                                    if (value!.isEmpty) {
                                                      return 'Please enter your email';
                                                    } else if (!validEmail(value)) {
                                                      return 'Invalid email address';
                                                    }

                                                    return null;
                                                  },
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: TextFormField(
                                                  controller: _signInPass,
                                                  obscureText: _hidePassword,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Password',
                                                  ),
                                                  keyboardType: TextInputType.visiblePassword,
                                                  validator: (String? value) {
                                                    if (value!.isEmpty) {
                                                      return 'Please enter a password';
                                                    }

                                                    return null;
                                                  },
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      foregroundColor: Colors.white,
                                                      backgroundColor: Theme.of(context).primaryColor,
                                                    ),
                                                    child: const Text("Sign in"),
                                                    onPressed: () async {
                                                      if (_signInFormKey.currentState!.validate()) {
                                                        _signInFormKey.currentState!.save();

                                                        signIn(
                                                            context,
                                                            AuthAttempt(
                                                              _signInEmail.text,
                                                              _signInPass.text,
                                                            ), (error) async {
                                                          // ignore: deprecated_member_use
                                                          // ignore: deprecated_member_use
                                                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                          // ignore: deprecated_member_use
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text(error),
                                                              duration: const Duration(seconds: 10),
                                                              action: SnackBarAction(
                                                                label: "Dismiss",
                                                                onPressed: () {
                                                                  // ignore: deprecated_member_use
                                                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                                },
                                                              ),
                                                            ),
                                                          );
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(
                          top: 10,
                          bottom: 80,
                        ),
                        child: SizedBox(
                          height: 60,
                          width: 360,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.transparent,
                            ),
                            child: Text(
                              'Sign up'.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _hidePassword = true;
                              });

                              showDialog(
                                context: context,
                                builder: (context) {
                                  return SimpleDialog(
                                    contentPadding: const EdgeInsets.all(25),
                                    children: [
                                      SingleChildScrollView(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                SizedBox(
                                                  height: 50,
                                                  child: SvgPicture.asset(
                                                    'assets/images/logo/SkillDrillsDark.svg',
                                                    semanticsLabel: 'Skill Drills',
                                                    width: 120,
                                                  ),
                                                ),
                                                const Text(
                                                  'SIGN UP',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Form(
                                              key: _signUpFormKey,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: TextFormField(
                                                      controller: _signUpEmail,
                                                      decoration: const InputDecoration(
                                                        labelText: 'Email',
                                                      ),
                                                      keyboardType: TextInputType.emailAddress,
                                                      validator: (String? value) {
                                                        if (value!.isEmpty) {
                                                          return 'Please enter your email';
                                                        }
                                                        if (!validEmail(value)) {
                                                          return 'Invalid email address';
                                                        }

                                                        return null;
                                                      },
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: TextFormField(
                                                      controller: _signUpPass,
                                                      obscureText: _hidePassword,
                                                      decoration: const InputDecoration(
                                                        labelText: 'Password',
                                                      ),
                                                      keyboardType: TextInputType.visiblePassword,
                                                      validator: (String? value) {
                                                        if (value!.isEmpty) {
                                                          return 'Please enter a password';
                                                        } else if (!validPassword(value)) {
                                                          return 'Please enter a stronger password';
                                                        }

                                                        return null;
                                                      },
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: TextFormField(
                                                      controller: _signUpConfirmPass,
                                                      obscureText: _hidePassword,
                                                      decoration: const InputDecoration(
                                                        labelText: 'Confirm Password',
                                                      ),
                                                      keyboardType: TextInputType.visiblePassword,
                                                      validator: (String? value) {
                                                        if (value!.isEmpty) {
                                                          return 'Please confirm your password';
                                                        } else if (value != _signUpPass.text) {
                                                          return 'Passwords do not match';
                                                        }

                                                        return null;
                                                      },
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          foregroundColor: Colors.white,
                                                          backgroundColor: Theme.of(context).primaryColor,
                                                        ),
                                                        child: const Text("Sign up"),
                                                        onPressed: () async {
                                                          if (_signUpFormKey.currentState!.validate()) {
                                                            _signUpFormKey.currentState!.save();

                                                            signUp(
                                                                context,
                                                                AuthAttempt(
                                                                  _signUpEmail.text,
                                                                  _signUpPass.text,
                                                                ), (error) async {
                                                              // ignore: deprecated_member_use
                                                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                              // ignore: deprecated_member_use
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(error),
                                                                  duration: const Duration(seconds: 10),
                                                                  action: SnackBarAction(
                                                                    label: "Dismiss",
                                                                    onPressed: () {
                                                                      // ignore: deprecated_member_use
                                                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                                    },
                                                                  ),
                                                                ),
                                                              );
                                                            });
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  signUp(BuildContext context, AuthAttempt authAttempt, Function error) async {
    try {
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: authAttempt.email,
        password: authAttempt.password,
      )
          .then((credential) {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop('dialog');

        setState(() {
          _signedIn = true;
        });
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print(e.toString());
        await error('The password provided is too weak');
      } else if (e.code == 'email-already-in-use') {
        print(e.toString());
        await error('An account already exists with that email');
      } else {
        print(e.toString());
        await error('There was an error signing up');
      }
    } catch (e) {
      print(e.toString());
      await error('There was an error signing up');
    }
  }

  signIn(BuildContext context, AuthAttempt authAttempt, Function error) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: authAttempt.email, password: authAttempt.password).then((credential) {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop('dialog');

        setState(() {
          _signedIn = true;
        });
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print(e.toString());
        await error('No user found for that email');
      } else if (e.code == 'wrong-password') {
        print(e.toString());
        await error('Wrong password');
      } else {
        print(e.toString());
        await error('There was an error signing in');
      }
    } catch (e) {
      print(e.toString());
      await error('There was an error signing in');
    }
  }

  socialSignIn(BuildContext context, String provider, Function error) async {
    if (provider == 'google') {
      signInWithGoogle().then((googleSignInAccount) {
        setState(() {
          _signedIn = true;
        });
      }).catchError((e) async {
        var message = "There was an error signing in with Google";
        // if (e.code == "user-disabled") {
        //   message = "Your account has been disabled by the administrator";
        // } else if (e.code == "account-exists-with-different-credential") {
        //   message = "An account already exists with the same email address but different sign-in credentials. Please try signing in a different way";
        // }

        print(e);
        await error(message);
      });
    }
  }
}

class AuthAttempt {
  final String email;
  final String password;

  AuthAttempt(this.email, this.password);
}
