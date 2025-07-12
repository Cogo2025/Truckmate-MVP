import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../api_config.dart';

class OwnerDriversPage extends StatefulWidget {
  const OwnerDriversPage({super.key});

  @override
  State<OwnerDriversPage> createState() => _OwnerDriversPageState();
}

class _OwnerDriversPageState extends State<OwnerDriversPage> {
  bool isLoading = true;
  List<dynamic> drivers = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchDrivers();
  }

  Future<void> fetchDrivers() async {
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
        Uri.parse('${ApiConfig.baseUrl}/owner/drivers'), // Update with your actual endpoint
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          drivers = data['drivers'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to fetch drivers";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error: $e";
      });
    }
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
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
          ],
        ),
        trailing: PopupMenuButton<String>(
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
      ),
    );
  }

  void _viewDriverProfile(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(driver['name'] ?? 'Driver Profile'),
        content: Column(
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

  void _contactDriver(Map<String, dynamic> driver) {
    // Implement contact functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Contacting ${driver['name']}..."),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _hireDriver(Map<String, dynamic> driver) {
    // Implement hire functionality
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Drivers"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
                errorMessage = null;
              });
              fetchDrivers();
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
                          fetchDrivers();
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : drivers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No drivers found",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Drivers who apply to your jobs will appear here",
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
                      onRefresh: fetchDrivers,
                      child: ListView.builder(
                        itemCount: drivers.length,
                        itemBuilder: (context, index) {
                          return _buildDriverCard(drivers[index]);
                        },
                      ),
                    ),
    );
  }
}