import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:truckmate_app/api_config.dart';
import 'owner_main_navigation.dart';

class OwnerPostJobPage extends StatefulWidget {
  const OwnerPostJobPage({super.key});

  @override
  State<OwnerPostJobPage> createState() => _OwnerPostJobPageState();
}

class _OwnerPostJobPageState extends State<OwnerPostJobPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  
  // Form fields (FIX: Added wheelsType declaration)
  String truckType = '';
  String variant = '';
  String wheelsType = '';  // New declaration to fix undefined name error
  String sourceLocation = '';
  String experience = '';
  String dutyType = '';
  String salaryType = '';
  String salaryMin = '';
  String salaryMax = '';
  String description = '';
  String phone = '';
  String companyName = '';
  List<XFile> lorryPhotos = [];
  bool isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  // Data arrays
  final List<String> tamilNaduDistricts = [
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

  List<String> truckTypes = [
    "Body Vehicle", "Trailer", "Tipper", "Gas Tanker",
    "Wind Mill", "Concrete Mixer", "Petrol Tank",
    "Container", "Bulker"
  ];

  Map<String, List<String>> variantOptions = {
    "Body Vehicle": ["6 wheels", "8 wheels", "12 wheels", "14 wheels", "16 wheels"],
    "Trailer": ["20 ft", "32 ft", "40 ft"],
    "Tipper": ["6 wheel", "10 wheel", "12 wheel", "16 wheel"],
    "Container": ["20 ft", "22 ft", "24 ft", "32 ft"],
  };


  List<String> experienceOptions = ["1-3", "3-6", "6-9", "9+ years"];
  List<String> dutyTypes = ["12 hours", "24 hours"];
  List<String> salaryTypes = ["Daily", "Monthly", "Trip Based"];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
    _loadProfileInfo();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  // Modern Dropdown Widget
  Widget _buildModernDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<T>(
              value: value,
              decoration: InputDecoration(
                prefixIcon: icon != null 
                  ? Icon(icon, color: const Color(0xFF6B7280), size: 20)
                  : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, 
                  vertical: 16
                ),
              ),
              hint: Text(
                'Select $label',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                ),
              ),
              items: items.map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  item.toString(),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF374151),
                  ),
                ),
              )).toList(),
              onChanged: onChanged,
              validator: validator,
              dropdownColor: Colors.white,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modern Text Field Widget
  Widget _buildModernTextField({
    required String label,
    String? initialValue,
    TextInputType? keyboardType,
    int maxLines = 1,
    void Function(String?)? onSaved,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
    bool readOnly = false,
    IconData? icon,
    String? hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextFormField(
              initialValue: initialValue,
              keyboardType: keyboardType,
              maxLines: maxLines,
              onSaved: onSaved,
              onChanged: onChanged,
              validator: validator,
              readOnly: readOnly,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF374151),
              ),
              decoration: InputDecoration(
                prefixIcon: icon != null 
                  ? Icon(icon, color: const Color(0xFF6B7280), size: 20)
                  : null,
                hintText: hint ?? 'Enter $label',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, 
                  vertical: 16
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modern Photo Grid
  Widget _buildModernPhotoGrid() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lorry Photos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (lorryPhotos.isEmpty)
                  Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No photos added yet',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                if (lorryPhotos.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: lorryPhotos.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(lorryPhotos[index].path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeLorryPhoto(index),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.add_photo_alternate, size: 18),
                    label: const Text('Add Photos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  // Modern Image Source Dialog
  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Add Photo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildImageSourceOption(
                        icon: Icons.camera_alt,
                        title: 'Camera',
                        subtitle: 'Take a new photo',
                        onTap: () {
                          Navigator.pop(context);
                          _pickLorryImage(ImageSource.camera);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildImageSourceOption(
                        icon: Icons.photo_library,
                        title: 'Gallery',
                        subtitle: 'Choose from gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickLorryImage(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  // Modern Submit Button
  Widget _buildModernSubmitButton() {
    return Container(
      width: double.infinity,
      height: 50,
      margin: const EdgeInsets.only(top: 20),
      child: ElevatedButton(
        onPressed: isSubmitting ? null : _submitJob,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: const Color(0xFFD1D5DB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                "Post Job",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  // Section Header Widget
  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  // Load Profile Info
  Future<void> _loadProfileInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      phone = prefs.getString('ownerPhone') ?? '';
      companyName = prefs.getString('ownerCompanyName') ?? '';
    });
  }

  // Pick Image
  Future<void> _pickLorryImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );
      
      if (picked != null) {
        setState(() {
          lorryPhotos.add(picked);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Remove Photo
  void _removeLorryPhoto(int index) {
    setState(() {
      lorryPhotos.removeAt(index);
    });
  }

  // Upload Images
  
// owner_post_job.dart - Updated _submitJob function
// ...existing imports...
Future<void> _submitJob() async {
  if (!_formKey.currentState!.validate()) return;

  _formKey.currentState!.save();
  setState(() => isSubmitting = true);

  if (lorryPhotos.isEmpty) {
    setState(() => isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please add at least one lorry photo")),
    );
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('authToken');

  if (token == null) {
    setState(() => isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Authentication token not found")),
    );
    return;
  }

  try {
    // First upload images to Cloudinary
    debugPrint('Starting image upload with ${lorryPhotos.length} images');
    final imageUrls = await _uploadImagesToCloudinary(token);
    debugPrint('Images uploaded successfully: ${imageUrls.length} URLs received');
    
    // Then create job with the Cloudinary URLs
    final jobData = {
      "truckType": truckType,
      "variant": {
        "type": variant,
        "wheelsOrFeet": truckType == "Body Vehicle" ? wheelsType : variant,
      },
      "sourceLocation": sourceLocation,
      "experienceRequired": experience,
      "dutyType": dutyType,
      "salaryType": salaryType,
      "salaryRange": {
        "min": salaryMin,
        "max": salaryMax,
      },
      "description": description,
      "phone": phone,
      "lorryPhotos": imageUrls, // Cloudinary URLs
    };
    
    debugPrint('Sending job data: ${jsonEncode(jobData)}');
    
    final response = await http.post(
      Uri.parse(ApiConfig.jobs),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(jobData),
    );

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Job Posted Successfully!"),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
      _resetForm();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const OwnerMainNavigation(initialTabIndex: 0),
        ),
      );
    } else {
      final err = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err["error"] ?? "Error occurred: ${response.statusCode}")),
      );
    }
  } catch (e) {
    debugPrint('Error in _submitJob: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: ${e.toString()}")),
    );
  } finally {
    setState(() => isSubmitting = false);
  }
}

Future<List<String>> _uploadImagesToCloudinary(String token) async {
  List<String> uploadedUrls = [];
  
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.jobImageUpload),
    )..headers['Authorization'] = 'Bearer $token';

    // Add all photos to the request - FIXED: Use 'images' instead of 'lorryPhotos'
    for (var photo in lorryPhotos) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'images',  // CHANGED FROM 'lorryPhotos' TO 'images'
          photo.path,
          contentType: MediaType.parse(photo.mimeType ?? 'image/jpeg'),
        ),
      );
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    debugPrint('Upload response: $responseBody');

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(responseBody);
      if (jsonResponse is Map && jsonResponse['urls'] is List) {
        uploadedUrls = List<String>.from(jsonResponse['urls']);
      } else {
        throw Exception('Invalid response format from server');
      }
    } else {
      try {
        final errorResponse = jsonDecode(responseBody);
        final errorMsg = errorResponse['error'] ?? 'Unknown error';
        throw Exception('Upload failed: $errorMsg (${response.statusCode})');
      } catch (e) {
        throw Exception('Upload failed with status ${response.statusCode}. Response: $responseBody');
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image upload failed: ${e.toString()}'),
        duration: const Duration(seconds: 5),
      ),
    );
    rethrow;
  }
  
  return uploadedUrls;
}



