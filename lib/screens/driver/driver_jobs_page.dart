import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:truckmate_app/services/auth_service.dart'; // NEW: Import AuthService

import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/api_utils.dart';
import 'package:truckmate_app/screens/driver/job_detail_page.dart';

class DriverJobsPage extends StatefulWidget {
  final String? filterByVehicle;

  const DriverJobsPage({super.key, this.filterByVehicle});

  @override
  State<DriverJobsPage> createState() => _DriverJobsPageState();
}

class _DriverJobsPageState extends State<DriverJobsPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> jobs = []; 
  bool isLoading = true;
  String? errorMessage;

  // Filter variables
  final Map<String, dynamic> _activeFilters = {};
  Map<String, dynamic> _filterOptions = {};
  bool _isLoadingFilters = false;

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

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minSalaryController = TextEditingController();
  final TextEditingController _maxSalaryController = TextEditingController();

  // Animation controllers
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;

  // Timers
  Timer? _searchDebounce;
  Timer? _salaryDebounce;

  // UI State
  bool _showFilters = false;
  String _searchQuery = '';

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
  static const Color primaryColor = Color(0xFF1565C0); // Deep Blue
  static const Color accentColor = Color(0xFFFF7043); // Deep Orange
  static const Color surfaceColor = Color(0xFFFAFAFA); // Light Grey
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF388E3C); // Green
  static const Color errorColor = Color(0xFFD32F2F); // Red
  static const Color textPrimaryColor = Color(0xFF212121); // Dark Grey
  static const Color textSecondaryColor = Color(0xFF757575); // Medium Grey

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeFilters();
    _loadInitialData();

    // Apply initial vehicle filter if provided
    if (widget.filterByVehicle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateFilter('truckType', widget.filterByVehicle);
      });
    }
  }

  void _initializeControllers() {
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOutCubic,
    );
  }

  void _initializeFilters() {
    _minSalaryController.text = '0';
    _maxSalaryController.text = '100000';
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _fetchFilterOptions(),
      _fetchJobs(),
    ]);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _salaryDebounce?.cancel();
    _filterAnimationController.dispose();
    _searchController.dispose();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    super.dispose();
  }

  Future<void> _fetchFilterOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) return;

    setState(() => _isLoadingFilters = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/jobs/filter-options'),
        headers: ApiUtils.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final options = jsonDecode(response.body);
        setState(() {
          _filterOptions = options;
          if (options['salaryRange'] != null) {
            _minSalaryController.text = options['salaryRange']['min'].toString();
            _maxSalaryController.text = options['salaryRange']['max'].toString();
          }
          _isLoadingFilters = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingFilters = false);
      _showErrorSnackbar('Failed to load filter options');
    }
  }
