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
  final String? selectedTruckType;
  
  const OwnerMainNavigation({
    super.key, 
    this.initialTabIndex = 0,
    this.selectedTruckType,
  });

  @override
  State<OwnerMainNavigation> createState() => _OwnerMainNavigationState();
}

class _OwnerMainNavigationState extends State<OwnerMainNavigation> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  // Enhanced navigation items with modern icons and colors for owner
  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.dashboard_rounded,
      activeIcon: Icons.dashboard,
      label: "Dashboard",
      color: const Color(0xFF6C63FF),
      gradient: const LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    NavigationItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: "Profile",
      color: const Color(0xFF00BCD4),
      gradient: const LinearGradient(
        colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    NavigationItem(
      icon: Icons.add_circle_outline_rounded,
      activeIcon: Icons.add_circle_rounded,
      label: "Post",
      color: const Color(0xFF9C27B0),
      gradient: const LinearGradient(
        colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    NavigationItem(
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups_rounded,
      label: "Drivers",
      color: const Color(0xFF4CAF50),
      gradient: const LinearGradient(
        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    NavigationItem(
      icon: Icons.favorite_border_rounded,
      activeIcon: Icons.favorite_rounded,
      label: "Likes",
      color: const Color(0xFFFF5722),
      gradient: const LinearGradient(
        colors: [Color(0xFFFF5722), Color(0xFFFF7043)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    
    // Initialize pages with truck type filter if provided
    _pages = [
      const OwnerDashboard(),
      const OwnerProfilePage(),
      const OwnerPostJobPage(),
      OwnerDriversPage(
        initialTruckTypeFilter: widget.selectedTruckType,
      ),
      const OwnerLikesPage(),
    ];
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _rippleController.dispose();
    super.dispose();
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

    // Trigger animations
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    _rippleController.forward().then((_) {
      _rippleController.reset();
    });

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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_navigationItems.length, (index) {
                  final item = _navigationItems[index];
                  final isSelected = _selectedIndex == index;
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onItemTapped(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: isSelected ? item.gradient : null,
                          color: isSelected ? null : Colors.transparent,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Ripple effect
                                if (isSelected)
                                  AnimatedBuilder(
                                    animation: _rippleAnimation,
                                    builder: (context, child) {
                                      return Container(
                                        width: 40 * _rippleAnimation.value,
                                        height: 40 * _rippleAnimation.value,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(
                                            0.3 * (1 - _rippleAnimation.value),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                // Icon with scale animation
                                AnimatedBuilder(
                                  animation: _scaleAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: isSelected ? _scaleAnimation.value : 1.0,
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected 
                                              ? Colors.white.withOpacity(0.2)
                                              : Colors.transparent,
                                        ),
                                        child: Icon(
                                          isSelected ? item.activeIcon : item.icon,
                                          size: 22,
                                          color: isSelected 
                                              ? Colors.white 
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              style: TextStyle(
                                fontSize: isSelected ? 11 : 10,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.grey.shade600,
                              ),
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Navigation Item Model
class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  final LinearGradient gradient;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
    required this.gradient,
  });
}