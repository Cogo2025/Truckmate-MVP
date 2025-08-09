// my_posted_jobs_page.dart (Enhanced UI Version)

import 'dart:convert';
import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/owner/owner_main_navigation.dart';
import 'detail_my_post.dart';

class MyPostedJobsPage extends StatefulWidget {
  const MyPostedJobsPage({super.key});

  @override
  State<MyPostedJobsPage> createState() => _MyPostedJobsPageState();
}

class _MyPostedJobsPageState extends State<MyPostedJobsPage> 
    with TickerProviderStateMixin {
  bool isLoading = true;
  List<dynamic> jobPosts = [];
  List<dynamic> filteredJobs = [];
  String? errorMessage;
  String searchQuery = '';
  late AnimationController _refreshController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _searchController.addListener(_onSearchChanged);
    fetchMyJobs();
  }

  void _initializeAnimations() {
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fabScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _fabAnimationController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _filterJobs();
    });
  }

  void _filterJobs() {
    setState(() {
      filteredJobs = jobPosts.where((job) {
        final matchesSearch = job['sourceLocation']
                ?.toString()
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ??
            true;
        
        return matchesSearch;
      }).toList();
    });
  }
Future deleteJob(String jobId) async {
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('authToken');
  
  if (token == null) {
    Navigator.pop(context);
    _showSnackBar('Authentication token missing', Colors.red, Icons.error);
    return;
  }

  try {
    final res = await http.delete(
      Uri.parse('${ApiConfig.jobs}/$jobId'),
      headers: {"Authorization": "Bearer $token"},
    ).timeout(const Duration(seconds: 30)); // Add timeout

    Navigator.pop(context); // Remove loading dialog

    if (res.statusCode == 200) {
      HapticFeedback.lightImpact();
      _showSnackBar('Job deleted successfully', Colors.green, Icons.check_circle);
      fetchMyJobs(); // Refresh the list
    } else if (res.statusCode == 404) {
      _showSnackBar('Job not found', Colors.orange, Icons.warning);
    } else if (res.statusCode == 403) {
      _showSnackBar('You are not authorized to delete this job', Colors.red, Icons.error);
    } else {
      _showSnackBar('Failed to delete job (${res.statusCode})', Colors.red, Icons.error);
    }
  } catch (e) {
    Navigator.pop(context);
    if (e.toString().contains('TimeoutException')) {
      _showSnackBar('Connection timeout. Please check your internet.', Colors.orange, Icons.warning);
    } else {
      _showSnackBar('Error: ${e.toString()}', Colors.orange, Icons.warning);
    }
  }
}
  Future<void> fetchMyJobs() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    _refreshController.repeat();
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    
    if (token == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Token missing. Please log in.";
        });
      }
      _refreshController.stop();
      return;
    }

    try {
      final res = await http.get(
        Uri.parse(ApiConfig.ownerJobs),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final List<dynamic> jobs = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            jobPosts = jobs;
            filteredJobs = jobs;
            isLoading = false;
            errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = "Failed to load jobs (${res.statusCode})";
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString().contains('TimeoutException') 
              ? "Connection timeout. Please check your internet."
              : "Network error: ${e.toString()}";
          isLoading = false;
        });
      }
    }

    _refreshController.stop();
  }

  

  void _showSnackBar(String message, Color color, IconData icon) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void navigateToCreateJob() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OwnerMainNavigation(initialTabIndex: 2),
      ),
    ).then((_) => fetchMyJobs());
  }

  void navigateToEditJob(dynamic job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailPage(isEditMode: true, job: job),
      ),
    ).then((_) => fetchMyJobs());
  }

  String _formatSalary(Map? salaryRange) {
    if (salaryRange == null) return 'N/A';
    final min = salaryRange['min']?.toString() ?? '';
    final max = salaryRange['max']?.toString() ?? '';
    if (min.isEmpty && max.isEmpty) return 'N/A';
    if (min.isEmpty) return '₹$max';
    if (max.isEmpty) return '₹$min';
    return '₹$min - ₹$max';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;
      
      if (difference == 0) return 'Today';
      if (difference == 1) return 'Yesterday';
      if (difference < 7) return '$difference days ago';
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString.substring(0, 10);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search jobs by location...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterJobs();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, int index) {
    final destinationLocation = job['destinationLocation'];
    final showDestination = destinationLocation != null && 
                            destinationLocation.isNotEmpty &&
                            destinationLocation != 'Destination not specified';
    
    final status = job['status'];
    final showStatus = status != null && 
                       status.isNotEmpty && 
                       status.toLowerCase() != 'pending';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => navigateToEditJob(job),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                // Header with status badge
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job['sourceLocation'] ?? 'Location not specified',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (showDestination) ...[
                              const SizedBox(height: 4),
                              Text(
                                '→ $destinationLocation',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (showStatus)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(job['status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getStatusColor(job['status']).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            status.toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(job['status']),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Job details section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Truck image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 80,
                          height: 80,
                          child: (job['lorryPhotos'] != null && 
                                  job['lorryPhotos'].isNotEmpty)
                              ? Image.network(
                                  job['lorryPhotos'][0],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                    'assets/images/placeholder_truck.png',
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/placeholder_truck.png',
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Job info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              Icons.local_shipping,
                              'Truck Type',
                              job['truckType'] ?? 'Not specified',
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.currency_rupee,
                              'Salary',
                              _formatSalary(job['salaryRange']),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.calendar_today,
                              'Posted',
                              _formatDate(job['createdAt']),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Actions section
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: Colors.blue,
                        tooltip: 'Edit Job',
                        onPressed: () => navigateToEditJob(job),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        color: Colors.red,
                        tooltip: 'Delete Job',
                        onPressed: () => _showDeleteConfirmation(job),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation(Map job) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Delete Job'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this job?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${job['sourceLocation'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      deleteJob(job['_id']);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.work_off_outlined,
                size: 64,
                color: Colors.blue.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Jobs Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              searchQuery.isNotEmpty
                  ? 'Try adjusting your search'
                  : 'Start by posting your first job to connect with drivers',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: searchQuery.isNotEmpty
                  ? () {
                      _searchController.clear();
                      _filterJobs();
                    }
                  : navigateToCreateJob,
              icon: Icon(searchQuery.isNotEmpty
                  ? Icons.clear_all
                  : Icons.add),
              label: Text(searchQuery.isNotEmpty
                  ? 'Clear Search'
                  : 'Post Your First Job'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              "My Posted Jobs",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (!isLoading && filteredJobs.isNotEmpty)
              Text(
                '${filteredJobs.length} job${filteredJobs.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          AnimatedBuilder(
            animation: _refreshController,
            builder: (context, child) {
              return IconButton(
                icon: Transform.rotate(
                  angle: _refreshController.value * 2.0 * 3.14159,
                  child: const Icon(Icons.refresh),
                ),
                onPressed: isLoading ? null : fetchMyJobs,
                tooltip: 'Refresh',
              );
            },
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: FloatingActionButton.extended(
          onPressed: navigateToCreateJob,
          icon: const Icon(Icons.add),
          label: const Text('Post New Job'),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 8,
        ),
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading your jobs...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Oops! Something went wrong',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: fetchMyJobs,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Try Again"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildSearchBar(),
                    Expanded(
                      child: filteredJobs.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: fetchMyJobs,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: filteredJobs.length,
                                itemBuilder: (context, index) {
                                  return _buildJobCard(
                                    filteredJobs[index] as Map<String, dynamic>,
                                    index,
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
