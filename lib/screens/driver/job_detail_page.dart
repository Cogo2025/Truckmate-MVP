import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:truckmate_app/api_config.dart';
import 'specific_owner_posts.dart';
import 'package:carousel_slider/carousel_slider.dart'; // Add this dependency for better image gallery
import 'package:animate_do/animate_do.dart'; // Add this for animations (optional, or use built-in animations)

// Enhanced Theme Colors
const primaryColor = Color(0xFF1976D2); // Blue for logistics theme
const accentColor = Color.fromARGB(255, 255, 0, 0); // Orange accent
const backgroundColor = Color(0xFFF5F5F5);
const cardColor = Colors.white;
const textColor = Colors.black87;
const subTextColor = Colors.grey;

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
        setState(() {
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

      // Optimistic update with animation
      final bool previousLikeState = isLiked;

      setState(() {
        isLiked = !isLiked;
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Widget _buildOwnerInfo() {
    return GestureDetector(
      onTap: () {
        // Navigate to owner profile or specific posts if needed
        if (ownerProfile != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SpecificOwnerPosts(ownerId: widget.job['ownerId'], ownerName: '',),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: 'ownerAvatar_${widget.job['ownerId']}',
              child: CircleAvatar(
                radius: 30,
                backgroundColor: primaryColor.withOpacity(0.1),
                backgroundImage: ownerProfile?['photoUrl'] != null
                    ? NetworkImage(ownerProfile!['photoUrl'])
                    : null,
                child: ownerProfile?['photoUrl'] == null
                    ? Icon(Icons.person, size: 30, color: primaryColor)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ownerProfile?['name'] ??
                        widget.job['ownerName'] ??
                        widget.job['owner']?['name'] ??
                        'Loading...',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  if (widget.job['sourceLocation'] != null)
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: subTextColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.job['sourceLocation'],
                            style: TextStyle(color: subTextColor, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: subTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company Name
          if (ownerProfile?['companyName'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                ownerProfile!['companyName'],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),

          // Job Description
          if (widget.job['description'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.job['description'],
                style: const TextStyle(fontSize: 14, color: textColor, height: 1.5),
              ),
            ),

          const Divider(color: Color.fromRGBO(238, 238, 238, 1)),

          // Enhanced Detail Rows with Icons
          if (widget.job['truckType'] != null)
            _buildDetailRow(Icons.local_shipping, "Truck Type", widget.job['truckType']),

          if (widget.job['salaryRange'] != null)
            _buildDetailRow(
              Icons.attach_money,
              "Salary",
              '₹${widget.job['salaryRange']['min']} - ₹${widget.job['salaryRange']['max']}',
            ),

          if (widget.job['experienceRequired'] != null)
            _buildDetailRow(Icons.work_history, "Experience", widget.job['experienceRequired']),

          if (widget.job['dutyType'] != null)
            _buildDetailRow(Icons.schedule, "Duty Type", widget.job['dutyType']),

          if (widget.job['variant'] != null && widget.job['variant']['type'] != null)
            _buildDetailRow(Icons.category, "Variant", widget.job['variant']['type']),

          if (widget.job['variant'] != null && widget.job['variant']['wheelsOrFeet'] != null)
            _buildDetailRow(Icons.settings, "Configuration", widget.job['variant']['wheelsOrFeet']),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: subTextColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery() {
    if (widget.job['lorryPhotos'] == null || widget.job['lorryPhotos'].isEmpty) {
      return Container();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Vehicle Photos",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          CarouselSlider.builder(
            itemCount: widget.job['lorryPhotos'].length,
            itemBuilder: (context, index, realIndex) {
              return GestureDetector(
                onTap: () => _showFullScreenImage(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.job['lorryPhotos'][index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 40, color: subTextColor),
                          SizedBox(height: 8),
                          Text('Failed to load image', style: TextStyle(color: subTextColor)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            options: CarouselOptions(
              height: 200,
              viewportFraction: 0.8,
              enlargeCenterPage: true,
              enableInfiniteScroll: false,
              initialPage: 0,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 3),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.fastOutSlowIn,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Job Details"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey<bool>(isLiked),
                color: isLiked ? accentColor : Colors.white,
              ),
            ),
            onPressed: _toggleLike,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: textColor),
                        ),
                        const SizedBox(height: 16),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _fetchJobDetails();
                    await _fetchOwnerProfile();
                    await _checkIfLiked();
                  },
                  color: primaryColor,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Image Gallery with fade-in animation
                        FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          child: _buildImageGallery(),
                        ),
                        const SizedBox(height: 16),
                        // Owner Info with animation
                        FadeInUp(
                          duration: const Duration(milliseconds: 600),
                          child: _buildOwnerInfo(),
                        ),
                        const SizedBox(height: 16),
                        // Job Details with animation
                        FadeInUp(
                          duration: const Duration(milliseconds: 700),
                          child: _buildJobDetails(),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
