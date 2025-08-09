import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate_app/api_config.dart';
import 'job_detail_page.dart';
import 'package:shimmer/shimmer.dart'; // Add for loading animations
import 'package:animate_do/animate_do.dart'; // For smooth animations

// Enhanced color scheme
class AppColors {
  static const primary = Color(0xFF2196F3);
  static const primaryDark = Color(0xFF1976D2);
  static const accent = Color(0xFFFF9800);
  static const background = Color(0xFFF8F9FA);
  static const surface = Colors.white;
  static const error = Color(0xFFE53E3E);
  static const success = Color(0xFF38A169);
  static const textPrimary = Color(0xFF2D3748);
  static const textSecondary = Color(0xFF718096);
}

class SpecificOwnerPosts extends StatefulWidget {
  final String ownerId;
  final String ownerName;
  final String? ownerPhoto; // Add owner photo parameter

  const SpecificOwnerPosts({
    super.key,
    required this.ownerId,
    required this.ownerName,
    this.ownerPhoto,
  });

  @override
  State<SpecificOwnerPosts> createState() => _SpecificOwnerPostsState();
}

class _SpecificOwnerPostsState extends State<SpecificOwnerPosts>
    with TickerProviderStateMixin {
  List<dynamic> jobs = [];
  Map<String, dynamic>? ownerProfile;
  bool isLoading = true;
  String? errorMessage;
  bool _isMounted = false;
  late AnimationController _animationController;
  String sortBy = 'newest'; // newest, salary_high, salary_low
  String filterBy = 'all'; // all, full_time, part_time

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fetchOwnerData();
  }

  @override
  void dispose() {
    _isMounted = false;
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchOwnerData() async {
    await Future.wait([
      _fetchOwnerProfile(),
      _fetchOwnerJobs(),
    ]);
    _animationController.forward();
  }

  Future<void> _fetchOwnerProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      if (token == null || !_isMounted) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.ownerProfile}/${widget.ownerId}'),
        headers: ApiConfig.authHeaders(token),
      );

      if (response.statusCode == 200 && _isMounted) {
        setState(() {
          ownerProfile = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching owner profile: $e");
    }
  }
Future<void> _fetchOwnerJobs() async {
    if (!_isMounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      
      if (token == null) {
        if (_isMounted) {
          setState(() {
            isLoading = false;
            errorMessage = "Authentication required. Please login again.";
          });
        }
        return;
      }

      final url = Uri.parse(ApiConfig.getOwnerJobs(widget.ownerId));
      debugPrint("Attempting to fetch from: $url");

      final response = await http.get(
        url,
        headers: ApiConfig.authHeaders(token),
      );

      debugPrint("Response status: ${response.statusCode}");
      debugPrint("Response body start: ${response.body.length > 50 ? response.body.substring(0, 50) : response.body}");

      if (!_isMounted) return;

      if (response.statusCode == 200) {
        if (response.body.trim().startsWith('<!DOCTYPE html>')) {
          throw Exception("Server returned HTML page. Wrong endpoint?");
        }

        final responseBody = jsonDecode(response.body);
        setState(() {
          jobs = responseBody is List ? responseBody : [];
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error details: $e");
      if (!_isMounted) return;
      setState(() {
        isLoading = false;
        errorMessage = _parseError(e);
      });
    }
  }

  String _parseError(dynamic error) {
    if (error.toString().contains('Failed host lookup')) {
      return "Network unavailable. Check your connection.";
    } else if (error.toString().contains('<!DOCTYPE html>')) {
      return "Server returned unexpected response. Check API endpoint.";
    }
    return "Error loading jobs: ${error.toString().replaceAll('Exception: ', '')}";
  }
  // Enhanced job card with better visual hierarchy
  Widget _buildEnhancedJobCard(Map<String, dynamic> job, int index) {
    return FadeInUp(
      duration: Duration(milliseconds: 300 + (index * 100)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, 4),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _navigateToJobDetail(job),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with truck type and status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          job['truckType'] ?? 'Truck',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getDutyTypeColor(job['dutyType']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          job['dutyType'] ?? 'Full Time',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Job description or title
                  if (job['description'] != null)
                    Text(
                      job['description'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Location with improved icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          job['sourceLocation'] ?? 'Location not specified',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bottom row with salary and experience
                  Row(
                    children: [
                      // Salary
                      if (job['salaryRange'] != null)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.currency_rupee,
                                  size: 16,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${job['salaryRange']['min']}-${job['salaryRange']['max']}',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      const SizedBox(width: 12),
                      
                      // Experience
                      if (job['experienceRequired'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.work_outline,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                job['experienceRequired'],
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const Spacer(),
                      
                      // Arrow indicator
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced owner header
  Widget _buildOwnerHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Owner avatar
              Hero(
                tag: 'owner_${widget.ownerId}',
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    backgroundImage: (ownerProfile?['photoUrl'] != null)
                        ? NetworkImage(ownerProfile!['photoUrl'])
                        : null,
                    child: (ownerProfile?['photoUrl'] == null)
                        ? Icon(
                            Icons.person,
                            size: 35,
                            color: AppColors.primary,
                          )
                        : null,
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Owner info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ownerName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (ownerProfile?['companyName'] != null)
                      Text(
                        ownerProfile!['companyName'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${jobs.length} Active Jobs',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Filter and sort controls
  Widget _buildFilterSortControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Filter dropdown
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textSecondary.withOpacity(0.2),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: filterBy,
                  icon: Icon(
                    Icons.filter_list,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      filterBy = newValue!;
                    });
                    _applyFiltersAndSort();
                  },
                  items: [
                    DropdownMenuItem(value: 'all', child: Text('All Jobs')),
                    DropdownMenuItem(value: 'full_time', child: Text('Full Time')),
                    DropdownMenuItem(value: 'part_time', child: Text('Part Time')),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Sort dropdown
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textSecondary.withOpacity(0.2),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: sortBy,
                  icon: Icon(
                    Icons.sort,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      sortBy = newValue!;
                    });
                    _applyFiltersAndSort();
                  },
                  items: [
                    DropdownMenuItem(value: 'newest', child: Text('Newest')),
                    DropdownMenuItem(value: 'salary_high', child: Text('Salary High')),
                    DropdownMenuItem(value: 'salary_low', child: Text('Salary Low')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shimmer loading effect
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  // Helper methods
  Color _getDutyTypeColor(String? dutyType) {
    switch (dutyType?.toLowerCase()) {
      case 'full time':
        return AppColors.success;
      case 'part time':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  void _navigateToJobDetail(Map<String, dynamic> job) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            JobDetailPage(job: job),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _applyFiltersAndSort() {
    // Implement filtering and sorting logic here
    List<dynamic> filteredJobs = List.from(jobs);
    
    // Apply filters
    if (filterBy != 'all') {
      filteredJobs = filteredJobs.where((job) {
        return job['dutyType']?.toLowerCase().replaceAll(' ', '_') == filterBy;
      }).toList();
    }
    
    // Apply sorting
    filteredJobs.sort((a, b) {
      switch (sortBy) {
        case 'salary_high':
          return (b['salaryRange']?['max'] ?? 0).compareTo(
              a['salaryRange']?['max'] ?? 0);
        case 'salary_low':
          return (a['salaryRange']?['min'] ?? 0).compareTo(
              b['salaryRange']?['min'] ?? 0);
        default: // newest
          return 0; // Add timestamp comparison if available
      }
    });
    
    setState(() {
      jobs = filteredJobs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Jobs by ${widget.ownerName}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchOwnerData,
          ),
        ],
      ),
      body: isLoading
          ? _buildShimmerLoading()
          : errorMessage != null
              ? _buildErrorState()
              : jobs.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchOwnerData,
                      color: AppColors.primary,
                      child: CustomScrollView(
                        slivers: [
                          // Owner header
                          SliverToBoxAdapter(
                            child: _buildOwnerHeader(),
                          ),
                          
                          // Filter and sort controls
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildFilterSortControls(),
                            ),
                          ),
                          
                          // Job list
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildEnhancedJobCard(jobs[index], index),
                              childCount: jobs.length,
                            ),
                          ),
                          
                          // Bottom padding
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 80),
                          ),
                        ],
                      ),
                    ),
    );
  }
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchOwnerJobs,
            icon: const Icon(Icons.refresh),
            label: const Text("Try Again"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          Image.asset(
            'assets/images/empty_jobs.png', // Add this asset to your project
            width: 150,
            height: 150,
            color: Colors.blueGrey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            "No jobs available",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "This owner hasn't posted any jobs yet",
            style: TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
  // Keep your existing methods for _fetchOwnerJobs, _buildErrorState, _buildEmptyState, etc.
  // Just update them with the new color scheme and styling
}
