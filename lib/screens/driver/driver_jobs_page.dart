import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:truckmate_app/services/auth_service.dart';
import 'package:truckmate_app/utils/image_utils.dart';
import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/api_utils.dart';
import 'package:truckmate_app/screens/driver/job_detail_page.dart';
import 'driver_jobs_filter.dart'; // NEW: Import the filter widget

class DriverJobsPage extends StatefulWidget {
  final String? filterByVehicle;

  const DriverJobsPage({super.key, this.filterByVehicle});

  @override
  State<DriverJobsPage> createState() => _DriverJobsPageState();
}

class _DriverJobsPageState extends State<DriverJobsPage> {
  List<Map<String, dynamic>> jobs = []; 
  bool isLoading = true;
  String? errorMessage;

  // Filter variables
  final Map<String, dynamic> _activeFilters = {};
  Map<String, dynamic> _filterOptions = {};
  bool _isLoadingFilters = false;
  bool _showFilters = false; // NEW: Default to showing filters

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minSalaryController = TextEditingController();
  final TextEditingController _maxSalaryController = TextEditingController();

  Timer? _searchDebounce;
  Timer? _salaryDebounce;

  String _searchQuery = '';

  // Enhanced Material Design Colors
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color surfaceColor = Color(0xFFFAFAFA);
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF388E3C);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color textPrimaryColor = Color(0xFF212121);
  static const Color textSecondaryColor = Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _initializeFilters();
    _loadInitialData();

    // Apply initial vehicle filter if provided
    if (widget.filterByVehicle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateFilter('truckType', widget.filterByVehicle);
      });
    }
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

      final result = await ApiUtils.handleApiCall(
        Future.value(response),
        context,
        checkVerification: false,
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
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Main Content
          Column(
            children: [
              _buildSearchBar(),
              _buildActiveFiltersChips(),
              Expanded(child: _buildJobsList()),
            ],
          ),

          // Filter Overlay
          if (_showFilters)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Row(
                  children: [
                    // Filter Panel
                    DriverJobsFilter(
                      activeFilters: _activeFilters,
                      filterOptions: _filterOptions,
                      onFilterChanged: _updateFilter,
                      onClearAll: _clearAllFilters,
                      
                      isLoading: _isLoadingFilters,
                      onClose: _toggleFilters, // NEW: Close callback
                    ),
                    
                    // Empty space to close filter when tapped
                    Expanded(
                      child: GestureDetector(
                        onTap: _toggleFilters,
                        child: Container(
                          color: Colors.transparent,
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
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
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
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _fetchJobs,
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
          prefixIcon: const Icon(Icons.search, color: primaryColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: textSecondaryColor),
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
              const Icon(Icons.filter_alt, size: 16, color: primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Active Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textPrimaryColor,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear_all, size: 16, color: primaryColor),
                label: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                final displayName = entry.key;
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
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onDeleted,
      backgroundColor: primaryColor.withOpacity(0.08),
    );
  }

  Widget _buildJobsList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (jobs.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _fetchJobs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: jobs.length,
        itemBuilder: (context, index) => _buildJobCard(jobs[index]),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: errorColor),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage!,
            style: TextStyle(color: textSecondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchJobs,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.work_off, size: 64, color: textSecondaryColor),
          const SizedBox(height: 16),
          const Text(
            'No jobs found',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _activeFilters.isNotEmpty || _searchQuery.isNotEmpty
                ? 'Try adjusting your filters or search terms'
                : 'Check back later for new job opportunities',
            style: TextStyle(color: textSecondaryColor),
            textAlign: TextAlign.center,
          ),
          if (_activeFilters.isNotEmpty || _searchQuery.isNotEmpty)
            ElevatedButton(
              onPressed: _clearAllFilters,
              child: const Text('Clear All Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _navigateToJobDetail(job),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (job['sourceLocation'] != null)
                          _buildInfoRow(Icons.location_on, job['sourceLocation']),
                        if (job['experienceRequired'] != null)
                          _buildInfoRow(Icons.work_history, job['experienceRequired']),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildJobFooter(job),
            ],
          ),
        ),
      ),
    );
  }
Widget _buildJobThumbnail(Map<String, dynamic> job) {
  // Check if job has lorryPhotos and the first photo exists
  final hasPhotos = job['lorryPhotos'] != null && 
                   job['lorryPhotos'] is List && 
                   job['lorryPhotos'].isNotEmpty &&
                   job['lorryPhotos'][0] != null &&
                   job['lorryPhotos'][0].toString().isNotEmpty;

  if (hasPhotos) {
    // Use the first photo as thumbnail
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(
          image: NetworkImage(job['lorryPhotos'][0].toString()),
          fit: BoxFit.cover,
        ),
      ),
    );
  } else {
    // Fallback to icon if no photos
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.local_shipping, size: 32, color: Colors.grey),
    );
  }
}

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: textSecondaryColor),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: textSecondaryColor)),
      ],
    );
  }

  Widget _buildJobFooter(Map<String, dynamic> job) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (job['salaryRange'] != null)
          Text(
            '₹${job['salaryRange']['min']} - ₹${job['salaryRange']['max']}',
            style: TextStyle(
              color: successColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        const Icon(Icons.arrow_forward, size: 16, color: primaryColor),
      ],
    );
  }

  void _navigateToJobDetail(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailPage(job: job),
      ),
    );
  }
}