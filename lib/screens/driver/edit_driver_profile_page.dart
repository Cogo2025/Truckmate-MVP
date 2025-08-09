import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart';

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

class _EditDriverProfilePageState extends State<EditDriverProfilePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Color scheme
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color secondaryColor = Color(0xFF10B981); // Emerald
  static const Color accentColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color surfaceColor = Color(0xFFF8FAFC); // Light gray
  static const Color cardColor = Colors.white;
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
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
      for (var type in _availableTruckTypes) {
        if (!_knownTruckTypes.contains(type)) {
          _knownTruckTypes.add(type);
        }
      }
    } else {
      _knownTruckTypes = List.from(_availableTruckTypes);
    }

    // Photos
    _licensePhotoUrl = widget.profileData['licensePhoto'];
    _profilePhotoUrl = widget.profileData['profilePhoto'];
  }

  bool _isValidImageFile(File file) {
    final extension = file.path.toLowerCase().split('.').last;
    if (!_allowedImageExtensions.any((ext) => ext.substring(1) == extension)) {
      return false;
    }

    final mimeType = lookupMimeType(file.path);
    if (mimeType == null || !_allowedImageTypes.contains(mimeType)) {
      return false;
    }

    return true;
  }

  Future<void> _pickImage(bool isLicensePhoto) async {
    try {
      final source = await _showImageSourceDialog();
      if (source == null) return;

      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        
        if (!_isValidImageFile(file)) {
          _showError('Please select a valid image file (JPEG, JPG, PNG, or GIF)');
          return;
        }

        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
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
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Select Image Source',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImageSourceOption(
                icon: Icons.photo_library,
                title: 'Gallery',
                subtitle: 'Choose from gallery',
                color: secondaryColor,
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 16),
              _buildImageSourceOption(
                icon: Icons.photo_camera,
                title: 'Camera',
                subtitle: 'Take a new photo',
                color: accentColor,
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: cardColor,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
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
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      if (_nameController.text != widget.userData['name'] || 
          _phoneController.text != widget.userData['phone']) {
        await _updateUserInfo(token);
      }

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
    final request = http.MultipartRequest(
      'PATCH',
      Uri.parse(ApiConfig.driverProfile),
    );
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['experience'] = _experienceController.text.trim();
    request.fields['licenseType'] = _licenseTypeController.text.trim();
    request.fields['licenseNumber'] = _licenseNumberController.text.trim();
    request.fields['licenseExpiryDate'] = _licenseExpiryController.text;
    request.fields['gender'] = _selectedGender ?? '';
    request.fields['age'] = _ageController.text;
    request.fields['location'] = _locationController.text.trim();
    request.fields['knownTruckTypes'] = jsonEncode(_knownTruckTypes);

    if (_licensePhotoFile != null) {
      final mimeType = lookupMimeType(_licensePhotoFile!.path) ?? 'image/jpeg';
      request.files.add(await http.MultipartFile.fromPath(
        'licensePhoto',
        _licensePhotoFile!.path,
        contentType: http_parser.MediaType.parse(mimeType),
      ));
    }

    if (_profilePhotoFile != null) {
      final mimeType = lookupMimeType(_profilePhotoFile!.path) ?? 'image/jpeg';
      request.files.add(await http.MultipartFile.fromPath(
        'profilePhoto',
        _profilePhotoFile!.path,
        contentType: http_parser.MediaType.parse(mimeType),
      ));
    }

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
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isLicensePhoto ? Icons.credit_card : Icons.account_circle,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Photo display
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.1),
                      secondaryColor.withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildPhotoWidget(isLicensePhoto, existingPhotoUrl),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _buildPhotoButton(
                      icon: Icons.cloud_upload_outlined,
                      label: 'Upload Photo',
                      color: primaryColor,
                      onPressed: () => _pickImage(isLicensePhoto),
                    ),
                    const SizedBox(height: 12),
                    _buildPhotoButton(
                      icon: Icons.delete_outline,
                      label: 'Remove Photo',
                      color: errorColor,
                      onPressed: () => _removePhoto(isLicensePhoto),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Supported: JPEG, JPG, PNG, GIF (Max: 5MB)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoWidget(bool isLicensePhoto, String? existingPhotoUrl) {
    if (isLicensePhoto ? _licensePhotoFile != null : _profilePhotoFile != null) {
      return Image.file(
        isLicensePhoto ? _licensePhotoFile! : _profilePhotoFile!,
        fit: BoxFit.cover,
      );
    } else if (existingPhotoUrl != null && existingPhotoUrl.isNotEmpty) {
      return Image.network(
        existingPhotoUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              strokeWidth: 2,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 32),
              const SizedBox(height: 4),
              Text(
                'Failed to load',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          );
        },
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLicensePhoto ? Icons.credit_card : Icons.account_circle,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'No Photo',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      );
    }
  }

  Widget _buildPhotoButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildTruckTypesField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_shipping,
                  color: secondaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Truck Types You Can Drive',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTruckTypes.map((type) {
              final isSelected = _knownTruckTypes.contains(type);
              return FilterChip(
                label: Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? Colors.white : primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
                selectedColor: primaryColor,
                checkmarkColor: Colors.white,
                backgroundColor: primaryColor.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? primaryColor : primaryColor.withOpacity(0.3),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: errorColor, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: errorColor, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey[600]),
          floatingLabelStyle: const TextStyle(color: primaryColor),
        ),
        validator: validator,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
      ),
    );
  }

  Widget _buildCustomDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor),
          filled: true,
          fillColor: surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey[600]),
          floatingLabelStyle: const TextStyle(color: primaryColor),
        ),
        items: items,
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: primaryGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Update your driver information',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            backgroundColor: primaryColor,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitForm,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(_isSubmitting ? 'Saving...' : 'Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: _isLoading
                ? Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                  )
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (_errorMessage != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: errorColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: errorColor),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(color: errorColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Profile Photo Section
                            _buildPhotoField(
                              label: 'Profile Photo',
                              isLicensePhoto: false,
                              existingPhotoUrl: _profilePhotoUrl,
                            ),

                            // Personal Information Section
                            _buildSectionCard(
                              title: 'Personal Information',
                              icon: Icons.person_outline,
                              children: [
                                _buildCustomTextField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                  icon: Icons.person,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),
                                _buildCustomTextField(
                                  controller: _phoneController,
                                  label: 'Phone Number',
                                  icon: Icons.phone,
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
                                _buildCustomDropdown(
                                  label: 'Gender',
                                  icon: Icons.person_outline,
                                  value: _selectedGender,
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
                                _buildCustomTextField(
                                  controller: _ageController,
                                  label: 'Age',
                                  icon: Icons.cake,
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
                                _buildCustomTextField(
                                  controller: _locationController,
                                  label: 'Location',
                                  icon: Icons.location_on,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your location';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),

                            // Driver Information Section
                            _buildSectionCard(
                              title: 'Driver Information',
                              icon: Icons.drive_eta,
                              iconColor: secondaryColor,
                              children: [
                                _buildCustomTextField(
                                  controller: _experienceController,
                                  label: 'Years of Experience',
                                  icon: Icons.work_outline,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your experience';
                                    }
                                    return null;
                                  },
                                ),
                                _buildCustomTextField(
                                  controller: _licenseTypeController,
                                  label: 'License Type',
                                  icon: Icons.credit_card,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your license type';
                                    }
                                    return null;
                                  },
                                ),
                                _buildCustomTextField(
                                  controller: _licenseNumberController,
                                  label: 'License Number',
                                  icon: Icons.confirmation_number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your license number';
                                    }
                                    return null;
                                  },
                                ),
                                _buildCustomTextField(
                                  controller: _licenseExpiryController,
                                  label: 'License Expiry Date',
                                  icon: Icons.calendar_today,
                                  readOnly: true,
                                  onTap: () => _selectDate(context),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.date_range, color: primaryColor),
                                    onPressed: () => _selectDate(context),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select expiry date';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),

                            // Truck Types Section
                            _buildTruckTypesField(),

                            // License Photo Section
                            _buildPhotoField(
                              label: 'License Photo',
                              isLicensePhoto: true,
                              existingPhotoUrl: _licensePhotoUrl,
                            ),

                            // Submit Button
                            Container(
                              width: double.infinity,
                              height: 56,
                              margin: const EdgeInsets.only(bottom: 24),
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
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
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Saving Changes...',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        'Save Changes',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
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
