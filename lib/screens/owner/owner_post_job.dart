import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:truckmate_app/api_config.dart';
import 'owner_main_navigation.dart'; // Add this import

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
  XFile? lorryPhoto;
  bool isSubmitting = false; // Add loading state

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

  Future<void> _pickLorryImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    setState(() => lorryPhoto = picked);
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;
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
          "lorryPhotos": [],
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
          lorryPhoto = null;
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
        SnackBar(content: Text("Network error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentVariantOptions = variantOptions[truckType] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Post a Job"),
        automaticallyImplyLeading: false, // Remove back button
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
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: isSubmitting ? null : _pickLorryImage,
                icon: const Icon(Icons.photo),
                label: const Text("Upload Lorry Photo *"),
              ),
              if (lorryPhoto != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.file(File(lorryPhoto!.path), width: 100, height: 100),
                ),
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