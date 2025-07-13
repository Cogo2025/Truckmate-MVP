import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

import 'package:truckmate_app/api_config.dart';

class OwnerProfileSetupPage extends StatefulWidget {
  const OwnerProfileSetupPage({super.key});

  @override
  State<OwnerProfileSetupPage> createState() => _OwnerProfileSetupPageState();
}

class _OwnerProfileSetupPageState extends State<OwnerProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companyLocationController = TextEditingController();
  
  String gender = '';
  XFile? profilePhoto;
  String? existingPhotoUrl;
  bool _isLoading = false;
  bool _isUpdateMode = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyLocationController.dispose();
    super.dispose();
  }

 Future<void> _loadExistingProfile() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('authToken');

  if (token == null) return;

  try {
    print("🔄 Loading existing profile...");
    final response = await http.get(
      Uri.parse(ApiConfig.ownerProfile),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    ).timeout(const Duration(seconds: 15));

    print("📥 Load profile response: ${response.statusCode}");
    print("📥 Response body: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _companyNameController.text = data['companyName'] ?? '';
        _companyLocationController.text = data['companyLocation'] ?? '';
        gender = data['gender'] ?? '';
        existingPhotoUrl = data['photoUrl'];
        _isUpdateMode = _companyNameController.text.isNotEmpty;
      });
      
      // Test image URL if it exists
      if (existingPhotoUrl != null && existingPhotoUrl!.isNotEmpty) {
        print("🖼️ Found existing photo URL: $existingPhotoUrl");
        _testImageUrl(existingPhotoUrl!);
      } else {
        print("ℹ️ No existing photo URL found");
      }
    }
  } catch (e) {
    print("❌ Error loading existing profile: $e");
    // Continue with empty form
  }
}
  Future<void> _pickProfilePhoto() async {
    final result = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Photo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final picked = await _picker.pickImage(
          source: result,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (picked != null) {
          // Validate the image file
          final mimeType = lookupMimeType(picked.path);
          print("📷 Selected image MIME type: $mimeType");
          
          if (mimeType == null || !mimeType.startsWith('image/')) {
            _showErrorSnackBar("Please select a valid image file");
            return;
          }
          
          final allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
          if (!allowedTypes.contains(mimeType.toLowerCase())) {
            _showErrorSnackBar("Please select a JPEG, PNG, or GIF image");
            return;
          }
          
          setState(() => profilePhoto = picked);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error picking image: $e")),
          );
        }
      }
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validation logic
    if (!_isUpdateMode && profilePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a profile photo")),
      );
      return;
    }

    if (gender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your gender")),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) {
      _showErrorSnackBar("User not logged in");
      setState(() => _isLoading = false);
      return;
    }

    print("📤 Submitting profile:");
    print("Token: ${token.substring(0, 20)}...");
    print("Company Name: ${_companyNameController.text}");
    print("Company Location: ${_companyLocationController.text}");
    print("Gender: $gender");
    print("Photo Path: ${profilePhoto?.path ?? 'No new photo'}");
    print("Update Mode: $_isUpdateMode");
    print("API URL: ${ApiConfig.ownerProfile}");

    try {
      // Create multipart request
      final requestMethod = _isUpdateMode ? 'PUT' : 'POST';
      var request = http.MultipartRequest(requestMethod, Uri.parse(ApiConfig.ownerProfile));
      
      // Add headers
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add form fields
      request.fields['companyName'] = _companyNameController.text.trim();
      request.fields['companyLocation'] = _companyLocationController.text.trim();
      request.fields['gender'] = gender;
      
      // Add photo file if selected
      if (profilePhoto != null) {
        try {
          // Get the proper MIME type
          final mimeType = lookupMimeType(profilePhoto!.path);
          print("📷 Image MIME type: $mimeType");
          
          if (mimeType == null || !mimeType.startsWith('image/')) {
            _showErrorSnackBar("Invalid image file format");
            setState(() => _isLoading = false);
            return;
          }
          
          // Read the file as bytes and create MultipartFile
          final bytes = await File(profilePhoto!.path).readAsBytes();
          final multipartFile = http.MultipartFile.fromBytes(
            'photo', // Field name expected by backend
            bytes,
            filename: 'profile_photo.${mimeType.split('/').last}',
            contentType: MediaType.parse(mimeType),
          );
          
          request.files.add(multipartFile);
          print("📎 Photo file added successfully with MIME type: $mimeType");
        } catch (e) {
          print("❌ Error adding photo file: $e");
          _showErrorSnackBar("Error processing photo file: $e");
          setState(() => _isLoading = false);
          return;
        }
      }

      print("🚀 Sending request...");
      
      // Send request with timeout
      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      print("📥 Response Status: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Save profile completion status
        await prefs.setBool("ownerProfileCompleted", true);
        await prefs.setString("ownerCompanyName", _companyNameController.text.trim());
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isUpdateMode 
                ? "Profile updated successfully!" 
                : "Profile setup completed successfully!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        String errorMessage = "Something went wrong";
        try {
          final error = jsonDecode(response.body);
          errorMessage = error["error"] ?? error["message"] ?? errorMessage;
        } catch (e) {
          errorMessage = "Server error (${response.statusCode})";
        }
        
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      print("❌ Exception during profile submission: $e");
      String errorMessage = "Network error";
      if (e.toString().contains("TimeoutException")) {
        errorMessage = "Request timed out. Please try again.";
      } else if (e.toString().contains("SocketException")) {
        errorMessage = "No internet connection";
      }
      
      _showErrorSnackBar(errorMessage);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

 Widget _buildProfilePhotoChild() {
  if (profilePhoto != null) {
    return ClipOval(
      child: Image.file(
        File(profilePhoto!.path),
        fit: BoxFit.cover,
        width: 120,
        height: 120,
      ),
    );
  } else if (existingPhotoUrl != null && existingPhotoUrl!.isNotEmpty) {
    print("🖼️ Loading image from URL: $existingPhotoUrl");
    
    return ClipOval(
      child: Image.network(
        existingPhotoUrl!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        headers: {
          'User-Agent': 'TruckMateApp/1.0',
          'Accept': 'image/*',
        },
        errorBuilder: (context, error, stackTrace) {
          print("❌ Error loading image: $error");
          print("❌ URL: $existingPhotoUrl");
          return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 40, color: Colors.red),
                SizedBox(height: 8),
                Text("Error loading", 
                  style: TextStyle(color: Colors.red, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
              ),
            ),
          );
        },
      ),
    );
  } else {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt, size: 40, color: Colors.deepOrange),
        SizedBox(height: 8),
        Text(
          "Add Photo",
          style: TextStyle(color: Colors.deepOrange, fontSize: 12),
        ),
      ],
    );
  }
}

