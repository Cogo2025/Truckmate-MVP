import 'dart:convert';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/owner/my_posted_jobs_page.dart';
import 'package:truckmate_app/screens/welcome_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'owner_profile_setup.dart';


class OwnerProfilePage extends StatefulWidget {

  final Map<String, dynamic>? registerInfo;
  final bool? profileCompleted;
  const OwnerProfilePage({super.key,
  this.registerInfo, 
    this.profileCompleted});
  

  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> with SingleTickerProviderStateMixin {

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch the requested app')),
      );
    }
  }

  bool isLoading = true;
  bool isEditing = false;
  bool isUpdating = false;
  Map<String, dynamic> userData = {};
  Map<String, dynamic> profileData = {};


  String? errorMessage;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Enhanced Material Design Colors matching driver side
  static const Color primaryColor = Color(0xFF00BCD4); // Cyan matching driver
  static const Color secondaryColor = Color(0xFF1976D2); // Blue
  static const Color accentColor = Color(0xFFFF6F00); // Orange
  static const Color errorColor = Color(0xFFD32F2F); // Red
  static const Color successColor = Color(0xFF26C6DA); // Light cyan
  static const Color warningColor = Color(0xFFF57C00); // Warning Orange
  static const Color cardColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Color(0xFFF5F7FA);
