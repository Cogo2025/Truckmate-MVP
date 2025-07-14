import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/job_detail_page.dart';
import 'package:truckmate_app/screens/driver/api_utils.dart';

class DriverLikesPage extends StatefulWidget {
  const DriverLikesPage({Key? key}) : super(key: key);

  @override
  _DriverLikesPageState createState() => _DriverLikesPageState();
}

class _DriverLikesPageState extends State<DriverLikesPage> {
  List<dynamic> likedJobs = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLikedJobs();
  }

  Future<void> _fetchLikedJobs() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');

      if (token == null) {
        throw Exception('Not authenticated - please login again');
      }

      // Use the correct endpoint from ApiConfig
      final response = await http.get(
        Uri.parse('${ApiConfig.likes}/user'),
        headers: ApiUtils.getAuthHeaders(token),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        
        // Handle empty response or null
        if (responseBody.isEmpty || responseBody == 'null') {
          setState(() {
            likedJobs = [];
            isLoading = false;
          });
          return;
        }

        try {
          final dynamic decodedResponse = jsonDecode(responseBody);
          
          // Handle different response types
          List<dynamic> jobs = [];
          if (decodedResponse is List) {
            jobs = decodedResponse;
          } else if (decodedResponse is Map && decodedResponse.containsKey('data')) {
            jobs = decodedResponse['data'] ?? [];
          } else {
            jobs = [];
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
        // Handle error responses
        String errorMsg = 'Failed to load liked jobs';
        
        try {
          final errorResponse = jsonDecode(response.body);
          errorMsg = errorResponse['error'] ?? 
                    errorResponse['message'] ?? 
                    'Server error (${response.statusCode})';
        } catch (e) {
          errorMsg = 'Server error (${response.statusCode})';
        }
        
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error in _fetchLikedJobs: $e');
      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Widget _buildJobItem(BuildContext context, Map<String, dynamic> job) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailPage(job: job),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
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
              // Handle company name safely
              if (job['ownerId'] != null)
                Row(
                  children: [
                    const Icon(Icons.business, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _getCompanyName(job['ownerId']),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              // Add description if available
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
      ),
    );
  }

  String _getCompanyName(dynamic ownerData) {
    if (ownerData == null) return 'Unknown Company';
    
    // Handle different data structures
    if (ownerData is Map<String, dynamic>) {
      return ownerData['companyName'] ?? 'Unknown Company';
    } else if (ownerData is String) {
      return ownerData;
    }
    
    return 'Unknown Company';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liked Jobs'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLikedJobs,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLikedJobs,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading liked jobs...'),
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
              Text(
                'Error Loading Liked Jobs',
                style: const TextStyle(
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
              'Start browsing jobs and like the ones you\'re interested in!',
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