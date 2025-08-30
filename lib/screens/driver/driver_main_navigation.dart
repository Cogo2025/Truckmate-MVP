// screens/driver/driver_main_navigation.dart - Enhanced version with filter fix

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
import 'api_utils.dart';


class DriverMainNavigation extends StatefulWidget {
  final int initialTabIndex;
  final String? filterByVehicle;

  const DriverMainNavigation({
    super.key,
    this.initialTabIndex = 0,
    this.filterByVehicle,
  });

  @override
  State<DriverMainNavigation> createState() => _DriverMainNavigationState();
}

class _DriverMainNavigationState extends State<DriverMainNavigation>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _checkingProfile = false;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _verificationStatus;
  final GlobalKey<DriverLikesPageState> _likesPageKey = GlobalKey();

  // Store filter state
  String? _currentVehicleFilter;
  bool _hasAppliedInitialFilter = false;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  // Store pages as instance variables but handle Jobs page dynamically
  late final List<Widget> _staticPages;

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

  // Initialize static pages (excluding Jobs page)
  _staticPages = [
    const DriverDashboard(),
    DriverLikesPage(
      key: _likesPageKey,
      onRefresh: () => _likesPageKey.currentState?.refreshLikedJobs(),
    ),
    Container(), // Placeholder for Jobs page - will be replaced dynamically
    DriverProfilePage(userData: _userData ?? {}), // ✅ FIXED - pass userData
  ];

  // Set initial filter if provided and navigating directly to Jobs page
  if (widget.filterByVehicle != null && widget.initialTabIndex == 2) {
    _currentVehicleFilter = widget.filterByVehicle;
    _hasAppliedInitialFilter = true;
  }

  _loadUserData();
  _initializeAnimations();
}

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  // Create Jobs page dynamically based on current filter state
  Widget _createJobsPage() {
    String? filterToApply;

    // Only apply filter if:
    // 1. Coming from dashboard with initial filter AND haven't applied it yet
    // 2. OR if there's a current vehicle filter set
    if (!_hasAppliedInitialFilter &&
        widget.filterByVehicle != null &&
        _selectedIndex == 2) {
      filterToApply = widget.filterByVehicle;
      _hasAppliedInitialFilter = true;
    } else if (_selectedIndex == 2 && _currentVehicleFilter != null) {
      filterToApply = _currentVehicleFilter;
    }

    return DriverJobsPage(
      key: ValueKey(
        'jobs_${filterToApply ?? 'all'}',
      ), // Unique key for each filter state
      filterByVehicle: filterToApply,
    );
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
        await _loadVerificationStatus();
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
    }
  }

  Future<void> _loadVerificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) return;

    try {
      final result = await ApiUtils.getVerificationStatus(token, context);
      if (result['success']) {
        setState(() {
          _verificationStatus = result['data'];
        });
      }
    } catch (e) {
      debugPrint("Error loading verification status: $e");
    }
  }

  void _showVerificationStatusDialog() {
    if (_verificationStatus == null) return;

    final status = _verificationStatus!['verificationStatus'];
    String title = 'Verification Required';
    String content = 'Your profile needs verification to access this feature.';
    List<Widget> actions = [];

    switch (status) {
      case 'pending':
        title = 'Verification Pending';
        content =
            'Your profile is being reviewed by our team. Please wait for approval.';
        actions = [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ];
        break;
      case 'rejected':
        title = 'Verification Rejected';
        content =
            'Your profile was rejected. Please update your information and resubmit.';
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _selectedIndex = 3);
            },
            child: const Text('Update Profile'),
          ),
        ];
        break;
      // Around line 240, update this part:
case 'no_profile':
  title = 'Complete Your Profile';
  content = 'Please complete your driver profile to access jobs and other features.';
  actions = [
    ElevatedButton(
      onPressed: () {
        Navigator.of(context).pop();
        if (_userData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverProfileSetupPage(
                userData: _userData! as Map<String, dynamic>, // ✅ This is correct
              ),
            ),
          );
        }
      },
      child: const Text('Complete Profile'),
    ),
  ];
  break;
      default:
        actions = [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ];
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: actions,
          ),
    );
  }

  void _refreshDashboard() {
    if (_selectedIndex == 0) {
      setState(() {});
    }
  }

  void _onItemTapped(int index) async {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    _rippleController.forward().then((_) {
      _rippleController.reset();
    });

    // Clear vehicle filter when navigating to Jobs page from bottom nav
    // (unless it's the initial navigation with a filter)
    if (index == 2 && _selectedIndex != 2) {
      // Only clear filter if not coming from dashboard initially
      if (_hasAppliedInitialFilter) {
        _currentVehicleFilter = null;
      }
    }

    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _likesPageKey.currentState?.refreshLikedJobs();
      });
    }

    if (index == 0) {
      _refreshDashboard();
    }
  }

  Widget _buildVerificationStatusIndicator() {
    if (_verificationStatus == null) return const SizedBox.shrink();

    final status = _verificationStatus!['verificationStatus'];
    Color indicatorColor;
    IconData indicatorIcon;
    String statusText;

    switch (status) {
      case 'approved':
        indicatorColor = Colors.green;
        indicatorIcon = Icons.verified;
        statusText = 'Verified';
        break;
      case 'pending':
        indicatorColor = Colors.orange;
        indicatorIcon = Icons.pending;
        statusText = 'Pending';
        break;
      case 'rejected':
        indicatorColor = Colors.red;
        indicatorIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      default:
        indicatorColor = Colors.grey;
        indicatorIcon = Icons.info;
        statusText = 'Incomplete';
    }

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        border: Border.all(color: indicatorColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(indicatorIcon, size: 16, color: indicatorColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: indicatorColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return false;
        } else {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Are you quitting?'),
                  content: const Text('Do you want to exit the app?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('No'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Yes'),
                    ),
                  ],
                ),
          );
          return shouldExit == true;
        }
      },
      child: Scaffold(
        appBar:
            _selectedIndex != 0 &&
                    _selectedIndex !=
                        2 // Exclude both Dashboard (0) and Jobs (2)
                ? AppBar(
                  title: Text(_navigationItems[_selectedIndex].label),
                  automaticallyImplyLeading: false,
                  actions: [_buildVerificationStatusIndicator()],
                )
                : null,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _staticPages[0], // Dashboard
            _staticPages[1], // Likes
            _createJobsPage(), // Jobs - created dynamically
            _staticPages[3], // Profile
          ],
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
                  final needsVerification = false;
                  final isVerified = true;

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
                                AnimatedBuilder(
                                  animation: _scaleAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale:
                                          isSelected
                                              ? _scaleAnimation.value
                                              : 1.0,
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              isSelected
                                                  ? Colors.white.withOpacity(
                                                    0.2,
                                                  )
                                                  : Colors.transparent,
                                        ),
                                        child: Icon(
                                          isSelected
                                              ? item.activeIcon
                                              : item.icon,
                                          size: 22,
                                          color:
                                              isSelected
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
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : (needsVerification && !isVerified)
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
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
