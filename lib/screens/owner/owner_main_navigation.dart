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
  final bool isFromDashboard;

  const OwnerMainNavigation({
    super.key,
    this.initialTabIndex = 0,
    this.selectedTruckType,
    this.isFromDashboard = false,
  });

  @override
  State createState() => _OwnerMainNavigationState();
}

class _OwnerMainNavigationState extends State<OwnerMainNavigation> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  late AnimationController _animationController;
 
  late AnimationController _rippleController;
  late Animation<double> _scaleAnimation;
late Animation<double> _rippleAnimation;

  bool _isLoading = true;
  bool _profileCompleted = false;
  Map<String, dynamic>? _registerData;

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
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _loadProfileStatus();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _rippleAnimation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) {
      setState(() {
        _profileCompleted = false;
        _isLoading = false;
        _pages = _buildPages(false, {});
      });
      return;
    }

    try {
      // Load user data first
      final userRes = await http.get(
        Uri.parse(ApiConfig.authMe),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 10));

      // Try to load profile data
      final profileRes = await http.get(
        Uri.parse(ApiConfig.ownerProfile),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 10));

      Map<String, dynamic> userData = {};
      Map<String, dynamic> profileData = {};
      bool completed = false;

      if (userRes.statusCode == 200) {
        userData = jsonDecode(userRes.body);
      }

      if (profileRes.statusCode == 200) {
        profileData = jsonDecode(profileRes.body);
        completed = profileData['companyName'] != null && 
                   profileData['companyName'].toString().isNotEmpty;
      }

      // Combine user and profile data for register info
      final registerInfo = {
        'name': userData['name'] ?? '',
        'email': userData['email'] ?? '',
        'phone': userData['phone'] ?? '',
        'photoUrl': userData['photoUrl'] ?? '',
      };

      setState(() {
        _profileCompleted = completed;
        _registerData = registerInfo;
        _pages = _buildPages(completed, registerInfo);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _profileCompleted = false;
        _registerData = {};
        _pages = _buildPages(false, {});
        _isLoading = false;
      });
    }
  }

  List<Widget> _buildPages(bool profileCompleted, Map<String, dynamic>? registerInfo) {
    return [
      OwnerDashboard(newUser: !profileCompleted),
      const OwnerLikesPage(),
      const OwnerPostJobPage(),
      OwnerDriversPage(
        initialTruckTypeFilter: widget.selectedTruckType,
        isFromDashboard: widget.isFromDashboard,
      ),
      OwnerProfilePage(
        registerInfo: registerInfo,
        profileCompleted: profileCompleted,
      ),
    ];
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
      final res = await http.get(
        Uri.parse(ApiConfig.ownerProfile),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ).timeout(const Duration(seconds: 15));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['companyName'] != null && data['companyName'].toString().isNotEmpty;
      } else if (res.statusCode == 401) {
        await prefs.remove('authToken');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Session expired. Please log in again.")),
          );
        }
        return false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

void _onItemTapped(int index) async {
  if (_isLoading) return;

  // Only check profile completion for Post tab (not Profile tab anymore)
  if (index == 2 && !_profileCompleted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final completed = await _checkProfileStatus();
    if (mounted) Navigator.of(context).pop();

    if (!completed) {
      final updated = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OwnerProfileSetupPage()),
      );
      if (updated == true) {
        await _loadProfileStatus(); // Reload profile status
      }
      if (updated != true) return;
    }
  }

  setState(() {
    _selectedIndex = index;
  });

  // Fixed lines - add underscore parameter to accept the callback parameter:
  _animationController.forward().then((_) => _animationController.reverse());
  _rippleController.forward().then((_) => _rippleController.reset());
}


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
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
                                if (isSelected)
                                  AnimatedBuilder(
                                    animation: _rippleAnimation,
                                    builder: (context, child) {
                                      return Container(
                                        width: (40 * _rippleAnimation.value).toDouble(),
height: (40 * _rippleAnimation.value).toDouble(),

                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(
                                            0.3 * (1 - _rippleAnimation.value),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
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
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.w500,
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