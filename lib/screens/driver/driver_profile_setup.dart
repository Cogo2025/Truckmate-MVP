import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mime/mime.dart'; // Add this import

import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/driver_main_navigation.dart';

class DriverProfileSetupPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const DriverProfileSetupPage({super.key, required this.userData});

  @override
  State<DriverProfileSetupPage> createState() => _DriverProfileSetupPageState();
}

class _DriverProfileSetupPageState extends State<DriverProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final List<String> truckTypes = [
    "Body Vehicle",
    "Trailer",
    "Tipper",
    "Gas Tanker",
    "Wind Mill",
    "Concrete Mixer",
    "Petrol Tank",
    "Container",
    "Bulker"
  ];

  // Form fields
  String gender = '';
  String experience = '';
  String licenseType = '';
  String licenseNumber = '';
  String location = '';
  String age = '';
  DateTime? licenseExpiryDate;
  List<String> selectedTruckTypes = [];
  XFile? licensePhoto;
  XFile? profilePhoto; // ✅ NEW: Added profile photo
  
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickLicensePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85, // Compress image to reduce size
      maxWidth: 1024,   // Limit width to 1024px
      maxHeight: 1024,  // Limit height to 1024px
    );
    if (picked != null) {
      setState(() => licensePhoto = picked);
    }
  }

  // ✅ NEW: Function to pick profile photo
  Future<void> _pickProfilePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null) {
      setState(() => profilePhoto = picked);
    }
  }

  // ✅ NEW: Function to show photo source options
  Future<void> _showPhotoSourceOptions(bool isProfilePhoto) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                    maxWidth: 1024,
                    maxHeight: 1024,
                  );
                  if (picked != null) {
                    setState(() {
                      if (isProfilePhoto) {
                        profilePhoto = picked;
                      } else {
                        licensePhoto = picked;
                      }
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                    maxWidth: 1024,
                    maxHeight: 1024,
                  );
                  if (picked != null) {
                    setState(() {
                      if (isProfilePhoto) {
                        profilePhoto = picked;
                      } else {
                        licensePhoto = picked;
                      }
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != licenseExpiryDate) {
      setState(() => licenseExpiryDate = picked);
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate() || licensePhoto == null || licenseExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and upload license photo")),
      );
      return;
    }
    
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Create multipart request for profile creation with photo
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.driverProfile),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields['experience'] = experience;
      request.fields['licenseType'] = licenseType;
      request.fields['licenseNumber'] = licenseNumber;
      request.fields['licenseExpiryDate'] = licenseExpiryDate!.toIso8601String();
      request.fields['gender'] = gender;
      request.fields['age'] = age;
      request.fields['location'] = location;
      request.fields['knownTruckTypes'] = jsonEncode(selectedTruckTypes);

      // Add license photo file with proper MIME type detection
      if (licensePhoto != null) {
        final file = File(licensePhoto!.path);
        
        // Get MIME type
        final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
        
        // Generate proper filename with extension
        final extension = mimeType.split('/').last;
        final filename = 'license_${DateTime.now().millisecondsSinceEpoch}.$extension';
        
        print('📤 License file path: ${file.path}');
        print('📤 License MIME type: $mimeType');
        print('📤 License filename: $filename');
        
        request.files.add(
          await http.MultipartFile.fromPath(
            'licensePhoto',
            file.path,
            filename: filename,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      // ✅ NEW: Add profile photo file
      if (profilePhoto != null) {
        final file = File(profilePhoto!.path);
        
        // Get MIME type
        final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
        
        // Generate proper filename with extension
        final extension = mimeType.split('/').last;
        final filename = 'profile_${DateTime.now().millisecondsSinceEpoch}.$extension';
        
        print('📤 Profile file path: ${file.path}');
        print('📤 Profile MIME type: $mimeType');
        print('📤 Profile filename: $filename');
        
        request.files.add(
          await http.MultipartFile.fromPath(
            'profilePhoto',
            file.path,
            filename: filename,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      print('📤 Submitting profile with fields: ${request.fields}');
      print('📤 Files attached: ${request.files.length}');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: $responseBody');

      if (response.statusCode == 201) {
        final responseData = jsonDecode(responseBody);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? "Profile setup completed")),
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DriverMainNavigation()),
          );
        }
      } else {
        final error = jsonDecode(responseBody);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error["error"] ?? "Something went wrong")),
        );
      }
    } catch (e) {
      print('❌ Error submitting profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Your Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Personal Information",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // User info from Google
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: widget.userData['photoUrl'] != null 
                      ? NetworkImage(widget.userData['photoUrl'])
                      : null,
                  child: widget.userData['photoUrl'] == null 
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(widget.userData['name'] ?? 'No name'),
                subtitle: Text(widget.userData['email'] ?? 'No email'),
              ),
              
              const SizedBox(height: 16),
              
              // ✅ NEW: Profile Photo Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Profile Photo:",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Upload a clear photo of yourself (optional)",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showPhotoSourceOptions(true),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(profilePhoto == null 
                            ? "Add Profile Photo" 
                            : "Change Photo"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (profilePhoto != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Profile photo:",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(profilePhoto!.path),
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              const Text(
                "Driver Information",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              
              // Age
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Age",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved: (val) => age = val ?? '',
              ),
              const SizedBox(height: 16),
              
              // Gender
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Gender",
                  border: OutlineInputBorder(),
                ),
                items: ["Male", "Female", "Other"]
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                validator: (val) => val == null || val.isEmpty ? "Select gender" : null,
                onChanged: (val) => setState(() => gender = val ?? ''),
              ),
              const SizedBox(height: 16),
              
              // Location
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Location",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved: (val) => location = val ?? '',
              ),
              const SizedBox(height: 16),
              
              // Experience
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Years of Experience",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved: (val) => experience = val ?? '',
              ),
              const SizedBox(height: 16),
              
              // License Type
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "License Type (e.g., Commercial, Heavy Vehicle)",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved: (val) => licenseType = val ?? '',
              ),
              const SizedBox(height: 16),
              
              // License Number
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "License Number",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved: (val) => licenseNumber = val ?? '',
              ),
              const SizedBox(height: 16),
              
              // License Expiry Date
              Card(
                child: ListTile(
                  title: const Text("License Expiry Date"),
                  subtitle: Text(licenseExpiryDate != null 
                      ? DateFormat('yyyy-MM-dd').format(licenseExpiryDate!)
                      : "Select date"),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectExpiryDate(context),
                ),
              ),
              const SizedBox(height: 16),
              
              // Truck Types (Multi-select)
              const Text(
                "Truck Types You Can Operate:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: truckTypes.map((type) {
                  final isSelected = selectedTruckTypes.contains(type);
                  return FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedTruckTypes.add(type);
                        } else {
                          selectedTruckTypes.remove(type);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              
              // License Photo
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "License Photo:",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Please take a clear photo of your driving license",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showPhotoSourceOptions(false),
                        icon: const Icon(Icons.camera_alt),
                        label: Text(licensePhoto == null 
                            ? "Take License Photo" 
                            : "Retake Photo"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (licensePhoto != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "License photo captured:",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(licensePhoto!.path),
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Navigation Buttons
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        // Previous Button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Previous"),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Complete Profile Button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: selectedTruckTypes.isNotEmpty ? _submitProfile : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text("Complete Profile"),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}