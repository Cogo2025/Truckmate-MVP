import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart';
import 'package:truckmate_app/api_config.dart';

class DriverProfileSetupPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DriverProfileSetupPage({Key? key, required this.userData}) : super(key: key);

  @override
  _DriverProfileSetupPageState createState() => _DriverProfileSetupPageState();
}

class _DriverProfileSetupPageState extends State<DriverProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _licenseNumberController = TextEditingController();
  final _experienceController = TextEditingController();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  
  String? _gender;
  DateTime? _licenseExpiryDate;
  File? _profilePhoto;
  File? _licenseFront;
  File? _licenseBack;

  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  final List<String> _availableTruckTypes = [
    "Body Vehicle", "Trailer", "Tipper", "Gas Tanker", "Wind Mill",
    "Concrete Mixer", "Petrol Tank", "Container", "Bulker"
  ];

  List<String> _selectedTruckTypes = [];
  
  // *** NEW: Store user name from multiple sources ***
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    print('📋 Setup page initialized with user data: ${widget.userData}');
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _experienceController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // *** NEW: Load user name from multiple sources ***
  Future<void> _loadUserName() async {
    try {
      // Try to get name from widget.userData first
      _userName = widget.userData['name']?.toString().trim();
      
      print('📋 User name from widget.userData: "$_userName"');
      
      // If not found, try to get from SharedPreferences
      if (_userName == null || _userName!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('userData');
        
        if (userDataString != null) {
          final userData = jsonDecode(userDataString);
          _userName = userData['name']?.toString().trim();
          print('📋 User name from SharedPreferences: "$_userName"');
        }
      }
      
      // If still not found, show error
      if (_userName == null || _userName!.isEmpty) {
        print('❌ User name not found in any source');
        _showError("Unable to retrieve user name. Please go back and complete registration first.");
      } else {
        print('✅ User name loaded successfully: "$_userName"');
        setState(() {}); // Refresh UI to show the name
      }
    } catch (e) {
      print('❌ Error loading user name: $e');
      _showError("Error loading user information: ${e.toString()}");
    }
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          if (type == 'profile') {
            _profilePhoto = File(picked.path);
          } else if (type == 'front') {
            _licenseFront = File(picked.path);
          } else if (type == 'back') {
            _licenseBack = File(picked.path);
          }
        });
      }
    } catch (e) {
      _showError("Failed to pick image: ${e.toString()}");
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
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
        ),
      );
    }
  }

  Future<String> _getSecureToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('authToken');

      if (token == null || token.isEmpty) {
        token = widget.userData['token'];
      }

      if (token == null || token.isEmpty) {
        throw Exception("No authentication token found");
      }

      return token;
    } catch (e) {
      throw Exception("Failed to retrieve authentication token: $e");
    }
  }

  Future<void> _submitProfile() async {
    print('📝 Submit profile called');

    if (_isSubmitting) {
      print('⚠ Already submitting profile, ignoring duplicate call');
      return;
    }

    if (_hasSubmitted) {
      print('⚠ Profile already submitted successfully');
      _showError("Profile has already been submitted");
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    // *** CRITICAL: Enhanced name validation ***
    if (_userName == null || _userName!.isEmpty) {
      print('❌ User name is missing');
      _showError("User name is required. Please go back and complete registration first.");
      
      // Try to reload user name one more time
      await _loadUserName();
      
      if (_userName == null || _userName!.isEmpty) {
        return;
      }
    }

    // Validate required fields
    if (_profilePhoto == null || _licenseFront == null || _licenseBack == null) {
      _showError("Profile photo and both license images are required");
      return;
    }

    if (_licenseExpiryDate == null) {
      _showError("Please select license expiry date");
      return;
    }

    if (_selectedTruckTypes.isEmpty) {
      _showError("Please select at least one truck type");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      print('🔐 Getting authentication token...');
      final token = await _getSecureToken();
      print('🌐 Preparing multipart request...');

      final url = Uri.parse(ApiConfig.driverProfile);
      var request = http.MultipartRequest('POST', url);

      // *** CRITICAL: Authorization Header ***
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'multipart/form-data';

      // *** ENHANCED: Add all required form fields with better validation ***
      print('📋 Using user name: "$_userName"');
      request.fields['name'] = _userName!; // Using validated user name
      request.fields['licenseNumber'] = _licenseNumberController.text.trim();
      request.fields['experience'] = _experienceController.text.trim();
      request.fields['age'] = _ageController.text.trim();
      request.fields['gender'] = _gender ?? '';
      request.fields['location'] = _locationController.text.trim();
      request.fields['knownTruckTypes'] = jsonEncode(_selectedTruckTypes);
      request.fields['licenseExpiryDate'] = _licenseExpiryDate!.toIso8601String();

      print('📋 Form fields added: ${request.fields.keys.toList()}');
      print('📋 Request fields: ${request.fields}');

      // *** CRITICAL: Attach images with proper MIME types ***
      try {
        String? profileMime = lookupMimeType(_profilePhoto!.path);
        request.files.add(await http.MultipartFile.fromPath(
          'profilePhoto',
          _profilePhoto!.path,
          contentType: MediaType.parse(profileMime ?? 'image/jpeg'),
        ));

        String? frontMime = lookupMimeType(_licenseFront!.path);
        request.files.add(await http.MultipartFile.fromPath(
          'licensePhotoFront',
          _licenseFront!.path,
          contentType: MediaType.parse(frontMime ?? 'image/jpeg'),
        ));

        String? backMime = lookupMimeType(_licenseBack!.path);
        request.files.add(await http.MultipartFile.fromPath(
          'licensePhotoBack',
          _licenseBack!.path,
          contentType: MediaType.parse(backMime ?? 'image/jpeg'),
        ));

        print('📸 Images attached: ${request.files.length} files');
      } catch (e) {
        throw Exception("Failed to attach images: $e");
      }

      // *** CRITICAL: Send request with timeout ***
      print('🚀 Sending profile creation request...');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception("Request timeout - please try again");
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      print('📡 Response received: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      // *** CRITICAL: Handle response properly ***
      if (response.statusCode == 201) {
        try {
          final jsonResponse = jsonDecode(response.body);
          print('✅ Profile created successfully');

          setState(() {
            _hasSubmitted = true;
          });

          _showSuccess("Profile created successfully!");
          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            Navigator.pop(context, true);
          }
        } catch (e) {
          print('⚠ JSON parsing failed but status was 201');
          setState(() {
            _hasSubmitted = true;
          });

          _showSuccess("Profile created successfully!");
          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            Navigator.pop(context, true);
          }
        }
      } else {
        // Handle error responses
        String errorMessage = "Unknown error occurred";
        try {
          final jsonResponse = jsonDecode(response.body);
          errorMessage = jsonResponse['message'] ?? jsonResponse['error'] ?? "Server error";
        } catch (e) {
          errorMessage = "Server error: ${response.statusCode}";
        }

        print('❌ Profile creation failed: $errorMessage');
        _showError("Error: $errorMessage");
      }
    } catch (e) {
      print('❌ Profile submission error: $e');
      _showError("Failed to create profile: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Profile Setup"),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // *** ENHANCED: Show name from registration with better validation ***
              Card(
                color: _userName != null && _userName!.isNotEmpty ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person, 
                        color: _userName != null && _userName!.isNotEmpty ? Colors.green : Colors.red
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Full Name (from registration)",
                              style: TextStyle(
                                fontSize: 12,
                                color: _userName != null && _userName!.isNotEmpty ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userName ?? 'Name not found - Please complete registration first',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _userName != null && _userName!.isNotEmpty ? Icons.check_circle : Icons.error,
                        color: _userName != null && _userName!.isNotEmpty ? Colors.green : Colors.red, 
                        size: 20
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // License Number
              TextFormField(
                controller: _licenseNumberController,
                decoration: const InputDecoration(
                  labelText: "License Number *",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? "Enter license number" : null,
              ),

              const SizedBox(height: 16),

              // Experience
              TextFormField(
                controller: _experienceController,
                decoration: const InputDecoration(
                  labelText: "Experience (years) *",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Enter years of experience" : null,
              ),

              const SizedBox(height: 16),

              // Age
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: "Age *",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Enter your age" : null,
              ),

              const SizedBox(height: 16),

              // Gender
              DropdownButtonFormField<String>(
                value: _gender,
                items: ["Male", "Female", "Other"]
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (val) => setState(() => _gender = val),
                decoration: const InputDecoration(
                  labelText: "Gender *",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null ? "Select your gender" : null,
              ),

              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: "Location *",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? "Enter your location" : null,
              ),

              const SizedBox(height: 16),

              // Truck types selection
              const Text(
                "Truck Types You Can Drive *",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTruckTypes.map((type) {
                  final isSelected = _selectedTruckTypes.contains(type);
                  return FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTruckTypes.add(type);
                        } else {
                          _selectedTruckTypes.remove(type);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // License Expiry Date
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(_licenseExpiryDate == null
                      ? "Pick License Expiry Date *"
                      : "Expiry: ${DateFormat('yyyy-MM-dd').format(_licenseExpiryDate!)}"),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2050),
                    );
                    if (picked != null) {
                      setState(() => _licenseExpiryDate = picked);
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Photos Section
              const Text(
                "Upload Photos *",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),

              // Profile Photo
              _buildPhotoUploadCard(
                "Profile Photo",
                Icons.person,
                _profilePhoto,
                () => _pickImage('profile'),
              ),

              const SizedBox(height: 10),

              // License Front
              _buildPhotoUploadCard(
                "License Front",
                Icons.credit_card,
                _licenseFront,
                () => _pickImage('front'),
              ),

              const SizedBox(height: 10),

              // License Back
              _buildPhotoUploadCard(
                "License Back",
                Icons.credit_card_outlined,
                _licenseBack,
                () => _pickImage('back'),
              ),

              const SizedBox(height: 30),

              // *** ENHANCED: Submit Button with name validation ***
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _hasSubmitted || _userName == null || _userName!.isEmpty) 
                      ? null 
                      : _submitProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasSubmitted ? Colors.green : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text("Submitting..."),
                          ],
                        )
                      : _hasSubmitted
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 8),
                                Text("Profile Submitted"),
                              ],
                            )
                          : Text(
                              _userName == null || _userName!.isEmpty 
                                  ? "Complete Registration First" 
                                  : "Submit Profile"
                            ),
                ),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoUploadCard(String title, IconData icon, File? file, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, size: 30),
        title: Text(title),
        subtitle: Text(file == null ? "Required - Tap to select" : "Photo selected"),
        trailing: file == null
            ? const Icon(Icons.add_photo_alternate, color: Colors.blue)
            : const Icon(Icons.check_circle, color: Colors.green),
        onTap: onTap,
      ),
    );
  }
}