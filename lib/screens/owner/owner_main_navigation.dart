import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'owner_dashboard.dart';
import 'owner_profile_page.dart';
import 'owner_post_job.dart';
import 'owner_profile_setup.dart';
import 'owner_drivers_page.dart';
import 'owner_likes_page.dart';

import '../../api_config.dart';

class OwnerMainNavigation extends StatefulWidget {
  final int initialTabIndex;
  const OwnerMainNavigation({super.key, this.initialTabIndex = 0});

  @override
  State<OwnerMainNavigation> createState() => _OwnerMainNavigationState();
}

class _OwnerMainNavigationState extends State<OwnerMainNavigation> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const OwnerDashboard(),
    const OwnerProfilePage(),
    const OwnerPostJobPage(),
    const OwnerDriversPage(),
    const OwnerLikesPage(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
  }

  Future<bool> _checkProfileStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You need to log in again.")),
        );
      }
      return false;
    }

    try {
      print("🔍 Checking profile status...");
      print("Token: ${token.substring(0, 20)}...");
      print("URL: ${ApiConfig.ownerProfile}");

      final res = await http.get(
        Uri.parse(ApiConfig.ownerProfile),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ).timeout(const Duration(seconds: 15));

      print("📥 Profile check response: ${res.statusCode}");
      print("📥 Response body: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        print("📊 Profile data: $data");
        
        // Check if profile is completed
        final completed = data['companyInfoCompleted'] == true;
        print("✅ Profile completed: $completed");
        
        return completed;
      } else if (res.statusCode == 401) {
        // Token expired or invalid
        await prefs.remove('authToken');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Session expired. Please log in again.")),
          );
        }
        return false;
      } else {
        print("❌ Profile check failed with status: ${res.statusCode}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to verify profile status. Status: ${res.statusCode}")),
          );
        }
        return false;
      }
    } catch (e) {
      print("❌ Profile check exception: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Network error: $e")),
        );
      }
      return false;
    }
  }

  void _onItemTapped(int index) async {
    // For Profile tab (index 1) and Post Job tab (index 2), check profile status
    if (index == 1 || index == 2) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final isProfileCompleted = await _checkProfileStatus();
      
      // Hide loading indicator
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!isProfileCompleted) {
        // Navigate to profile setup
        final completedNow = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OwnerProfileSetupPage()),
        );

        // If profile setup was not completed, don't change tab
        if (completedNow != true) {
          return;
        }
      }
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
              child: BottomNavigationBar(
                backgroundColor: Colors.transparent,
                type: BottomNavigationBarType.fixed,
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                selectedItemColor: Colors.deepOrange,
                unselectedItemColor: Colors.grey,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 11,
                ),
                showUnselectedLabels: true,
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home, size: 26),
                    label: "Home",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline, size: 26),
                    label: "Profile",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.post_add, size: 28),
                    label: "Post",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.people_outline, size: 26),
                    label: "Drivers",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.favorite_border, size: 26),
                    label: "Likes",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}