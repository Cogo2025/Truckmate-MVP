import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../api_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Add this import

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
  bool _showFullPhone = false;
  bool _showingImage = false; // Track if we're showing the image
  bool _hasSeenImageBefore = false; // Track if user has seen the image
@override
  void initState() {
    super.initState();
    _checkIfDriverLiked();
    _checkIfImageSeenBefore();
  }

  // Check if user has seen the image before
  Future<void> _checkIfImageSeenBefore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasSeenImageBefore = prefs.getBool('hasSeenCallImage') ?? false;
    });
  }

  // Mark that user has seen the image
  Future<void> _markImageAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenCallImage', true);
    setState(() {
      _hasSeenImageBefore = true;
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: const Text(
            'Contact Driver',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              'You can contact this driver through the following methods:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('Call Driver'),
              subtitle: Text(_showFullPhone 
                ? widget.driver['phone'] ?? 'N/A' 
                : _getMaskedPhone()),
              trailing: IconButton(
                icon: Icon(
                  _showFullPhone ? Icons.visibility_off : Icons.visibility,
                  color: Theme.of(context).primaryColor,
                ),
                onPressed: () {
                  setState(() {
                    _showFullPhone = !_showFullPhone;
                  });
                  Navigator.pop(context);
                  _contactDriver();
                },
              ),
            ),
            
            const Text(
              'Note: Please be professional and respectful when contacting drivers.',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Only show image if it's the first time
              if (!_hasSeenImageBefore) {
                _showImageAndCall();
              } else {
                _makePhoneCall();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Call Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showImageAndCall() async {
    // Show the image
    setState(() {
      _showingImage = true;
    });
    
    // Show dialog with the image
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Image.asset('assets/images/banner1.jpg'), // Replace with your actual image path
      ),
    );
    
    // Mark that user has seen the image
    await _markImageAsSeen();
    
    // Wait for 5 seconds
    await Future.delayed(const Duration(seconds: 5));
    
    // Close the image dialog
    Navigator.of(context).pop();
    
    // Reset the state
    setState(() {
      _showingImage = false;
    });
    
    // Make the phone call
    _makePhoneCall();
  }

  // Method to make the actual phone call
  void _makePhoneCall() async {
    final phoneNumber = widget.driver['phone'];
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number not available")),
      );
      return;
    }
    
    final url = 'tel:$phoneNumber';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  String _getMaskedPhone() {
    final phone = widget.driver['phone'] ?? '';
    if (phone.length <= 4) return phone;
    return '******${phone.substring(phone.length - 4)}';
  }

 

  void _hireDriver() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: const Text(
            'Hire Driver',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              'Send hiring request to ${widget.driver['name']}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 15),
            const Text(
              'This will notify the driver of your interest. You can discuss details directly once they accept your request.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            const Text(
              'Driver Details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 5),
                Text("Rating: ${widget.driver['rating'] ?? 'N/A'}"),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.work, size: 16, color: Colors.blue),
                const SizedBox(width: 5),
                Text("Experience: ${widget.driver['experience'] ?? 'N/A'} years"),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement hire logic here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Hiring request sent to ${widget.driver['name']}'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      // Undo hire request logic
                    },
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Send Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
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
            // Contact Information
            _buildProfileSection(
              title: 'Contact Information',
              icon: Icons.contact_phone,
              children: [
                _buildProfileItem(Icons.phone, 'Phone', _getMaskedPhone()),
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
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _contactDriver,
                    icon: const Icon(Icons.phone),
                    label: const Text('Contact Driver'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _hireDriver,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Hire Driver'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}