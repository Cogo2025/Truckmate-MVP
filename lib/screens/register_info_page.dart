import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/driver_main_navigation.dart';
import 'package:truckmate_app/screens/owner/owner_main_navigation.dart';
import 'package:google_fonts/google_fonts.dart'; // For consistent Poppins font

class RegisterSelectionPage extends StatefulWidget {
  const RegisterSelectionPage({super.key});

  @override
  State<RegisterSelectionPage> createState() => _RegisterSelectionPageState();
}

class _RegisterSelectionPageState extends State<RegisterSelectionPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedRole = 'driver';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
  }

  Future<void> submitRegistration() async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken(true);
    if (idToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID token missing.")));
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty || _selectedRole.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fill all fields")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.googleLogin),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idToken": idToken,
          "name": name,
          "phone": phone,
          "role": _selectedRole,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final role = data["user"]["role"];
        if (role == "driver") {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DriverMainNavigation()));
        } else if (role == "owner") {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OwnerMainNavigation()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid role.")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["error"] ?? "Registration failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: Colors.white,
        textTheme: TextTheme(
          headlineLarge: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          bodyLarge: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
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
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 4,
            textStyle: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        radioTheme: RadioThemeData(
          fillColor: MaterialStateProperty.all(Colors.blueAccent),
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center, // Changed to center for overall alignment
                      children: [
                        const SizedBox(height: 20),
                        FadeInAnimation(
                          child: Text(
                            "Complete Your Registration",
                            textAlign: TextAlign.center, // Explicitly center the title text
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
                        const SizedBox(height: 30),
                        FadeInAnimation(
                          delay: const Duration(milliseconds: 300),
                          child: Text(
                            "Name",
                            textAlign: TextAlign.center, // Center the label
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeInAnimation(
                          delay: const Duration(milliseconds: 400),
                          child: TextField(
                            controller: _nameController,
                            textAlign: TextAlign.center, // Center input text
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeInAnimation(
                          delay: const Duration(milliseconds: 500),
                          child: Text(
                            "Phone",
                            textAlign: TextAlign.center, // Center the label
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeInAnimation(
                          delay: const Duration(milliseconds: 600),
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textAlign: TextAlign.center, // Center input text
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeInAnimation(
                          delay: const Duration(milliseconds: 700),
                          child: Text(
                            "Role",
                            textAlign: TextAlign.center, // Center the label
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeInAnimation(
                          delay: const Duration(milliseconds: 800),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center, // Center the radio buttons row
                            children: [
                              Radio<String>(
                                value: 'driver',
                                groupValue: _selectedRole,
                                onChanged: (value) {
                                  setState(() => _selectedRole = value!);
                                },
                              ),
                              Text(
                                "Driver",
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(width: 20),
                              Radio<String>(
                                value: 'owner',
                                groupValue: _selectedRole,
                                onChanged: (value) {
                                  setState(() => _selectedRole = value!);
                                },
                              ),
                              Text(
                                "Owner",
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        SlideInAnimation(
                          child: Center(
                            child: ElevatedButton.icon(
                              onPressed: submitRegistration,
                              icon: const Icon(
                                Icons.check_rounded, // Attractive Material icon for submission
                                size: 24,
                              ),
                              label: const Text("Submit"),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
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
