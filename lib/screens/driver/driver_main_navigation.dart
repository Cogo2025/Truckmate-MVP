import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'driver_dashboard.dart';
import 'driver_profile_page.dart';
import 'driver_jobs_page.dart';
import 'driver_likes_page.dart';
import 'driver_profile_setup.dart';

import '../../api_config.dart';

class DriverMainNavigation extends StatefulWidget {
  final int initialTabIndex;
  const DriverMainNavigation({super.key, this.initialTabIndex = 0});

  @override
  State<DriverMainNavigation> createState() => _DriverMainNavigationState();
}

class _DriverMainNavigationState extends State<DriverMainNavigation> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _checkingProfile = false;
  Map<String, dynamic>? _userData;
  final GlobalKey<DriverLikesPageState> _likesPageKey = GlobalKey<DriverLikesPageState>();
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  // Enhanced navigation items with modern icons and colors
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
      icon: Icons.work_outline_rounded,
      activeIcon: Icons.work_rounded,
      label: "Jobs",
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

  List<Widget> get _pages => [
    const DriverDashboard(),
    const DriverProfilePage(),
    const DriverJobsPage(),
    DriverLikesPage(
      key: _likesPageKey,
      onRefresh: () => _likesPageKey.currentState?.refreshLikedJobs(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _loadUserData();
    
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

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.authMe),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          _userData = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
    }
  }

  Future<bool> _checkProfileCompletion() async {
    if (_checkingProfile) return true;
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) return false;

    setState(() => _checkingProfile = true);
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.driverProfile}/check-completion'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['completed'] == false && _userData != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverProfileSetupPage(userData: _userData!),
            ),
          );
          return _checkProfileCompletion();
        }
        return data['completed'] == true;
      }
      return false;
    } catch (e) {
      debugPrint("Error checking profile completion: $e");
      return false;
    } finally {
      setState(() => _checkingProfile = false);
    }
  }

  void _onItemTapped(int index) async {
    if (index == 1 || index == 2) {
      final isComplete = await _checkProfileCompletion();
      if (!isComplete) return;
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
    
    // Refresh likes page when navigating to it OR when already on it and tapping again
    if (index == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _likesPageKey.currentState?.refreshLikedJobs();
      });
    }
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
                        margin: const EdgeInsets.symmetric(horizontal: 4),
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