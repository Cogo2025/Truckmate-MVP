import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'package:truckmate_app/services/auth_service.dart';
import 'package:truckmate_app/screens/driver/driver_main_navigation.dart';
import 'package:truckmate_app/screens/owner/owner_main_navigation.dart';
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  // Check if user is already logged in
  Future<void> _checkExistingLogin(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('authToken');
      final userData = prefs.getString('userData');
      
      if (authToken != null && userData != null) {
        // Get a fresh token before proceeding
        final freshToken = await AuthService.getFreshAuthToken();
        if (freshToken != null) {
          final user = jsonDecode(userData);
          final role = user["role"];
          if (role != null && role.isNotEmpty && role != "null") {
            // Navigate directly to main app if role exists
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => 
                role == "driver" ? const DriverMainNavigation() : const OwnerMainNavigation(),
            )
            );
          }
        }
      }
    } catch (e) {
      print("Error checking existing login: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check for existing login when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingLogin(context);
    });

    return Theme(
      data: ThemeData.light().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: Colors.white,
        textTheme: TextTheme(
          headlineLarge: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          bodyLarge: GoogleFonts.poppins(
            fontSize: 18,
            color: Colors.black54,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 4,
            textStyle: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 1),
                FadeInAnimation(
                  child: Text(
                    "Welcome to TruckMate",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          shadows: [
                            const Shadow(
                              blurRadius: 4.0,
                              color: Colors.black12,
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                  ),
                ),
                const SizedBox(height: 24),
                Lottie.asset(
                  'assets/animations/truck.json',
                  width: 250,
                  height: 250,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
                const SizedBox(height: 16),
                FadeInAnimation(
                  delay: const Duration(milliseconds: 300),
                  child: Text(
                    "Connecting Owners and Drivers",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 48),
                SlideInAnimation(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 24,
                    ),
                    label: const Text("Get Started"),
                  ),
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Rest of the animation widgets remain unchanged...
// Animation Widgets (kept minimal and unchanged for functionality)
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

class _FadeInAnimationState extends State<FadeInAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
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
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}

class SlideInAnimation extends StatefulWidget {
  final Widget child;

  const SlideInAnimation({super.key, required this.child});

  @override
  _SlideInAnimationState createState() => _SlideInAnimationState();
}

class _SlideInAnimationState extends State<SlideInAnimation> with SingleTickerProviderStateMixin {
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
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _animation,
      child: widget.child,
    );
  }
}
