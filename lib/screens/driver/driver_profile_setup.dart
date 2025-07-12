import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:truckmate_app/api_config.dart';

class DriverProfileSetupPage extends StatefulWidget {
  const DriverProfileSetupPage({super.key});

  @override
  State<DriverProfileSetupPage> createState() => _DriverProfileSetupPageState();
}

class _DriverProfileSetupPageState extends State<DriverProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  String gender = '';
  String experience = '';
  String licenseType = '';
  XFile? profilePhoto;
  XFile? licensePhoto;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickProfilePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => profilePhoto = picked);
    }
  }
  Future<void> _pickLicensePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => licensePhoto = picked);
    }
  }
Future<void> _submitProfile() async {
  if (!_formKey.currentState!.validate() || licensePhoto == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please fill all fields and take license photo")),
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
    // First upload the license photo
    final licensePhotoRequest = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/uploads'),
    );
    licensePhotoRequest.headers['Authorization'] = 'Bearer $token';
    licensePhotoRequest.files.add(
      await http.MultipartFile.fromPath(
        'file',
        licensePhoto!.path,
        filename: 'license_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    );

    final licensePhotoResponse = await licensePhotoRequest.send();
    if (licensePhotoResponse.statusCode != 200) {
      throw Exception('Failed to upload license photo');
    }
    final licensePhotoData = await licensePhotoResponse.stream.bytesToString();
    final licensePhotoUrl = jsonDecode(licensePhotoData)['url'];

    // Then submit the profile data
    final response = await http.post(
      Uri.parse(ApiConfig.driverProfile),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "experience": experience,
        "licenseType": licenseType,
        "gender": gender,
        "licensePhoto": licensePhotoUrl,
        "knownTruckTypes": [], // You can add this from UI if needed
      }),
    );
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile setup completed")),
      );
      if (mounted) Navigator.pop(context);
    } else {
      final error = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error["error"] ?? "Something went wrong")),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: ${e.toString()}")),
    );
  }

  if (mounted) setState(() => _isLoading = false);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Profile Setup")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickProfilePhoto,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.orange.shade100,
                    backgroundImage:
                        profilePhoto != null ? FileImage(File(profilePhoto!.path)) : null,
                    child: profilePhoto == null
                        ? const Icon(Icons.camera_alt, size: 30)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Gender"),
                items: ["Male", "Female", "Other"]
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                validator: (val) => val == null || val.isEmpty ? "Select gender" : null,
                onChanged: (val) => gender = val ?? '',
              ),
              const SizedBox(height: 10),
              TextFormField(
                decoration: const InputDecoration(labelText: "Experience"),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved: (val) => experience = val ?? '',
              ),
              const SizedBox(height: 10),
              TextFormField(
                decoration: const InputDecoration(labelText: "License Type"),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved: (val) => licenseType = val ?? '',
              ),
              const SizedBox(height: 20),
              const Text("License Photo:"),
              ElevatedButton(
                onPressed: _pickLicensePhoto,
                child: const Text("Take License Photo"),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitProfile,
                      child: const Text("Submit"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}