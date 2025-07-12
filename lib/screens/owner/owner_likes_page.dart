import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../api_config.dart';

class OwnerLikesPage extends StatefulWidget {
  const OwnerLikesPage({super.key});

  @override
  State<OwnerLikesPage> createState() => _OwnerLikesPageState();
}

class _OwnerLikesPageState extends State<OwnerLikesPage> {
  bool isLoading = true;
  List<dynamic> likedDrivers = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchLikedDrivers();
  }

  Future<void> fetchLikedDrivers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) {
      setState(() {
        isLoading = false;
        errorMessage = "Authentication token not found";
      });
      return;
    }

    try {
      // This endpoint might need to be created in your backend
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/owner/liked-drivers'), // Update with your actual endpoint
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          likedDrivers = data['likedDrivers'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to fetch liked drivers";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error: $e";
      });
    }
  }

  Future<void> _removeLike(String driverId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/owner/like/$driverId'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          likedDrivers.removeWhere((driver) => driver['id'] == driverId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Removed from liked drivers")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to remove like")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Widget _buildLikedDriverCard(Map<String, dynamic> driver) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: driver['photoUrl'] != null
              ? NetworkImage(driver['photoUrl'])
              : null,
          child: driver['photoUrl'] == null
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(driver['name'] ?? 'Unknown Driver'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Phone: ${driver['phone'] ?? 'N/A'}"),
            Text("Experience: ${driver['experience'] ?? 'N/A'}"),
            Text("Location: ${driver['location'] ?? 'N/A'}"),
            if (driver['likedDate'] != null)
              Text(
                "Liked on: ${_formatDate(driver['likedDate'])}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () => _showRemoveLikeDialog(driver),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _viewDriverProfile(driver);
                    break;
                  case 'contact':
                    _contactDriver(driver);
                    break;
                  case 'hire':
                    _hireDriver(driver);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility),
                      SizedBox(width: 8),
                      Text('View Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'contact',
                  child: Row(
                    children: [
                      Icon(Icons.phone),
                      SizedBox(width: 8),
                      Text('Contact'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'hire',
                  child: Row(
                    children: [
                      Icon(Icons.work),
                      SizedBox(width: 8),
                      Text('Hire'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveLikeDialog(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Like'),
        content: Text("Remove ${driver['name']} from your liked drivers?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeLike(driver['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _viewDriverProfile(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(driver['name'] ?? 'Driver Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Name: ${driver['name'] ?? 'N/A'}"),
              Text("Phone: ${driver['phone'] ?? 'N/A'}"),
              Text("Email: ${driver['email'] ?? 'N/A'}"),
              Text("Experience: ${driver['experience'] ?? 'N/A'}"),
              Text("Location: ${driver['location'] ?? 'N/A'}"),
              Text("License: ${driver['licenseNumber'] ?? 'N/A'}"),
              Text("Truck Types: ${driver['truckTypes']?.join(', ') ?? 'N/A'}"),
              if (driver['rating'] != null)
                Text("Rating: ${driver['rating']} ⭐"),
              if (driver['bio'] != null)
                Text("Bio: ${driver['bio']}"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _contactDriver(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Contact ${driver['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(driver['phone'] ?? 'N/A'),
              onTap: () {
                // Implement phone call functionality
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Calling ${driver['phone']}...")),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: Text(driver['email'] ?? 'N/A'),
              onTap: () {
                // Implement email functionality
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Emailing ${driver['email']}...")),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text("Send Message"),
              onTap: () {
                // Implement messaging functionality
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Messaging ${driver['name']}...")),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _hireDriver(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hire Driver'),
        content: Text("Do you want to hire ${driver['name']}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Hiring request sent to ${driver['name']}"),
                ),
              );
            },
            child: const Text('Hire'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Liked Drivers"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
                errorMessage = null;
              });
              fetchLikedDrivers();
            },
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
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });
                          fetchLikedDrivers();
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : likedDrivers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No liked drivers yet",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Drivers you like will appear here",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchLikedDrivers,
                      child: ListView.builder(
                        itemCount: likedDrivers.length,
                        itemBuilder: (context, index) {
                          return _buildLikedDriverCard(likedDrivers[index]);
                        },
                      ),
                    ),
    );
  }
}