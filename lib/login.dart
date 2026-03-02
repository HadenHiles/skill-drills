// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:skilldrills/services/auth.dart';
import 'package:skilldrills/theme/theme.dart';
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
  // State variables
  final bool _signedIn = FirebaseAuth.instance.currentUser != null;

  @override
  Widget build(BuildContext context) {
    //If user is signed in
    if (_signedIn) {
      return const Nav();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0186B5),
              SkillDrillsColors.brandBlue,
              Color(0xFF01C4A1),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),
                      SizedBox(
                        height: 120,
                        child: SvgPicture.asset(
                          'assets/images/logo/SkillDrills.svg',
                          semanticsLabel: 'Skill Drills',
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Keep track of your\nimprovements in any skill',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Choplin',
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          height: 1.4,
                        ),
                      ),
                      const Spacer(flex: 3),
                      // ── Action buttons ──────────────────────────────
                      SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: SignInButton(
                          Buttons.Google,
                          onPressed: () async {
                            try {
                              await signInWithGoogle();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const Nav()),
                                  (route) => false,
                                );
                              }
                            } catch (e) {
                              print(e);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text("There was an error signing in with Google"),
                                    duration: const Duration(seconds: 10),
                                    action: SnackBarAction(
                                      label: "Dismiss",
                                      onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Divider row
                      Row(
                        children: [
                          Expanded(child: Container(height: 1, color: Colors.white30)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          Expanded(child: Container(height: 1, color: Colors.white30)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Sign in with Email
                      SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: SkillDrillsColors.brandBlue,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: SkillDrillsRadius.smBorderRadius,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => const _SignInScreen(),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/images/icons/icon.svg',
                                semanticsLabel: 'Skill Drills',
                                height: 24,
                                width: 24,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Sign in with Email',
                                style: TextStyle(
                                  fontFamily: 'Choplin',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Sign up link
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => const _SignUpScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Don't have an account? Sign up",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sign In Screen
// ---------------------------------------------------------------------------

class _SignInScreen extends StatefulWidget {
  const _SignInScreen();

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: SkillDrillsTheme.lightTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'SIGN IN',
            style: TextStyle(
              fontFamily: 'Choplin',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: SkillDrillsColors.lightOnSurface,
              letterSpacing: 0.5,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  height: 48,
                  child: SvgPicture.asset(
                    'assets/images/logo/SkillDrillsDark.svg',
                    semanticsLabel: 'Skill Drills',
                    width: 130,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value!.isEmpty) return 'Please enter your email';
                        if (!validEmail(value)) return 'Invalid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pass,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      keyboardType: TextInputType.visiblePassword,
                      validator: (value) {
                        if (value!.isEmpty) return 'Please enter a password';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          await _signIn();
                        }
                      },
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text,
        password: _pass.text,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Nav()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      print(e);
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect email or password';
      } else {
        message = 'There was an error signing in';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('There was an error signing in')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Sign Up Screen
// ---------------------------------------------------------------------------

class _SignUpScreen extends StatefulWidget {
  const _SignUpScreen();

  @override
  State<_SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<_SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirmPass = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: SkillDrillsTheme.lightTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'CREATE ACCOUNT',
            style: TextStyle(
              fontFamily: 'Choplin',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: SkillDrillsColors.lightOnSurface,
              letterSpacing: 0.5,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  height: 48,
                  child: SvgPicture.asset(
                    'assets/images/logo/SkillDrillsDark.svg',
                    semanticsLabel: 'Skill Drills',
                    width: 130,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value!.isEmpty) return 'Please enter your email';
                        if (!validEmail(value)) return 'Invalid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pass,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      keyboardType: TextInputType.visiblePassword,
                      validator: (value) {
                        if (value!.isEmpty) return 'Please enter a password';
                        if (!validPassword(value)) {
                          return 'Please enter a stronger password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPass,
                      obscureText: _hidePassword,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      keyboardType: TextInputType.visiblePassword,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _pass.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          await _signUp();
                        }
                      },
                      child: const Text('Create Account'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signUp() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text,
        password: _pass.text,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Nav()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      print(e);
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists with that email';
      } else {
        message = 'There was an error signing up';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('There was an error signing up')),
        );
      }
    }
  }
}
