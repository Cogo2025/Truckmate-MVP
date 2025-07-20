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

class _DriverJobsPageState extends State<DriverJobsPage> with TickerProviderStateMixin {
  List<dynamic> jobs = [];
  bool isLoading = true;
  String? errorMessage;
  
  // Filter variables
  final Map<String, dynamic> _activeFilters = {};
  Map<String, dynamic> _filterOptions = {};
  bool _isLoadingFilters = false;
  
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

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeFilters();
    _loadInitialData();
  }

  void _initializeControllers() {
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );
  }

  void _initializeFilters() {
    if (widget.filterByVehicle != null) {
      _activeFilters['truckType'] = widget.filterByVehicle;
    }
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
    final token = prefs.getString('authToken');

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
      final queryParams = _buildQueryParameters();
      final uri = Uri.parse(ApiConfig.driverJobs).replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: ApiUtils.getAuthHeaders(token),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final fetchedJobs = jsonDecode(response.body);
        setState(() {
          jobs = _filterJobsBySearch(fetchedJobs);
          isLoading = false;
        });
      } else {
        _handleApiError(response);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = _getErrorMessage(e);
      });
    }
  }

  Map<String, String> _buildQueryParameters() {
    final queryParams = <String, String>{};
    
    _activeFilters.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        queryParams[key] = value.toString();
      }
    });
    
    final minSalary = int.tryParse(_minSalaryController.text) ?? 0;
    final maxSalary = int.tryParse(_maxSalaryController.text) ?? 100000;
    
    if (minSalary > 0) queryParams['minSalary'] = minSalary.toString();
    if (maxSalary < 100000) queryParams['maxSalary'] = maxSalary.toString();
    
    return queryParams;
  }

  List<dynamic> _filterJobsBySearch(List<dynamic> jobList) {
    if (_searchQuery.isEmpty) return jobList;
    
    return jobList.where((job) {
      final searchFields = [
        job['truckType'] ?? '',
        job['sourceLocation'] ?? '',
        job['description'] ?? '',
        job['experienceRequired'] ?? '',
        job['dutyType'] ?? '',
      ];
      
      return searchFields.any((field) => 
        field.toLowerCase().contains(_searchQuery.toLowerCase())
      );
    }).toList();
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
        backgroundColor: Colors.red,
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
        jobs = _filterJobsBySearch(jobs);
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
      _minSalaryController.text = _filterOptions['salaryRange']?['min']?.toString() ?? '0';
      _maxSalaryController.text = _filterOptions['salaryRange']?['max']?.toString() ?? '100000';
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
      backgroundColor: Colors.grey[50],
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
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      title: const Text(
        'Available Jobs',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      automaticallyImplyLeading: false,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: Icon(
                _showFilters ? Icons.filter_list_off : Icons.tune,
                color: _activeFilters.isNotEmpty ? Colors.orange : Colors.grey[600],
              ),
              onPressed: _toggleFilters,
            ),
            if (_activeFilters.isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _activeFilters.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search jobs...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    if (_activeFilters.isEmpty && _searchQuery.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                'Active Filters:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearAllFilters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onDeleted,
        backgroundColor: Colors.orange.shade50,
        deleteIconColor: Colors.orange,
        side: BorderSide(color: Colors.orange.shade200),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return SizeTransition(
      sizeFactor: _filterAnimation,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: _isLoadingFilters
                  ? const Center(child: CircularProgressIndicator())
                  : _buildFilterContent(),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearAllFilters,
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _toggleFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Show Jobs (${jobs.length})'),
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
          const SizedBox(height: 16),
          _buildSalaryRangeFilter(),
        ],
      ),
    );
  }

  Widget _buildFilterGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildDropdownFilter(
          'Vehicle Type',
          'truckType',
          _getFilterOptionsList('truckTypes'),
        ),
        _buildDropdownFilter(
          'Location',
          'sourceLocation',
          _getFilterOptionsList('locations'),
        ),
        _buildDropdownFilter(
          'Body Variant',
          'variantType',
          _getFilterOptionsList('variantTypes'),
        ),
        _buildDropdownFilter(
          'Wheels/Feet',
          'wheelsOrFeet',
          _getFilterOptionsList('wheelsOrFeetOptions'),
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
  }

  Widget _buildDropdownFilter(String title, String key, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _activeFilters[key],
            decoration: InputDecoration(
              hintText: 'Select',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All'),
              ),
              ...options.map((option) => DropdownMenuItem(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              )),
            ],
            onChanged: (value) => _updateFilter(key, value),
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
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minSalaryController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _onSalaryChanged(),
                decoration: InputDecoration(
                  labelText: 'Min Salary',
                  prefixText: '₹',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _maxSalaryController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _onSalaryChanged(),
                decoration: InputDecoration(
                  labelText: 'Max Salary',
                  prefixText: '₹',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<String> _getFilterOptionsList(String key) {
    if (_filterOptions[key] != null) {
      return List<String>.from(_filterOptions[key]);
    }
    return [];
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
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            errorMessage!,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchJobs,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
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
          Icon(Icons.work_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No jobs found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _activeFilters.isNotEmpty || _searchQuery.isNotEmpty
                ? 'Try adjusting your filters or search terms'
                : 'Check back later for new opportunities',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_activeFilters.isNotEmpty || _searchQuery.isNotEmpty)
            ElevatedButton(
              onPressed: _clearAllFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear All Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToJobDetail(job),
        borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(height: 4),
                        if (job['sourceLocation'] != null)
                          _buildInfoRow(
                            Icons.location_on,
                            job['sourceLocation'],
                            Colors.red,
                          ),
                        const SizedBox(height: 4),
                        if (job['experienceRequired'] != null)
                          _buildInfoRow(
                            Icons.work,
                            job['experienceRequired'],
                            Colors.blue,
                          ),
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
    if (job['lorryPhotos'] != null && job['lorryPhotos'].isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          job['lorryPhotos'][0],
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultThumbnail(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingThumbnail();
          },
        ),
      );
    }
    return _buildDefaultThumbnail();
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.local_shipping,
        color: Colors.orange,
        size: 30,
      ),
    );
  }

  Widget _buildLoadingThumbnail() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600]),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.currency_rupee, size: 16, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text(
                  '${job['salaryRange']['min']} - ${job['salaryRange']['max']}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
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