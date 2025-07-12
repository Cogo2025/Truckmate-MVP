import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:truckmate_app/api_config.dart';
import 'driver_profile_setup.dart';

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
      // Profile doesn't exist yet
      setState(() {
        userData = jsonDecode(userResponse.body);
        profileData = {};
        isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Profile"),
        automaticallyImplyLeading: false,
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
                      "Driver Information",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    _infoTile(
                      "Experience",
                      profileData["experience"] ?? "N/A",
                    ),
                    _infoTile(
                      "License Type",
                      profileData["licenseType"] ?? "N/A",
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