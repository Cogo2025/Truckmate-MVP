import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckmate_app/api_config.dart';
import 'job_detail_page.dart';

class SpecificOwnerPosts extends StatefulWidget {
  final String ownerId;
  final String ownerName;

  const SpecificOwnerPosts({
    super.key,
    required this.ownerId,
    required this.ownerName,
  });

  @override
  State<SpecificOwnerPosts> createState() => _SpecificOwnerPostsState();
}

class _SpecificOwnerPostsState extends State<SpecificOwnerPosts> {
  List<dynamic> jobs = [];
  bool isLoading = true;
  String? errorMessage;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _fetchOwnerJobs();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
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

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Card(
      margin: const EdgeInsets.all(6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailPage(job: job),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      job['truckType'] ?? 'No Truck Type',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      job['dutyType'] ?? 'Full Time',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 12, color: Colors.blueGrey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job['sourceLocation'] ?? 'No Location',
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (job['salaryRange'] != null)
                Row(
                  children: [
                    const Icon(Icons.attach_money, size: 12, color: Colors.green),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '₹${job['salaryRange']['min']} - ₹${job['salaryRange']['max']}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 6),
              if (job['experienceRequired'] != null)
                Row(
                  children: [
                    const Icon(Icons.work_history, size: 12, color: Colors.blueGrey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job['experienceRequired'],
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      physics: const ClampingScrollPhysics(), // Reduces scroll sensitivity
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        return _buildJobCard(jobs[index]);
      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Jobs by ${widget.ownerName}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF57C00),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchOwnerJobs,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF57C00),
              Colors.white,
            ],
            stops: [0.1, 0.1],
          ),
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueGrey),
                ),
              )
            : errorMessage != null
                ? _buildErrorState()
                : jobs.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchOwnerJobs,
                        color: Colors.blueGrey,
                        backgroundColor: Colors.white,
                        child: ScrollConfiguration(
                          behavior: const ScrollBehavior().copyWith(
                            physics: const ClampingScrollPhysics(),
                            overscroll: false,
                            scrollbars: false,
                          ),
                          child: _buildJobsGrid(),
                        ),
                      ),
      ),
    );
  }
}