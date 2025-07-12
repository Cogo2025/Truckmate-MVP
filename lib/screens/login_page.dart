import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate_app/screens/driver/driver_main_navigation.dart';
import 'package:truckmate_app/screens/owner/owner_main_navigation.dart';
import 'register_info_page.dart';
import 'driver/driver_dashboard.dart';
import 'owner/owner_dashboard.dart';
import 'package:truckmate_app/api_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _isRegisterMode = false;

  Future<void> signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user;

      final idToken = await firebaseUser!.getIdToken(true);
      final prefs = await SharedPreferences.getInstance();

      if (idToken != null) {
  await prefs.setString('authToken', idToken);
} else {
  throw Exception("Failed to get Firebase ID Token");
}

      final response = await http.post(
  Uri.parse(ApiConfig.googleLogin),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idToken": idToken,
          "name": firebaseUser.displayName ?? "",
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = data["user"];
        final role = user["role"];

        if (_isRegisterMode || role == null || role.isEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RegisterSelectionPage()),
          );
        } else if (role == "driver") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverMainNavigation()),
          );
        } else if (role == "owner") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OwnerMainNavigation()),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Unknown role")));
        }
      } else {
        final error = data["error"] ?? "Login failed";
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF7E00), Color(0xFFFFA726), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  FadeInAnimation(
                    child: Text(
                      "Login to TruckMate",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black26,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 300),
                    child: Text(
                      "Sign in to connect with drivers and owners",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _isLoading
                      ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                      : SlideInAnimation(
                        child: ElevatedButton.icon(
                          onPressed: signInWithGoogle,
                          icon: Image.asset(
                            'assets/google_logo.png',
                            height: 24,
                          ),
                          label: const Text("Continue with Google"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 16,
                            ),
                            elevation: 8,
                            shadowColor: Colors.black38,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            side: const BorderSide(
                              color: Colors.grey,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 20),
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 600),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _isRegisterMode = true);
                        signInWithGoogle();
                      },
                      child: const Text(
                        "New user? Register here",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Animation Widgets
class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const FadeInAnimation({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 0),
  });

  @override
  _FadeInAnimationState createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }
}

class SlideInAnimation extends StatefulWidget {
  final Widget child;

  const SlideInAnimation({super.key, required this.child});

  @override
  _SlideInAnimationState createState() => _SlideInAnimationState();
}

class _SlideInAnimationState extends State<SlideInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _animation, child: widget.child);
  }
}
