import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:truckmate_app/api_config.dart';

class MyPostedJobsPage extends StatefulWidget {
  const MyPostedJobsPage({super.key});

  @override
  State<MyPostedJobsPage> createState() => _MyPostedJobsPageState();
}

class _MyPostedJobsPageState extends State<MyPostedJobsPage> {
  bool isLoading = true;
  List<dynamic> jobPosts = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchMyJobs();
  }

  Future<void> fetchMyJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) {
      setState(() {
        isLoading = false;
        errorMessage = "Token missing. Please log in.";
      });
      return;
    }

    try {
      final res = await http.get(
        Uri.parse(ApiConfig.ownerJobs),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        setState(() {
          jobPosts = jsonDecode(res.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Failed to load posts";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  Widget _buildJobDetails(Map<String, dynamic> job) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Truck Type: ${job['truckType'] ?? 'N/A'}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Variant: ${job['variant']?['wheelsOrFeet'] ?? 'N/A'}"),
        Text("Location: ${job['sourceLocation'] ?? 'N/A'}"),
        Text("Experience: ${job['experienceRequired'] ?? 'N/A'}"),
        Text("Salary: ₹${job['salaryRange']?['min'] ?? ''} - ₹${job['salaryRange']?['max'] ?? ''}"),
        Text("Posted on: ${job['createdAt']?.substring(0, 10) ?? 'N/A'}"),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Posted Jobs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchMyJobs,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage!, 
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: fetchMyJobs,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : jobPosts.isEmpty
                  ? const Center(
                      child: Text(
                        "You haven't posted any jobs yet",
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView.builder(
                        itemCount: jobPosts.length,
                        itemBuilder: (context, index) {
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: _buildJobDetails(jobPosts[index]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}