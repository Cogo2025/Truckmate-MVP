import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/edit_driver_profile_page.dart';
import 'package:truckmate_app/screens/welcome_page.dart';
import 'package:truckmate_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // *** NEW: Added for URL launching ***
import 'driver_profile_setup.dart';

class DriverProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DriverProfilePage({Key? key, required this.userData}) : super(key: key);

  @override
  _DriverProfilePageState createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _currentUserData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProfileComplete = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isLoggingOut = false;
  
  // *** Availability toggle state ***
  bool _isAvailable = false;
  bool _isUpdatingAvailability = false;

  @override
  void initState() {
    super.initState();
    _currentUserData = widget.userData;
    _loadProfileData();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.0, end: 1.0));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // *** NEW: Launch URL method for Support & Tutorial links ***
  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      _showError("Could not open link: $e");
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Authentication token missing";
        });
        return;
      }

      // Load profile data (will return user data with N/A if profile not complete)
      final response = await http.get(
        Uri.parse(ApiConfig.driverProfile),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        setState(() {
          _profileData = responseData['profile'];
          _isProfileComplete = _profileData?['profileCompleted'] == true;
          _isAvailable = _profileData?['isAvailable'] ?? false;
          _isLoading = false;
        });
        _fadeController.forward();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load profile: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading profile: ${e.toString()}";
      });
    }
  }

  // *** Update availability toggle ***
  Future<void> _updateAvailability(bool newValue) async {
    if (_isUpdatingAvailability) return;

    setState(() {
      _isUpdatingAvailability = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      
      if (token == null) {
        _showError("Authentication token missing");
        return;
      }

      print('🔄 Updating availability to: $newValue');

      final response = await http.patch(
        Uri.parse(ApiConfig.updateAvailability),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"isAvailable": newValue}),
      );

      print('📥 Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _isAvailable = newValue;
          if (_profileData != null) {
            _profileData!['isAvailable'] = newValue;
          }
        });
        
        _showSuccess(newValue 
            ? "You are now available for job opportunities!" 
            : "You are now unavailable for jobs");
      } else {
        final data = jsonDecode(response.body);
        _showError(data['error'] ?? 'Failed to update availability');
      }
    } catch (e) {
      print('❌ Availability update error: $e');
      _showError("Failed to update availability: ${e.toString()}");
    } finally {
      setState(() {
        _isUpdatingAvailability = false;
      });
    }
  }

  void _navigateToEditProfile() {
    if (_profileData != null && _currentUserData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditDriverProfilePage(
            profileData: _profileData!,
            userData: _currentUserData!,
          ),
        ),
      ).then((_) {
        _loadProfileData();
      });
    }
  }

  void _navigateToProfileSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverProfileSetupPage(
          userData: _currentUserData ?? {},
        ),
      ),
    ).then((_) {
      _loadProfileData();
    });
  }

  // *** FIXED: Complete logout function ***
  Future<void> _logout() async {
    if (_isLoggingOut) return;

    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?\n\nYou will need to sign in again to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      print('🚪 Starting logout process...');

      // 1. Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      print('✅ Firebase signout successful');

      // 2. Clear local authentication data
      await AuthService.clearAuthData();
      print('✅ Local auth data cleared');

      // 3. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('✅ SharedPreferences cleared');

      // 4. Show success message
      if (mounted) {
        _showSuccess("Logged out successfully");
      }

      // 5. Navigate to welcome page with delay
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ Logout error: $e');
      if (mounted) {
        _showError("Logout failed: ${e.toString()}");
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildInfoTile(String label, String value, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: value == 'N/A' ? Colors.grey : Colors.black,
                fontStyle: value == 'N/A' ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          if (canCopy && value != 'N/A')
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                _showSuccess("Copied to clipboard!");
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(String label, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Center(
                child: Text(
                  'N/A',
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _FullscreenImageViewer(imageUrl: imageUrl),
            ),
          ),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.error_outline, color: Colors.red),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildVerificationStatusCard() {
    if (!_isProfileComplete) return const SizedBox.shrink();

    final status = _profileData?['verificationStatus'] ?? 'pending';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getVerificationColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getVerificationColor(status),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getVerificationIcon(status),
            color: _getVerificationColor(status),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Verification Status: ${status.toString().toUpperCase()}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getVerificationColor(status),
                  ),
                ),
                if (status == 'pending')
                  const Text(
                    "Your profile is under admin review",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (status == 'approved')
                  const Text(
                    "You can now access job opportunities",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (status == 'rejected')
                  Text(
                    "Reason: ${_profileData?['rejectionReason'] ?? 'Please update your profile'}",
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // *** Availability toggle widget for approved drivers ***
  Widget _buildAvailabilityToggle() {
    final status = _profileData?['verificationStatus'] ?? 'pending';
    
    // Only show for approved drivers
    if (status != 'approved' || !_isProfileComplete) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.work_outline,
                color: Colors.blue[700],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                "Job Availability",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isAvailable ? "Available for Jobs" : "Not Available",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _isAvailable ? Colors.green[700] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isAvailable 
                          ? "You will receive job notifications"
                          : "You won't receive job notifications",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _isUpdatingAvailability
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch(
                      value: _isAvailable,
                      onChanged: _updateAvailability,
                      activeColor: Colors.white,
                      activeTrackColor: Colors.green,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.grey[400],
                    ),
            ],
          ),
        ],
      ),
    );
  }

  // *** NEW: Support & Help Card ***
  Widget _buildSupportHelpCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "Support & Help",
                  style: TextStyle(
                    color: Colors.teal[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal[100],
                      child: Icon(Icons.phone, color: Colors.teal[700]),
                    ),
                    title: Text(
                      "Phone Support",
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      "+91 9629452526",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                    onTap: () => _launchURL("tel:9629452526"),
                  ),
                  Divider(height: 1, color: Colors.grey[200]),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal[100],
                      child: Icon(Icons.email_rounded, color: Colors.teal[700]),
                    ),
                    title: Text(
                      "Email Support",
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      "cogo2025@gamil.com",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                    onTap: () => _launchURL("mailto:cogo2025@gmail.com"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Profile'),
        actions: [
          if (_isProfileComplete && !_isLoggingOut)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _navigateToEditProfile,
            ),
          if (!_isLoggingOut)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadProfileData,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProfileData,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView(
                      children: [
                        // Profile Header
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: _profileData!['profilePhoto'] != null && _profileData!['profilePhoto'].isNotEmpty
                                    ? NetworkImage(_profileData!['profilePhoto'])
                                    : (_profileData?['userPhotoUrl'] != null && _profileData!['userPhotoUrl'].isNotEmpty
                                        ? NetworkImage(_profileData!['userPhotoUrl'])
                                        : null),
                                child: (_profileData!['profilePhoto'] == null || _profileData!['profilePhoto'].isEmpty) &&
                                        (_profileData?['userPhotoUrl'] == null || _profileData!['userPhotoUrl'].isEmpty)
                                    ? const Icon(Icons.person, size: 40)
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _profileData?['userName'] ?? _profileData?['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _profileData?['userEmail'] ?? 'No email provided',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Show setup button if profile not complete
                        if (!_isProfileComplete) ...[
                          Card(
                            color: Colors.blue[50],
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.blue, size: 48),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Profile Setup Required',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Complete your driver profile to access job opportunities and get verified by admin.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _navigateToProfileSetup,
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Complete Profile Setup'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Verification Status (only show if profile complete)
                        _buildVerificationStatusCard(),

                        // Availability Toggle (only for approved drivers)
                        _buildAvailabilityToggle(),

                        // Personal Information
                        Text(
                          "Personal Information",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoTile("Name", _profileData?['userName'] ?? _profileData?['name'] ?? "Not specified"),
                        _buildInfoTile("Phone", _profileData?['userPhone'] ?? "Not provided"),
                        _buildInfoTile("Gender", _profileData?['gender']?.toString() ?? "N/A"),
                        _buildInfoTile("Age", _profileData?['age']?.toString() ?? "N/A"),
                        _buildInfoTile("Location", _profileData?['location']?.toString() ?? "N/A"),

                        const SizedBox(height: 24),

                        // Driver Information
                        Text(
                          "Driver Information",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoTile("Experience", (_profileData?['experience']?.toString() ?? "N/A") + (_profileData?['experience'] != "N/A" ? " years" : "")),
                        _buildInfoTile("License Number", _profileData?['licenseNumber']?.toString() ?? "N/A", canCopy: true),
                        _buildInfoTile(
                          "License Expiry",
                          _profileData?['licenseExpiryDate'] != null
                              ? DateFormat('yyyy-MM-dd').format(DateTime.parse(_profileData!['licenseExpiryDate']))
                              : "N/A"
                        ),
                        _buildInfoTile(
                          "Truck Types",
                          _profileData?['knownTruckTypes'] != null && (_profileData!['knownTruckTypes'] as List).isNotEmpty
                              ? (_profileData!['knownTruckTypes'] as List).join(", ")
                              : "N/A"
                        ),

                        const SizedBox(height: 24),

                        // Photos
                        Text(
                          "Photos",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPhotoSection("License Front", _profileData?['licensePhotoFront']),
                        _buildPhotoSection("License Back", _profileData?['licensePhotoBack']),

                        // *** NEW: Support & Help Card ***
                        _buildSupportHelpCard(),

                        const SizedBox(height: 20),

                        // *** NEW: Watch Tutorial Button ***
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _launchURL("https://www.youtube.com/watch?v=exampleTutorial"),
                            icon: const Icon(Icons.play_circle_fill_rounded, size: 24),
                            label: const Text("Watch Tutorial"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // *** NEW: Styled Logout Button ***
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoggingOut ? null : _logout,
                            icon: _isLoggingOut
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.logout_rounded, size: 24),
                            label: Text(_isLoggingOut ? 'Logging out...' : 'Logout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Color _getVerificationColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getVerificationIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.verified;
      case 'pending':
        return Icons.pending;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
}

// Keep your existing _FullscreenImageViewer class
class _FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullscreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.error_outline, color: Colors.red, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}