import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart'; // Add this package to pubspec.yaml

import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/driver_main_navigation.dart';
import 'driver_profile_page.dart';

class EditDriverProfilePage extends StatefulWidget {
  final Map<String, dynamic> profileData;
  final Map<String, dynamic> userData;

  const EditDriverProfilePage({
    super.key,
    required this.profileData,
    required this.userData,
  });

  @override
  State<EditDriverProfilePage> createState() => _EditDriverProfilePageState();
}

class _EditDriverProfilePageState extends State<EditDriverProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSubmitting = false;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _licenseTypeController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();
  final TextEditingController _licenseExpiryController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Photo handling
  File? _licensePhotoFile;
  File? _profilePhotoFile;
  String? _licensePhotoUrl;
  String? _profilePhotoUrl;
  final ImagePicker _picker = ImagePicker();

  // Multiple selection for truck types
  List<String> _knownTruckTypes = [];
  final List<String> _availableTruckTypes = [
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

  // Gender selection
  String? _selectedGender;

  // Allowed image types
  final List<String> _allowedImageTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif'
  ];

  final List<String> _allowedImageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif'
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    // User data
    _nameController.text = widget.userData['name'] ?? '';
    _phoneController.text = widget.userData['phone'] ?? '';

    // Profile data
    _ageController.text = widget.profileData['age']?.toString() ?? '';
    _experienceController.text = widget.profileData['experience'] ?? '';
    _licenseTypeController.text = widget.profileData['licenseType'] ?? '';
    _licenseNumberController.text = widget.profileData['licenseNumber'] ?? '';
    _locationController.text = widget.profileData['location'] ?? '';
    _selectedGender = widget.profileData['gender'] ?? '';

    // License expiry date
    if (widget.profileData['licenseExpiryDate'] != null) {
      final expiryDate = DateTime.parse(widget.profileData['licenseExpiryDate']);
      _licenseExpiryController.text = DateFormat('yyyy-MM-dd').format(expiryDate);
    }

    // Truck types
    if (widget.profileData['knownTruckTypes'] != null) {
      _knownTruckTypes = List<String>.from(widget.profileData['knownTruckTypes']);
      // Add any new types that weren't previously in the profile but are in our master list
      for (var type in _availableTruckTypes) {
        if (!_knownTruckTypes.contains(type)) {
          _knownTruckTypes.add(type);
        }
      }
    } else {
      // If no truck types were stored before, initialize with all available types
      _knownTruckTypes = List.from(_availableTruckTypes);
    }

    // Photos
    _licensePhotoUrl = widget.profileData['licensePhoto'];
    _profilePhotoUrl = widget.profileData['profilePhoto'];
  }

  bool _isValidImageFile(File file) {
    // Check file extension
    final extension = file.path.toLowerCase().split('.').last;
    if (!_allowedImageExtensions.any((ext) => ext.substring(1) == extension)) {
      return false;
    }

    // Check MIME type
    final mimeType = lookupMimeType(file.path);
    if (mimeType == null || !_allowedImageTypes.contains(mimeType)) {
      return false;
    }

    return true;
  }

  Future<void> _pickImage(bool isLicensePhoto) async {
    try {
      // Show options to pick from camera or gallery
      final source = await _showImageSourceDialog();
      if (source == null) return;

      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Compress image to reduce size
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        
        // Validate the image file
        if (!_isValidImageFile(file)) {
          _showError('Please select a valid image file (JPEG, JPG, PNG, or GIF)');
          return;
        }

        // Check file size (optional - limit to 5MB)
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) { // 5MB limit
          _showError('Image file size must be less than 5MB');
          return;
        }

        setState(() {
          if (isLicensePhoto) {
            _licensePhotoFile = file;
          } else {
            _profilePhotoFile = file;
          }
        });
      }
    } catch (e) {
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removePhoto(bool isLicensePhoto) async {
    setState(() {
      if (isLicensePhoto) {
        _licensePhotoFile = null;
        _licensePhotoUrl = null;
      } else {
        _profilePhotoFile = null;
        _profilePhotoUrl = null;
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _licenseExpiryController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = "Authentication token missing. Please log in again.";
      });
      return;
    }

    try {
      // First update user info if changed
      if (_nameController.text != widget.userData['name'] || 
          _phoneController.text != widget.userData['phone']) {
        await _updateUserInfo(token);
      }

      // Then update driver profile
      await _updateDriverProfile(token);

      if (mounted) {
        _showSuccess('Profile updated successfully!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DriverMainNavigation(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = "Failed to update profile: ${e.toString()}";
      });
      debugPrint("Profile update error: $e");
    }
  }

  Future<void> _updateUserInfo(String token) async {
    final response = await http.patch(
      Uri.parse(ApiConfig.updateUser),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to update user info: ${response.statusCode}");
    }
  }

  Future<void> _updateDriverProfile(String token) async {
    // Create multipart request
    final request = http.MultipartRequest(
      'PATCH',
      Uri.parse(ApiConfig.driverProfile),
    );
    request.headers['Authorization'] = 'Bearer $token';

    // Add text fields
    request.fields['experience'] = _experienceController.text.trim();
    request.fields['licenseType'] = _licenseTypeController.text.trim();
    request.fields['licenseNumber'] = _licenseNumberController.text.trim();
    request.fields['licenseExpiryDate'] = _licenseExpiryController.text;
    request.fields['gender'] = _selectedGender ?? '';
    request.fields['age'] = _ageController.text;
    request.fields['location'] = _locationController.text.trim();
    request.fields['knownTruckTypes'] = jsonEncode(_knownTruckTypes);

    // Add license photo if selected
    if (_licensePhotoFile != null) {
      final mimeType = lookupMimeType(_licensePhotoFile!.path) ?? 'image/jpeg';
      request.files.add(await http.MultipartFile.fromPath(
        'licensePhoto',
        _licensePhotoFile!.path,
        contentType: http_parser.MediaType.parse(mimeType),
      ));
    }

    // Add profile photo if selected
    if (_profilePhotoFile != null) {
      final mimeType = lookupMimeType(_profilePhotoFile!.path) ?? 'image/jpeg';
      request.files.add(await http.MultipartFile.fromPath(
        'profilePhoto',
        _profilePhotoFile!.path,
        contentType: http_parser.MediaType.parse(mimeType),
      ));
    }

    // Send request
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      final errorData = jsonDecode(responseBody);
      throw Exception(errorData['error'] ?? 'Failed to update profile');
    }
  }

  Widget _buildPhotoField({
    required String label,
    required bool isLicensePhoto,
    String? existingPhotoUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Display current photo or placeholder
            if (isLicensePhoto ? _licensePhotoFile != null : _profilePhotoFile != null)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    isLicensePhoto ? _licensePhotoFile! : _profilePhotoFile!,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else if (existingPhotoUrl != null && existingPhotoUrl.isNotEmpty)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    existingPhotoUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: Colors.grey),
                          Text('Failed to load', style: TextStyle(fontSize: 10)),
                        ],
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_camera, size: 40, color: Colors.grey),
                    Text('No Image', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            const SizedBox(width: 16),
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(isLicensePhoto),
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _removePhoto(isLicensePhoto),
                  icon: const Icon(Icons.delete),
                  label: const Text('Remove'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Supported formats: JPEG, JPG, PNG, GIF (Max size: 5MB)',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTruckTypesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Truck Types You Can Drive',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableTruckTypes.map((type) {
            final isSelected = _knownTruckTypes.contains(type);
            return FilterChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _knownTruckTypes.add(type);
                  } else {
                    _knownTruckTypes.remove(type);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSubmitting ? null : _submitForm,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Personal Information Section
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (!RegExp(r'^[+]?[\d\s\-\(\)]{10,}$').hasMatch(value)) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your gender';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your age';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your location';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Profile Photo Section
                    _buildPhotoField(
                      label: 'Profile Photo',
                      isLicensePhoto: false,
                      existingPhotoUrl: _profilePhotoUrl,
                    ),
                    // Driver Information Section
                    const Text(
                      'Driver Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    TextFormField(
                      controller: _experienceController,
                      decoration: const InputDecoration(
                        labelText: 'Years of Experience',
                        prefixIcon: Icon(Icons.work),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your experience';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _licenseTypeController,
                      decoration: const InputDecoration(
                        labelText: 'License Type',
                        prefixIcon: Icon(Icons.drive_eta),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your license type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _licenseNumberController,
                      decoration: const InputDecoration(
                        labelText: 'License Number',
                        prefixIcon: Icon(Icons.confirmation_number),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your license number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _licenseExpiryController,
                      decoration: InputDecoration(
                        labelText: 'License Expiry Date',
                        prefixIcon: const Icon(Icons.calendar_today),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.date_range),
                          onPressed: () => _selectDate(context),
                        ),
                      ),
                      readOnly: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select expiry date';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Truck Types Section
                    _buildTruckTypesField(),
                    // License Photo Section
                    _buildPhotoField(
                      label: 'License Photo',
                      isLicensePhoto: true,
                      existingPhotoUrl: _licensePhotoUrl,
                    ),
                    const SizedBox(height: 24),
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSubmitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Saving...'),
                                ],
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _experienceController.dispose();
    _licenseTypeController.dispose();
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}