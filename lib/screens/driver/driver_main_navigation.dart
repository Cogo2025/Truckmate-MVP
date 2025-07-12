import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'driver_dashboard.dart';
import 'driver_profile_page.dart';
import 'driver_jobs_page.dart';
import 'driver_likes_page.dart';

import '../../api_config.dart';

class DriverMainNavigation extends StatefulWidget {
  final int initialTabIndex;
  const DriverMainNavigation({super.key, this.initialTabIndex = 0});

  @override
  State<DriverMainNavigation> createState() => _DriverMainNavigationState();
}

class _DriverMainNavigationState extends State<DriverMainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DriverDashboard(),
    const DriverProfilePage(),
    const DriverJobsPage(),
    const DriverLikesPage(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
  }

  void _onItemTapped(int index) {
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
                    icon: Icon(Icons.work_outline, size: 26),
                    label: "Jobs",
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