import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart';
import 'package:truckmate_app/utils/image_utils.dart';
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

  // *** NEW: Track changes for re-verification ***
  bool _needsReVerification = false;
  Set<String> _changedCriticalFields = {};
  
  // Store original values for comparison
  String? _originalName;
  String? _originalLicenseFrontUrl;
  String? _originalLicenseBackUrl;
  List<String> _originalTruckTypes = [];

  // Color scheme definitions
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF10B981);
  static const Color accentColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color surfaceColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();
  final TextEditingController _licenseExpiryController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Photo files and URLs
  File? _licensePhotoFrontFile;
  File? _licensePhotoBackFile;
  File? _profilePhotoFile;
  String? _licensePhotoFrontUrl;
  String? _licensePhotoBackUrl;
  String? _profilePhotoUrl;

  final ImagePicker _picker = ImagePicker();

  // Truck types
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

  // Gender
  String? _selectedGender;

  // Allowed image types/extensions
  final List<String> _allowedImageTypes = [
    'image/jpeg', 'image/jpg', 'image/png', 'image/gif'
  ];
  final List<String> _allowedImageExtensions = [
    '.jpg', '.jpeg', '.png', '.gif'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _animationController.forward();
    _initializeForm();
  }

  // *** FIXED: Proper data initialization ***
  void _initializeForm() {
    print('📋 Initializing form with data:');
    print('User Data: ${widget.userData}');
    print('Profile Data: ${widget.profileData}');

    // *** FIXED: Use correct data sources with fallbacks ***
    // For name and phone, use profile data first, then userData as fallback
    _nameController.text = widget.profileData['userName'] ?? 
                          widget.profileData['name'] ?? 
                          widget.userData['name'] ?? '';
    
    _phoneController.text = widget.profileData['userPhone'] ?? 
                           widget.userData['phone'] ?? '';

    // Store original values for comparison
    _originalName = _nameController.text;

    // Other profile fields
    _ageController.text = widget.profileData['age']?.toString() ?? '';
    _experienceController.text = widget.profileData['experience'] ?? '';
    _licenseNumberController.text = widget.profileData['licenseNumber'] ?? '';
    _locationController.text = widget.profileData['location'] ?? '';
    _selectedGender = widget.profileData['gender'] ?? '';

    // License expiry date
    if (widget.profileData['licenseExpiryDate'] != null) {
      try {
        final expiry = DateTime.parse(widget.profileData['licenseExpiryDate']);
        _licenseExpiryController.text = DateFormat('yyyy-MM-dd').format(expiry);
      } catch (e) {
        print('Error parsing license expiry date: $e');
      }
    }

    // Truck types
    if (widget.profileData['knownTruckTypes'] != null) {
      _knownTruckTypes = List<String>.from(widget.profileData['knownTruckTypes']);
      _originalTruckTypes = List<String>.from(_knownTruckTypes);
    }

    // Photo URLs
    _licensePhotoFrontUrl = widget.profileData['licensePhotoFront'];
    _licensePhotoBackUrl = widget.profileData['licensePhotoBack'];
    _profilePhotoUrl = widget.profileData['profilePhoto'];

    // Store original photo URLs for comparison
    _originalLicenseFrontUrl = _licensePhotoFrontUrl;
    _originalLicenseBackUrl = _licensePhotoBackUrl;

    print('📋 Form initialized successfully');
    print('Name: "${_nameController.text}"');
    print('Phone: "${_phoneController.text}"');
  }

  // *** NEW: Check if critical fields changed ***
  void _checkForCriticalChanges() {
    _changedCriticalFields.clear();
    _needsReVerification = false;

    // Check name change
    if (_nameController.text.trim() != _originalName?.trim()) {
      _changedCriticalFields.add('name');
      print('🔄 Name changed: "${_originalName}" -> "${_nameController.text.trim()}"');
    }

    // Check truck types change
    final currentTruckTypes = List<String>.from(_knownTruckTypes);
    currentTruckTypes.sort();
    _originalTruckTypes.sort();
    
    if (currentTruckTypes.join(',') != _originalTruckTypes.join(',')) {
      _changedCriticalFields.add('knownTruckTypes');
      print('🔄 Truck types changed');
    }

    // Check license photos change
    if (_licensePhotoFrontFile != null || 
        (_licensePhotoFrontUrl != _originalLicenseFrontUrl)) {
      _changedCriticalFields.add('licensePhotoFront');
      print('🔄 License front photo changed');
    }

    if (_licensePhotoBackFile != null || 
        (_licensePhotoBackUrl != _originalLicenseBackUrl)) {
      _changedCriticalFields.add('licensePhotoBack');
      print('🔄 License back photo changed');
    }

    _needsReVerification = _changedCriticalFields.isNotEmpty;
    
    if (_needsReVerification) {
      print('⚠ Re-verification needed for fields: ${_changedCriticalFields.join(', ')}');
    }
  }

  bool _isValidImageFile(File file) {
    final ext = file.path.toLowerCase().split('.').last;
    if (!_allowedImageExtensions.any((e) => e.substring(1) == ext)) return false;
    final mimeType = lookupMimeType(file.path);
    if (mimeType == null || !_allowedImageTypes.contains(mimeType)) return false;
    return true;
  }

  Future<void> _pickImage({required String field}) async {
    try {
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      if (!_isValidImageFile(file)) {
        _showError('Please select a valid image file (JPEG, JPG, PNG, GIF)');
        return;
      }

      final size = await file.length();
      if (size > 5 * 1024 * 1024) {
        _showError('Image file size must be less than 5MB');
        return;
      }

      setState(() {
        if (field == 'profile') {
          _profilePhotoFile = file;
        } else if (field == 'licenseFront') {
          _licensePhotoFrontFile = file;
        } else if (field == 'licenseBack') {
          _licensePhotoBackFile = file;
        }
      });

      // Check for critical changes after photo selection
      _checkForCriticalChanges();
    } catch (e) {
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Select Image Source',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20)
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImageSourceOption(
                icon: Icons.photo_library,
                title: 'Gallery',
                subtitle: 'Choose from gallery',
                color: secondaryColor,
                onTap: () => Navigator.pop(context, ImageSource.gallery)
              ),
              const SizedBox(height: 16),
              _buildImageSourceOption(
                icon: Icons.photo_camera,
                title: 'Camera',
                subtitle: 'Take a new photo',
                color: accentColor,
                onTap: () => Navigator.pop(context, ImageSource.camera)
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
                borderRadius: BorderRadius.circular(10)
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removePhoto(String field) async {
    setState(() {
      if (field == 'profile') {
        _profilePhotoFile = null;
        _profilePhotoUrl = null;
      } else if (field == 'licenseFront') {
        _licensePhotoFrontFile = null;
        _licensePhotoFrontUrl = null;
      } else if (field == 'licenseBack') {
        _licensePhotoBackFile = null;
        _licensePhotoBackUrl = null;
      }
    });

    // Check for critical changes after photo removal
    _checkForCriticalChanges();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: primaryColor,
            onPrimary: Colors.white,
            surface: cardColor,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
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

  // *** NEW: Show re-verification warning ***
  void _showReVerificationDialog() {
    if (!_needsReVerification) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: accentColor),
            const SizedBox(width: 8),
            const Text('Re-verification Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You have made changes to critical fields that require admin re-verification:'),
            const SizedBox(height: 12),
            ..._changedCriticalFields.map((field) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: accentColor),
                  const SizedBox(width: 8),
                  Text(_getCriticalFieldLabel(field)),
                ],
              ),
            )),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Your profile will be marked as "Pending Verification" and you won\'t receive job opportunities until admin approval.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _performSubmit();
      }
    });
  }

  String _getCriticalFieldLabel(String field) {
    switch (field) {
      case 'name': return 'Full Name';
      case 'knownTruckTypes': return 'Truck Types';
      case 'licensePhotoFront': return 'License Photo (Front)';
      case 'licensePhotoBack': return 'License Photo (Back)';
      default: return field;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Check for critical changes
    _checkForCriticalChanges();

    // Show re-verification dialog if needed
    if (widget.profileData['verificationStatus'] == 'rejected') {
  // Show message that verification will be resubmitted
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Profile updated and verification resubmitted!"),
      backgroundColor: Colors.green,
    ),
  );
}
    
  }

  Future<void> _performSubmit() async {
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
      // Update user info if name or phone changed
      if (_nameController.text.trim() != (_originalName?.trim() ?? '') ||
          _phoneController.text.trim() != (widget.userData['phone'] ?? '')) {
        await _updateUserInfo(token);
      }

      // Update driver profile
      await _updateDriverProfile(token);

      if (mounted) {
        if (_needsReVerification) {
          _showSuccess('Profile updated successfully! Your changes are pending admin verification.');
        } else {
          _showSuccess('Profile updated successfully!');
        }
        
        // Navigate back to profile page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DriverMainNavigation())
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = "Failed to update profile: ${e.toString()}";
      });
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
    var request = http.MultipartRequest('PATCH', Uri.parse(ApiConfig.driverProfile));
    request.headers['Authorization'] = 'Bearer $token';

    // Add form fields
    request.fields['experience'] = _experienceController.text.trim();
    request.fields['licenseNumber'] = _licenseNumberController.text.trim();
    request.fields['licenseExpiryDate'] = _licenseExpiryController.text;
    request.fields['gender'] = _selectedGender ?? '';
    request.fields['age'] = _ageController.text;
    request.fields['location'] = _locationController.text.trim();
    request.fields['knownTruckTypes'] = jsonEncode(_knownTruckTypes);

    // *** NEW: Add re-verification flag if needed ***
    if (_needsReVerification) {
      request.fields['requiresReVerification'] = 'true';
      request.fields['changedFields'] = jsonEncode(_changedCriticalFields.toList());
    }

    // Add photos if selected
    if (_licensePhotoFrontFile != null) {
      String? mimeType = lookupMimeType(_licensePhotoFrontFile!.path);
      request.files.add(await http.MultipartFile.fromPath(
        'licensePhotoFront',
        _licensePhotoFrontFile!.path,
        contentType: http_parser.MediaType.parse(mimeType ?? 'image/jpeg'),
      ));
    }

    if (_licensePhotoBackFile != null) {
      String? mimeType = lookupMimeType(_licensePhotoBackFile!.path);
      request.files.add(await http.MultipartFile.fromPath(
        'licensePhotoBack',
        _licensePhotoBackFile!.path,
        contentType: http_parser.MediaType.parse(mimeType ?? 'image/jpeg'),
      ));
    }

    if (_profilePhotoFile != null) {
      String? mimeType = lookupMimeType(_profilePhotoFile!.path);
      request.files.add(await http.MultipartFile.fromPath(
        'profilePhoto',
        _profilePhotoFile!.path,
        contentType: http_parser.MediaType.parse(mimeType ?? 'image/jpeg'),
      ));
    }

    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      final errorData = jsonDecode(responseData);
      throw Exception(errorData['error'] ?? 'Failed to update profile');
    }

    print('Profile updated successfully. Response: $responseData');
  }

  Widget _buildPhotoField({
    required String label,
    required String field,
    String? existingPhotoUrl,
  }) {
    File? file;
    if (field == 'profile') file = _profilePhotoFile;
    else if (field == 'licenseFront') file = _licensePhotoFrontFile;
    else if (field == 'licenseBack') file = _licensePhotoBackFile;

    final isLicensePhoto = field.startsWith('license');

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
            offset: const Offset(0, 2)
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
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Icon(
                  isLicensePhoto ? Icons.credit_card : Icons.account_circle,
                  color: primaryColor,
                  size: 20
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87
                )
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.1),
                      secondaryColor.withOpacity(0.1)
                    ]
                  ),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 2
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildPhotoWidget(file, existingPhotoUrl, isLicensePhoto),
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
                      onPressed: () => _pickImage(field: field),
                    ),
                    const SizedBox(height: 12),
                    _buildPhotoButton(
                      icon: Icons.delete_outline,
                      label: 'Remove Photo',
                      color: errorColor,
                      onPressed: () => _removePhoto(field),
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
              borderRadius: BorderRadius.circular(8)
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Supported: JPEG, JPG, PNG, GIF (Max: 5MB)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500
                    )
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoWidget(File? file, String? existingPhotoUrl, bool isLicensePhoto) {
    if (file != null) {
      return Image.file(file, fit: BoxFit.cover);
    } else if (existingPhotoUrl != null && existingPhotoUrl.isNotEmpty) {
      if (existingPhotoUrl.startsWith('http')) {
        return Image.network(
          existingPhotoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(isLicensePhoto),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null
              )
            );
          },
        );
      } else if (existingPhotoUrl.startsWith('data:image')) {
        final bytes = ImageUtils.decodeBase64Image(existingPhotoUrl);
        if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
      }
    }
    return _buildPlaceholderIcon(isLicensePhoto);
  }

  Widget _buildPlaceholderIcon(bool isLicensePhoto) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isLicensePhoto ? Icons.credit_card : Icons.account_circle,
          size: 40,
          color: Colors.grey[400]
        ),
        const SizedBox(height: 8),
        Text(
          'No Photo',
          style: TextStyle(fontSize: 12, color: Colors.grey)
        ),
      ],
    );
  }

  Widget _buildPhotoButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed
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
            offset: const Offset(0, 2)
          )
        ]
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
                  borderRadius: BorderRadius.circular(8)
                ),
                child: const Icon(Icons.local_shipping, color: secondaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Truck Types You Can Drive',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87
                )
              ),
            ]
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
                    fontWeight: FontWeight.w500
                  )
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
                  // Check for critical changes after truck type selection
                  _checkForCriticalChanges();
                },
                selectedColor: primaryColor,
                checkmarkColor: Colors.white,
                backgroundColor: primaryColor.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? primaryColor : primaryColor.withOpacity(0.3)
                  )
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
    Color? iconColor
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
            offset: const Offset(0, 2)
          )
        ]
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
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Icon(icon, color: iconColor ?? primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87
                )
              ),
            ]
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
    VoidCallback? onChanged,
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
            borderSide: BorderSide.none
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2)
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: errorColor, width: 2)
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: errorColor, width: 2)
          ),
          labelStyle: TextStyle(color: Colors.grey[600]),
          floatingLabelStyle: const TextStyle(color: primaryColor),
        ),
        validator: validator,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged != null ? (value) {
          onChanged();
          // Check for critical changes on name field
          if (icon == Icons.person) {
            _checkForCriticalChanges();
          }
        } : null,
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
            borderSide: BorderSide.none
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2)
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

  // *** NEW: Build re-verification warning card ***
  Widget _buildReVerificationWarning() {
    _checkForCriticalChanges();
    
    if (!_needsReVerification) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: accentColor),
              const SizedBox(width: 8),
              const Text(
                'Re-verification Required',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: accentColor
                )
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You have made changes to critical fields. Your profile will be re-reviewed by admin.',
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'Changed fields: ${_changedCriticalFields.map(_getCriticalFieldLabel).join(', ')}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
                decoration: const BoxDecoration(gradient: primaryGradient),
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
                            fontWeight: FontWeight.bold
                          )
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Update your driver information',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16
                          )
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(_isSubmitting ? 'Saving...' : 'Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        valueColor: AlwaysStoppedAnimation(primaryColor)
                      )
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
                                    const Icon(Icons.error_outline, color: errorColor),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: errorColor))),
                                  ],
                                ),
                              ),

                            // *** NEW: Re-verification warning ***
                            _buildReVerificationWarning(),

                            _buildPhotoField(
                              label: 'Profile Photo',
                              field: 'profile',
                              existingPhotoUrl: _profilePhotoUrl
                            ),
                            _buildPhotoField(
                              label: 'License Photo (Front)',
                              field: 'licenseFront',
                              existingPhotoUrl: _licensePhotoFrontUrl
                            ),
                            _buildPhotoField(
                              label: 'License Photo (Back)',
                              field: 'licenseBack',
                              existingPhotoUrl: _licensePhotoBackUrl
                            ),

                            _buildSectionCard(
                              title: 'Personal Information',
                              icon: Icons.person_outline,
                              children: [
                                _buildCustomTextField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                  icon: Icons.person,
                                  validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
                                  onChanged: () {}, // Enable change detection
                                ),
                                _buildCustomTextField(
                                  controller: _phoneController,
                                  label: 'Phone Number',
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Please enter your phone number';
                                    if (!RegExp(r'^[+]?[\d\s\-\(\)]{10,}$').hasMatch(value)) return 'Please enter a valid phone number';
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
                                  onChanged: (value) => setState(() => _selectedGender = value),
                                  validator: (value) => value == null || value.isEmpty ? 'Please select your gender' : null,
                                ),
                                _buildCustomTextField(
                                  controller: _ageController,
                                  label: 'Age',
                                  icon: Icons.cake,
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Please enter your age';
                                    if (int.tryParse(value) == null) return 'Please enter a valid number';
                                    return null;
                                  },
                                ),
                                _buildCustomTextField(
                                  controller: _locationController,
                                  label: 'Location',
                                  icon: Icons.location_on,
                                  validator: (value) => value == null || value.isEmpty ? 'Please enter your location' : null,
                                ),
                              ],
                            ),

                            _buildSectionCard(
                              title: 'Driver Information',
                              icon: Icons.drive_eta,
                              iconColor: secondaryColor,
                              children: [
                                _buildCustomTextField(
                                  controller: _experienceController,
                                  label: 'Years of Experience',
                                  icon: Icons.work_outline,
                                  validator: (value) => value == null || value.isEmpty ? 'Please enter your experience' : null,
                                ),
                                _buildCustomTextField(
                                  controller: _licenseNumberController,
                                  label: 'License Number',
                                  icon: Icons.confirmation_number,
                                  validator: (value) => value == null || value.isEmpty ? 'Please enter your license number' : null,
                                ),
                                _buildCustomTextField(
                                  controller: _licenseExpiryController,
                                  label: 'License Expiry Date',
                                  icon: Icons.calendar_today,
                                  readOnly: true,
                                  onTap: () => _selectDate(context),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.date_range, color: primaryColor),
                                    onPressed: () => _selectDate(context)
                                  ),
                                  validator: (value) => value == null || value.isEmpty ? 'Please select expiry date' : null,
                                ),
                              ],
                            ),

                            _buildTruckTypesField(),

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
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                              valueColor: AlwaysStoppedAnimation(Colors.white)
                                            )
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Saving Changes...',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        'Save Changes',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
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
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}