// screens/driver/driver_main_navigation.dart - Enhanced version
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
  const DriverMainNavigation({super.key, this.initialTabIndex = 0, this.filterByVehicle});

  @override
  State<DriverMainNavigation> createState() => _DriverMainNavigationState();
}

class _DriverMainNavigationState extends State<DriverMainNavigation> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _checkingProfile = false;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _verificationStatus;
  final GlobalKey<DriverLikesPageState> _likesPageKey = GlobalKey<DriverLikesPageState>();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

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

  List<Widget> get _pages => [
    const DriverDashboard(),
    DriverLikesPage(
      key: _likesPageKey,
      onRefresh: () => _likesPageKey.currentState?.refreshLikedJobs(),
    ),
    DriverJobsPage(
      filterByVehicle: _selectedIndex == 2 ? widget.filterByVehicle : null,
    ),
    const DriverProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _loadUserData();
    _initializeAnimations();
  }

  void _initializeAnimations() {
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

        // Load verification status
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
              builder: (context) => DriverProfileSetupPage(userData: _userData! as Map<String, String>),
            ),
          );
          // Reload verification status after profile setup
          await _loadVerificationStatus();
          return await _checkProfileCompletion();
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

  Future<bool> _checkVerificationStatus() async {
    if (_verificationStatus == null) {
      await _loadVerificationStatus();
    }

    if (_verificationStatus == null) return false;

    final canAccess = _verificationStatus!['canAccessJobs'] ?? false;
    
    if (!canAccess) {
      _showVerificationStatusDialog();
      return false;
    }
    
    return true;
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
        content = 'Your profile is being reviewed by our team. Please wait for approval.';
        actions = [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ];
        break;

      case 'rejected':
        title = 'Verification Rejected';
        content = 'Your profile was rejected. Please update your information and resubmit.';
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to profile edit page
              setState(() => _selectedIndex = 3);
            },
            child: const Text('Update Profile'),
          ),
        ];
        break;

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
                      userData: _userData! as Map<String, String>,
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
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: actions,
      ),
    );
  }

  void _onItemTapped(int index) async {
    // Check profile completion and verification for protected tabs
    if (index == 1 || index == 2) {
      final isComplete = await _checkProfileCompletion();
      if (!isComplete) return;

      final isVerified = await _checkVerificationStatus();
      if (!isVerified) return;
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

    // Refresh likes page when navigating to it
    if (index == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _likesPageKey.currentState?.refreshLikedJobs();
      });
    }
  }

  Widget _buildVerificationStatusIndicator() {
    if (_verificationStatus == null) return const SizedBox.shrink();

    final status = _verificationStatus!['verificationStatus'];
    final canAccess = _verificationStatus!['canAccessJobs'] ?? false;

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
          final shouldExit = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
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
        appBar: _selectedIndex != 0 ? AppBar(
          title: Text(_navigationItems[_selectedIndex].label),
          automaticallyImplyLeading: false,
          actions: [_buildVerificationStatusIndicator()],
        ) : null,
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
                  final needsVerification = (index == 1 || index == 2);
                  final isVerified = _verificationStatus?['canAccessJobs'] ?? false;

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
                                // Icon with scale animation and verification indicator
                                AnimatedBuilder(
                                  animation: _scaleAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: isSelected ? _scaleAnimation.value : 1.0,
                                      child: Stack(
                                        children: [
                                          Container(
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
                                                  : (needsVerification && !isVerified)
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade600,
                                            ),
                                          ),
                                          // Verification warning indicator
                                          if (needsVerification && !isVerified)
                                            Positioned(
                                              right: -2,
                                              top: -2,
                                              child: Container(
                                                width: 12,
                                                height: 12,
                                                decoration: const BoxDecoration(
                                                  color: Colors.orange,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.warning,
                                                  size: 8,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
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
                                color: isSelected 
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

// Navigation Item Model (unchanged)
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
