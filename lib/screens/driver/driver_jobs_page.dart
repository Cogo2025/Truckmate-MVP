import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/api_utils.dart';
import 'package:truckmate_app/screens/driver/job_detail_page.dart';

class DriverJobsPage extends StatefulWidget {
  final String? filterByVehicle;
  
  const DriverJobsPage({super.key, this.filterByVehicle});

  @override
  State<DriverJobsPage> createState() => _DriverJobsPageState();
}

class _DriverJobsPageState extends State<DriverJobsPage> {
  List<dynamic> jobs = [];
  List<dynamic> filteredJobs = [];
  bool isLoading = true;
  String? errorMessage;
  
  // Filter variables
  String? selectedVehicleType;
  String? selectedLocation;
  String? selectedVariantType;
  String? selectedWheelsOrFeet;
  String? selectedExperience;
  String? selectedDutyType;
  String? selectedSalaryType;
  double minSalary = 0;
  double maxSalary = 100000;
  bool showFilters = false;
  
  // Filter options from backend
  Map<String, dynamic> filterOptions = {};
  bool isLoadingFilterOptions = false;
  
  // Debounce timer for salary range inputs
  Timer? _debounceTimer;
  
  // Text controllers for salary inputs
  final TextEditingController _minSalaryController = TextEditingController();
  final TextEditingController _maxSalaryController = TextEditingController();
  
  // Available filter options (fallback)
  final List<String> vehicleTypes = [
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
  
  final List<String> variantTypes = [
    "Open Body",
    "Closed Body", 
    "Refrigerated",
    "Flatbed",
    "Tanker",
    "Others"
  ];
  
  final List<String> wheelsOrFeetOptions = [
    "6 Wheels",
    "8 Wheels",
    "10 Wheels",
    "12 Wheels",
    "14 Wheels",
    "16 Wheels",
    "18 Wheels",
    "20 Feet",
    "32 Feet",
    "40 Feet"
  ];
  
  final List<String> experienceOptions = [
    "Fresher",
    "1-2 Years",
    "2-5 Years",
    "5-10 Years",
    "10+ Years"
  ];
  
  final List<String> dutyTypes = [
    "Full Time",
    "Part Time",
    "Contract",
    "Temporary"
  ];
  
  final List<String> salaryTypes = [
    "Monthly",
    "Per Trip",
    "Per Day",
    "Per Load"
  ];

  @override
  void initState() {
    super.initState();
    selectedVehicleType = widget.filterByVehicle;
    fetchFilterOptions();
    fetchJobs();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    super.dispose();
  }

  Future<void> fetchFilterOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) return;

