import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:truckmate_app/api_config.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:convert';

class JobDetailPage extends StatefulWidget {
  final bool isEditMode;
  final Map? job;

  const JobDetailPage({super.key, required this.isEditMode, this.job});

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  String? errorMessage;

  // Controllers for job fields
  final TextEditingController _truckTypeController = TextEditingController();
  final TextEditingController _variantTypeController = TextEditingController();
  final TextEditingController _wheelsTypeController = TextEditingController();
  final TextEditingController _sourceLocationController = TextEditingController();
  final TextEditingController _experienceRequiredController = TextEditingController();
  final TextEditingController _dutyTypeController = TextEditingController();
  final TextEditingController _salaryTypeController = TextEditingController();
  final TextEditingController _minSalaryController = TextEditingController();
  final TextEditingController _maxSalaryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Photo handling
  List<String> existingPhotoUrls = [];
  List<XFile> newPhotos = [];
  final ImagePicker _picker = ImagePicker();

  // Wheels options for Body Vehicle
  final List<String> bodyVehicleWheelsOptions = [
    "6 wheels",
    "8 wheels",
    "12 wheels",
    "14 wheels",
    "16 wheels"
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode && widget.job != null) {
      _truckTypeController.text = widget.job!['truckType'] ?? '';
      _variantTypeController.text = widget.job!['variant']?['type'] ?? '';
      if (widget.job!['truckType'] == "Body Vehicle") {
        _wheelsTypeController.text = widget.job!['variant']?['wheelsOrFeet'] ?? '';
      } else {
        _variantTypeController.text = widget.job!['variant']?['wheelsOrFeet'] ?? '';
      }
      _sourceLocationController.text = widget.job!['sourceLocation'] ?? '';
      _experienceRequiredController.text = widget.job!['experienceRequired'] ?? '';
      _dutyTypeController.text = widget.job!['dutyType'] ?? '';
      _salaryTypeController.text = widget.job!['salaryType'] ?? '';
      _minSalaryController.text = widget.job!['salaryRange']?['min']?.toString() ?? '';
      _maxSalaryController.text = widget.job!['salaryRange']?['max']?.toString() ?? '';
      _descriptionController.text = widget.job!['description'] ?? '';
      _phoneController.text = widget.job!['phone'] ?? '';
      // Initialize with existing Cloudinary photo URLs
      existingPhotoUrls = List<String>.from(widget.job!['lorryPhotos'] ?? []);
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (images != null && images.isNotEmpty) {
        setState(() {
          newPhotos.addAll(images);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking photos: $e')),
      );
    }
  }

  void _removeExistingPhoto(int index) {
    setState(() {
      existingPhotoUrls.removeAt(index);
    });
  }

  void _removeNewPhoto(int index) {
    setState(() {
      newPhotos.removeAt(index);
    });
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Token missing. Please log in.';
      });
      return;
    }

    // Prepare variant data based on truck type
    Map<String, dynamic> variantData = {};
    if (_truckTypeController.text == "Body Vehicle") {
      variantData = {
        'type': _variantTypeController.text,
        'wheelsOrFeet': _wheelsTypeController.text,
      };
    } else {
      variantData = {
        'type': _variantTypeController.text,
        'wheelsOrFeet': _variantTypeController.text,
      };
    }

    try {
      http.StreamedResponse res;
      var uri = widget.isEditMode && widget.job != null
          ? Uri.parse('${ApiConfig.jobs}/${widget.job!['_id']}')
          : Uri.parse(ApiConfig.jobs);

      var request = http.MultipartRequest(
        widget.isEditMode && widget.job != null ? 'PATCH' : 'POST',
        uri,
      );
      request.headers['Authorization'] = "Bearer $token";

      request.fields['truckType'] = _truckTypeController.text;
      request.fields['variant[type]'] = variantData['type'] ?? '';
      request.fields['variant[wheelsOrFeet]'] = variantData['wheelsOrFeet'] ?? '';
      request.fields['sourceLocation'] = _sourceLocationController.text;
      request.fields['experienceRequired'] = _experienceRequiredController.text;
      request.fields['dutyType'] = _dutyTypeController.text;
      request.fields['salaryType'] = _salaryTypeController.text;
      request.fields['salaryRange[min]'] = _minSalaryController.text;
      request.fields['salaryRange[max]'] = _maxSalaryController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['phone'] = _phoneController.text;

      // Add existing photo URLs (if you want to keep them)
      for (var url in existingPhotoUrls) {
        request.fields['existingPhotos[]'] = url;
      }

      // Attach new images
      for (var photo in newPhotos) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'lorryPhotos',
            photo.path,
          ),
        );
      }

      res = await request.send();

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditMode ? 'Job updated successfully' : 'Job created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final respStr = await res.stream.bytesToString();
        String errMsg = 'Failed to save job: $respStr';
        if (res.statusCode == 403) errMsg = 'Unauthorized: You cannot edit this job.';
        if (res.statusCode == 404) errMsg = 'Job not found.';
        setState(() {
          errorMessage = errMsg;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildPhotoCarousel() {
    List<Widget> photoWidgets = [];

    // Existing photos from database (Cloudinary URLs)
    photoWidgets.addAll(existingPhotoUrls.asMap().entries.map((entry) {
      int idx = entry.key;
      String url = entry.value;
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.broken_image, size: 60)),
              ),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const Center(child: CircularProgressIndicator()),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: () => _removeExistingPhoto(idx),
            ),
          ),
        ],
      );
    }));

    // Newly added photos (temporary files before upload)
    photoWidgets.addAll(newPhotos.asMap().entries.map((entry) {
      int idx = entry.key;
      XFile file = entry.value;
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(file.path),
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: () => _removeNewPhoto(idx),
            ),
          ),
        ],
      );
    }));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lorry Photos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (photoWidgets.isNotEmpty)
          CarouselSlider(
            options: CarouselOptions(
              height: 200,
              enlargeCenterPage: true,
              enableInfiniteScroll: false,
              viewportFraction: 0.9,
            ),
            items: photoWidgets,
          )
        else
          Container(
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('No photos added yet'),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Add Photos'),
          onPressed: _pickPhotos,
        ),
      ],
    );
  }

  Widget _buildWheelsTypeField() {
    if (_truckTypeController.text != "Body Vehicle") {
      return const SizedBox.shrink();
    }

    return DropdownButtonFormField<String>(
      value: _wheelsTypeController.text.isEmpty ? null : _wheelsTypeController.text,
      decoration: InputDecoration(
        labelText: 'Wheels Type',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: bodyVehicleWheelsOptions.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _wheelsTypeController.text = newValue ?? '';
        });
      },
      validator: (value) {
        if (_truckTypeController.text == "Body Vehicle" && (value == null || value.isEmpty)) {
          return 'Please select wheels type';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Job' : 'Create Job'),
        actions: [
          if (widget.isEditMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Job'),
                    content: const Text('Are you sure you want to delete this job?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  // Implement delete functionality
                  Navigator.pop(context, true);
                }
              },
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildPhotoCarousel(),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _truckTypeController.text.isEmpty ? null : _truckTypeController.text,
                      decoration: InputDecoration(
                        labelText: 'Truck Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: "Body Vehicle", child: Text("Body Vehicle")),
                        DropdownMenuItem(value: "Trailer", child: Text("Trailer")),
                        DropdownMenuItem(value: "Tipper", child: Text("Tipper")),
                        DropdownMenuItem(value: "Gas Tanker", child: Text("Gas Tanker")),
                        DropdownMenuItem(value: "Wind Mill", child: Text("Wind Mill")),
                        DropdownMenuItem(value: "Concrete Mixer", child: Text("Concrete Mixer")),
                        DropdownMenuItem(value: "Petrol Tank", child: Text("Petrol Tank")),
                        DropdownMenuItem(value: "Container", child: Text("Container")),
                        DropdownMenuItem(value: "Bulker", child: Text("Bulker")),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _truckTypeController.text = value ?? '';
                          _wheelsTypeController.text = '';
                        });
                      },
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    if (_truckTypeController.text == "Body Vehicle")
                      DropdownButtonFormField<String>(
                        value: _variantTypeController.text.isEmpty ? null : _variantTypeController.text,
                        decoration: InputDecoration(
                          labelText: 'Variant',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: const [
                          DropdownMenuItem(value: "Half", child: Text("Half")),
                          DropdownMenuItem(value: "Full", child: Text("Full")),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _variantTypeController.text = value ?? '';
                          });
                        },
                        validator: (value) {
                          if (_truckTypeController.text == "Body Vehicle" && (value == null || value.isEmpty)) {
                            return 'Please select variant';
                          }
                          return null;
                        },
                      )
                    else
                      TextFormField(
                        controller: _variantTypeController,
                        decoration: InputDecoration(
                          labelText: 'Variant',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _buildWheelsTypeField(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sourceLocationController,
                      decoration: InputDecoration(
                        labelText: 'Source Location',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _experienceRequiredController,
                      decoration: InputDecoration(
                        labelText: 'Experience Required',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dutyTypeController,
                      decoration: InputDecoration(
                        labelText: 'Duty Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _salaryTypeController,
                      decoration: InputDecoration(
                        labelText: 'Salary Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _minSalaryController,
                      decoration: InputDecoration(
                        labelText: 'Min Salary',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty || int.tryParse(value) == null ? 'Enter a valid number' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _maxSalaryController,
                      decoration: InputDecoration(
                        labelText: 'Max Salary',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty || int.tryParse(value) == null ? 'Enter a valid number' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveJob,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          widget.isEditMode ? 'Update Job' : 'Create Job',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}