Future<void> _fetchJobs() async {
  final prefs = await SharedPreferences.getInstance();
  final token = await AuthService.getFreshAuthToken();
  
  if (token == null) {
    setState(() {
      isLoading = false;
      errorMessage = "Authentication required";
    });
    return;
  }

  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    final queryParams = <String, String>{};
    
    // Add active filters to query params
    _activeFilters.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        queryParams[key] = value.toString();
      }
    });

    // Add salary range if specified
    final minSalary = int.tryParse(_minSalaryController.text) ?? 0;
    final maxSalary = int.tryParse(_maxSalaryController.text) ?? 100000;
    if (minSalary > 0) queryParams['minSalary'] = minSalary.toString();
    if (maxSalary < 100000) queryParams['maxSalary'] = maxSalary.toString();

    final uri = Uri.parse(ApiConfig.driverJobs).replace(queryParameters: queryParams);
    
    final response = await http.get(
      uri,
      headers: ApiUtils.getAuthHeaders(token),
    ).timeout(const Duration(seconds: 30));

    // Use enhanced API utils for verification handling
    final result = await ApiUtils.handleApiCall(
      Future.value(response),
      context,
      checkVerification: true,
    );

    if (result['success']) {
      final dynamic decoded = result['data'];
      setState(() {
        jobs = (decoded as List)
            .map((item) => (item as Map<String, dynamic>).cast<String, dynamic>())
            .toList();
        isLoading = false;
      });
    } else {
      // Handle verification errors
      if (result['verificationError'] == true) {
        setState(() {
          isLoading = false;
          errorMessage = "Verification required to access jobs";
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = result['error'] ?? "Failed to load jobs";
        });
      }
    }
  } catch (e) {
    setState(() {
      isLoading = false;
      errorMessage = _getErrorMessage(e);
    });
  }
}
  void _handleApiError(http.Response response) {
    setState(() {
      isLoading = false;
      errorMessage = "Failed to load jobs (${response.statusCode})";
    });
  }

  String _getErrorMessage(dynamic error) {
    if (error is TimeoutException) {
      return "Request timed out. Please check your connection.";
    }
    return "Network error. Please try again.";
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _fetchJobs,
        ),
      ),
    );
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
        _activeFilters['sourceLocation'] = query.isNotEmpty ? query : null;
        _fetchJobs();
      });
    });
  }

  void _onSalaryChanged() {
    _salaryDebounce?.cancel();
    _salaryDebounce = Timer(const Duration(milliseconds: 800), () {
      _fetchJobs();
    });
  }

  void _updateFilter(String key, dynamic value) {
    setState(() {
      if (value == null || value == '') {
        _activeFilters.remove(key);
      } else {
        _activeFilters[key] = value;
      }
    });
    _fetchJobs();
  }

  void _clearAllFilters() {
    setState(() {
      _activeFilters.clear();
      _searchQuery = '';
      _searchController.clear();
      _minSalaryController.text = '0';
      _maxSalaryController.text = '100000';
    });
    _fetchJobs();
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
    if (_showFilters) {
      _filterAnimationController.forward();
    } else {
      _filterAnimationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildActiveFiltersChips(),
          _buildFilterPanel(),
          Expanded(child: _buildJobsList()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 2,
      backgroundColor: cardColor,
      foregroundColor: textPrimaryColor,
      shadowColor: Colors.grey.withOpacity(0.3),
      title: const Text(
        'Available Jobs',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 22,
          letterSpacing: -0.5,
        ),
      ),
      automaticallyImplyLeading: false,
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _activeFilters.isNotEmpty 
                        ? primaryColor.withOpacity(0.1) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _showFilters ? Icons.filter_list_off : Icons.tune,
                    color: _activeFilters.isNotEmpty ? primaryColor : textSecondaryColor,
                    size: 24,
                  ),
                ),
                onPressed: _toggleFilters,
              ),
            ),
            if (_activeFilters.isNotEmpty)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    _activeFilters.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh, color: textSecondaryColor, size: 20),
            ),
            onPressed: _fetchJobs,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 16, color: textPrimaryColor),
        decoration: InputDecoration(
          hintText: 'Search jobs by location...',
          hintStyle: TextStyle(color: textSecondaryColor.withOpacity(0.7)),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.search, color: primaryColor, size: 20),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: textSecondaryColor, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: surfaceColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    if (_activeFilters.isEmpty && _searchQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.filter_alt, size: 16, color: primaryColor),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Active Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textPrimaryColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _clearAllFilters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: Icon(Icons.clear_all, size: 16, color: accentColor),
                label: Text(
                  'Clear All',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fixed overflow issue with proper wrapping
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (_searchQuery.isNotEmpty)
                _buildFilterChip('Search: $_searchQuery', () {
                  _searchController.clear();
                  _onSearchChanged('');
                }),
              ..._activeFilters.entries.map((entry) {
                final displayName = _filterKeys[entry.key] ?? entry.key;
                return _buildFilterChip(
                  '$displayName: ${entry.value}',
                  () => _updateFilter(entry.key, null),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200), // Prevent overflow
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: primaryColor,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        deleteIcon: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.close, size: 14, color: primaryColor),
        ),
        onDeleted: onDeleted,
        backgroundColor: primaryColor.withOpacity(0.08),
        side: BorderSide(color: primaryColor.withOpacity(0.2)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 0,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildFilterPanel() {
    return SizeTransition(
      sizeFactor: _filterAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
              ),
              child: _isLoadingFilters
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                        strokeWidth: 3,
                      ),
                    )
                  : _buildFilterContent(),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearAllFilters,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryColor, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: Icon(Icons.clear_all, color: primaryColor, size: 18),
                      label: Text(
                        'Clear All',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _toggleFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shadowColor: primaryColor.withOpacity(0.3),
                      ),
                      icon: const Icon(Icons.work, size: 18),
                      label: Text(
                        'Show Jobs (${jobs.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
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
  }

  Widget _buildFilterContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildFilterGrid(),
          const SizedBox(height: 24),
          _buildSalaryRangeFilter(),
        ],
      ),
    );
  }

  Widget _buildFilterGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: constraints.maxWidth > 600 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildDropdownFilter(
              'Vehicle Type',
              'truckType',
              const [
                "Body Vehicle",
                "Trailer",
                "Tipper",
                "Gas Tanker",
                "Wind Mill",
                "Concrete Mixer",
                "Petrol Tank",
                "Container",
                "Bulker"
              ],
            ),
            _buildDropdownFilter(
              'Location',
              'sourceLocation',
              tamilNaduDistricts,
            ),
            _buildDropdownFilter(
              'Body Variant',
              'variantType',
              _getFilterOptionsList('variantTypes'),
            ),
            _buildDropdownFilter(
  'Wheels/Feet',
  'wheelsOrFeet',
  _activeFilters['truckType'] == "Body Vehicle" 
      ? _getFilterOptionsList('bodyVehicleWheels')
      : _getFilterOptionsList('otherWheelsOptions'),
),
            _buildDropdownFilter(
              'Experience',
              'experienceRequired',
              _getFilterOptionsList('experienceOptions'),
            ),
            _buildDropdownFilter(
              'Duty Type',
              'dutyType',
              _getFilterOptionsList('dutyTypes'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdownFilter(String title, String key, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: textPrimaryColor,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _activeFilters[key],
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Select',
              hintStyle: TextStyle(color: textSecondaryColor.withOpacity(0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              filled: true,
              fillColor: cardColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
            icon: Icon(Icons.keyboard_arrow_down, color: primaryColor),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(
                  'All ${title.toLowerCase()}',
                  style: TextStyle(color: textSecondaryColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...options.map((option) => DropdownMenuItem(
                    value: option,
                    child: Text(
                      option,
                      style: const TextStyle(color: textPrimaryColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: (value) {
              setState(() {
                if (value == null) {
                  _activeFilters.remove(key);
                } else {
                  _activeFilters[key] = value;
                }
              });
              _fetchJobs();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Salary Range',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: textPrimaryColor,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minSalaryController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _onSalaryChanged(),
                style: const TextStyle(color: textPrimaryColor),
                decoration: InputDecoration(
                  labelText: 'Min Salary',
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(color: successColor, fontWeight: FontWeight.w600),
                  labelStyle: TextStyle(color: textSecondaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _maxSalaryController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _onSalaryChanged(),
                style: const TextStyle(color: textPrimaryColor),
                decoration: InputDecoration(
                  labelText: 'Max Salary',
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(color: successColor, fontWeight: FontWeight.w600),
                  labelStyle: TextStyle(color: textSecondaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<String> _getFilterOptionsList(String key) {
    if (key == 'truckTypes') {
      return [
        "Body Vehicle", "Trailer", "Tipper", "Gas Tanker",
        "Wind Mill", "Concrete Mixer", "Petrol Tank",
        "Container", "Bulker"
      ];
    }
    if (_filterOptions[key] != null && key != 'locations') {
      return List<String>.from(_filterOptions[key]);
    }
    return [];
  }

  Widget _buildJobsList() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryColor,
          strokeWidth: 3,
        ),
      );
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (jobs.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _fetchJobs,
      color: primaryColor,
      backgroundColor: cardColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: jobs.length,
        itemBuilder: (context, index) => _buildJobCard(jobs[index]),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 64, color: errorColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: TextStyle(
                fontSize: 16,
                color: textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _fetchJobs,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: textSecondaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.work_off, size: 64, color: textSecondaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              'No jobs found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _activeFilters.isNotEmpty || _searchQuery.isNotEmpty
                  ? 'Try adjusting your filters or search terms to find more opportunities'
                  : 'Check back later for new job opportunities',
              style: TextStyle(
                color: textSecondaryColor,
                fontSize: 16,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_activeFilters.isNotEmpty || _searchQuery.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.clear_all),
                label: const Text(
                  'Clear All Filters',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToJobDetail(job),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildJobThumbnail(job),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job['truckType'] ?? 'No Type',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: textPrimaryColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (job['sourceLocation'] != null)
                            _buildInfoRow(
                              Icons.location_on,
                              job['sourceLocation'],
                              errorColor,
                            ),
                          const SizedBox(height: 8),
                          if (job['experienceRequired'] != null)
                            _buildInfoRow(
                              Icons.work_history,
                              job['experienceRequired'],
                              primaryColor,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildJobFooter(job),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobThumbnail(Map<String, dynamic> job) {
    if (job['lorryPhotos'] != null && job['lorryPhotos'].isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            job['lorryPhotos'][0],
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultThumbnail(),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildLoadingThumbnail();
            },
          ),
        ),
      );
    }
    return _buildDefaultThumbnail();
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withOpacity(0.1), accentColor.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.local_shipping,
        color: primaryColor,
        size: 32,
      ),
    );
  }

  Widget _buildLoadingThumbnail() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textSecondaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildJobFooter(Map<String, dynamic> job) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (job['salaryRange'] != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [successColor.withOpacity(0.1), successColor.withOpacity(0.05)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: successColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.currency_rupee, size: 16, color: successColor),
                const SizedBox(width: 4),
                Text(
                  '${job['salaryRange']['min']} - ${job['salaryRange']['max']}',
                  style: TextStyle(
                    color: successColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  void _navigateToJobDetail(Map<String, dynamic> job) {  // Updated type
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => JobDetailPage(job: job),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
              CurveTween(curve: Curves.easeInOutCubic),
            ),
          ),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}
}
