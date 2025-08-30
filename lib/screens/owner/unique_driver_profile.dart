import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UniqueDriverProfile extends StatefulWidget {
  final Map driver;
  const UniqueDriverProfile({
    super.key,
    required this.driver,
  });

  @override
  State<UniqueDriverProfile> createState() => _UniqueDriverProfileState();
}

class _UniqueDriverProfileState extends State<UniqueDriverProfile> {
  bool isLiked = false;
  bool isLoading = true;
  bool _showingImage = false;
  bool _hasSeenImageForThisDriver = false;
  bool _showFullPhone = false;
  
  // Add ScrollController and GlobalKey
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _contactInfoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkIfDriverLiked();
    _checkIfImageSeenForThisDriver();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  // Check if user has seen the image for THIS specific driver
  Future<void> _checkIfImageSeenForThisDriver() async {
    final prefs = await SharedPreferences.getInstance();
    final driverId = widget.driver['id']?.toString();
    if (driverId == null) return;
    
    final seenDrivers = prefs.getStringList('seenCallImageDrivers') ?? [];
    setState(() {
      _hasSeenImageForThisDriver = seenDrivers.contains(driverId);
      // If user has seen image for this driver, show full phone immediately
      if (_hasSeenImageForThisDriver) {
        _showFullPhone = true;
      }
    });
  }

  // Mark that user has seen the image for THIS specific driver
  Future<void> _markImageAsSeenForThisDriver() async {
    final prefs = await SharedPreferences.getInstance();
    final driverId = widget.driver['id']?.toString();
    if (driverId == null) return;
    
    final seenDrivers = prefs.getStringList('seenCallImageDrivers') ?? [];
    if (!seenDrivers.contains(driverId)) {
      seenDrivers.add(driverId);
      await prefs.setStringList('seenCallImageDrivers', seenDrivers);
    }
    
    setState(() {
      _hasSeenImageForThisDriver = true;
      _showFullPhone = true; // Show full phone after seeing image
    });
  }

  Future<void> _checkIfDriverLiked() async {
    final freshToken = await AuthService.getFreshAuthToken();
    if (freshToken == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.checkDriverLike}?driverId=${widget.driver['id']}'),
        headers: {"Authorization": "Bearer $freshToken"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          isLiked = data['isLiked'] ?? false;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleDriverLike() async {
    final freshToken = await AuthService.getFreshAuthToken();
    if (freshToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please re-login.")),
      );
      return;
    }

    try {
      if (isLiked) {
        await _unlikeDriver(freshToken);
      } else {
        await _likeDriver(freshToken);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error toggling like: $e")),
      );
    }
  }

  Future<void> _likeDriver(String token) async {
    final response = await http.post(
      Uri.parse(ApiConfig.likeDriver),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({'driverId': widget.driver['id'].toString()}),
    );

    if (response.statusCode == 201) {
      setState(() => isLiked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Driver added to favorites")),
      );
    } else {
      throw Exception("Failed to like driver");
    }
  }

  Future<void> _unlikeDriver(String token) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.unlikeDriver}${widget.driver['id']}'),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      setState(() => isLiked = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Driver removed from favorites")),
      );
    } else {
      throw Exception("Failed to unlike driver");
    }
  }

  void _contactDriver() {
    // Only show image if it's the first time for THIS driver
    if (!_hasSeenImageForThisDriver) {
      _showImage();
    } else {
      // If already seen image for this driver, just update the phone display and scroll to contact info
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
    
    // Mark that user has seen the image for THIS driver
    await _markImageAsSeenForThisDriver();
    
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
    final phone = widget.driver['phone'] ?? '';
    if (_showFullPhone || _hasSeenImageForThisDriver) {
      return phone;
    }
    if (phone.length <= 4) return phone;
    return '******${phone.substring(phone.length - 4)}';
  }

  // Updated _buildProfileSection to accept key parameter
  Widget _buildProfileSection({
    Key? key,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      key: key, // Pass the key to the Column
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_showingImage) {
      return Scaffold(
        body: Center(
          child: Image.asset('assets/images/banner1.jpg'), // Replace with your actual image path
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.driver['name'] ?? 'Driver Profile'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!isLoading)
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_outline,
                color: isLiked ? Colors.red : Colors.white,
              ),
              onPressed: _toggleDriverLike,
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController, // Add scroll controller
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: widget.driver['photoUrl'] != null && widget.driver['photoUrl'].isNotEmpty
                            ? NetworkImage(widget.driver['photoUrl'])
                            : null,
                        backgroundColor: Colors.grey.shade200,
                        child: (widget.driver['photoUrl'] == null || widget.driver['photoUrl'].isEmpty)
                            ? const Icon(Icons.person, size: 60, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.driver['name'] ?? 'Unknown Driver',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Available',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, size: 20, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        "${widget.driver['rating'] ?? '0.0'}",
                        style: TextStyle(
                          fontSize: 18,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.work, size: 20, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        "${widget.driver['experience'] ?? 'N/A'} years experience",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Contact Information - Add GlobalKey here
            _buildProfileSection(
              key: _contactInfoKey, // Add key to contact info section
              title: 'Contact Information',
              icon: Icons.contact_phone,
              children: [
                _buildProfileItem(Icons.phone, 'Phone', _getPhoneDisplay()),
                _buildProfileItem(Icons.email, 'Email', widget.driver['email'] ?? 'N/A'),
                _buildProfileItem(Icons.location_on, 'Location', widget.driver['location'] ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 24),
            // Experience & Skills
            _buildProfileSection(
              title: 'Experience & Skills',
              icon: Icons.work,
              children: [
                _buildProfileItem(Icons.timer, 'Experience', '${widget.driver['experience'] ?? 'N/A'} years'),
                _buildProfileItem(Icons.star, 'Rating', '${widget.driver['rating'] ?? 'N/A'} out of 5'),
                _buildProfileItem(Icons.local_shipping, 'Truck Types',
                    widget.driver['truckTypes']?.join(', ') ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 24),
            // Truck Types Chips
            if (widget.driver['truckTypes'] != null && widget.driver['truckTypes'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_shipping, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Specialized Vehicles',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (widget.driver['truckTypes'] as List)
                        .map((type) => Chip(
                              label: Text(
                                type.toString(),
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: theme.primaryColor.withOpacity(0.1),
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: theme.primaryColor.withOpacity(0.3),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            // Additional Info
            if (widget.driver['bio'] != null || widget.driver['specializations'] != null)
              _buildProfileSection(
                title: 'Additional Information',
                icon: Icons.info,
                children: [
                  if (widget.driver['bio'] != null)
                    _buildProfileItem(Icons.person, 'Bio', widget.driver['bio']),
                  if (widget.driver['specializations'] != null)
                    _buildProfileItem(Icons.build, 'Specializations',
                        widget.driver['specializations']?.join(', ') ?? 'N/A'),
                ],
              ),
            
            const SizedBox(height: 32),
            // Contact Button Only (Hire Driver button removed)
            Center(
              child: ElevatedButton.icon(
                onPressed: _contactDriver,
                icon: const Icon(Icons.phone),
                label: Text(_hasSeenImageForThisDriver ? 'View Phone Number' : 'Phone Number'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}