import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart';
import 'package:truckmate_app/api_config.dart';

class DriverProfileSetupPage extends StatefulWidget {
  final Map userData;

  const DriverProfileSetupPage({Key? key, required this.userData}) : super(key: key);

  @override
  _DriverProfileSetupPageState createState() => _DriverProfileSetupPageState();
}

class _DriverProfileSetupPageState extends State<DriverProfileSetupPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _licenseNumberController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _ageController = TextEditingController();

  String? _gender;
  String? _selectedExperience;
  String? _selectedLocation;
  DateTime? _licenseExpiryDate;
  File? _profilePhoto;
  File? _licenseFront;
  File? _licenseBack;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  String? _errorMessage;
  String? _userName;

  final ImagePicker _picker = ImagePicker();

  // Animation controllers matching owner side
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Color scheme matching owner side
  static const Color primaryColor = Color(0xFF00BCD4); // Cyan
  static const Color secondaryColor = Color(0xFF1976D2); // Blue
  static const Color accentColor = Color(0xFFFF6F00); // Orange
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color successColor = Color(0xFF26C6DA); // Light cyan
  static const Color surfaceColor = Color(0xFFF8FAFC); // Light gray
  static const Color cardColor = Colors.white;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final List<String> _availableTruckTypes = [
    "Body Vehicle", "Trailer", "Tipper", "Gas Tanker", "Wind Mill",
    "Concrete Mixer", "Petrol Tank", "Container", "Bulker"
  ];

  final List<String> _experienceOptions = [
    "0-1 years", "1-2 years", "2-5 years", "5-10 years",
    "10-15 years", "15-20 years", "20+ years"
  ];

  final List<String> _tamilNaduDistricts = [
    "Ariyalur", "Chengalpattu", "Chennai", "Coimbatore",
    "Cuddalore", "Dharmapuri", "Dindigul", "Erode",
    "Kallakurichi", "Kancheepuram", "Karur",
    "Krishnagiri", "Madurai", "Mayiladuthurai", "Nagapattinam",
    "Namakkal", "Nilgiris", "Perambalur", "Pudukkottai",
    "Ramanathapuram", "Ranipet", "Salem", "Sivaganga",
    "Tenkasi", "Thanjavur", "Theni", "Thoothukudi",
    "Tiruchirappalli", "Tirunelveli", "Tirupathur", "Tiruppur",
    "Tiruvallur", "Tiruvannamalai", "Tiruvarur", "Vellore",
    "Viluppuram", "Virudhunagar"
  ];

  List<String> _selectedTruckTypes = [];

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
    _loadUserName();
    print('📋 Setup page initialized with user data: ${widget.userData}');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _licenseNumberController.dispose();
    _phoneNumberController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // Enhanced validation functions
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return "Phone number is required";
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return "Phone number must contain only numbers";
    }
    if (value.length != 10) {
      return "Phone number must be 10 digits";
    }
    return null;
  }

  String? _validateAge(String? value) {
    if (value == null || value.isEmpty) {
      return "Age is required";
    }
    final age = int.tryParse(value);
    if (age == null) {
      return "Age must be a valid number";
    }
    if (age < 18) {
      return "Age must be at least 18 years";
    }
    if (age >= 100) {
      return "Age must be less than 100 years";
    }
    return null;
  }

  String? _validateExperienceAgainstAge() {
    if (_selectedExperience == null || _ageController.text.isEmpty) {
      return null;
    }
    final age = int.tryParse(_ageController.text);
    if (age == null) return null;

    int maxExperienceYears = 0;
    if (_selectedExperience!.contains("20+")) {
      maxExperienceYears = 25;
    } else if (_selectedExperience!.contains("-")) {
      final parts = _selectedExperience!.split("-");
      if (parts.length >= 2) {
        final endYears = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
        maxExperienceYears = int.tryParse(endYears) ?? 0;
      }
    } else if (_selectedExperience!.contains("0-1")) {
      maxExperienceYears = 1;
    }

    final possibleExperience = age - 18;
    if (maxExperienceYears > possibleExperience) {
      return "Experience cannot exceed $possibleExperience years based on your age";
    }
    return null;
  }

  Future<void> _loadUserName() async {
    try {
      _userName = widget.userData['name']?.toString().trim();
      print('📋 User name from widget.userData: "$_userName"');
      if (_userName == null || _userName!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('userData');
        if (userDataString != null) {
          final userData = jsonDecode(userDataString);
          _userName = userData['name']?.toString().trim();
          print('📋 User name from SharedPreferences: "$_userName"');
        }
      }
      if (_userName == null || _userName!.isEmpty) {
        print('❌ User name not found in any source');
        _showError("Unable to retrieve user name. Please go back and complete registration first.");
      } else {
        print('✅ User name loaded successfully: "$_userName"');
        setState(() {});
      }
    } catch (e) {
      print('❌ Error loading user name: $e');
      _showError("Error loading user information: ${e.toString()}");
    }
  }

  Future<void> _showImageSourceDialog(String type) async {
    final result = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Select ${type == 'profile' ? 'Profile Photo' : 'License Photo'}',
            style: const TextStyle(
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

    if (result != null) {
      await _pickImage(type, result);
    }
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

  Future<void> _pickImage(String type, ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
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
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
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

    // Enhanced validation
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    // Additional experience vs age validation
    final experienceAgeError = _validateExperienceAgainstAge();
    if (experienceAgeError != null) {
      _showError(experienceAgeError);
      return;
    }

    if (_userName == null || _userName!.isEmpty) {
      print('❌ User name is missing');
      _showError("User name is required. Please go back and complete registration first.");
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
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'multipart/form-data';

      // Enhanced form fields with new validations
      print('📋 Using user name: "$_userName"');
      request.fields['name'] = _userName!;
      request.fields['licenseNumber'] = _licenseNumberController.text.trim();
      request.fields['phoneNumber'] = _phoneNumberController.text.trim();
      request.fields['experience'] = _selectedExperience ?? '';
      request.fields['age'] = _ageController.text.trim();
      request.fields['gender'] = _gender ?? '';
      request.fields['location'] = _selectedLocation ?? '';
      request.fields['knownTruckTypes'] = jsonEncode(_selectedTruckTypes);
      request.fields['licenseExpiryDate'] = _licenseExpiryDate!.toIso8601String();

      print('📋 Form fields added: ${request.fields.keys.toList()}');
      print('📋 Request fields: ${request.fields}');

      // Attach images
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

  Widget _buildGradientCard({
    required Widget child,
    Color? startColor,
    Color? endColor,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            startColor ?? Colors.white,
            endColor ?? surfaceColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
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
        inputFormatters: inputFormatters,
        onChanged: onChanged,
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
    String? errorText,
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
          errorText: errorText,
        ),
        items: items,
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  Widget _buildUserNameCard() {
    return _buildGradientCard(
      startColor: _userName != null && _userName!.isNotEmpty ? Colors.green[50] : Colors.red[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_userName != null && _userName!.isNotEmpty ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person,
                  color: _userName != null && _userName!.isNotEmpty ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'User Information',
                style: TextStyle(
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
                size: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoUploadSection() {
    return _buildGradientCard(
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
                child: const Icon(Icons.photo_camera, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Upload Photos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPhotoUploadCard(
            "Profile Photo",
            Icons.account_circle,
            _profilePhoto,
            () => _showImageSourceDialog('profile'),
          ),
          const SizedBox(height: 12),
          _buildPhotoUploadCard(
            "License Front",
            Icons.credit_card,
            _licenseFront,
            () => _showImageSourceDialog('front'),
          ),
          const SizedBox(height: 12),
          _buildPhotoUploadCard(
            "License Back",
            Icons.credit_card_outlined,
            _licenseBack,
            () => _showImageSourceDialog('back'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoUploadCard(String title, IconData icon, File? file, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: file != null ? successColor.withOpacity(0.1) : surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: file != null ? successColor.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: file != null ? successColor : Colors.grey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          file == null ? "Required - Tap to select" : "Photo selected ✓",
          style: TextStyle(
            color: file != null ? successColor : Colors.grey[600],
            fontWeight: file != null ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        trailing: Icon(
          file == null ? Icons.add_photo_alternate : Icons.check_circle,
          color: file != null ? successColor : primaryColor,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildTruckTypesSection() {
    return _buildGradientCard(
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
                child: const Icon(Icons.local_shipping, color: accentColor, size: 20),
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
                selectedColor: primaryColor.withOpacity(0.2),
                checkmarkColor: primaryColor,
                backgroundColor: surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? primaryColor : Colors.grey.withOpacity(0.3),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedTruckTypes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Please select at least one truck type",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLicenseExpiryCard() {
    return _buildGradientCard(
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
                child: const Icon(Icons.calendar_today, color: secondaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'License Expiry Date',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
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
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _licenseExpiryDate != null ? successColor.withOpacity(0.1) : surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _licenseExpiryDate != null ? successColor.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: _licenseExpiryDate != null ? successColor : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _licenseExpiryDate == null
                          ? "Select License Expiry Date *"
                          : "Expiry: ${DateFormat('dd MMM yyyy').format(_licenseExpiryDate!)}",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _licenseExpiryDate != null ? Colors.black87 : Colors.grey[600],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ],
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
                          'Driver Profile Setup',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Complete your driver profile to start earning',
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
                  onPressed: (_isSubmitting || _hasSubmitted || _userName == null || _userName!.isEmpty)
                      ? null
                      : _submitProfile,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : _hasSubmitted
                          ? const Icon(Icons.check_circle, size: 18)
                          : const Icon(Icons.save, size: 18),
                  label: Text(_isSubmitting
                      ? 'Saving...'
                      : _hasSubmitted
                          ? 'Saved'
                          : 'Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasSubmitted ? successColor : Colors.white,
                    foregroundColor: _hasSubmitted ? Colors.white : primaryColor,
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
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // User Name Section
                      _buildUserNameCard(),

                      // Personal Information Section
                      _buildGradientCard(
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
                                  child: const Icon(
                                    Icons.person_outline,
                                    color: secondaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Personal Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildCustomTextField(
                              controller: _phoneNumberController,
                              label: 'Phone Number *',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: _validatePhoneNumber,
                            ),
                            _buildCustomTextField(
                              controller: _ageController,
                              label: 'Age *',
                              icon: Icons.cake,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              validator: _validateAge,
                              onChanged: (value) {
                                if (_selectedExperience != null) {
                                  setState(() {});
                                }
                              },
                            ),
                            _buildCustomDropdown(
                              label: 'Gender *',
                              icon: Icons.person_outline,
                              value: _gender,
                              items: ["Male", "Female", "Other"]
                                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (val) => setState(() => _gender = val),
                              validator: (v) => v == null ? "Select your gender" : null,
                            ),
                          ],
                        ),
                      ),

                      // Professional Information Section
                      _buildGradientCard(
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
                                  child: const Icon(
                                    Icons.work_outline,
                                    color: accentColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Professional Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildCustomTextField(
                              controller: _licenseNumberController,
                              label: 'License Number *',
                              icon: Icons.credit_card,
                              validator: (v) => v!.isEmpty ? "Enter license number" : null,
                            ),
                            _buildCustomDropdown(
                              label: 'Driving Experience *',
                              icon: Icons.timeline,
                              value: _selectedExperience,
                              items: _experienceOptions
                                  .map((exp) => DropdownMenuItem(value: exp, child: Text(exp)))
                                  .toList(),
                              onChanged: (val) => setState(() => _selectedExperience = val),
                              validator: (v) => v == null ? "Select your driving experience" : null,
                              errorText: _validateExperienceAgainstAge(),
                            ),
                            _buildCustomDropdown(
                              label: 'Location (Tamil Nadu District) *',
                              icon: Icons.location_on,
                              value: _selectedLocation,
                              items: _tamilNaduDistricts
                                  .map((district) => DropdownMenuItem(value: district, child: Text(district)))
                                  .toList(),
                              onChanged: (val) => setState(() => _selectedLocation = val),
                              validator: (v) => v == null ? "Select your district" : null,
                            ),
                          ],
                        ),
                      ),

                      // Truck Types Section
                      _buildTruckTypesSection(),

                      // License Expiry Section
                      _buildLicenseExpiryCard(),

                      // Photos Section
                      _buildPhotoUploadSection(),

                      // Submit Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        margin: const EdgeInsets.only(bottom: 24),
                        child: ElevatedButton(
                          onPressed: (_isSubmitting || _hasSubmitted || _userName == null || _userName!.isEmpty)
                              ? null
                              : _submitProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasSubmitted ? successColor : primaryColor,
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
                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Submitting Profile...',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                )
                              : _hasSubmitted
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text(
                                          "Profile Submitted",
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _userName == null || _userName!.isEmpty
                                          ? "Complete Registration First"
                                          : "Submit Profile",
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
}