final Color quickActionColor = Colors.teal;       // instead of accentColor
final Color buttonColor = Colors.deepPurple;      // instead of primaryColor
final Color supportColor = const Color.fromARGB(255, 25, 219, 164); 
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
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.0, end: 1.0));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyNameController.dispose();
    _companyLocationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // Build gradient card widget matching driver side
  Widget _buildGradientCard({
    required Widget child,
    Color? startColor,
    Color? endColor,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            startColor ?? Colors.white,
            endColor ?? cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (startColor ?? primaryColor).withOpacity(0.1),
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

  Widget _buildInfoTile(String label, String value, {IconData? icon, Color? iconColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
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
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children, {IconData? titleIcon, Color? titleColor}) {
    return _buildGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (titleIcon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (titleColor ?? primaryColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    titleIcon,
                    color: titleColor ?? primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: titleColor ?? primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildIncompleteProfileBanner() {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: Colors.orange[800]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete Profile for Full Accessibility',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add company details and complete your profile to access all features.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OwnerProfileSetupPage()),
            );
          },
          child: const Text('Complete'),
        ),
      ],
    ),
  );
}


  Future fetchOwnerProfile() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('authToken');
  if (token == null) {
    setState(() {
      isLoading = false;
      errorMessage = "Token missing. Please log in.";
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

    if (userRes.statusCode == 200) {
      final userDataResponse = jsonDecode(userRes.body);
      
      // For new users, use register info if profile incomplete
      if (widget.profileCompleted == false && widget.registerInfo != null) {
        setState(() {
          this.userData = {
            'name': widget.registerInfo!['name'] ?? '',
            'email': widget.registerInfo!['email'] ?? '',
            'phone': widget.registerInfo!['phone'] ?? '',
            'photoUrl': widget.registerInfo!['photoUrl'] ?? '',
          };
          profileData = {}; // Empty profile data for new users
          isLoading = false;
          _nameController.text = this.userData["name"] ?? "";
          _phoneController.text = this.userData["phone"] ?? "";
          _companyNameController.text = "";
          _companyLocationController.text = "";
          _selectedGender = "Not Specified";
        });
      } else if (profileRes.statusCode == 200) {
        // Existing complete profile logic
        setState(() {
          this.userData = userDataResponse;
          profileData = jsonDecode(profileRes.body);
          isLoading = false;
          _nameController.text = this.userData["name"] ?? "";
          _phoneController.text = this.userData["phone"] ?? "";
          _companyNameController.text = profileData["companyName"] ?? "";
          _companyLocationController.text = profileData["companyLocation"] ?? "";
          _selectedGender = profileData["gender"] ?? "Not Specified";
        });
      }
      _fadeController.forward();
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



  Future _refreshProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    await fetchOwnerProfile();
  }

Future _showImageSourceDialog() async {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Wrap(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Select Photo Source',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, ImageSource.camera),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    size: 32,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Camera',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, ImageSource.gallery),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: secondaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: secondaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.photo_library,
                                    size: 32,
                                    color: secondaryColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Gallery',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: secondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
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
    },
  );
}

Future _pickImage() async {
  try {
    // Show source selection dialog
    final ImageSource? source = await _showImageSourceDialog();
    
    if (source == null) return; // User cancelled
    
    final XFile? image = await _picker.pickImage(
      source: source, // Now uses the selected source
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (image != null) {
      String fileName = image.path.toLowerCase();
      if (!fileName.endsWith('.jpg') &&
          !fileName.endsWith('.jpeg') &&
          !fileName.endsWith('.png') &&
          !fileName.endsWith('.gif')) {
        _showSnackBar("Please select a valid image file (JPEG, JPG, PNG, GIF)", Colors.red);
        return;
      }

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

  Widget _buildProfileAvatar() {
    String? photoUrl = profileData['photoUrl'];
    String? googlePhotoUrl = userData['photoUrl'];

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: CircleAvatar(
        radius: 65,
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey[100],
          child: ClipOval(
            child: photoUrl != null && photoUrl.isNotEmpty
                ? Image.network(
                    photoUrl,
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      if (googlePhotoUrl != null && googlePhotoUrl.isNotEmpty) {
                        return Image.network(
                          googlePhotoUrl,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.person, size: 60, color: Colors.grey[600]);
                          },
                        );
                      }
                      return Icon(Icons.person, size: 60, color: Colors.grey);
                    },
                  )
                : googlePhotoUrl != null && googlePhotoUrl.isNotEmpty
                    ? Image.network(
                        googlePhotoUrl,
                        height: 120,
                        width: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.person, size: 60, color: Colors.grey);
                        },
                      )
                    : Icon(Icons.person, size: 60, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == successColor ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _enableEditMode() {
    setState(() {
      isEditing = true;
      _selectedImage = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      isEditing = false;
      _selectedImage = null;
      _nameController.text = userData["name"] ?? "";
      _phoneController.text = userData["phone"] ?? "";
      _companyNameController.text = profileData["companyName"] ?? "";
      _companyLocationController.text = profileData["companyLocation"] ?? "";
      _selectedGender = profileData["gender"] ?? "Not Specified";
    });
  }

  Future _saveProfile() async {
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
      // First update user info
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

      // Then update profile with potential image
      var profileRequest = http.MultipartRequest('PATCH', Uri.parse(ApiConfig.ownerProfile));
      profileRequest.headers['Authorization'] = 'Bearer $token';
      
      // Add text fields
      profileRequest.fields['companyName'] = _companyNameController.text.trim();
      profileRequest.fields['companyLocation'] = _companyLocationController.text.trim();
      profileRequest.fields['gender'] = _selectedGender;
      
      // Add image if selected
      if (_selectedImage != null) {
        final fileExtension = _selectedImage!.path.split('.').last.toLowerCase();
        final mimeType = fileExtension == 'png' 
            ? 'image/png' 
            : fileExtension == 'jpg' || fileExtension == 'jpeg'
                ? 'image/jpeg'
                : 'image/gif';

        profileRequest.files.add(
          await http.MultipartFile.fromPath(
            'photo',
            _selectedImage!.path,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }

      final profileResponse = await profileRequest.send();
      final profileResponseData = await http.Response.fromStream(profileResponse);

      if (userUpdateSuccess && (profileResponse.statusCode == 200 || profileResponse.statusCode == 201)) {
        final jsonResponse = jsonDecode(profileResponseData.body);
        setState(() {
          profileData = jsonResponse['profile'] ?? jsonResponse;
          userData['name'] = _nameController.text.trim();
          userData['phone'] = _phoneController.text.trim();
          _selectedImage = null;
          isEditing = false;
        });
        _showSnackBar("Profile updated successfully!", Colors.green);
      } else {
        String errorMessage = "Failed to update profile";
        if (profileResponse.statusCode != 200) {
          try {
            final errorResponse = jsonDecode(profileResponseData.body);
            errorMessage = errorResponse['error'] ?? errorResponse['message'] ?? errorMessage;
          } catch (e) {
            errorMessage = "Server error: ${profileResponse.statusCode}";
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

  // Add this function for navigation to My Jobs page
  void _navigateToMyJobs() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPostedJobsPage()));
  }

  Widget _editableField(String label, TextEditingController controller,
      {bool isRequired = true, TextInputType? keyboardType}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label + (isRequired ? " *" : ""),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: "Enter $label",
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.deepOrange.shade100),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.deepOrange),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Gender *", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
          const SizedBox(height: 6),
          DropdownButtonFormField(
            value: _selectedGender,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.deepOrange),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            ),
            dropdownColor: Colors.white,
            items: ['Male', 'Female', 'Other', 'Not Specified']
                .map((String value) => DropdownMenuItem(value: value, child: Text(value)))
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

  Widget _buildEditableProfileImage() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          _buildProfileAvatar(),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
            ),
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
    final bool? shouldLogout = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FadeTransition(
        opacity: _fadeAnimation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Are you sure you want to logout?", style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Text("You will need to sign in again to access your account.",
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Logout", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    if (shouldLogout == true) {
      try {
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
                    Text("Logging out...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.of(context).pop(); // Close loading
          await Future.delayed(const Duration(milliseconds: 100));
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const WelcomePage()), (route) => false);
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text("Logged out successfully", style: TextStyle(fontWeight: FontWeight.w500)),
                  ]),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          });
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Logout failed: ${e.toString()}", style: const TextStyle(fontWeight: FontWeight.w500))),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Image with Edit Option
          Center(
            child: Column(
              children: [
                _buildEditableProfileImage(),
                const SizedBox(height: 16),
                Text(
                  "Tap camera icon to change photo",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Personal Information Form
          _buildInfoSection(
            "Edit Personal Information",
            [
              _editableField("Full Name", _nameController),
              _editableField("Phone Number", _phoneController, keyboardType: TextInputType.phone),
              _genderDropdown(),
            ],
            titleIcon: Icons.person,
            titleColor: secondaryColor,
          ),

          // Company Information Form
          _buildInfoSection(
            "Edit Company Information",
            [
              _editableField("Company Name", _companyNameController),
              _editableField("Company Location", _companyLocationController),
            ],
            titleIcon: Icons.business,
            titleColor: successColor,
          ),

          // Action Buttons
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _cancelEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: isUpdating ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text("Save Changes"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: Text(
          isEditing ? "Edit Profile" : "Owner Profile",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: primaryColor,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (!isEditing) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
                onPressed: _enableEditMode,
                tooltip: "Edit Profile",
              ),
            ),
          ] else ...[
            if (isUpdating)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              )
            else ...[
              TextButton(
                onPressed: _cancelEdit,
                child: const Text("Cancel", style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: _saveProfile,
                child: const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ],
      ),
      body: isLoading
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [surfaceColor, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(primaryColor),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Loading your profile...",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : errorMessage != null
              ? Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [surfaceColor, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: errorColor.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: errorColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: fetchOwnerProfile,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Retry"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : isEditing
                  ? _buildEditForm()
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [surfaceColor, Colors.white],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Profile Avatar Section
                          Center(
                            child: Column(
                              children: [
                                _buildProfileAvatar(),
                                const SizedBox(height: 12),
                                Text(
                                  userData["name"] ?? "Owner",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "Business Owner",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const SizedBox(height: 24),

// Add incomplete profile banner for new users
if (widget.profileCompleted == false) ...[
  _buildIncompleteProfileBanner(),
],


                          // Personal Information Section
                          _buildInfoSection(
                            "Personal Information",
                            [
                              _buildInfoTile("Full Name", userData["name"] ?? "N/A",
                                  icon: Icons.person, iconColor: secondaryColor),
                              _buildInfoTile("Email Address", userData["email"] ?? "N/A",
                                  icon: Icons.email, iconColor: accentColor),
                              _buildInfoTile("Phone Number", userData["phone"] ?? "N/A",
                                  icon: Icons.phone, iconColor: successColor),
                              _buildInfoTile("Gender", profileData["gender"] ?? "N/A",
                                  icon: Icons.wc, iconColor: primaryColor),
                            ],
                            titleIcon: Icons.account_circle,
                            titleColor: secondaryColor,
                          ),

                          // Company Information Section
                          _buildInfoSection(
                            "Company Information",
                            [
                              _buildInfoTile("Company Name", profileData["companyName"] ?? "N/A",
                                  icon: Icons.business, iconColor: successColor),
                              _buildInfoTile("Company Location", profileData["companyLocation"] ?? "N/A",
                                  icon: Icons.location_on, iconColor: errorColor),
                            ],
                            titleIcon: Icons.business_center,
                            titleColor: successColor,
                          ),
// Quick Actions Section
_buildGradientCard(
  startColor: quickActionColor.withOpacity(0.1),
  endColor: Colors.white,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: quickActionColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.dashboard,
              color: quickActionColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Manage Job Posts",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: quickActionColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _navigateToMyJobs,
          icon: const Icon(Icons.work, size: 18),
          label: const Text('View My Job Posts'),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ],
  ),
),

// Support Section
_buildGradientCard(
  startColor: supportColor.withOpacity(0.1),
  endColor: Colors.white,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: supportColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.support_agent,
              color: supportColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Support & Help",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: supportColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // Phone Support clickable
      InkWell(
        onTap: () => _launchURL("tel:+919629452526"),
        child: _buildInfoTile(
          "Phone Support",
          "9629452526",
          icon: Icons.phone,
          iconColor: supportColor,
        ),
      ),

      const SizedBox(height: 8),

      // Email Support clickable
      InkWell(
        onTap: () => _launchURL("mailto:cogo@gmail.com"),
        child: _buildInfoTile(
          "Email Support",
          "cogo@gmail.com",
          icon: Icons.email,
          iconColor: supportColor,
        ),
      ),
    ],
  ),
),
const SizedBox(height: 16),

                          // Action Buttons
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _launchTutorial,
                              icon: const Icon(Icons.play_circle_fill, size: 18),
                              label: const Text('Watch Tutorial'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: secondaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _logout,
                              icon: const Icon(Icons.logout, size: 18),
                              label: const Text('Logout'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: errorColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}