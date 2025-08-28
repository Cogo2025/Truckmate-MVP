import 'package:flutter/material.dart';
import 'package:truckmate_app/screens/driver/api_utils.dart';

class DriverJobsFilter extends StatefulWidget {
  final Map<String, dynamic> activeFilters;
  final Map<String, dynamic> filterOptions;
  final Function(String, dynamic) onFilterChanged;
  final Function() onClearAll;

  final bool isLoading;
  final VoidCallback onClose; // NEW: Close callback

  const DriverJobsFilter({
    super.key,
    required this.activeFilters,
    required this.filterOptions,
    required this.onFilterChanged,
    required this.onClearAll,

    required this.isLoading,
    required this.onClose, // NEW: Close callback
  });

  @override
  State<DriverJobsFilter> createState() => _DriverJobsFilterState();
}

class _DriverJobsFilterState extends State<DriverJobsFilter> {
  // Filter categories
  static const Map<String, String> _filterKeys = {
    'truckType': 'Vehicle Type',
    'sourceLocation': 'Location',
    'variantType': 'Body Variant',
    'wheelsOrFeet': 'Wheels/Feet',
    'experienceRequired': 'Experience',
    'dutyType': 'Duty Type',
    'salaryType': 'Salary Type',
  };

  // Enhanced Material Design Colors
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color textPrimaryColor = Color(0xFF212121);
  static const Color textSecondaryColor = Color(0xFF757575);

  // Updated data structures
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

  final List<String> truckTypes = [
    "Body Vehicle", "Trailer", "Tipper", "Gas Tanker",
    "Wind Mill", "Concrete Mixer", "Petrol Tank",
    "Container", "Bulker"
  ];

  final Map<String, List<String>> variantOptions = {
    "Body Vehicle": ["Half", "Full"],
    "Trailer": ["20 ft", "32 ft", "40 ft"],
    "Tipper": ["6 wheel", "10 wheel", "12 wheel", "16 wheel"],
    "Container": ["20 ft", "22 ft", "24 ft", "32 ft"],
  };

  final Map<String, List<String>> wheelsOptions = {
    "Body Vehicle": ["6 wheels", "8 wheels", "12 wheels", "14 wheels", "16 wheels"],
    "Trailer": [],
    "Tipper": [],
    "Container": [],
    "Gas Tanker": [],
    "Wind Mill": [],
    "Concrete Mixer": [],
    "Petrol Tank": [],
    "Bulker": [],
  };

  final List<String> experienceOptions = ["1-3", "3-6", "6-9", "9+ years"];
  final List<String> dutyTypes = ["12 hours", "24 hours"];
  final List<String> salaryTypes = ["Daily", "Monthly", "Trip Based"];

 @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Filter Header with close button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list, color: Colors.white, size: 28),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white, size: 28),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 3,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vehicle Type Section
                        _buildFilterSection(
                          'Vehicle Type',
                          'truckType',
                          truckTypes,
                          Icons.directions_car,
                        ),
                        const SizedBox(height: 24),

                        // Location Section
                        _buildFilterSection(
                          'Location',
                          'sourceLocation',
                          tamilNaduDistricts,
                          Icons.location_on,
                        ),
                        const SizedBox(height: 24),

                        // Body Variant Section
                        _buildFilterSection(
                          'Body Variant',
                          'variantType',
                          _getFilterOptionsList('variantType'),
                          Icons.build,
                        ),
                        const SizedBox(height: 24),

                        // Wheels/Feet Section
                        _buildFilterSection(
                          'Wheels/Feet',
                          'wheelsOrFeet',
                          _getFilterOptionsList('wheelsOrFeet'),
                          Icons.settings,
                        ),
                        const SizedBox(height: 24),

                        // Experience Section
                        _buildFilterSection(
                          'Experience',
                          'experienceRequired',
                          experienceOptions,
                          Icons.work_history,
                        ),
                        const SizedBox(height: 24),

                        // Duty Type Section
                        _buildFilterSection(
                          'Duty Type',
                          'dutyType',
                          dutyTypes,
                          Icons.access_time,
                        ),
                        const SizedBox(height: 24),

                        // Salary Type Section
                        _buildFilterSection(
                          'Salary Type',
                          'salaryType',
                          salaryTypes,
                          Icons.attach_money,
                        ),
                        const SizedBox(height: 32),

                        // Clear All Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onClearAll,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.red.shade200),
                              ),
                            ),
                            icon: const Icon(Icons.clear_all),
                            label: const Text(
                              'Clear All Filters',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  Widget _buildFilterSection(String title, String key, List<String> options, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: primaryColor, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: textPrimaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: widget.activeFilters[key],
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: InputBorder.none,
              filled: false,
              prefixIcon: Icon(Icons.arrow_drop_down, color: primaryColor),
            ),
            style: const TextStyle(
              fontSize: 16,
              color: textPrimaryColor,
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(
                  'All ${title.toLowerCase()}',
                  style: const TextStyle(
                    color: textSecondaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
              ...options.map((option) => DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: const TextStyle(
                    fontSize: 16,
                    color: textPrimaryColor,
                  ),
                ),
              )),
            ],
            onChanged: (value) {
              widget.onFilterChanged(key, value);
            },
          ),
        ),
      ],
    );
  }

  List<String> _getFilterOptionsList(String key) {
    switch (key) {
      case 'variantType':
        final selectedTruck = widget.activeFilters['truckType'];
        if (selectedTruck != null && variantOptions.containsKey(selectedTruck)) {
          return variantOptions[selectedTruck]!;
        }
        return [];
      
      case 'wheelsOrFeet':
        final selectedTruck = widget.activeFilters['truckType'];
        if (selectedTruck != null && wheelsOptions.containsKey(selectedTruck)) {
          return wheelsOptions[selectedTruck]!;
        }
        return [];
      
      default:
        if (widget.filterOptions[key] != null) {
          return List<String>.from(widget.filterOptions[key]);
        }
        return [];
    }
  }
}