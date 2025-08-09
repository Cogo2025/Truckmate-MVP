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
import 'package:google_fonts/google_fonts.dart'; // For consistent Poppins font
import 'package:truckmate_app/screens/welcome_page.dart';
import 'register_info_page.dart'; // Assuming this is the correct import for RegisterSelectionPage
import 'package:flutter/services.dart'; // Add this import for SystemNavigator

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
    await googleSignIn.signOut(); // Clear any previous session
    
    // Sign in with Google
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    // Get Google authentication
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    
    // Create Firebase credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    // Sign in to Firebase with Google credential
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final firebaseUser = userCredential.user;
    
    if (firebaseUser == null) {
      throw Exception("Firebase user is null after sign in");
    }
    
    // Get fresh ID token (force refresh)
    final idToken = await firebaseUser.getIdToken(true);
    if (idToken!.isEmpty) {
      throw Exception("Failed to get fresh Firebase ID Token");
    }
    
    // Save the fresh token
    await AuthService.saveAuthToken(idToken);
    
    // Call your backend API with the fresh token
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
      await SharedPreferences.getInstance().then((prefs) {
        prefs.setString('userData', jsonEncode(user));
      });
      
      if (_isRegisterMode) {
        _navigateToRegistration();
      } else if (role == null || role.isEmpty || role == "null") {
        _navigateToRegistration();
      } else {
        _navigateToMainApp(role);
      }
    } else {
      final error = data["error"] ?? "Login failed";
      _showError(error);
    }
  } catch (e) {
    print("Login error: $e");
    _showError("Error: ${e.toString()}");
  } finally {
    setState(() => _isLoading = false);
  }
}
  void _navigateToRegistration() {
    setState(() => _isRegisterMode = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegisterSelectionPage()),
    );
  }

  void _navigateToMainApp(String role) {
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
      _showError("Unknown role: $role");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleRegistrationReturn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('authToken');
      if (authToken != null) {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/user/profile'),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $authToken",
          },
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final user = data["user"];
          final role = user["role"];
          if (role != null && role.isNotEmpty && role != "null") {
            await prefs.setString('userData', jsonEncode(user));
            _navigateToMainApp(role);
          } else {
            _showError("Registration incomplete. Please try again.");
          }
        }
      }
    } catch (e) {
      print("Error handling registration return: $e");
      _showError("Error loading user data. Please try signing in again.");
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
          _navigateToMainApp(role);
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
                    icon: const Icon(
                      Icons.login_rounded, // Attractive Material icon for login
                      size: 24,
                    ),
                    label: const Text("Continue with Google"),
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

// Animation Widgets (kept minimal; consider centralizing in a shared file for reuse across pages)
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
