import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/owner/my_posted_jobs_page.dart';

class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key});

  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  bool isLoading = true;
  Map<String, dynamic> userData = {};
  Map<String, dynamic> profileData = {};
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchOwnerProfile();
  }

  Future<void> fetchOwnerProfile() async {
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
      final userRes = await http.get(
        Uri.parse(ApiConfig.authMe),
        headers: {"Authorization": "Bearer $token"},
      );

      final profileRes = await http.get(
        Uri.parse(ApiConfig.ownerProfile),
        headers: {"Authorization": "Bearer $token"},
      );

      if (userRes.statusCode == 200 && profileRes.statusCode == 200) {
        setState(() {
          userData = jsonDecode(userRes.body);
          profileData = jsonDecode(profileRes.body);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to fetch profile.";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error: $e";
      });
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    await fetchOwnerProfile();
  }

  Widget _infoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const Text(": ", style: TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
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

      // Clear all stored data
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
      
      // Optional: Make logout API call if you have one
      /*
      final token = prefs.getString('authToken');
      if (token != null) {
        try {
          await http.post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/logout'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 5));
        } catch (e) {
          print('Logout API call failed: $e');
          // Continue with local logout even if API fails
        }
      }
      */

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
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
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

  void _navigateToMyJobs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyPostedJobsPage(),
      ),
    );
  }

  Widget _buildProfileImage() {
    final photoUrl = profileData['photoUrl'] ?? userData['photoUrl'];
    
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.orange, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                width: 120,
                height: 120,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.orange.shade50,
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.orange,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.orange.shade50,
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                  );
                },
              )
            : Container(
                color: Colors.orange.shade50,
                child: const Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.orange,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Owner Profile"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProfile,
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
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshProfile,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Profile Image Section
                      Center(child: _buildProfileImage()),
                      const SizedBox(height: 20),
                      
                      // Name Display
                      Center(
                        child: Text(
                          userData["name"] ?? "Unknown User",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Personal Information Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Personal Information",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _infoTile("Name", userData["name"] ?? "N/A"),
                            _infoTile("Email", userData["email"] ?? "N/A"),
                            _infoTile("Phone", userData["phone"] ?? "N/A"),
                            _infoTile("Gender", profileData["gender"] ?? "N/A"),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Company Information Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Company Information",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _infoTile(
                              "Company Name",
                              profileData["companyName"] ?? "N/A",
                            ),
                            _infoTile(
                              "Company Location",
                              profileData["companyLocation"] ?? "N/A",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // My Job Posts Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "My Job Posts",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _navigateToMyJobs,
                                icon: const Icon(Icons.work),
                                label: const Text("View My Job Posts"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Support Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Support",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Row(
                              children: [
                                Icon(Icons.phone, color: Colors.orange),
                                SizedBox(width: 8),
                                Text("1800-TRUCKMATE", style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(Icons.email, color: Colors.orange),
                                SizedBox(width: 8),
                                Text("support@truckmate.app", style: TextStyle(fontSize: 16)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _launchTutorial,
                          icon: const Icon(Icons.play_circle),
                          label: const Text("Watch Tutorial"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text("Logout"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}