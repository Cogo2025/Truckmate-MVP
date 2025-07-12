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

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        "$label: $value",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Owner Profile"),
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: userData['photoUrl'] != null
                          ? NetworkImage(userData['photoUrl'])
                          : null,
                      child: userData['photoUrl'] == null
                          ? const Icon(Icons.person, size: 60)
                          : null,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Personal Information",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    _infoTile("Name", userData["name"] ?? "N/A"),
                    _infoTile("Email", userData["email"] ?? "N/A"),
                    _infoTile("Phone", userData["phone"] ?? "N/A"),

                    const SizedBox(height: 20),
                    const Text(
                      "Company Information",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    _infoTile(
                      "Company Name",
                      profileData["companyName"] ?? "N/A",
                    ),
                    _infoTile(
                      "Company Location",
                      profileData["companyLocation"] ?? "N/A",
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      "My Job Posts",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    ElevatedButton.icon(
                      onPressed: _navigateToMyJobs,
                      icon: const Icon(Icons.work),
                      label: const Text("My Job Posts"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Text(
                      "Support",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    const Text("📞 1800-TRUCKMATE\n📧 support@truckmate.app"),

                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _launchTutorial,
                      icon: const Icon(Icons.play_circle),
                      label: const Text("Watch Tutorial"),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text("Logout"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
    );
  }
}