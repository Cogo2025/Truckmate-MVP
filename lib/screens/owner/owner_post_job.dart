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

class _OwnerPostJobPageState extends State<OwnerPostJobPage> {
  final _formKey = GlobalKey<FormState>();
  String truckType = '';
  String variant = '';
  String sourceLocation = '';
  String experience = '';
  String dutyType = '';
  String salaryType = '';
  String salaryMin = '';
  String salaryMax = '';
  String description = '';
  String phone = '';
  String companyName = '';
  List<XFile> lorryPhotos = []; // Changed to List for multiple photos
  bool isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  List<String> truckTypes = [
    "Body Vehicle", "Trailer", "Tipper", "Gas Tanker",
    "Wind Mill", "Concrete Mixer", "Petrol Tank",
    "Container", "Bulker"
  ];

  Map<String, List<String>> variantOptions = {
    "Body Vehicle": ["Half", "Full"],
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
    _loadProfileInfo();
  }

  Future<void> _loadProfileInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      phone = prefs.getString('ownerPhone') ?? '';
      companyName = prefs.getString('ownerCompanyName') ?? '';
    });
  }

  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickLorryImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickLorryImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

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

  void _removeLorryPhoto(int index) {
    setState(() {
      lorryPhotos.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
  List<String> uploadedUrls = [];
  
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    
    if (token == null) {
      throw Exception('Authentication token not found');
    }

    // Print image info for debugging
    for (var photo in lorryPhotos) {
      final file = File(photo.path);
      final stats = await file.stat();
      print('Preparing to upload: ${photo.name} '
          '(${stats.size} bytes, ${photo.mimeType})');
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.uploads),
    )..headers['Authorization'] = 'Bearer $token';

    // Add all images to the request
    for (var photo in lorryPhotos) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'images', 
          photo.path,
          contentType: MediaType.parse(photo.mimeType ?? 'image/jpeg'),
        ),
      );
    }

    print('Sending upload request with ${lorryPhotos.length} images');
    
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final jsonResponse = jsonDecode(responseBody);

    print('Upload response: ${response.statusCode} - $responseBody');

    if (response.statusCode == 200) {
      uploadedUrls = List<String>.from(jsonResponse['urls'] ?? []);
      print('Successfully uploaded ${uploadedUrls.length} images');
      return uploadedUrls;
    } else {
      final errorMsg = jsonResponse['error'] ?? 'Unknown error';
      throw Exception('Upload failed: $errorMsg (${response.statusCode})');
    }
  } catch (e) {
    print('Image upload error: ${e.toString()}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image upload failed: ${e.toString()}'),
        duration: const Duration(seconds: 5),
      ),
    );
    rethrow;
  }
}
  Future<void> _submitJob() async {
  if (!_formKey.currentState!.validate()) return;
  
  if (lorryPhotos.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please add at least one lorry photo")),
    );
    return;
  }
  
  _formKey.currentState!.save();

  setState(() {
    isSubmitting = true;
  });

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('authToken');

  if (token == null) {
    setState(() {
      isSubmitting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Authentication token not found")),
    );
    return;
  }

  try {
    // Upload images first
    List<String> photoUrls = await _uploadImages();
    
    final response = await http.post(
      Uri.parse(ApiConfig.jobs),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({
        "truckType": truckType,
        "variant": {
          "type": truckType,
          "wheelsOrFeet": variant
        },
        "sourceLocation": sourceLocation,
        "experienceRequired": experience,
        "dutyType": dutyType,
        "salaryType": salaryType,
        "salaryRange": {
          "min": int.tryParse(salaryMin) ?? 0,
          "max": int.tryParse(salaryMax) ?? 0
        },
        "description": description,
        "phone": phone,
        "lorryPhotos": photoUrls,
      }),
    );

    setState(() {
      isSubmitting = false;
    });

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Job Posted Successfully!"),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Clear form
      _formKey.currentState!.reset();
      setState(() {
        truckType = '';
        variant = '';
        sourceLocation = '';
        experience = '';
        dutyType = '';
        salaryType = '';
        salaryMin = '';
        salaryMax = '';
        description = '';
        lorryPhotos.clear();
      });

      // Navigate to dashboard after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const OwnerMainNavigation(initialTabIndex: 0),
            ),
          );
        }
      });
    } else {
      final err = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err["error"] ?? "Error occurred")),
      );
    }
  } catch (e) {
    setState(() {
      isSubmitting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: ${e.toString()}")),
    );
  }
}

  Widget _buildPhotoGrid() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Lorry Photos *",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        height: 120,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Add photo button
              if (!isSubmitting)
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 30, color: Colors.grey),
                        SizedBox(height: 4),
                        Text(
                          "Add Photo",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              // Photo thumbnails
              ...lorryPhotos.asMap().entries.map((entry) {
                int index = entry.key;
                XFile photo = entry.value;
                
                return Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(photo.path),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (!isSubmitting)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeLorryPhoto(index),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
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
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        "Added ${lorryPhotos.length} photo(s). Tap + to add more.",
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    final currentVariantOptions = variantOptions[truckType] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Post a Job"),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Truck Type *"),
                value: truckType.isEmpty ? null : truckType,
                items: truckTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => truckType = val ?? ''),
                validator: (val) => val == null || val.isEmpty ? "Select truck type" : null,
              ),
              if (variantOptions.containsKey(truckType))
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Variant *"),
                  value: variant.isEmpty ? null : variant,
                  items: currentVariantOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (val) => setState(() => variant = val ?? ''),
                  validator: (val) => val == null || val.isEmpty ? "Select variant" : null,
                ),
              TextFormField(
                decoration: const InputDecoration(labelText: "Source Location *"),
                onSaved: (val) => sourceLocation = val ?? '',
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Experience *"),
                value: experience.isEmpty ? null : experience,
                items: experienceOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => experience = val ?? ''),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),
              _buildPhotoGrid(),
              const Divider(height: 30),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Duty Type"),
                value: dutyType.isEmpty ? null : dutyType,
                items: dutyTypes.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setState(() => dutyType = val ?? ''),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Salary Type"),
                value: salaryType.isEmpty ? null : salaryType,
                items: salaryTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => salaryType = val ?? ''),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: "Salary Min"),
                      keyboardType: TextInputType.number,
                      onSaved: (val) => salaryMin = val ?? '',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: "Salary Max"),
                      keyboardType: TextInputType.number,
                      onSaved: (val) => salaryMax = val ?? '',
                    ),
                  ),
                ],
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "Description"),
                maxLines: 3,
                onSaved: (val) => description = val ?? '',
              ),
              TextFormField(
                initialValue: phone,
                decoration: const InputDecoration(labelText: "Phone (editable)"),
                keyboardType: TextInputType.phone,
                onChanged: (val) => phone = val,
                onSaved: (val) => phone = val ?? '',
              ),
              TextFormField(
                initialValue: companyName,
                decoration: const InputDecoration(labelText: "Company Name (auto-fetched)"),
                readOnly: true,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submitJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isSubmitting
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
                            SizedBox(width: 10),
                            Text("Submitting..."),
                          ],
                        )
                      : const Text("Submit Job Post"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}