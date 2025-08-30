import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:truckmate_app/api_config.dart';
import 'specific_owner_posts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:truckmate_app/utils/image_utils.dart';
import 'driver_profile_setup.dart'; // Add this import
import 'api_utils.dart'; // Add this import if available
import 'dart:async';

// Enhanced Theme Colors
const primaryColor = Color(0xFF1976D2);
const accentColor = Color.fromARGB(255, 255, 0, 0);
const primaryColor = Color(0xFF1976D2);
const accentColor = Color.fromARGB(255, 255, 0, 0);
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
  bool _showingImage = false;
  bool _hasSeenImageForThisJob = false;
  bool _showFullPhone = false;
  Timer? _imageTimer;
  
  // Add profile status variables
  bool _isProfileComplete = false;
  bool _isCheckingProfile = false;
  Map<String, dynamic>? _driverProfile;
  Map<String, dynamic>? _userData;

  // Add ScrollController and GlobalKey for scrolling to contact info
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _contactInfoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchJobDetails();
    _fetchOwnerProfile();
    _checkIfLiked();
    _checkIfImageSeenForThisJob();
    _checkDriverProfile(); // Add this line
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // NEW: Check driver profile completion status
  Future<void> _checkDriverProfile() async {
    setState(() {
      _isCheckingProfile = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      
      if (token == null) {
        setState(() {
          _isCheckingProfile = false;
          _isProfileComplete = false;
        });
        return;
      }

      // Get user data first
      final userResponse = await http.get(
        Uri.parse(ApiConfig.authMe),
        headers: {"Authorization": "Bearer $token"},
      );

      if (userResponse.statusCode == 200) {
        _userData = jsonDecode(userResponse.body);
      }

      // Check driver profile
      final profileResponse = await http.get(
        Uri.parse(ApiConfig.driverProfile),
        headers: {"Authorization": "Bearer $token"},
      );

      if (profileResponse.statusCode == 200) {
        final responseData = jsonDecode(profileResponse.body);
        _driverProfile = responseData['profile'];
        
        setState(() {
          _isProfileComplete = _driverProfile?['profileCompleted'] == true;
          _isCheckingProfile = false;
        });
      } else {
        setState(() {
          _isProfileComplete = false;
          _isCheckingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking driver profile: $e');
      setState(() {
        _isProfileComplete = false;
        _isCheckingProfile = false;
      });
    }
  }

  // NEW: Show profile incomplete dialog
  void _showProfileIncompleteDialog(String action) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Profile Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To $action, you need to complete your driver profile first.',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Complete your profile to access all features and get verified by admin.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToProfileSetup();
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Complete Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // NEW: Navigate to profile setup
  void _navigateToProfileSetup() {
    if (_userData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverProfileSetupPage(
            userData: _userData!,
          ),
        ),
      ).then((result) {
        // Refresh profile status after returning from setup
        if (result == true) {
          _checkDriverProfile();
        }
      });
    } else {
      _showErrorMessage('Unable to load user data. Please try again.');
    }
  }

  // Scroll to contact information section
  void _scrollToContactInfo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_contactInfoKey.currentContext != null) {
        final box = _contactInfoKey.currentContext!.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero);
        final scrollPosition = position.dy - MediaQuery.of(context).padding.top - kToolbarHeight;

        _scrollController.animateTo(
          scrollPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // Check if user has seen the image for THIS specific job
  Future<void> _checkIfImageSeenForThisJob() async {
    final prefs = await SharedPreferences.getInstance();
    final jobId = widget.job['_id']?.toString();
    if (jobId == null) return;

    final seenJobs = prefs.getStringList('seenCallImageJobs') ?? [];
    setState(() {
      _hasSeenImageForThisJob = seenJobs.contains(jobId);
      // If user has seen image for this job, show full phone immediately
      if (_hasSeenImageForThisJob) {
        _showFullPhone = true;
      }
    });
  }

  // Mark that user has seen the image for THIS specific job
  Future<void> _markImageAsSeenForThisJob() async {
    final prefs = await SharedPreferences.getInstance();
    final jobId = widget.job['_id']?.toString();
    if (jobId == null) return;

    final seenJobs = prefs.getStringList('seenCallImageJobs') ?? [];
    if (!seenJobs.contains(jobId)) {
      seenJobs.add(jobId);
      await prefs.setStringList('seenCallImageJobs', seenJobs);
    }

    setState(() {
      _hasSeenImageForThisJob = true;
      _showFullPhone = true; // Show full phone after seeing image
    });
  }

  // MODIFIED: Contact owner with profile check
  void _contactOwner() {
    // Check if profile is complete first
    if (!_isProfileComplete) {
      _showProfileIncompleteDialog('contact the owner');
      return;
    }

    // Only show image if it's the first time for THIS job
    if (!_hasSeenImageForThisJob) {
      _showImage();
    } else {
      // If already seen image for this job, just update the phone display and scroll to contact info
      setState(() {
        _showFullPhone = true;
      });
      _scrollToContactInfo();
    }
  }

  void _showImage() async {
    // Show the image
    setState(() {
      _showingImage = true;
    });

    // Show dialog with the image
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Image.asset('assets/images/ad.png'), // Replace with your actual image path
      ),
    );

    // Mark that user has seen the image for THIS job
    await _markImageAsSeenForThisJob();

    // Wait for 5 seconds
    await Future.delayed(const Duration(seconds: 5));

    // Close the image dialog
    Navigator.of(context).pop();

    // Reset the state
    setState(() {
      _showingImage = false;
      _showFullPhone = true; // Unmask the phone number
    });

    // Scroll to contact information after showing image
    _scrollToContactInfo();
  }

  String _getPhoneDisplay() {
    final phone = widget.job['phone']?.toString() ?? '';
    if (_showFullPhone || _hasSeenImageForThisJob) {
      return phone;
    }
    if (phone.length <= 4) return phone;
    return '******${phone.substring(phone.length - 4)}';
  }

  void _showFullScreenImage(int initialIndex) {
    final List<dynamic>? photosBase64 = widget.job['lorryPhotosBase64'] as List<dynamic>?;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(0),
          child: Stack(
            children: [
              PageView.builder(
                itemCount: photosBase64?.length ?? 0,
                itemCount: photosBase64?.length ?? 0,
                controller: PageController(initialPage: initialIndex),
                itemBuilder: (context, index) {
                  final bytes = ImageUtils.decodeBase64Image(photosBase64![index] as String?);
                  return InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: bytes != null
                        ? Image.memory(bytes, fit: BoxFit.contain)
                        : Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Text('Failed to load image', style: TextStyle(color: Colors.white)),
                            ),
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

  // MODIFIED: Toggle like with profile check
  Future<void> _toggleLike() async {
    // Check if profile is complete first
    if (!_isProfileComplete) {
      _showProfileIncompleteDialog('like this job');
      return;
    }

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
              builder: (context) => SpecificOwnerPosts(ownerId: widget.job['ownerId'], ownerName: ''),
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

  // Modified: Phone Number Box with Owner Info (without button)
  Widget _buildOwnerContactBox() {
    return Container(
      key: _contactInfoKey,
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
          // Owner Name
          Text(
            ownerProfile?['name'] ??
                widget.job['ownerName'] ??
                widget.job['owner']?['name'] ??
                'Owner Name',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          // Company Name
          if (ownerProfile?['companyName'] != null)
            Text(
              ownerProfile!['companyName'],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          const SizedBox(height: 16),
          // Phone Number Section
          Row(
            children: [
              Icon(Icons.phone, color: primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact Number',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: subTextColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getPhoneDisplay(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _showFullPhone ? primaryColor : textColor,
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

  // MODIFIED: Bottom Contact Button with profile status check
  Widget _buildBottomContactButton() {
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
        children: [
          // Show profile status if incomplete
          if (!_isProfileComplete && !_isCheckingProfile) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Complete your profile to contact owners',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          ElevatedButton(
            onPressed: _isCheckingProfile ? null : _contactOwner,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isProfileComplete ? primaryColor : Colors.grey,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isCheckingProfile
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    _isProfileComplete
                        ? (_hasSeenImageForThisJob ? 'View Phone Number' : 'Contact Owner')
                        : 'Complete Profile First',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
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

          if (widget.job['variant'] != null &&
              widget.job['variant']['type'] != null &&
              widget.job['variant']['type'].toString().isNotEmpty)
            _buildDetailRow(Icons.category, "Variant", widget.job['variant']['type']),
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
    // Try Base64 first
    final List<dynamic>? photosBase64 = widget.job['lorryPhotosBase64'] as List<dynamic>?;

    if (photosBase64 != null && photosBase64.isNotEmpty) {
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
              itemCount: photosBase64.length,
              itemBuilder: (context, index, realIndex) {
                final bytes = ImageUtils.decodeBase64Image(photosBase64[index] as String?);
                return GestureDetector(
                  onTap: () => _showFullScreenImage(index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: bytes != null
                        ? Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Container(
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

    // Fallback to URL-based images if Base64 not available
    if (widget.job['lorryPhotos'] != null && widget.job['lorryPhotos'].isNotEmpty) {
      final List<String> photoUrls = (widget.job['lorryPhotos'] as List).cast<String>();
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
              itemCount: photoUrls.length,
              itemBuilder: (context, index, realIndex) {
                return GestureDetector(
                  onTap: () => _showFullScreenImage(index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photoUrls[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 40, color: subTextColor),
                              SizedBox(height: 8),
                              Text('Failed to load image', style: TextStyle(color: subTextColor)),
                            ],
                          ),
                        );
                      },
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

    return Container();
  }

  @override
  Widget build(BuildContext context) {
    if (_showingImage) {
      return Scaffold(
        body: Center(
          child: Image.asset('assets/images/ad.png', fit: BoxFit.cover),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Job Details"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // MODIFIED: Like button with profile status indicator
          Stack(
            children: [
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(isLiked),
                    color: isLiked ? accentColor : Colors.white,
                  ),
                ),
                onPressed: _toggleLike,
              ),
              // Show warning dot if profile incomplete
              if (!_isProfileComplete && !_isCheckingProfile)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
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
                            _checkDriverProfile(); // Add this line
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
                    await _checkDriverProfile(); // Add this line
                  },
                  color: primaryColor,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    controller: _scrollController,
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

                        // Owner Contact Box with Phone Number (without button)
                        FadeInUp(
                          duration: const Duration(milliseconds: 650),
                          child: _buildOwnerContactBox(),
                        ),
                        const SizedBox(height: 16),

                        // Job Details with animation
                        FadeInUp(
                          duration: const Duration(milliseconds: 700),
                          child: _buildJobDetails(),
                        ),
                        const SizedBox(height: 16),

                        // MODIFIED: Bottom Contact Button with profile check
                        FadeInUp(
                          duration: const Duration(milliseconds: 750),
                          child: _buildBottomContactButton(),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
