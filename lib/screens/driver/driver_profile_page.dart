import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/edit_driver_profile_page.dart';
import 'package:intl/intl.dart';
import 'driver_profile_setup.dart';

class DriverProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const DriverProfilePage({Key? key, required this.userData}) : super(key: key);

  @override
  _DriverProfilePageState createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _currentUserData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentUserData = widget.userData;
    _loadProfileData();
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

      // Load fresh user data
      final userResponse = await http.get(
        Uri.parse(ApiConfig.authMe),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (userResponse.statusCode == 200) {
        _currentUserData = jsonDecode(userResponse.body);
      }

      // Load profile data
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
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Profile not found. Please complete your profile setup.";
        });
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
        // Refresh profile data after editing
        _loadProfileData();
      });
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
              style: TextStyle(fontSize: 16),
            ),
          ),
          if (canCopy)
            IconButton(
              icon: Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Copied to clipboard!")),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(String label, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
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
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(Icons.error_outline, color: Colors.red),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Profile'),
        actions: [
          if (_profileData != null)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: _navigateToEditProfile,
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadProfileData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProfileData,
                        child: Text("Retry"),
                      ),
                    ],
                  ),
                )
              : _profileData == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Profile not found",
                            style: TextStyle(fontSize: 18),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DriverProfileSetupPage(
                                    userData: _currentUserData ?? {},
                                  ),
                                ),
                              );
                            },
                            child: Text("Create Profile"),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView(
                        children: [
                          // Profile Header
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundImage: _profileData!['profilePhoto'] != null
                                      ? NetworkImage(_profileData!['profilePhoto'])
                                      : (_currentUserData?['photoUrl'] != null
                                          ? NetworkImage(_currentUserData!['photoUrl'])
                                          : null),
                                  child: (_profileData!['profilePhoto'] == null && 
                                          _currentUserData?['photoUrl'] == null)
                                      ? Icon(Icons.person, size: 40)
                                      : null,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  // Try profile data first, then user data, then fallback
                                  _profileData?['userName'] ?? 
                                  _profileData?['name'] ?? 
                                  _currentUserData?['name'] ?? 
                                  'Unknown',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _profileData?['userEmail'] ?? 
                                  _currentUserData?['email'] ?? 
                                  'No email provided',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 24),

                          // Personal Information
                          Text(
                            "Personal Information",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          _buildInfoTile(
                            "Name", 
                            _profileData?['userName'] ?? 
                            _profileData?['name'] ?? 
                            _currentUserData?['name'] ?? 
                            "Not specified"
                          ),
                          _buildInfoTile(
                            "Phone", 
                            _profileData?['userPhone'] ?? 
                            _currentUserData?['phone'] ?? 
                            "Not provided", 
                            canCopy: true
                          ),
                          _buildInfoTile("Gender", _profileData!['gender'] ?? "Not specified"),
                          _buildInfoTile("Age", _profileData!['age']?.toString() ?? "Not specified"),
                          _buildInfoTile("Location", _profileData!['location'] ?? "Not specified"),
                          
                          SizedBox(height: 24),

                          // Driver Information
                          Text(
                            "Driver Information",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          _buildInfoTile("Experience", _profileData!['experience'] ?? "Not specified"),
                          _buildInfoTile("License Number", _profileData!['licenseNumber'] ?? "Not specified", canCopy: true),
                          _buildInfoTile(
                            "License Expiry",
                            _profileData!['licenseExpiryDate'] != null
                                ? DateFormat('yyyy-MM-dd').format(DateTime.parse(_profileData!['licenseExpiryDate']))
                                : "Not specified"
                          ),
                          _buildInfoTile(
                            "Truck Types",
                            _profileData!['knownTruckTypes'] != null
                                ? (_profileData!['knownTruckTypes'] as List).join(", ")
                                : "Not specified"
                          ),
                          
                          SizedBox(height: 24),

                          // Photos
                          Text(
                            "Photos",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          _buildPhotoSection("License Front", _profileData!['licensePhotoFront']),
                          _buildPhotoSection("License Back", _profileData!['licensePhotoBack']),
                          
                          SizedBox(height: 32),

                          // Verification Status
                          if (_profileData!['verificationStatus'] != null)
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _getVerificationColor(_profileData!['verificationStatus']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getVerificationColor(_profileData!['verificationStatus']),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _getVerificationIcon(_profileData!['verificationStatus']),
                                    color: _getVerificationColor(_profileData!['verificationStatus']),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Verification Status: ${_profileData!['verificationStatus']?.toString().toUpperCase() ?? 'PENDING'}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _getVerificationColor(_profileData!['verificationStatus']),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
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
        iconTheme: IconThemeData(color: Colors.white),
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
            errorBuilder: (context, error, stackTrace) => Center(
              child: Icon(Icons.error_outline, color: Colors.red, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}
