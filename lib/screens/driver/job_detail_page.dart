import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:truckmate_app/api_config.dart';
import 'specific_owner_posts.dart';

class JobDetailPage extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobDetailPage({super.key, required this.job});

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  bool isLoading = true;
  Map<String, dynamic>? ownerProfile;
  bool isLiked = false;
  int likeCount = 0;
  String? errorMessage;
  String? likeId;

  @override
  void initState() {
    super.initState();
    _fetchJobDetails();
    _fetchOwnerProfile();
    _checkIfLiked();
  }

  void _showFullScreenImage(int initialIndex) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(0),
          child: Stack(
            children: [
              PageView.builder(
                itemCount: widget.job['lorryPhotos'].length,
                controller: PageController(initialPage: initialIndex),
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Image.network(
                      widget.job['lorryPhotos'][index],
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchJobDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.jobs}/${widget.job['_id']}'),
        headers: {"Authorization": "Bearer $token"},
      );

      debugPrint('Job details response: ${response.statusCode}');
      debugPrint('Job details body: ${response.body}');

      if (response.statusCode == 200) {
        final jobData = jsonDecode(response.body);
        setState(() {
          likeCount = jobData['likeCount'] ?? 0;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to load job details";
        });
      }
    } catch (e) {
      debugPrint('Error fetching job details: $e');
      setState(() {
        isLoading = false;
        errorMessage = "Network error occurred";
      });
    }
  }

  Future<void> _fetchOwnerProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.ownerProfile}/${widget.job['ownerId']}'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          ownerProfile = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching owner profile: $e");
    }
  }

  Future<void> _checkIfLiked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      
      if (token == null) {
        debugPrint('No auth token found');
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.checkLike}?likedItemId=${widget.job['_id']}'),
        headers: {"Authorization": "Bearer $token"},
      );

      debugPrint('Check like response: ${response.statusCode}');
      debugPrint('Check like body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          isLiked = result['isLiked'] ?? false;
          likeId = result['likeId'];
        });
      }
    } catch (e) {
      debugPrint("Error checking like: $e");
    }
  }

  Future<void> _toggleLike() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');

      if (token == null) {
        _showErrorMessage('Please login again');
        return;
      }

      // Optimistic update
      final bool previousLikeState = isLiked;
      final int previousLikeCount = likeCount;

      setState(() {
        isLiked = !isLiked;
        likeCount = isLiked ? likeCount + 1 : likeCount - 1;
      });

      http.Response response;

      if (isLiked) {
        // Like the job
        debugPrint('Liking job: ${widget.job['_id']}');
        response = await http.post(
          Uri.parse(ApiConfig.likes),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'likedItemId': widget.job['_id'],
          }),
        );
      } else {
        // Unlike the job
        debugPrint('Unliking job: ${widget.job['_id']}');
        response = await http.delete(
          Uri.parse('${ApiConfig.likes}/${widget.job['_id']}'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
      }

      debugPrint('Toggle like response: ${response.statusCode}');
      debugPrint('Toggle like body: ${response.body}');

      if (response.statusCode != 201 && response.statusCode != 200) {
        // Revert optimistic update
        setState(() {
          isLiked = previousLikeState;
          likeCount = previousLikeCount;
        });

        // Parse error message
        String errorMsg = 'Failed to ${isLiked ? 'unlike' : 'like'} job';
        try {
          final errorBody = jsonDecode(response.body);
          errorMsg = errorBody['error'] ?? errorMsg;
        } catch (e) {
          debugPrint('Error parsing error response: $e');
        }

        _showErrorMessage(errorMsg);
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      _showErrorMessage('Network error occurred');
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildOwnerSection() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SpecificOwnerPosts(
              ownerId: widget.job['ownerId'],
              ownerName: ownerProfile?['companyName'] ?? 'Owner',
            ),
          ),
        );
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: ownerProfile?['photoUrl'] != null
                    ? NetworkImage(ownerProfile!['photoUrl'])
                    : null,
                child: ownerProfile?['photoUrl'] == null
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ownerProfile?['companyName'] ?? 'Owner',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (widget.job['sourceLocation'] != null)
                      Text(
                        widget.job['sourceLocation'],
                        style: const TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.job['truckType'] ?? 'No Type Specified',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Salary Information
        if (widget.job['salaryRange'] != null)
          Row(
            children: [
              const Icon(Icons.attach_money, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                '₹${widget.job['salaryRange']['min']} - ₹${widget.job['salaryRange']['max']}',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        
        const SizedBox(height: 16),
        
        // Job Description
        if (widget.job['description'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Description:",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.job['description'],
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        
        const SizedBox(height: 16),
        
        // Additional Details
        const Text(
          "Details:",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        if (widget.job['experienceRequired'] != null)
          _buildDetailRow("Experience", widget.job['experienceRequired']),
        
        if (widget.job['dutyType'] != null)
          _buildDetailRow("Duty Type", widget.job['dutyType']),
        
        if (widget.job['variant'] != null && widget.job['variant']['type'] != null)
          _buildDetailRow("Variant", widget.job['variant']['type']),
        
        if (widget.job['variant'] != null && widget.job['variant']['wheelsOrFeet'] != null)
          _buildDetailRow("Configuration", widget.job['variant']['wheelsOrFeet']),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildImageGallery() {
    if (widget.job['lorryPhotos'] == null || widget.job['lorryPhotos'].isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          "Vehicle Photos",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.job['lorryPhotos'].length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () {
                    _showFullScreenImage(index);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.job['lorryPhotos'][index],
                      fit: BoxFit.cover,
                      width: 300,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 300,
                        color: Colors.grey[200],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 40),
                            Text('Failed to load image'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Job Details"),
        actions: [
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : null,
            ),
            onPressed: _toggleLike,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(child: Text('$likeCount')),
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
                      Text(errorMessage!),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });
                          _fetchJobDetails();
                          _fetchOwnerProfile();
                          _checkIfLiked();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildOwnerSection(),
                      const SizedBox(height: 20),
                      _buildJobDetails(),
                      const SizedBox(height: 20),
                      _buildImageGallery(),
                    ],
                  ),
                ),
    );
  }
}