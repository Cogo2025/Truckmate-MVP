import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../api_config.dart';

class OwnerDriversPage extends StatefulWidget {
  final String? initialTruckTypeFilter;
  
  const OwnerDriversPage({
    super.key,
    this.initialTruckTypeFilter,
  });

  @override
  State<OwnerDriversPage> createState() => _OwnerDriversPageState();
}

class _OwnerDriversPageState extends State<OwnerDriversPage> {
  bool isLoading = true;
  List<dynamic> drivers = [];
  String? errorMessage;
  String? selectedLocation;
  String? selectedTruckType;
  List<String> locations = [];
  List<String> truckTypes = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialTruckTypeFilter != null) {
      selectedTruckType = widget.initialTruckTypeFilter;
    }
    fetchAvailableDrivers();
  }

  Future<void> fetchAvailableDrivers() async {
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
      // Build query parameters
      final params = <String, String>{};
      if (selectedLocation != null && selectedLocation!.isNotEmpty) {
        params['location'] = selectedLocation!;
      }
      if (selectedTruckType != null && selectedTruckType!.isNotEmpty) {
        params['truckType'] = selectedTruckType!;
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/profile/driver/available')
          .replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          drivers = data['drivers'] ?? [];
          isLoading = false;
          
          // Extract unique locations and truck types for filters
          locations = drivers
              .map<String>((d) => d['location']?.toString() ?? 'Unknown')
              .toSet()
              .toList();
          locations.removeWhere((loc) => loc == 'Unknown');
              
          truckTypes = drivers
              .expand<String>((d) => 
                  (d['truckTypes'] as List<dynamic>?)?.map((t) => t.toString()) ?? [])
              .toSet()
              .toList();
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to fetch available drivers";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error: $e";
      });
    }
  }

  Future<void> _toggleDriverLike(Map<String, dynamic> driver) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Authentication token not found")),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.checkDriverLike}?driverId=${driver['id']}'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['isLiked']) {
          await _unlikeDriver(driver['id'], token);
        } else {
          await _likeDriver(driver['id'], token);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _likeDriver(String driverId, String token) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.likeDriver),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({'driverId': driverId}),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Driver added to favorites")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to like driver")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _unlikeDriver(String driverId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.unlikeDriver}$driverId'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Driver removed from favorites")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to unlike driver")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<bool> _checkIfDriverLiked(String driverId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.checkDriverLike}?driverId=$driverId'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isLiked'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Widget _buildFilterDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Filter Drivers',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Location Filter
            Text(
              'Location',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedLocation,
                decoration: InputDecoration(
                  labelText: 'Select Location',
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  prefixIcon: Icon(Icons.location_on, color: Colors.grey.shade600),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                dropdownColor: Colors.white,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(
                      'All Locations',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  ...locations.map((location) {
                    return DropdownMenuItem(
                      value: location,
                      child: Text(
                        location,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedLocation = value;
                  });
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Truck Type Filter
            Text(
              'Truck Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedTruckType,
                decoration: InputDecoration(
                  labelText: 'Select Truck Type',
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  prefixIcon: Icon(Icons.local_shipping, color: Colors.grey.shade600),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                dropdownColor: Colors.white,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(
                      'All Truck Types',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  ...truckTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedTruckType = value;
                  });
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedLocation = null;
                      selectedTruckType = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                  child: const Text('Clear All'),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => isLoading = true);
                        fetchAvailableDrivers();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewDriverProfile(driver),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Profile Picture with status indicator
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundImage: driver['photoUrl'] != null
                              ? NetworkImage(driver['photoUrl'])
                              : null,
                          backgroundColor: Colors.grey.shade200,
                          child: driver['photoUrl'] == null
                              ? Icon(Icons.person, size: 30, color: Colors.grey.shade400)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  // Driver Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver['name'] ?? 'Unknown Driver',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              "${driver['rating'] ?? '0.0'}",
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.work, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              "${driver['experience'] ?? 'N/A'} yrs",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                driver['location'] ?? 'N/A',
                                style: TextStyle(color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Action Buttons
                  Column(
                    children: [
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<bool>(
                        future: _checkIfDriverLiked(driver['id']),
                        builder: (context, snapshot) {
                          final isLiked = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_outline,
                              color: isLiked ? Colors.red : Colors.grey.shade400,
                              size: 24,
                            ),
                            onPressed: () => _toggleDriverLike(driver),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Truck types chips
              if (driver['truckTypes'] != null && driver['truckTypes'].isNotEmpty)
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: (driver['truckTypes'] as List<dynamic>)
                        .map((type) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Chip(
                                label: Text(
                                  type.toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.primaryColor,
                                  ),
                                ),
                                backgroundColor: theme.primaryColor.withOpacity(0.1),
                                shape: StadiumBorder(
                                  side: BorderSide(
                                    color: theme.primaryColor.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewDriverProfile(Map<String, dynamic> driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Header
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: driver['photoUrl'] != null
                                    ? NetworkImage(driver['photoUrl'])
                                    : null,
                                backgroundColor: Colors.grey.shade200,
                                child: driver['photoUrl'] == null
                                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                driver['name'] ?? 'Unknown Driver',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Available',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                            _buildProfileItem(Icons.phone, 'Phone', driver['phone'] ?? 'N/A'),
                            _buildProfileItem(Icons.email, 'Email', driver['email'] ?? 'N/A'),
                            _buildProfileItem(Icons.location_on, 'Location', driver['location'] ?? 'N/A'),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Experience & Skills
                        _buildProfileSection(
                          title: 'Experience & Skills',
                          icon: Icons.work,
                          children: [
                            _buildProfileItem(Icons.timer, 'Experience', driver['experience'] ?? 'N/A'),
                            _buildProfileItem(Icons.star, 'Rating', '${driver['rating'] ?? 'N/A'}'),
                            _buildProfileItem(Icons.local_shipping, 'Truck Types', 
                                driver['truckTypes']?.join(', ') ?? 'N/A'),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Additional Info
                        if (driver['bio'] != null || driver['specializations'] != null)
                          _buildProfileSection(
                            title: 'Additional Information',
                            icon: Icons.info,
                            children: [
                              if (driver['bio'] != null)
                                _buildProfileItem(Icons.person, 'Bio', driver['bio']),
                              if (driver['specializations'] != null)
                                _buildProfileItem(Icons.build, 'Specializations', 
                                    driver['specializations']?.join(', ') ?? 'N/A'),
                            ],
                          ),
                        
                        const SizedBox(height: 32),
                        
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _contactDriver(driver),
                                icon: const Icon(Icons.phone),
                                label: const Text('Contact'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5722),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _hireDriver(driver),
                                icon: const Icon(Icons.person_add),
                                label: const Text('Hire'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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

  void _contactDriver(Map<String, dynamic> driver) {
    // Implement contact functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Driver'),
        content: Text('Contact ${driver['name']} at ${driver['phone']}'),
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
    // Implement hire functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hire Driver'),
        content: Text('Send hiring request to ${driver['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement hire logic here
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Available Drivers",
              style: TextStyle(fontSize: 20),
            ),
            if (widget.initialTruckTypeFilter != null)
              Text(
                "Filtered by: ${widget.initialTruckTypeFilter}",
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        automaticallyImplyLeading: false,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            tooltip: 'Filters',
            onPressed: () => showDialog(
              context: context,
              builder: (context) => _buildFilterDialog(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                selectedLocation = null;
                selectedTruckType = widget.initialTruckTypeFilter;
                isLoading = true;
              });
              fetchAvailableDrivers();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Filters Display
          if (selectedLocation != null || selectedTruckType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 16, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (selectedLocation != null)
                          InputChip(
                            label: Text(selectedLocation!),
                            labelStyle: TextStyle(color: theme.primaryColor),
                            deleteIcon: Icon(Icons.close, size: 16, color: theme.primaryColor),
                            onDeleted: () {
                              setState(() {
                                selectedLocation = null;
                                isLoading = true;
                              });
                              fetchAvailableDrivers();
                            },
                            backgroundColor: theme.primaryColor.withOpacity(0.1),
                            shape: StadiumBorder(
                              side: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
                            ),
                          ),
                        if (selectedTruckType != null)
                          InputChip(
                            label: Text(selectedTruckType!),
                            labelStyle: TextStyle(color: theme.primaryColor),
                            deleteIcon: Icon(Icons.close, size: 16, color: theme.primaryColor),
                            onDeleted: () {
                              setState(() {
                                selectedTruckType = null;
                                isLoading = true;
                              });
                              fetchAvailableDrivers();
                            },
                            backgroundColor: theme.primaryColor.withOpacity(0.1),
                            shape: StadiumBorder(
                              side: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Main Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Finding available drivers...",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red.shade400,
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
                                fetchAvailableDrivers();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text("Try Again"),
                            ),
                          ],
                        ),
                      )
                    : drivers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "No available drivers found",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                  child: Text(
                                    selectedLocation != null || selectedTruckType != null
                                        ? "Try adjusting your filters or check back later"
                                        : "Drivers who are currently available will appear here",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (selectedTruckType != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          selectedTruckType = null;
                                          isLoading = true;
                                        });
                                        fetchAvailableDrivers();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text("Clear Truck Type Filter"),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: fetchAvailableDrivers,
                            color: theme.primaryColor,
                            child: ListView.separated(
                              itemCount: drivers.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                return _buildDriverCard(drivers[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}