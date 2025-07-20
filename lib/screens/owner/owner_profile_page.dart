import 'dart:convert';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate_app/screens/login_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/owner/my_posted_jobs_page.dart';

class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key});

  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  bool isLoading = true;
  bool isEditing = false;
  bool isUpdating = false;
  Map<String, dynamic> userData = {};
  Map<String, dynamic> profileData = {};
  String? errorMessage;
  
  // Controllers for edit mode - Added name and phone controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyLocationController = TextEditingController();
  String _selectedGender = 'Not Specified';
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    fetchOwnerProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyNameController.dispose();
    _companyLocationController.dispose();
    super.dispose();
  }

  Future<void> fetchOwnerProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

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
      final userRes = await http.get(
        Uri.parse(ApiConfig.authMe),
        headers: {"Authorization": "Bearer $token"},
      );

      final profileRes = await http.get(
        Uri.parse(ApiConfig.ownerProfile),
        headers: {"Authorization": "Bearer $token"},
      );

      if (userRes.statusCode == 200 && profileRes.statusCode == 200) {
        setState(() {
          userData = jsonDecode(userRes.body);
          profileData = jsonDecode(profileRes.body);
          isLoading = false;
          
          // Initialize controllers with current data
          _nameController.text = userData["name"] ?? "";
          _phoneController.text = userData["phone"] ?? "";
          _companyNameController.text = profileData["companyName"] ?? "";
          _companyLocationController.text = profileData["companyLocation"] ?? "";
          _selectedGender = profileData["gender"] ?? "Not Specified";
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to fetch profile.";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error: $e";
      });
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    await fetchOwnerProfile();
  }

  Future<void> _pickImage() async {
  try {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (image != null) {
      // Check file extension
      String fileName = image.path.toLowerCase();
      if (!fileName.endsWith('.jpg') && 
          !fileName.endsWith('.jpeg') && 
          !fileName.endsWith('.png') && 
          !fileName.endsWith('.gif')) {
        _showSnackBar("Please select a valid image file (JPEG, JPG, PNG, GIF)", Colors.red);
        return;
      }
      
      // Check file size (limit to 5MB)
      File file = File(image.path);
      int fileSizeInBytes = await file.length();
      double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
      
      if (fileSizeInMB > 5) {
        _showSnackBar("Image size must be less than 5MB", Colors.red);
        return;
      }
      
      setState(() {
        _selectedImage = file;
      });
      
      _showSnackBar("Image selected successfully", Colors.green);
    }
  } catch (e) {
    _showSnackBar("Error picking image: $e", Colors.red);
  }
}

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _enableEditMode() {
    setState(() {
      isEditing = true;
      _selectedImage = null; // Reset selected image
    });
  }

  void _cancelEdit() {
    setState(() {
      isEditing = false;
      _selectedImage = null;
      // Reset controllers to original values
      _nameController.text = userData["name"] ?? "";
      _phoneController.text = userData["phone"] ?? "";
      _companyNameController.text = profileData["companyName"] ?? "";
      _companyLocationController.text = profileData["companyLocation"] ?? "";
      _selectedGender = profileData["gender"] ?? "Not Specified";
    });
  }

  Future<void> _saveProfile() async {
  if (_nameController.text.trim().isEmpty ||
      _phoneController.text.trim().isEmpty ||
      _companyNameController.text.trim().isEmpty ||
      _companyLocationController.text.trim().isEmpty) {
    _showSnackBar("Please fill in all required fields", Colors.red);
    return;
  }

  setState(() {
    isUpdating = true;
  });

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('authToken');

  try {
    // First, update user data (name and phone)
    final userUpdateResponse = await http.patch(
      Uri.parse(ApiConfig.updateUser),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      }),
    );

    bool userUpdateSuccess = userUpdateResponse.statusCode == 200;
    
    // Then, update profile data with image
    var profileRequest = http.MultipartRequest('PATCH', Uri.parse(ApiConfig.ownerProfile));
    profileRequest.headers['Authorization'] = 'Bearer $token';
    
    // Add profile fields
    profileRequest.fields['companyName'] = _companyNameController.text.trim();
    profileRequest.fields['companyLocation'] = _companyLocationController.text.trim();
    profileRequest.fields['gender'] = _selectedGender;

    // Add image if selected with proper content type
    if (_selectedImage != null) {
      String fileName = _selectedImage!.path.split('/').last;
      String? mimeType;
      
      // Set correct MIME type based on file extension
      if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fileName.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.gif')) {
        mimeType = 'image/gif';
      }
      
      profileRequest.files.add(
        await http.MultipartFile.fromPath(
          'photo', // Make sure this matches your backend field name
          _selectedImage!.path,
          filename: fileName,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        ),
      );
    }

    final profileResponse = await profileRequest.send();
    final profileResponseData = await profileResponse.stream.bytesToString();

    if (userUpdateSuccess && profileResponse.statusCode == 200) {
      _showSnackBar("Profile updated successfully!", Colors.green);
      setState(() {
        isEditing = false;
        _selectedImage = null;
      });
      await fetchOwnerProfile(); // Refresh profile data
    } else {
      String errorMessage = "Failed to update profile";
      
      if (!userUpdateSuccess) {
        try {
          final errorData = jsonDecode(userUpdateResponse.body);
          errorMessage = "User info update failed: ${errorData['error'] ?? errorData['message'] ?? 'Unknown error'}";
        } catch (e) {
          errorMessage = "User info update failed: HTTP ${userUpdateResponse.statusCode}";
        }
      } else if (profileResponse.statusCode != 200) {
        try {
          final errorData = jsonDecode(profileResponseData);
          errorMessage = "Profile update failed: ${errorData['error'] ?? errorData['message'] ?? 'Unknown error'}";
        } catch (e) {
          errorMessage = "Profile update failed: HTTP ${profileResponse.statusCode}";
        }
      }
      
      _showSnackBar(errorMessage, Colors.red);
    }
  } catch (e) {
    _showSnackBar("Error updating profile: $e", Colors.red);
  } finally {
    setState(() {
      isUpdating = false;
    });
  }
}


  Widget _infoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const Text(": ", style: TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableField(String label, TextEditingController controller, {bool isRequired = true, TextInputType? keyboardType}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label + (isRequired ? " *" : ""),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: "Enter $label",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.orange),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Gender *",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.orange),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: ['Male', 'Female', 'Other', 'Not Specified']
                .map((String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ))
                .toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedGender = newValue;
                });
              }
            },
          ),
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

  Future<void> _logout() async {
  // Show confirmation dialog with enhanced UI
  final bool? shouldLogout = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Prevent dismissing by tapping outside
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Row(
        children: [
          Icon(Icons.logout, color: Colors.red.shade600),
          const SizedBox(width: 8),
          const Text(
            "Logout",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Are you sure you want to logout?",
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            "You will need to sign in again to access your account.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            "Cancel",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            "Logout",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  // If user confirmed logout
  if (shouldLogout == true) {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Logging out...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

       final prefs = await SharedPreferences.getInstance();
      
      // Clear specific keys to ensure complete logout
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
      await prefs.remove('userData'); // Also clear userData that LoginPage uses

      // Small delay to show the loading state
      await Future.delayed(const Duration(milliseconds: 500));

      // Close loading dialog FIRST
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      // Add a small delay to ensure dialog is fully closed
      await Future.delayed(const Duration(milliseconds: 100));

      // Navigate to login screen and clear all previous routes - FIXED
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false, // Remove all previous routes
        );
      }

      // Show success message with a delay to ensure navigation completed
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    "Logged out successfully",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });

    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }
        // Show error message
        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Logout failed: ${e.toString()}",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: "Retry",
              textColor: Colors.white,
              onPressed: _logout,
            ),
          ),
        );
      }
    }
  }
}

  void _navigateToMyJobs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyPostedJobsPage(),
      ),
    );
  }

  Widget _buildProfileImage() {
    final photoUrl = profileData['photoUrl'] ?? userData['photoUrl'];
    
    return GestureDetector(
      onTap: isEditing ? _pickImage : null,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isEditing ? Colors.orange : Colors.orange, 
            width: 3
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            children: [
              // Profile image
              _selectedImage != null
                  ? Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                    )
                  : photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.orange.shade50,
                              child: const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.orange,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.orange.shade50,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.orange.shade50,
                          child: const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.orange,
                          ),
                        ),
              
              // Edit overlay
              if (isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Profile" : "Owner Profile"),
        automaticallyImplyLeading: false,
        actions: [
          if (!isEditing) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _enableEditMode,
              tooltip: "Edit Profile",
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshProfile,
            ),
          ] else ...[
            if (isUpdating)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              TextButton(
                onPressed: _cancelEdit,
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: _saveProfile,
                child: const Text("Save"),
              ),
            ],
          ],
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshProfile,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Profile Image Section
                      Center(child: _buildProfileImage()),
                      const SizedBox(height: 20),
                      
                      // Name Display (only show in non-edit mode)
                      if (!isEditing)
                        Center(
                          child: Text(
                            userData["name"] ?? "Unknown User",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      const SizedBox(height: 30),

                      // Personal Information Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Personal Information",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (!isEditing) ...[
                              _infoTile("Name", userData["name"] ?? "N/A"),
                              _infoTile("Email", userData["email"] ?? "N/A"),
                              _infoTile("Phone", userData["phone"] ?? "N/A"),
                              _infoTile("Gender", profileData["gender"] ?? "N/A"),
                            ] else ...[
                              _editableField("Name", _nameController),
                              _infoTile("Email", userData["email"] ?? "N/A"), // Email remains non-editable
                              _editableField("Phone", _phoneController, keyboardType: TextInputType.phone),
                              _genderDropdown(),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Company Information Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Company Information",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (!isEditing) ...[
                              _infoTile(
                                "Company Name",
                                profileData["companyName"] ?? "N/A",
                              ),
                              _infoTile(
                                "Company Location",
                                profileData["companyLocation"] ?? "N/A",
                              ),
                            ] else ...[
                              _editableField("Company Name", _companyNameController),
                              _editableField("Company Location", _companyLocationController),
                            ],
                          ],
                        ),
                      ),

                      if (!isEditing) ...[
                        const SizedBox(height: 20),

                        // My Job Posts Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "My Job Posts",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _navigateToMyJobs,
                                  icon: const Icon(Icons.work),
                                  label: const Text("View My Job Posts"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Support Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Support",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Row(
                                children: [
                                  Icon(Icons.phone, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text("1800-TRUCKMATE", style: TextStyle(fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Icon(Icons.email, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text("support@truckmate.app", style: TextStyle(fontSize: 16)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _launchTutorial,
                            icon: const Icon(Icons.play_circle),
                            label: const Text("Watch Tutorial"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: const Text("Logout"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}