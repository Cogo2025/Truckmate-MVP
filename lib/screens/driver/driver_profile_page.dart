import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate_app/screens/welcome_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:truckmate_app/services/auth_service.dart'; // NEW: Import AuthService

import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/login_page.dart';
import 'driver_profile_setup.dart';
import 'edit_driver_profile_page.dart';

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  bool isLoading = true;
    bool isResubmitting = false; // Add this for resubmit loading state

  Map<String, dynamic> userData = {};
  Map<String, dynamic> profileData = {};
  String? errorMessage;

  // Updated vibrant color scheme with cyan/teal instead of green
  static const Color primaryColor = Color(0xFF00BCD4); // Changed from green to cyan
  static const Color secondaryColor = Color(0xFF1976D2); // Blue
  static const Color accentColor = Color(0xFFFF6F00); // Orange
  static const Color errorColor = Color(0xFFD32F2F); // Red
  static const Color successColor = Color(0xFF26C6DA); // Changed from green to light cyan
  static const Color warningColor = Color(0xFFF57C00); // Warning Orange
  static const Color cardColor = Color(0xFFF8F9FA);
  static const Color gradientStart = Color(0xFF667eea);
  static const Color gradientEnd = Color(0xFF764ba2);

  @override
  void initState() {
    super.initState();
    fetchDriverProfile();
  }

  Future<void> _updateAvailability(bool isAvailable) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    
    if (token == null) return;

    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.updateAvailability),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "isAvailable": isAvailable,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          userData['isAvailable'] = isAvailable;
        });
        _showSnackBar(
          isAvailable 
              ? "🟢 You're now available for jobs" 
              : "🔴 You're not available for jobs",
          isAvailable ? successColor : warningColor,
        );
      }
    } catch (e) {
      _showSnackBar("❌ Failed to update availability", errorColor);
      setState(() {
        userData['isAvailable'] = !isAvailable;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == successColor ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

Future<void> fetchDriverProfile() async {
  final prefs = await SharedPreferences.getInstance();
  // NEW: Get fresh token
  final token = await AuthService.getFreshAuthToken();
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
    final userResponse = await http.get(
      Uri.parse(ApiConfig.authMe),
      headers: {"Authorization": "Bearer $token"},
    );
    if (userResponse.statusCode != 200) {
      throw Exception("Failed to fetch user data: ${userResponse.statusCode}");
    }

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
      setState(() {
        userData = jsonDecode(userResponse.body);
        isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DriverProfileSetupPage(userData: userData),
          ),
        );
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

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDriverProfilePage(
          profileData: profileData,
          userData: userData,
        ),
      ),
    ).then((_) {
      fetchDriverProfile();
    });
  }
Widget _buildVerificationStatus() {
    final verificationStatus = profileData['verificationStatus'] ?? 'pending';
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusDescription;
    
    switch (verificationStatus) {
      case 'approved':
        statusColor = successColor;
        statusIcon = Icons.verified;
        statusText = 'Verified Driver';
        statusDescription = 'Your profile has been verified and approved';
        break;
      case 'rejected':
        statusColor = errorColor;
        statusIcon = Icons.cancel;
        statusText = 'Verification Rejected';
        statusDescription = 'Your profile was rejected. Please update and resubmit.';
        break;
      case 'pending':
      default:
        statusColor = warningColor;
        statusIcon = Icons.pending;
        statusText = 'Verification Pending';
        statusDescription = 'Your profile is under review by our team';
    }

    return _buildGradientCard(
      startColor: statusColor.withOpacity(0.1),
      endColor: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusDescription,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Show rejection details and resubmit button for rejected status
          if (verificationStatus == 'rejected') ...[
            const SizedBox(height: 16),
            
            // Rejection reason container
            if (profileData['rejectionReason'] != null && 
                profileData['rejectionReason'].toString().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: errorColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: errorColor, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Rejection Reason:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: errorColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profileData['rejectionReason'].toString(),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Resubmit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isResubmitting ? null : _resubmitVerification,
                icon: isResubmitting 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(
                  isResubmitting ? 'Resubmitting...' : 'Resubmit for Verification',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            
            // Additional help text
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Make sure to update any incorrect information before resubmitting.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Show info for pending status
          if (verificationStatus == 'pending') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: warningColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: warningColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You cannot access jobs and likes until your profile is approved.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Show success message for approved status
          if (verificationStatus == 'approved') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: successColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: successColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can now access all features including jobs and likes.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildProfileAvatar() {
    String? profilePhotoUrl = profileData["profilePhoto"];
    String? googlePhotoUrl = userData['photoUrl'];
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)], // Updated gradient colors
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3), // Updated shadow color
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: CircleAvatar(
        radius: 65,
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey[100],
          child: profilePhotoUrl != null && profilePhotoUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    profilePhotoUrl,
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      if (googlePhotoUrl != null && googlePhotoUrl.isNotEmpty) {
                        return Image.network(
                          googlePhotoUrl,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.person, size: 60, color: Colors.grey[600]);
                          },
                        );
                      }
                      return Icon(Icons.person, size: 60, color: Colors.grey[600]);
                    },
                  ),
                )
              : googlePhotoUrl != null && googlePhotoUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        googlePhotoUrl,
                        height: 120,
                        width: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.person, size: 60, color: Colors.grey[600]);
                        },
                      ),
                    )
                  : Icon(Icons.person, size: 60, color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildGradientCard({
    required Widget child,
    Color? startColor,
    Color? endColor,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            startColor ?? Colors.white,
            endColor ?? cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (startColor ?? primaryColor).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _infoTile(String label, String value, {IconData? icon, Color? iconColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? primaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor ?? primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> children, {IconData? titleIcon, Color? titleColor}) {
    return _buildGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (titleIcon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (titleColor ?? primaryColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    titleIcon,
                    color: titleColor ?? primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: titleColor ?? primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Future<void> _launchTutorial() async {
    final Uri url = Uri.parse('https://youtube.com');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
Future _resubmitVerification() async {
  setState(() => isResubmitting = true);
  
  try {
    // Get fresh token using AuthService
    final token = await AuthService.getFreshAuthToken();
    if (token == null) {
      _showSnackBar("❌ Authentication required. Please login again.", errorColor);
      return;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/verification/resubmit'),
      headers: {
        "Authorization": "Bearer $token", // Use actual token
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 201) {
      _showSnackBar("✅ Verification resubmitted successfully!", successColor);
      _showResubmitSuccessDialog();
      // Refresh profile data
      await fetchDriverProfile();
    } else {
      final errorData = jsonDecode(response.body);
      final error = errorData['error'] ?? 'Failed to resubmit verification';
      _showSnackBar("❌ $error", errorColor);
    }
  } catch (e) {
    _showSnackBar("❌ Network error: ${e.toString()}", errorColor);
  } finally {
    if (mounted) {
      setState(() => isResubmitting = false);
    }
  }
}

 // Success dialog after resubmit
  void _showResubmitSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: successColor, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Resubmitted Successfully',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your verification has been resubmitted for review.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                '• Our team will review your profile again\n'
                '• You will be notified once the review is complete\n'
                '• This usually takes 1-2 business days',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.logout, color: errorColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              "Logout Confirmation",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Are you sure you want to logout?",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Text(
                "You will need to sign in again to access your account and continue receiving job notifications.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: const Text(
              "Logout",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Logging out...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final prefs = await SharedPreferences.getInstance();
        
        await prefs.remove('authToken');
        await prefs.remove('userRole');
        await prefs.remove('userId');
        await prefs.remove('userName');
        await prefs.remove('userEmail');
        await prefs.remove('userPhone');
        await prefs.remove('ownerProfileCompleted');
        await prefs.remove('driverProfileCompleted');
        await prefs.remove('ownerCompanyName');
        await prefs.remove('driverLicenseType');
        await prefs.remove('userData');

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.of(context).pop();
        }

        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const WelcomePage()),
            (route) => false,
          );
        }

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _showSnackBar("✅ Logged out successfully", successColor);
          }
        });

      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          _showSnackBar("❌ Logout failed: ${e.toString()}", errorColor);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Driver Profile",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: primaryColor,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)], // Updated gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: Colors.white),
              ),
              onPressed: _navigateToEditProfile,
              tooltip: "Edit Profile",
            ),
          ),
        ],
      ),
      body: isLoading
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF5F7FA), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Loading your profile...",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : errorMessage != null
              ? Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF5F7FA), Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: errorColor.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: errorColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: fetchDriverProfile,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Retry"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF5F7FA), Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Availability Switch Card
                      _buildGradientCard(
                        startColor: userData['isAvailable'] == true 
                            ? successColor.withOpacity(0.1) 
                            : warningColor.withOpacity(0.1),
                        endColor: Colors.white,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: userData['isAvailable'] == true 
                                    ? successColor.withOpacity(0.1) 
                                    : warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                userData['isAvailable'] == true 
                                    ? Icons.work 
                                    : Icons.work_off,
                                color: userData['isAvailable'] == true 
                                    ? successColor 
                                    : warningColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Job Availability',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userData['isAvailable'] == true 
                                        ? 'You are available for jobs' 
                                        : 'You are not available',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Transform.scale(
                              scale: 1.2,
                              child: Switch(
                                value: userData['isAvailable'] ?? true,
                                onChanged: (value) => _updateAvailability(value),
                                activeColor: successColor,
                                activeTrackColor: successColor.withOpacity(0.3),
                                inactiveThumbColor: warningColor,
                                inactiveTrackColor: warningColor.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Profile Avatar Section
                      Center(
                        child: Column(
                          children: [
                            _buildProfileAvatar(),
                            const SizedBox(height: 12),
                            Text(
                              userData["name"] ?? "Driver",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)], // Updated gradient
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "Professional Driver",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (profileData["profilePhoto"] != null && profileData["profilePhoto"].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  "Profile Photo",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Personal Information Section
                      _infoSection(
                        "Personal Information",
                        [
                          _infoTile("Full Name", userData["name"] ?? "N/A", 
                              icon: Icons.person, iconColor: secondaryColor),
                          _infoTile("Email Address", userData["email"] ?? "N/A", 
                              icon: Icons.email, iconColor: accentColor),
                          _infoTile("Phone Number", userData["phone"] ?? "N/A", 
                              icon: Icons.phone, iconColor: successColor),
                          _infoTile("Age", "${profileData["age"] ?? "N/A"} years", 
                              icon: Icons.cake, iconColor: warningColor),
                          _infoTile("Gender", profileData["gender"] ?? "N/A", 
                              icon: Icons.wc, iconColor: primaryColor),
                          _infoTile("Location", profileData["location"] ?? "N/A", 
                              icon: Icons.location_on, iconColor: errorColor),
                        ],
                        titleIcon: Icons.account_circle,
                        titleColor: secondaryColor,
                      ),
                      
                      // Driver Information Section
                      _infoSection(
                        "Driver Credentials",
                        [
                          _infoTile("Experience", "${profileData["experience"] ?? "N/A"} years", 
                              icon: Icons.timeline, iconColor: primaryColor),
                          _infoTile("License Type", profileData["licenseType"] ?? "N/A", 
                              icon: Icons.credit_card, iconColor: successColor),
                          _infoTile("License Number", profileData["licenseNumber"] ?? "N/A", 
                              icon: Icons.numbers, iconColor: secondaryColor),
                          _infoTile(
                            "License Expiry", 
                            profileData["licenseExpiryDate"] != null 
                                ? DateFormat('dd MMM yyyy').format(DateTime.parse(profileData["licenseExpiryDate"]))
                                : "N/A",
                            icon: Icons.event,
                            iconColor: warningColor,
                          ),
                          if (profileData["knownTruckTypes"] != null && profileData["knownTruckTypes"].isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.local_shipping,
                                          color: accentColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "Known Truck Types",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (profileData["knownTruckTypes"] as List)
                                        .map((type) => Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    accentColor.withOpacity(0.8),
                                                    accentColor,
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: accentColor.withOpacity(0.3),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                type,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        titleIcon: Icons.badge,
                        titleColor: primaryColor,
                      ),
                      
                      // License Photo Section
                      if (profileData["licensePhoto"] != null && profileData["licensePhoto"].isNotEmpty)
                        _buildGradientCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: warningColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.photo_camera,
                                      color: warningColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "License Photo",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: warningColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    profileData["licensePhoto"],
                                    height: 220,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 220,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              size: 48,
                                              color: errorColor,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              "Failed to load license photo",
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 220,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Support Section
                      _infoSection(
                        "Support & Help",
                        [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  secondaryColor.withOpacity(0.1),
                                  Colors.white,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: secondaryColor.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: successColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.phone,
                                        color: successColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Call Support",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          "1800-TRUCKMATE",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: warningColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.email,
                                        color: warningColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Email Support",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          "support@truckmate.app",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        titleIcon: Icons.support_agent,
                        titleColor: secondaryColor,
                      ),
                      
                      // Action Buttons
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ElevatedButton.icon(
                          onPressed: _launchTutorial,
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.play_circle, size: 20),
                          ),
                          label: const Text(
                            "Watch Tutorial",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: secondaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: secondaryColor.withOpacity(0.3),
                          ),
                        ),
                      ),
                      
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ElevatedButton.icon(
                          onPressed: _logout,
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.logout, size: 20),
                          ),
                          label: const Text(
                            "Logout",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: errorColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: errorColor.withOpacity(0.3),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}