    setState(() => isLoadingFilterOptions = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/jobs/filter-options'),
        headers: ApiUtils.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final options = jsonDecode(response.body);
        setState(() {
          filterOptions = options;
          
          // Update salary range if available
          if (options['salaryRange'] != null) {
            minSalary = options['salaryRange']['min']?.toDouble() ?? 0;
            maxSalary = options['salaryRange']['max']?.toDouble() ?? 100000;
            _minSalaryController.text = minSalary.toInt().toString();
            _maxSalaryController.text = maxSalary.toInt().toString();
          }
          
          isLoadingFilterOptions = false;
        });
      }
    } catch (e) {
      setState(() => isLoadingFilterOptions = false);
      debugPrint("Error fetching filter options: $e");
    }
  }

  Future<void> fetchJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) {
      setState(() {
        isLoading = false;
        errorMessage = "Token missing. Please log in.";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Build query parameters for filtering
      final queryParams = <String, String>{};
      
      if (selectedVehicleType != null && selectedVehicleType!.isNotEmpty) {
        queryParams['truckType'] = selectedVehicleType!;
      }
      
      if (selectedLocation != null && selectedLocation!.isNotEmpty) {
        queryParams['location'] = selectedLocation!;
      }
      
      if (selectedVariantType != null && selectedVariantType!.isNotEmpty) {
        queryParams['variantType'] = selectedVariantType!;
      }
      
      if (selectedWheelsOrFeet != null && selectedWheelsOrFeet!.isNotEmpty) {
        queryParams['wheelsOrFeet'] = selectedWheelsOrFeet!;
      }
      
      if (selectedExperience != null && selectedExperience!.isNotEmpty) {
        queryParams['experienceRequired'] = selectedExperience!;
      }
      
      if (selectedDutyType != null && selectedDutyType!.isNotEmpty) {
        queryParams['dutyType'] = selectedDutyType!;
      }
      
      if (selectedSalaryType != null && selectedSalaryType!.isNotEmpty) {
        queryParams['salaryType'] = selectedSalaryType!;
      }
      
      if (minSalary > 0) {
        queryParams['minSalary'] = minSalary.toInt().toString();
      }
      
      if (maxSalary < 100000) {
        queryParams['maxSalary'] = maxSalary.toInt().toString();
      }

      final uri = Uri.parse(ApiConfig.driverJobs).replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: ApiUtils.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final fetchedJobs = jsonDecode(response.body);
        
        setState(() {
          jobs = fetchedJobs;
          filteredJobs = fetchedJobs;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to fetch jobs. Status: ${response.statusCode}";
        });
        debugPrint("Error response body: ${response.body}");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error: ${e.toString()}";
      });
      debugPrint("Exception details: $e");
    }
  }

  // Auto-apply filters with debounce for salary inputs
  void _applyFiltersWithDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      fetchJobs();
    });
  }

  // Immediate filter application for dropdowns
  void _applyFiltersImmediate() {
    fetchJobs();
  }

  void _clearFilters() {
    setState(() {
      selectedVehicleType = null;
      selectedLocation = null;
      selectedVariantType = null;
      selectedWheelsOrFeet = null;
      selectedExperience = null;
      selectedDutyType = null;
      selectedSalaryType = null;
      minSalary = filterOptions['salaryRange']?['min']?.toDouble() ?? 0;
      maxSalary = filterOptions['salaryRange']?['max']?.toDouble() ?? 100000;
      _minSalaryController.text = minSalary.toInt().toString();
      _maxSalaryController.text = maxSalary.toInt().toString();
    });
    fetchJobs();
  }

  List<String> _getFilterOptions(String key, List<String> fallback) {
    if (filterOptions[key] != null) {
      return List<String>.from(filterOptions[key]);
    }
    return fallback;
  }

  Widget _buildDropdownFilter({
    required String title,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            hintText: hintText ?? "Select $title",
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            DropdownMenuItem(value: null, child: Text("All ${title}s")),
            ...items.map((item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            )),
          ],
          onChanged: (newValue) {
            onChanged(newValue);
            // Auto-apply filters immediately when dropdown changes
            _applyFiltersImmediate();
          },
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Type Filter
            _buildDropdownFilter(
              title: "Vehicle Type",
              value: selectedVehicleType,
              items: _getFilterOptions('truckTypes', vehicleTypes),
              onChanged: (value) => setState(() => selectedVehicleType = value),
            ),
            
            const SizedBox(height: 16),
            
            // Location Filter
            _buildDropdownFilter(
              title: "Location",
              value: selectedLocation,
              items: _getFilterOptions('locations', []),
              onChanged: (value) => setState(() => selectedLocation = value),
            ),
            
            const SizedBox(height: 16),
            
            // Variant Type Filter
            _buildDropdownFilter(
              title: "Body Variant",
              value: selectedVariantType,
              items: _getFilterOptions('variantTypes', variantTypes),
              onChanged: (value) => setState(() => selectedVariantType = value),
            ),
            
            const SizedBox(height: 16),
            
            // Wheels/Feet Filter
            _buildDropdownFilter(
              title: "Wheels/Feet",
              value: selectedWheelsOrFeet,
              items: _getFilterOptions('wheelsOrFeetOptions', wheelsOrFeetOptions),
              onChanged: (value) => setState(() => selectedWheelsOrFeet = value),
            ),
            
            const SizedBox(height: 16),
            
            // Experience Filter
            _buildDropdownFilter(
              title: "Experience Required",
              value: selectedExperience,
              items: _getFilterOptions('experienceOptions', experienceOptions),
              onChanged: (value) => setState(() => selectedExperience = value),
            ),
            
            const SizedBox(height: 16),
            
            // Duty Type Filter
            _buildDropdownFilter(
              title: "Duty Type",
              value: selectedDutyType,
              items: _getFilterOptions('dutyTypes', dutyTypes),
              onChanged: (value) => setState(() => selectedDutyType = value),
            ),
            
            const SizedBox(height: 16),
            
            // Salary Type Filter
            _buildDropdownFilter(
              title: "Salary Type",
              value: selectedSalaryType,
              items: _getFilterOptions('salaryTypes', salaryTypes),
              onChanged: (value) => setState(() => selectedSalaryType = value),
            ),
            
            const SizedBox(height: 16),
            
            // Salary Range Filter
            const Text(
              "Salary Range",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minSalaryController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Min Salary",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      prefixText: "₹",
                    ),
                    onChanged: (value) {
                      setState(() {
                        minSalary = double.tryParse(value) ?? 0;
                      });
                      // Auto-apply filters with debounce for salary inputs
                      _applyFiltersWithDebounce();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _maxSalaryController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Max Salary",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      prefixText: "₹",
                    ),
                    onChanged: (value) {
                      setState(() {
                        maxSalary = double.tryParse(value) ?? 100000;
                      });
                      // Auto-apply filters with debounce for salary inputs
                      _applyFiltersWithDebounce();
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Clear Filters Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _clearFilters,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text("Clear All Filters"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFiltersRow() {
    List<Widget> chips = [];
    
    if (selectedVehicleType != null) {
      chips.add(_buildFilterChip("Vehicle: $selectedVehicleType", () {
        setState(() => selectedVehicleType = null);
        fetchJobs();
      }));
    }
    
    if (selectedLocation != null) {
      chips.add(_buildFilterChip("Location: $selectedLocation", () {
        setState(() => selectedLocation = null);
        fetchJobs();
      }));
    }
    
    if (selectedVariantType != null) {
      chips.add(_buildFilterChip("Variant: $selectedVariantType", () {
        setState(() => selectedVariantType = null);
        fetchJobs();
      }));
    }
    
    if (selectedWheelsOrFeet != null) {
      chips.add(_buildFilterChip("Wheels/Feet: $selectedWheelsOrFeet", () {
        setState(() => selectedWheelsOrFeet = null);
        fetchJobs();
      }));
    }
    
    if (selectedExperience != null) {
      chips.add(_buildFilterChip("Experience: $selectedExperience", () {
        setState(() => selectedExperience = null);
        fetchJobs();
      }));
    }
    
    if (selectedDutyType != null) {
      chips.add(_buildFilterChip("Duty: $selectedDutyType", () {
        setState(() => selectedDutyType = null);
        fetchJobs();
      }));
    }
    
    if (selectedSalaryType != null) {
      chips.add(_buildFilterChip("Salary Type: $selectedSalaryType", () {
        setState(() => selectedSalaryType = null);
        fetchJobs();
      }));
    }
    
    if (chips.isEmpty) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              const Text(
                "Active Filters:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              if (chips.isNotEmpty)
                TextButton(
                  onPressed: _clearFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text("Clear All", style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chips,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onDeleted,
        backgroundColor: Colors.orange.shade100,
        deleteIconColor: const Color(0xFFF57C00),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Jobs"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () {
              setState(() {
                showFilters = !showFilters;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Active Filters Row (side by side)
              _buildActiveFiltersRow(),
              
              // Filter Section
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: showFilters ? 400 : 0,
                child: showFilters ? _buildFilterSection() : null,
              ),
              
              // Jobs List
              Expanded(
                child: Stack(
                  children: [
                    // Main content
                    isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : errorMessage != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(errorMessage!),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: fetchJobs,
                                      child: const Text("Retry"),
                                    ),
                                  ],
                                ),
                              )
                            : jobs.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.work_off, size: 64, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text(
                                          "No jobs match your filters",
                                          style: TextStyle(fontSize: 16, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: fetchJobs,
                                    child: ListView.builder(
                                      itemCount: jobs.length,
                                      itemBuilder: (context, index) {
                                        final job = jobs[index];
                                        return Card(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          child: ListTile(
                                            leading: Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.local_shipping,
                                                color: Colors.orange,
                                              ),
                                            ),
                                            title: Text(
                                              job['truckType'] ?? 'No Type',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (job['sourceLocation'] != null)
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.location_on,
                                                        size: 16,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(job['sourceLocation']),
                                                    ],
                                                  ),
                                                if (job['salaryRange'] != null)
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.currency_rupee,
                                                        size: 16,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '₹${job['salaryRange']['min']} - ₹${job['salaryRange']['max']}',
                                                      ),
                                                    ],
                                                  ),
                                                if (job['dutyType'] != null)
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.work,
                                                        size: 16,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(job['dutyType']),
                                                    ],
                                                  ),
                                                if (job['variant'] != null && job['variant']['type'] != null)
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.directions_car,
                                                        size: 16,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(job['variant']['type']),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                            trailing: const Icon(Icons.arrow_forward_ios),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => JobDetailPage(job: job),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                    
                    // Overlay when filters are shown
                    if (showFilters)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          color: Colors.black.withOpacity(0.3),
                          child: GestureDetector(
                            onTap: () {
                              // Prevent interaction with background
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          // View Button (Bottom)
          if (showFilters)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      showFilters = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.visibility, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "View Jobs (${jobs.length})",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}