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

  // List of pages to display
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

  void _onItemTapped(int index) async {
    if (index == 2) { // Job Post tab
      // Check if profile is completed before allowing job post
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You need to log in again.")),
        );
        return;
      }

      try {
        final res = await http.get(
          Uri.parse(ApiConfig.ownerProfile),
          headers: {"Authorization": "Bearer $token"},
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final completed = data['companyInfoCompleted'] == true;

          if (!completed) {
            // Navigate to profile setup instead
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OwnerProfileSetupPage()),
            );
            return;
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Network error: $e")),
        );
        return;
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