import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/job_detail_page.dart';
import 'package:truckmate_app/screens/driver/api_utils.dart';
import 'package:truckmate_app/services/auth_service.dart';

class DriverLikesPage extends StatefulWidget {
  const DriverLikesPage({Key? key, this.onRefresh}) : super(key: key);
  final VoidCallback? onRefresh;

  @override
  DriverLikesPageState createState() => DriverLikesPageState();
}

class DriverLikesPageState extends State<DriverLikesPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>> likedJobs = [];
  bool isLoading = true;
  bool showSlowConnectionMessage = false;
  String? errorMessage;
  Timer? _slowConnectionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchLikedJobs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _slowConnectionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchLikedJobs();
    }
  }

  Future<void> refreshLikedJobs() async {
    await _fetchLikedJobs();
  }

  void _startSlowConnectionTimer() {
    _slowConnectionTimer?.cancel();
    _slowConnectionTimer = Timer(const Duration(seconds: 20), () {
      if (isLoading && mounted) {
        setState(() {
          showSlowConnectionMessage = true;
        });
      }
    });
  }

  void _cancelSlowConnectionTimer() {
    _slowConnectionTimer?.cancel();
    if (showSlowConnectionMessage && mounted) {
      setState(() {
        showSlowConnectionMessage = false;
      });
    }
  }

  Future<void> _fetchLikedJobs() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
        showSlowConnectionMessage = false;
      });
      _startSlowConnectionTimer();

      final token = await AuthService.getFreshAuthToken();
      if (token == null) {
        throw Exception('Not authenticated - please login again');
      }

      final response = await http.get(
        Uri.parse(ApiConfig.userLikes),
        headers: ApiUtils.getAuthHeaders(token),
      );

      _cancelSlowConnectionTimer();

      debugPrint('Liked jobs response status: ${response.statusCode}');
      debugPrint('Liked jobs response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty || responseBody == 'null') {
          setState(() {
            likedJobs = [];
            isLoading = false;
          });
          return;
        }

        try {
          final dynamic decodedResponse = jsonDecode(responseBody);
          List<Map<String, dynamic>> jobs = [];
          if (decodedResponse is List) {
            jobs = (decodedResponse as List<dynamic>)
                .map((item) => (item as Map<Object?, Object?>).cast<String, dynamic>())
                .toList();
          } else if (decodedResponse is Map && decodedResponse.containsKey('data')) {
            final data = decodedResponse['data'] as List<dynamic>? ?? [];
            jobs = data.map((item) => (item as Map<Object?, Object?>).cast<String, dynamic>()).toList();
          }

          setState(() {
            likedJobs = jobs;
            isLoading = false;
          });
        } catch (jsonError) {
          debugPrint('JSON decode error: $jsonError');
          throw Exception('Invalid response format from server');
        }
      } else {
        String errorMsg = 'Failed to load liked jobs';
        try {
          final errorResponse = jsonDecode(response.body);
          errorMsg = errorResponse['error'] ?? errorResponse['message'] ?? 'Server error (${response.statusCode})';
        } catch (e) {
          errorMsg = 'Server error (${response.statusCode})';
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error in _fetchLikedJobs: $e');
      _cancelSlowConnectionTimer();
      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _unlikeJob(String jobId) async {
    try {
      final token = await AuthService.getFreshAuthToken();
      if (token == null) {
        throw Exception('Not authenticated - please login again');
      }

      final response = await http.delete(
        Uri.parse('${ApiConfig.likes}/$jobId'),
        headers: ApiUtils.getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        // Remove the job from the list
        setState(() {
          likedJobs.removeWhere((job) => job['_id'] == jobId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job removed from likes')),
        );
      } else {
        throw Exception('Failed to unlike job');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Widget _buildJobItem(BuildContext context, Map<String, dynamic> job) {
    final Map<String, dynamic> formattedJob = Map<String, dynamic>.from(job);
    
    if (job['ownerId'] is Map) {
      final ownerMap = job['ownerId'] as Map<String, dynamic>;
      formattedJob['owner'] = ownerMap;
    }
    
    // Get the first image if available
    final List<dynamic> lorryPhotos = job['lorryPhotos'] is List ? job['lorryPhotos'] : [];
    final String? firstImageUrl = lorryPhotos.isNotEmpty ? lorryPhotos[0] : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailPage(job: formattedJob),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job photo on the left
              if (firstImageUrl != null)
                Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(firstImageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              
              // Job details in the center
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
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              job['sourceLocation'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    if (job['salaryRange'] != null)
                      Row(
                        children: [
                          const Icon(Icons.attach_money, size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            '₹${job['salaryRange']['min']} - ₹${job['salaryRange']['max']}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    if (job['owner'] != null)
                      Row(
                        children: [
                          const Icon(Icons.business, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _getCompanyName(job['owner']),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    if (job['description'] != null && job['description'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          job['description'],
                          style: const TextStyle(color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Unlike button on the right
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () => _unlikeJob(job['_id']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCompanyName(dynamic ownerData) {
    if (ownerData == null) return 'Unknown Company';
    if (ownerData is Map) {
      return ownerData['companyName'] ?? 'Unknown Company';
    }
    return 'Unknown Company';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liked Jobs'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLikedJobs,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            if (showSlowConnectionMessage) ...[
              const Text(
                'Loading liked jobs...',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.wifi_off,
                      size: 32,
                      color: Colors.orange[600],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Slow Internet Connection',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please check your internet connection and try again',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text('Loading liked jobs...'),
            ],
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              const Text(
                'Error Loading Liked Jobs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchLikedJobs,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (likedJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No liked jobs yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start browsing jobs and like the ones youre interested in!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: likedJobs.length,
      itemBuilder: (context, index) {
        return _buildJobItem(context, likedJobs[index]);
      },
    );
  }
}