void _resetForm() {
  _formKey.currentState?.reset();
  setState(() {
    truckType = '';
    variant = '';
    wheelsType = '';
    sourceLocation = '';
    experience = '';
    dutyType = '';
    salaryType = '';
    salaryMin = '';
    salaryMax = '';
    description = '';
    lorryPhotos.clear();
  });
}

  @override
  Widget build(BuildContext context) {
    final currentVariantOptions = variantOptions[truckType] ?? [];
    
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Post Job',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(_slideAnimation),
        child: FadeTransition(
          opacity: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vehicle Information Section
                  _buildSectionHeader('Vehicle Information'),
                  
                  _buildModernDropdown<String>(
                    label: "Truck Type",
                    value: truckType.isEmpty ? null : truckType,
                    items: truckTypes,
                    onChanged: (val) => setState(() {
                      truckType = val ?? '';
                      variant = '';
                      wheelsType = '';  // Reset wheelsType when truckType changes
                    }),
                    validator: (val) => val == null || val.isEmpty ? "Required" : null,
                    icon: Icons.local_shipping,
                  ),

                  if (variantOptions.containsKey(truckType))
                    _buildModernDropdown<String>(
                      label: "Variant",
                      value: variant.isEmpty ? null : variant,
                      items: currentVariantOptions,
                      onChanged: (val) => setState(() => variant = val ?? ''),
                      validator: (val) => val == null || val.isEmpty ? "Required" : null,
                      icon: Icons.settings,
                    ),
                  

                  _buildModernDropdown<String>(
                    label: "Source Location",
                    value: sourceLocation.isEmpty ? null : sourceLocation,
                    items: tamilNaduDistricts,
                    onChanged: (val) => setState(() => sourceLocation = val ?? ''),
                    validator: (val) => val == null || val.isEmpty ? "Required" : null,
                    icon: Icons.location_on,
                  ),

                  // Job Requirements Section
                  _buildSectionHeader('Job Requirements'),
                  
                  _buildModernDropdown<String>(
                    label: "Experience Required",
                    value: experience.isEmpty ? null : experience,
                    items: experienceOptions,
                    onChanged: (val) => setState(() => experience = val ?? ''),
                    validator: (val) => val == null || val.isEmpty ? "Required" : null,
                    icon: Icons.work_history,
                  ),

                  _buildModernDropdown<String>(
                    label: "Duty Type",
                    value: dutyType.isEmpty ? null : dutyType,
                    items: dutyTypes,
                    onChanged: (val) => setState(() => dutyType = val ?? ''),
                    icon: Icons.schedule,
                  ),

                  // Salary Information Section
                  _buildSectionHeader('Salary Information'),
                  
                  _buildModernDropdown<String>(
                    label: "Salary Type",
                    value: salaryType.isEmpty ? null : salaryType,
                    items: salaryTypes,
                    onChanged: (val) => setState(() => salaryType = val ?? ''),
                    icon: Icons.payments,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _buildModernTextField(
                          label: "Min Salary",
                          keyboardType: TextInputType.number,
                          onSaved: (val) => salaryMin = val ?? '',
                          icon: Icons.currency_rupee,
                          hint: "e.g. 25000",
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildModernTextField(
                          label: "Max Salary",
                          keyboardType: TextInputType.number,
                          onSaved: (val) => salaryMax = val ?? '',
                          icon: Icons.currency_rupee,
                          hint: "e.g. 35000",
                        ),
                      ),
                    ],
                  ),

                  // Photos Section
                  _buildSectionHeader('Lorry Photos'),
                  _buildModernPhotoGrid(),

                  // Additional Information Section
                  _buildSectionHeader('Additional Information'),
                  
                  _buildModernTextField(
                    label: "Job Description",
                    maxLines: 4,
                    onSaved: (val) => description = val ?? '',
                    icon: Icons.description,
                    hint: "Describe the job requirements...",
                  ),

                  // Contact Information Section
                  _buildSectionHeader('Contact Information'),
                  
                  _buildModernTextField(
                    label: "Phone Number",
                    initialValue: phone,
                    keyboardType: TextInputType.phone,
                    onChanged: (val) => phone = val,
                    onSaved: (val) => phone = val ?? '',
                    validator: (val) => val == null || val.isEmpty ? "Required" : null,
                    icon: Icons.phone,
                  ),

                  _buildModernTextField(
                    label: "Company Name",
                    initialValue: companyName,
                    readOnly: true,
                    icon: Icons.business,
                  ),

                  _buildModernSubmitButton(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}