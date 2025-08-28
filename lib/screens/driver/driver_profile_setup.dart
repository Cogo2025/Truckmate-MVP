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
  final Map userData;
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
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();
  final List<String> _availableTruckTypes = [
    "Body Vehicle", "Trailer", "Tipper", "Gas Tanker", "Wind Mill",
    "Concrete Mixer", "Petrol Tank", "Container", "Bulker"
  ];
  List<String> _selectedTruckTypes = [];

  Future _pickImage(String type) async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _submitProfile() async {
  if (!_formKey.currentState!.validate()) return;

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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken') ?? widget.userData['token'];

    if (token == null) {
      _showError("Authentication token missing. Please log in again.");
      setState(() => _isSubmitting = false);
      return;
    }

    final url = Uri.parse(ApiConfig.driverProfile);
    var request = http.MultipartRequest('POST', url);

    // ✅ Authorization Header
    request.headers['Authorization'] = 'Bearer $token';

    // ✅ Add Form Fields
    request.fields['licenseNumber'] = _licenseNumberController.text;
    request.fields['experience'] = _experienceController.text;
    request.fields['age'] = _ageController.text;
    request.fields['gender'] = _gender ?? '';
    request.fields['location'] = _locationController.text;

    // ✅ Send Truck Types as comma-separated instead of JSON
    request.fields['knownTruckTypes'] = _selectedTruckTypes.join(',');

    // ✅ License Expiry Date
    request.fields['licenseExpiryDate'] = _licenseExpiryDate!.toIso8601String();

    // ✅ Attach Images
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

    // ✅ Send Request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    // ✅ Handle Success & Errors Properly
    if (response.statusCode == 201) {
      try {
        final jsonResponse = jsonDecode(response.body);
        _showSuccess("Profile created successfully!");
        Navigator.pop(context, true);
      } catch (_) {
        _showSuccess("Profile created successfully!");
        Navigator.pop(context, true);
      }
    } else {
      try {
        final jsonResponse = jsonDecode(response.body);
        _showError("Error: ${jsonResponse['error'] ?? 'Something went wrong'}");
      } catch (_) {
        _showError("Unexpected server response: ${response.body}");
      }
    }
  } catch (e) {
    _showError("Failed to create profile: ${e.toString()}");
  } finally {
    setState(() => _isSubmitting = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Driver Profile Setup")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // License Number
              TextFormField(
                controller: _licenseNumberController,
                decoration: InputDecoration(labelText: "License Number *"),
                validator: (v) => v!.isEmpty ? "Enter license number" : null,
              ),
              SizedBox(height: 16),

              // Experience
              TextFormField(
                controller: _experienceController,
                decoration: InputDecoration(labelText: "Experience (years) *"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Enter years of experience" : null,
              ),
              SizedBox(height: 16),

              // Age
              TextFormField(
                controller: _ageController,
                decoration: InputDecoration(labelText: "Age *"),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Enter your age" : null,
              ),
              SizedBox(height: 16),

              // Gender
              DropdownButtonFormField(
                value: _gender,
                items: ["Male", "Female", "Other"]
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (val) => setState(() => _gender = val as String?),
                decoration: InputDecoration(labelText: "Gender *"),
                validator: (v) => v == null ? "Select your gender" : null,
              ),
              SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: "Location *"),
                validator: (v) => v!.isEmpty ? "Enter your location" : null,
              ),
              SizedBox(height: 16),

              // Truck types selection
              Text("Truck Types You Can Drive *", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              SizedBox(height: 8),
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
              SizedBox(height: 16),

              // License Expiry Date
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2050),
                  );
                  if (picked != null) {
                    setState(() => _licenseExpiryDate = picked);
                  }
                },
                child: Text(_licenseExpiryDate == null
                    ? "Pick License Expiry Date *"
                    : "Expiry: ${DateFormat('yyyy-MM-dd').format(_licenseExpiryDate!)}"),
              ),
              SizedBox(height: 16),

              // Photos Section
              Text("Upload Photos *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 10),

              // Profile Photo
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.person),
                    label: Text("Profile Photo"),
                    onPressed: () => _pickImage('profile'),
                  ),
                  SizedBox(width: 10),
                  Text(_profilePhoto == null ? "Required" : "Selected")
                ],
              ),
              SizedBox(height: 10),

              // License Front
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.credit_card),
                    label: Text("License Front"),
                    onPressed: () => _pickImage('front'),
                  ),
                  SizedBox(width: 10),
                  Text(_licenseFront == null ? "Required" : "Selected")
                ],
              ),
              SizedBox(height: 10),

              // License Back
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.credit_card_outlined),
                    label: Text("License Back"),
                    onPressed: () => _pickImage('back'),
                  ),
                  SizedBox(width: 10),
                  Text(_licenseBack == null ? "Required" : "Selected")
                ],
              ),
              SizedBox(height: 30),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitProfile,
                child: _isSubmitting 
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Submit Profile"),
              ),

              if (_errorMessage != null) 
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}