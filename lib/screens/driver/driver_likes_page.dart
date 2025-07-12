import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/job_detail_page.dart';

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

    final response = await http.get(
      Uri.parse('${ApiConfig.likes}/user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final responseBody = jsonDecode(response.body);
    debugPrint('Response: ${response.statusCode}, Body: $responseBody');

    if (response.statusCode == 200) {
      final List<dynamic> jobs = responseBody;
      setState(() {
        likedJobs = jobs;
        isLoading = false;
      });
    } else {
      // Handle different error cases
      final errorMsg = responseBody['error'] ?? 
                       responseBody['message'] ?? 
                       'Failed to load liked jobs: ${response.statusCode}';
      throw Exception(errorMsg);
    }
  } catch (e) {
    setState(() {
      isLoading = false;
      errorMessage = e.toString().replaceAll('Exception: ', '');
    });
    debugPrint('Detailed error: $e');
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
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 4),
                    Text(job['sourceLocation']),
                  ],
                ),
              const SizedBox(height: 8),
              if (job['salaryRange'] != null)
                Row(
                  children: [
                    const Icon(Icons.attach_money, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '₹${job['salaryRange']['min']} - ₹${job['salaryRange']['max']}',
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              if (job['ownerId'] != null && job['ownerId']['companyName'] != null)
                Row(
                  children: [
                    const Icon(Icons.business, size: 16),
                    const SizedBox(width: 4),
                    Text(job['ownerId']['companyName']),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
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
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchLikedJobs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (likedJobs.isEmpty) {
      return const Center(
        child: Text(
          'No liked jobs yet',
          style: TextStyle(fontSize: 18, color: Colors.grey),
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