import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate_app/api_config.dart';
import 'job_detail_page.dart';
import 'package:shimmer/shimmer.dart';
import 'package:animate_do/animate_do.dart';

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
  static const petrolBlue = Color(0xFF1A56DB);
  static const petrolCard = Color(0xFFE6F0FF);
}

class SpecificOwnerPosts extends StatefulWidget {
  final String ownerId;
  final String ownerName;
  final String? ownerPhoto;

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

    // Fetch owner profile
    final profileResponse = await http.get(
      Uri.parse('${ApiConfig.ownerProfile}/${widget.ownerId}'),
      headers: ApiConfig.authHeaders(token),
    );

    if (profileResponse.statusCode == 200 && _isMounted) {
      final profileData = jsonDecode(profileResponse.body);
      
      // Fetch user details to get the name
      final userResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/user/${widget.ownerId}'),
        headers: ApiConfig.authHeaders(token),
      );
      
      String ownerName = '';
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        ownerName = userData['name'] ?? '';
      }
      
      setState(() {
        ownerProfile = {
          ...profileData,
          'name': ownerName // Add the name to the profile data
        };
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

// NEW: Redesigned job card with petrol-themed styling
Widget _buildEnhancedJobCard(Map<String, dynamic> job, int index) {
  // Get the first image from the job post if available
  String? jobImageUrl = job['lorryPhotos'] != null && job['lorryPhotos'].isNotEmpty 
      ? job['lorryPhotos'][0] 
      : null;

  return FadeInUp(
    duration: Duration(milliseconds: 300 + (index * 100)),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.petrolCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.petrolBlue.withOpacity(0.1),
            offset: const Offset(0, 4),
            blurRadius: 12,
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
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Job image on the left
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.petrolBlue.withOpacity(0.1),
                    image: jobImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(jobImageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: jobImageUrl == null
                      ? Icon(
                          Icons.local_shipping,
                          size: 40,
                          color: AppColors.petrolBlue,
                        )
                      : null,
                ),
                
                const SizedBox(width: 16),
                
                // Details centered
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header with job type and status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Job type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.petrolBlue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              job['truckType'] ?? 'Truck',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Job title/description
                      if (job['description'] != null)
                        Text(
                          job['description'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Location information
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: AppColors.petrolBlue,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              job['sourceLocation'] ?? 'Location not specified',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Salary information
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.petrolBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.currency_rupee,
                              size: 14,
                              color: AppColors.petrolBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Salary: ',
                              style: TextStyle(
                                color: AppColors.petrolBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              job['salaryRange'] != null 
                                ? '₹${job['salaryRange']['min']}-${job['salaryRange']['max']}'
                                : 'Not specified',
                              style: TextStyle(
                                color: AppColors.petrolBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
Widget _buildOwnerHeader() {
  // Use company name since personal name is not available in the API response
  String displayName = ownerProfile?['companyName'] ?? widget.ownerName;
  
  if (displayName.isEmpty) {
    displayName = 'Owner';
  }

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
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display the company name as the primary identifier
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Show location if available
                  if (ownerProfile?['companyLocation'] != null)
                    Text(
                      ownerProfile!['companyLocation'],
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
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

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
                        SliverToBoxAdapter(
                          child: _buildOwnerHeader(),
                        ),
                        
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildEnhancedJobCard(jobs[index], index),
                            childCount: jobs.length,
                          ),
                        ),
                        
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
            'assets/images/empty_jobs.png',
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
}