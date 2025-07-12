import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:truckmate_app/api_config.dart'; // Ensure this points to your ApiConfig file
class OwnerProfileSetupPage extends StatefulWidget {
  const OwnerProfileSetupPage({super.key});

  @override
  State<OwnerProfileSetupPage> createState() => _OwnerProfileSetupPageState();
}

class _OwnerProfileSetupPageState extends State<OwnerProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  String gender = '';
  String companyName = '';
  String companyLocation = '';
  XFile? profilePhoto;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickProfilePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => profilePhoto = picked);
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate() || profilePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and take a photo")),
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

    final fakePhotoUrl = "https://your-server.com/uploads/${profilePhoto!.name}";

    // 🧪 Debug log
    print("📤 Submitting profile:");
    print("Token: $token");
    print("Company Name: $companyName");
    print("Company Location: $companyLocation");
    print("Gender: $gender");
    print("Photo URL: $fakePhotoUrl");

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.ownerProfile),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "companyName": companyName,
          "companyLocation": companyLocation,
          "gender": gender,
          "photoUrl": fakePhotoUrl,
        }),
      ).timeout(const Duration(seconds: 10));

      print("📥 Response Status: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      if (response.statusCode == 201) {
        await prefs.setBool("ownerProfileCompleted", true);
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
      print("❌ Exception during profile submission: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: $e")),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Owner Profile Setup")),
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
                decoration: const InputDecoration(labelText: "Company Name"),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved: (val) => companyName = val ?? '',
              ),
              const SizedBox(height: 10),
              TextFormField(
                decoration: const InputDecoration(labelText: "Company Location"),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
                onSaved: (val) => companyLocation = val ?? '',
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
