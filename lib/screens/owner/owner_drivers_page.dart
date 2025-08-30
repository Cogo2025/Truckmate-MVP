import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../api_config.dart';
import 'unique_driver_profile.dart';
import 'owner_profile_setup.dart'; // Add this import

class OwnerDriversPage extends StatefulWidget {
  final String? initialTruckTypeFilter;
  final bool isFromDashboard;

  const OwnerDriversPage({
    super.key,
    this.initialTruckTypeFilter,
    this.isFromDashboard = false,
  });

  @override
  State createState() => _OwnerDriversPageState();
  State createState() => _OwnerDriversPageState();
}

class _OwnerDriversPageState extends State<OwnerDriversPage> {
  bool isLoading = true;
  List drivers = [];
  List drivers = [];
  String? errorMessage;
  String? selectedLocation;
  String? selectedTruckType;
  List locations = [];
  List truckTypes = [];
  bool hasInitialFilterBeenApplied = false;

  @override
  void didUpdateWidget(OwnerDriversPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFromDashboard &&
        widget.initialTruckTypeFilter != null &&
        !hasInitialFilterBeenApplied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          selectedTruckType = widget.initialTruckTypeFilter;
          hasInitialFilterBeenApplied = true;
          isLoading = true;
        });
        fetchAvailableDrivers();
      });
    } else if (!widget.isFromDashboard &&
        hasInitialFilterBeenApplied &&
        selectedTruckType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          selectedTruckType = null;
          hasInitialFilterBeenApplied = false;
          isLoading = true;
        });
        fetchAvailableDrivers();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTruckTypeFilter != null && widget.isFromDashboard) {
      selectedTruckType = widget.initialTruckTypeFilter;
      hasInitialFilterBeenApplied = true;
    }
    fetchAvailableDrivers();
  }

  // Add profile completion check method
  Future<bool> _checkProfileCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    if (token == null) return false;

    try {
      final res = await http.get(
        Uri.parse(ApiConfig.ownerProfile),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ).timeout(const Duration(seconds: 15));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['companyName'] != null && data['companyName'].toString().isNotEmpty;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Add profile completion prompt dialog
  void _showProfileCompletionDialog(String featureName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_circle, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              const Text('Complete Profile Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To access $featureName, please complete your profile setup first.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[800], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Complete your company details to unlock all features.',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Later', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OwnerProfileSetupPage()),
                );
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Complete Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearAllFilters() {
    setState(() {
      selectedLocation = null;
      selectedTruckType = null;
      hasInitialFilterBeenApplied = false;
      isLoading = true;
      drivers.sort((a, b) {
        final aTime = a['createdAt'] ?? '';
        final bTime = b['createdAt'] ?? '';
        return bTime.compareTo(aTime);
      });
    });
    fetchAvailableDrivers();
  }

  Future fetchAvailableDrivers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    final freshToken = await AuthService.getFreshAuthToken();
    if (freshToken == null) {
      setState(() {
        isLoading = false;
        errorMessage = "Authentication failed. Please log in again.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please re-login.")),
      );
      return;
    }

    try {
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
        headers: {"Authorization": "Bearer $freshToken"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          drivers = data['drivers'] ?? [];
          isLoading = false;
          locations = drivers
              .map((d) => d['location']?.toString() ?? 'Unknown')
              .toSet()
              .toList();
          locations.removeWhere((loc) => loc == 'Unknown');
          truckTypes = drivers
              .expand((d) =>
                  (d['truckTypes'] as List?)?.map((t) => t?.toString() ?? '') ?? [])
              .toSet()
              .toList();
        });
      } else if (response.body.contains('auth/id-token-expired')) {
        final retryToken = await AuthService.getFreshAuthToken();
        if (retryToken != null) {
          final retryResponse = await http.get(
            uri,
            headers: {"Authorization": "Bearer $retryToken"},
          );
          if (retryResponse.statusCode == 200) {
            final data = jsonDecode(retryResponse.body);
            setState(() {
              drivers = data['drivers'] ?? [];
              isLoading = false;
              locations = drivers
                  .map((d) => d['location']?.toString() ?? 'Unknown')
                  .toSet()
                  .toList();
              locations.removeWhere((loc) => loc == 'Unknown');
              truckTypes = drivers
                  .expand((d) =>
                      (d['truckTypes'] as List?)?.map((t) => t?.toString() ?? '') ?? [])
                  .toSet()
                  .toList();
            });
          } else {
            setState(() {
              isLoading = false;
              errorMessage = "Retry failed: ${retryResponse.reasonPhrase}";
            });
          }
        } else {
          setState(() {
            isLoading = false;
            errorMessage = "Token refresh failed during retry";
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to fetch available drivers: ${response.reasonPhrase}";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error: $e";
      });
    }
  }

  // Modified: Toggle like with profile completion check
  Future _toggleDriverLike(Map driver) async {
    // Check profile completion first
    final isProfileComplete = await _checkProfileCompletion();
    if (!isProfileComplete) {
      _showProfileCompletionDialog('driver favorites');
      return;
    }

    final freshToken = await AuthService.getFreshAuthToken();
    if (freshToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please re-login.")),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.checkDriverLike}?driverId=${driver['id']}'),
        headers: {"Authorization": "Bearer $freshToken"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['isLiked'] == true) {
          await _unlikeDriver(driver['id'].toString(), freshToken);
        } else {
          await _likeDriver(driver['id'].toString(), freshToken);
        }
      } else {
        throw Exception("Check like failed: ${response.reasonPhrase}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error toggling like: $e")),
      );
    }
  }

  Future _likeDriver(String driverId, String token) async {
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
        await fetchAvailableDrivers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to like driver: ${response.reasonPhrase}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error liking driver: $e")),
      );
    }
  }

  Future _unlikeDriver(String driverId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.unlikeDriver}$driverId'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Driver removed from favorites")),
        );
        await fetchAvailableDrivers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to unlike driver: ${response.reasonPhrase}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error unliking driver: $e")),
      );
    }
  }

  Future<bool> _checkIfDriverLiked(String driverId) async {
    final freshToken = await AuthService.getFreshAuthToken();
    if (freshToken == null) return false;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.checkDriverLike}?driverId=$driverId'),
        headers: {"Authorization": "Bearer $freshToken"},
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
    final List<String> tamilNaduDistricts = [
      "Ariyalur", "Chengalpattu", "Chennai", "Coimbatore",
      "Cuddalore", "Dharmapuri", "Dindigul", "Erode",
      "Kallakurichi", "Kancheepuram", "Karur",
      "Krishnagiri", "Madurai", "Mayiladuthurai", "Nagapattinam",
      "Namakkal", "Nilgiris", "Perambalur", "Pudukkottai",
      "Ramanathapuram", "Ranipet", "Salem", "Sivaganga",
      "Tenkasi", "Thanjavur", "Theni", "Thoothukudi",
      "Tiruchirappalli", "Tirunelveli", "Tirupathur", "Tiruppur",
      "Tiruvallur", "Tiruvannamalai", "Tiruvarur", "Vellore",
      "Viluppuram", "Virudhunagar"
    ];
    final List<String> allTruckTypes = [
      "Body Vehicle", "Trailer", "Tipper", "Gas Tanker",
      "Wind Mill", "Concrete Mixer", "Petrol Tank",
      "Container", "Bulker"
    ];

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
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'All Locations',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  ...tamilNaduDistricts.map((location) {
                    return DropdownMenuItem<String>(
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
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'All Truck Types',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  ...allTruckTypes.map((type) {
                    return DropdownMenuItem<String>(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _clearAllFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                  child: const Text('Clear All'),
                ),
                Row(
                  children: [
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

  Widget _buildDriverCard(Map driver) {
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
                          backgroundImage: driver['photoUrl'] != null && driver['photoUrl'].isNotEmpty
                          backgroundImage: driver['photoUrl'] != null && driver['photoUrl'].isNotEmpty
                              ? NetworkImage(driver['photoUrl'])
                              : null,
                          backgroundColor: Colors.grey.shade200,
                          child: (driver['photoUrl'] == null || driver['photoUrl'].isEmpty)
                          child: (driver['photoUrl'] == null || driver['photoUrl'].isEmpty)
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
              if (driver['truckTypes'] != null && driver['truckTypes'].isNotEmpty)
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: (driver['truckTypes'] as List)
                    children: (driver['truckTypes'] as List)
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

  void _viewDriverProfile(Map driver) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UniqueDriverProfile(driver: driver),
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
            if (widget.initialTruckTypeFilter != null && widget.isFromDashboard)
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
            onPressed: _clearAllFilters,
          ),
        ],
      ),
 
      body: Column(
        children: [
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
                                hasInitialFilterBeenApplied = false;
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
