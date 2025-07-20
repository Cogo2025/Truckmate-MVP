import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/login_page.dart';
import 'driver_profile_setup.dart';
import 'edit_driver_profile_page.dart'; // Add this import

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  bool isLoading = true;
  Map<String, dynamic> userData = {};
  Map<String, dynamic> profileData = {};
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchDriverProfile();
  }
Future<void> _updateAvailability(bool isAvailable) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('authToken');
  
  if (token == null) return;

  try {
    final response = await http.patch(
      Uri.parse(ApiConfig.updateAvailability),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "isAvailable": isAvailable,
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        userData['isAvailable'] = isAvailable;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAvailable 
              ? "You're now available for jobs" 
              : "You're not available for jobs"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to update availability")),
    );
    // Revert the switch if the request fails
    setState(() {
      userData['isAvailable'] = !isAvailable;
    });
  }
}
  Future<void> fetchDriverProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) {
      setState(() {
        isLoading = false;
        errorMessage = "Token missing. Please log in.";
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      });
      return;
    }

    try {
      // First get user data
      final userResponse = await http.get(
        Uri.parse(ApiConfig.authMe),
        headers: {"Authorization": "Bearer $token"},
      );

      if (userResponse.statusCode != 200) {
        throw Exception("Failed to fetch user data: ${userResponse.statusCode}");
      }

      // Then get profile data
      final profileResponse = await http.get(
        Uri.parse(ApiConfig.driverProfile),
        headers: {"Authorization": "Bearer $token"},
      );

      if (profileResponse.statusCode == 200) {
        setState(() {
          userData = jsonDecode(userResponse.body);
          profileData = jsonDecode(profileResponse.body);
          isLoading = false;
        });
      } else if (profileResponse.statusCode == 404) {
        // Profile doesn't exist yet - redirect to setup
        setState(() {
          userData = jsonDecode(userResponse.body);
          isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DriverProfileSetupPage(userData: userData),
            ),
          );
        });
      } else {
        throw Exception("Failed to fetch profile: ${profileResponse.statusCode}");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error: ${e.toString()}";
      });
      debugPrint("Profile fetch error: $e");
    }
  }

  // Add this new method to navigate to edit profile
  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDriverProfilePage(
          profileData: profileData,
          userData: userData,
        ),
      ),
    ).then((_) {
      // Refresh profile data when returning from edit page
      fetchDriverProfile();
    });
  }

  Widget _buildProfileAvatar() {
    // Priority: Profile photo from driver profile > Google photo > Default icon
    String? profilePhotoUrl = profileData["profilePhoto"];
    String? googlePhotoUrl = userData['photoUrl'];
    
    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[300],
        child: ClipOval(
          child: Image.network(
            profilePhotoUrl,
            height: 120,
            width: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to Google photo if profile photo fails to load
              if (googlePhotoUrl != null && googlePhotoUrl.isNotEmpty) {
                return Image.network(
                  googlePhotoUrl,
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.person, size: 60, color: Colors.grey);
                  },
                );
              }
              return const Icon(Icons.person, size: 60, color: Colors.grey);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
          ),
        ),
      );
    } else if (googlePhotoUrl != null && googlePhotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[300],
        child: ClipOval(
          child: Image.network(
            googlePhotoUrl,
            height: 120,
            width: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.person, size: 60, color: Colors.grey);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
          ),
        ),
      );
    } else {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.person, size: 60, color: Colors.grey),
      );
    }
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        "$label: $value",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Divider(),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _launchTutorial() async {
    final Uri url = Uri.parse('https://youtube.com');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _logout() async {
    // Show confirmation dialog with enhanced UI
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text(
              "Logout",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Are you sure you want to logout?",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              "You will need to sign in again to access your account.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Logout",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    // If user confirmed logout
    if (shouldLogout == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      "Logging out...",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final prefs = await SharedPreferences.getInstance();
        
        // Clear specific keys to ensure complete logout
        await prefs.remove('authToken');
        await prefs.remove('userRole');
        await prefs.remove('userId');
        await prefs.remove('userName');
        await prefs.remove('userEmail');
        await prefs.remove('userPhone');
        await prefs.remove('ownerProfileCompleted');
        await prefs.remove('driverProfileCompleted');
        await prefs.remove('ownerCompanyName');
        await prefs.remove('driverLicenseType');
        await prefs.remove('userData'); // Also clear userData that LoginPage uses

        // Small delay to show the loading state
        await Future.delayed(const Duration(milliseconds: 500));

        // Close loading dialog FIRST
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
        }

        // Add a small delay to ensure dialog is fully closed
        await Future.delayed(const Duration(milliseconds: 100));

        // Navigate to login screen and clear all previous routes
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false, // Remove all previous routes
          );
        }

        // Show success message with a delay to ensure navigation completed
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      "Logged out successfully",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });

      } catch (e) {
        // Close loading dialog if still open
        if (mounted) {
          Navigator.of(context).pop();
        }
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Logout failed: ${e.toString()}",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: "Retry",
                textColor: Colors.white,
                onPressed: _logout,
              ),
            ),
          );
        }
      }
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Driver Profile"),
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: _navigateToEditProfile,
          tooltip: "Edit Profile",
        ),
      ],
    ),
    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: fetchDriverProfile,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Availability Switch
                  Card(
                    child: SwitchListTile(
                      title: const Text('Available for Jobs'),
                      value: userData['isAvailable'] ?? true,
                      onChanged: (value) => _updateAvailability(value),
                      secondary: const Icon(Icons.work),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Profile Avatar Section
                  Center(
                    child: Column(
                      children: [
                        _buildProfileAvatar(),
                        const SizedBox(height: 8),
                        if (profileData["profilePhoto"] != null && profileData["profilePhoto"].isNotEmpty)
                          const Text(
                            "Profile Photo",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                    
                    _infoSection(
                      "Personal Information",
                      [
                        _infoTile("Name", userData["name"] ?? "N/A"),
                        _infoTile("Email", userData["email"] ?? "N/A"),
                        _infoTile("Phone", userData["phone"] ?? "N/A"),
                        _infoTile("Age", profileData["age"]?.toString() ?? "N/A"),
                        _infoTile("Gender", profileData["gender"] ?? "N/A"),
                        _infoTile("Location", profileData["location"] ?? "N/A"),
                      ],
                    ),
                    
                    _infoSection(
                      "Driver Information",
                      [
                        _infoTile("Experience", "${profileData["experience"] ?? "N/A"} years"),
                        _infoTile("License Type", profileData["licenseType"] ?? "N/A"),
                        _infoTile("License Number", profileData["licenseNumber"] ?? "N/A"),
                        _infoTile(
                          "License Expiry", 
                          profileData["licenseExpiryDate"] != null 
                              ? DateFormat('yyyy-MM-dd').format(DateTime.parse(profileData["licenseExpiryDate"]))
                              : "N/A"
                        ),
                        if (profileData["knownTruckTypes"] != null && profileData["knownTruckTypes"].isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Truck Types:",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: (profileData["knownTruckTypes"] as List)
                                    .map((type) => Chip(
                                          label: Text(type),
                                          backgroundColor: Colors.blue[100],
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                      ],
                    ),
                    
                    // License Photo Section
                    if (profileData["licensePhoto"] != null && profileData["licensePhoto"].isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "License Photo",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  profileData["licensePhoto"],
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      color: Colors.grey[300],
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error, size: 48, color: Colors.red),
                                          SizedBox(height: 8),
                                          Text("Failed to load license photo"),
                                        ],
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 200,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    
                    _infoSection(
                      "Support",
                      [
                        const Text("📞 1800-TRUCKMATE\n📧 support@truckmate.app"),
                      ],
                    ),
                    
                    // Action Buttons
                    ElevatedButton.icon(
                      onPressed: _launchTutorial,
                      icon: const Icon(Icons.play_circle),
                      label: const Text("Watch Tutorial"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text("Logout"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
    );
  }
}