Widget _buildProfilePhotoSection() {
  return Center(
    child: Column(
      children: [
        GestureDetector(
          onTap: _pickProfilePhoto,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.deepOrange,
                width: 2,
              ),
              color: Colors.grey.shade50,
            ),
            child: _buildProfilePhotoChild(),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _pickProfilePhoto,
          icon: const Icon(Icons.camera_alt, color: Colors.deepOrange),
          label: Text(
            existingPhotoUrl != null ? "Change Photo" : "Add Photo",
            style: const TextStyle(color: Colors.deepOrange),
          ),
        ),
        if (!_isUpdateMode)
          const Text(
            "Profile photo is required",
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
      ],
    ),
  );
}

  Future<void> _testImageUrl(String url) async {
  try {
    print("🧪 Testing image URL: $url");
    final response = await http.get(Uri.parse(url));
    print("🧪 Image URL test - Status: ${response.statusCode}");
    print("🧪 Content-Type: ${response.headers['content-type']}");
    print("🧪 Content-Length: ${response.headers['content-length']}");
    
    if (response.statusCode != 200) {
      print("❌ Image URL test failed with status: ${response.statusCode}");
      print("❌ Response body: ${response.body}");
    } else {
      print("✅ Image URL test passed");
    }
  } catch (e) {
    print("❌ Image URL test failed: $e");
  }
}

Future<void> _testBackendUploads() async {
  try {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/profile/test-uploads'),
    );
    
    print("🧪 Backend uploads test - Status: ${response.statusCode}");
    print("🧪 Response: ${response.body}");
  } catch (e) {
    print("❌ Backend uploads test failed: $e");
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isUpdateMode ? "Update Profile" : "Owner Profile Setup"),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                _isUpdateMode 
                  ? "Update your profile information" 
                  : "Complete your profile to continue",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildProfilePhotoSection(),
              const SizedBox(height: 30),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Gender",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                value: gender.isEmpty ? null : gender,
                items: ["Male", "Female", "Other"]
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                validator: (val) => val == null || val.isEmpty ? "Please select gender" : null,
                onChanged: (val) => setState(() => gender = val ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: "Company Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Company name is required" : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyLocationController,
                decoration: const InputDecoration(
                  labelText: "Company Location",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Company location is required" : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _isUpdateMode ? "Update Profile" : "Complete Profile",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
              const SizedBox(height: 20),
              
              if (kDebugMode) ...[
                const Divider(),
                const Text("Debug Info:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("API URL: ${ApiConfig.ownerProfile}"),
                Text("Company Name: ${_companyNameController.text}"),
                Text("Company Location: ${_companyLocationController.text}"),
                Text("Gender: $gender"),
                Text("Photo Selected: ${profilePhoto != null}"),
                Text("Update Mode: $_isUpdateMode"),
                Text("Existing Photo URL: ${existingPhotoUrl ?? 'None'}"),
              ],
            ],
          ),
        ),
      ),
    );
  }
}