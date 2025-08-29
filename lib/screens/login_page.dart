import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:truckmate_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate_app/screens/driver/driver_main_navigation.dart';
import 'package:truckmate_app/screens/owner/owner_main_navigation.dart';
import 'package:truckmate_app/api_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'register_info_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  
  // *** FIXED: Using your actual Web Client ID from google-services.json ***
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '508947228679-ua5utqeq98tn9k15egvantdjk18qeegs.apps.googleusercontent.com',
    scopes: ['openid', 'email', 'profile'],
  );

  Future<void> signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      print('🔐 Starting Google Sign-In...');
      
      // Clear any previous session
      await _googleSignIn.signOut();

      // Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('❌ User cancelled sign-in');
        setState(() => _isLoading = false);
        return;
      }

      print('📱 Google user: ${googleUser.email}');

      // Get Google authentication
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // *** CRITICAL: Check if idToken is null ***
      if (googleAuth.idToken == null) {
        throw Exception("Failed to get Google ID Token. Please check your Firebase configuration.");
      }

      print('🔑 Got Google auth token: ${googleAuth.idToken!.substring(0, 20)}...');

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      
      if (firebaseUser == null) {
        throw Exception("Firebase user is null after sign in");
      }

      print('🔥 Firebase user: ${firebaseUser.uid}');

      // Get fresh Firebase ID token
      final idToken = await firebaseUser.getIdToken(true);
      
      if (idToken == null || idToken.isEmpty) {
        throw Exception("Failed to get Firebase ID Token");
      }

      // Save the token
      await AuthService.saveAuthToken(idToken);

      print('🔐 Firebase ID Token obtained: ${idToken.substring(0, 20)}...');
      print('🔐 User Display Name: "${firebaseUser.displayName}"');

      // *** TRY LOGIN FIRST (without phone and role) ***
      final loginResponse = await http.post(
        Uri.parse(ApiConfig.googleLogin),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idToken": idToken,
          "name": firebaseUser.displayName ?? "",
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception("Login request timeout - please try again");
        },
      );

      print('📥 Login response: ${loginResponse.statusCode}');
      print('📥 Login body: ${loginResponse.body}');

      final loginData = jsonDecode(loginResponse.body);

      if (loginResponse.statusCode == 200) {
        // User exists and logged in successfully
        final user = loginData["user"];
        final role = user["role"];

        await SharedPreferences.getInstance().then((prefs) {
          prefs.setString('userData', jsonEncode(user));
        });

        _showSuccess("Login successful!");
        
        // Wait a moment before navigation
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (role == "driver") {
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
          _navigateToRegistration();
        }
      } else if (loginResponse.statusCode == 404 && loginData["needsRegistration"] == true) {
        // User doesn't exist - redirect to registration
        print('👤 User not found, redirecting to registration');
        _navigateToRegistration();
      } else {
        // Other error
        final error = loginData["error"] ?? "Login failed";
        final details = loginData["details"] ?? "";
        _showError("$error${details.isNotEmpty ? ': $details' : ''}");
      }

    } catch (e) {
      print("❌ Login error: $e");
      
      // Specific error messages for debugging
      if (e.toString().contains('ApiException: 10')) {
        _showError("Configuration error: Please check SHA fingerprints in Firebase Console and ensure correct Client ID is used.");
      } else if (e.toString().contains('sign_in_failed')) {
        _showError("Google Sign-In failed. Please check your Google Services configuration.");
      } else if (e.toString().contains('network')) {
        _showError("Network error. Please check your internet connection.");
      } else if (e.toString().contains('timeout')) {
        _showError("Request timeout. Please try again.");
      } else {
        _showError("Login error: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToRegistration() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegisterSelectionPage()),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('authToken');
      final userData = prefs.getString('userData');
      
      if (authToken != null && userData != null) {
        final user = jsonDecode(userData);
        final role = user["role"];
        
        if (role != null && role.isNotEmpty && role != "null") {
          if (role == "driver") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DriverMainNavigation()),
            );
          } else if (role == "owner") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OwnerMainNavigation()),
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
          bodyMedium: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.black87,
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
                    "Login to TruckMate",
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
                
                FadeInAnimation(
                  delay: const Duration(milliseconds: 300),
                  child: Text(
                    "Sign in to connect with drivers and owners",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                
                const SizedBox(height: 48),
                
                if (_isLoading)
                  Column(
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Signing in...",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                      ),
                    ],
                  )
                else
                  SlideInAnimation(
                    child: ElevatedButton.icon(
                      onPressed: signInWithGoogle,
                      icon: const Icon(Icons.login_rounded, size: 24),
                      label: const Text("Continue with Google"),
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                FadeInAnimation(
                  delay: const Duration(milliseconds: 600),
                  child: GestureDetector(
                    onTap: signInWithGoogle,
                    child: Text(
                      "New user? Register here",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.blueAccent,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.blueAccent,
                      ),
                    ),
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

// Animation classes
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
