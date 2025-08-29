import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/driver_main_navigation.dart';
import 'package:truckmate_app/screens/owner/owner_main_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterSelectionPage extends StatefulWidget {
  const RegisterSelectionPage({super.key});

  @override
  State<RegisterSelectionPage> createState() => _RegisterSelectionPageState();
}

class _RegisterSelectionPageState extends State<RegisterSelectionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedRole = 'driver';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
    
    // Debug current user state
    print('🔐 Current Firebase User: ${user?.uid}');
    print('🔐 Display Name: ${user?.displayName}');
    print('🔐 Email: ${user?.email}');
  }

  // Enhanced validation method
  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    
    if (name.isEmpty) {
      _showError('Name is required');
      return false;
    }
    
    if (name.length < 2) {
      _showError('Name must be at least 2 characters');
      return false;
    }
    
    if (phone.isEmpty) {
      _showError('Phone number is required');
      return false;
    }
    
    if (phone.length < 10) {
      _showError('Phone number must be at least 10 digits');
      return false;
    }
    
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> submitRegistration() async {
    if (!_validateForm()) return;

    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      _showError('No user is signed in. Please sign in first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final idToken = await user.getIdToken(true);
      
      if (idToken == null || idToken.isEmpty) {
        _showError('Failed to get authentication token');
        return;
      }

      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      // *** ENHANCED DEBUGGING ***
      print('🔐 Debug - Firebase User: ${user.uid}');
      print('🔐 Debug - ID Token length: ${idToken.length}');
      print('🔐 Debug - Name: "$name"');
      print('🔐 Debug - Phone: "$phone"');
      print('🔐 Debug - Role: "$_selectedRole"');

      final requestBody = {
        "idToken": idToken,
        "name": name,
        "phone": phone,
        "role": _selectedRole,
      };

      print('📤 Request Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(ApiConfig.googleLogin),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception("Request timeout - please try again");
        },
      );

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = data["user"];
        final role = user["role"];

        // Save user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(user));

        _showSuccess('Registration successful!');

        // Wait a moment before navigation
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate based on role
        if (role == "driver") {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const DriverMainNavigation())
          );
        } else if (role == "owner") {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const OwnerMainNavigation())
          );
        } else {
          _showError("Invalid role received from server");
        }
      } else {
        final error = data["error"] ?? "Registration failed";
        final details = data["details"] ?? "";
        _showError("$error${details.isNotEmpty ? ': $details' : ''}");
      }

    } catch (e) {
      print('❌ Registration Error: $e');
      _showError("Registration failed: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Completing registration...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          
                          FadeInAnimation(
                            child: Text(
                              "Complete Your Registration",
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
                          
                          const SizedBox(height: 30),
                          
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 300),
                            child: Text(
                              "Name",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 400),
                            child: TextFormField(
                              controller: _nameController,
                              textAlign: TextAlign.center,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Name is required';
                                }
                                if (value.trim().length < 2) {
                                  return 'Name must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 500),
                            child: Text(
                              "Phone",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 600),
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textAlign: TextAlign.center,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Phone number is required';
                                }
                                if (value.trim().length < 10) {
                                  return 'Phone number must be at least 10 digits';
                                }
                                return null;
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 700),
                            child: Text(
                              "Role",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 800),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                  Icons.check_rounded,
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
      ),
    );
  }
}

// Keep your existing animation classes...
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
