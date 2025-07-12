import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/screens/driver/driver_jobs_page.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final List<String> carouselImages = [
    'assets/images/truck1.jpg',
    'assets/images/truck2.jpg',
    'assets/images/truck3.jpg',
    'assets/images/truck4.jpg',
    'assets/images/truck5.jpg',
  ];

  final List<Map<String, dynamic>> vehicleTypes = [
    {"image": "assets/images/body_vehicle.png", "label": "Body Vehicle"},
    {"image": "assets/images/trailer.png", "label": "Trailer"},
    {"image": "assets/images/tipper.png", "label": "Tipper"},
    {"image": "assets/images/gas_tanker.png", "label": "Gas Tanker"},
    {"image": "assets/images/wind_mill_trailer.png", "label": "Wind Mill"},
    {"image": "assets/images/concrete_mixer.png", "label": "Concrete Mixer"},
    {"image": "assets/images/petrol_tank.png", "label": "Petrol Tank"},
    {"image": "assets/images/container.png", "label": "Container"},
    {"image": "assets/images/bulker.png", "label": "Bulker"},
  ];

  String? selectedVehicleType;
  int notificationCount = 0;
  bool isLoadingProfile = true;
  Map<String, dynamic> driverProfile = {};

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
    _checkNotifications();
  }

  Future<void> _loadDriverProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.driverProfile),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          driverProfile = jsonDecode(response.body);
          selectedVehicleType = driverProfile['knownTruckTypes']?.isNotEmpty ?? false 
              ? driverProfile['knownTruckTypes'][0] 
              : null;
          isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() => isLoadingProfile = false);
    }
  }

  Future<void> _checkNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.driverNotifications),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final notifications = jsonDecode(response.body);
        setState(() {
          notificationCount = notifications.length;
        });
      }
    } catch (e) {
      // Silently fail for notifications
    }
  }

  Future<void> _updateVehiclePreference(String vehicleType) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    
    if (token == null) return;

    setState(() => selectedVehicleType = vehicleType);

    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.driverProfile),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "knownTruckTypes": [vehicleType],
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Preferred vehicle set to $vehicleType")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update vehicle preference")),
      );
    }
  }

  void _navigateToJobs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverJobsPage(
          filterByVehicle: selectedVehicleType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Welcome Driver 👋",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none),
                          onPressed: () {
                            // Navigate to notifications page
                          },
                        ),
                        if (notificationCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$notificationCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              CarouselSlider(
                options: CarouselOptions(
                  height: 180,
                  autoPlay: true,
                  enlargeCenterPage: true,
                ),
                items: carouselImages.map((image) {
                  return Builder(
                    builder: (BuildContext context) {
                      return Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        margin: const EdgeInsets.symmetric(horizontal: 5.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: AssetImage(image),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Choose Vehicle Type",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (selectedVehicleType != null)
                      ElevatedButton(
                        onPressed: _navigateToJobs,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text("View Jobs"),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: vehicleTypes.map((vehicle) {
                    final isSelected = selectedVehicleType == vehicle["label"];
                    return GestureDetector(
                      onTap: () => _updateVehiclePreference(vehicle["label"]),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected 
                                  ? Colors.orange.withOpacity(0.3)
                                  : Colors.orange.shade50,
                              border: isSelected
                                  ? Border.all(color: Colors.orange, width: 2)
                                  : null,
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              vehicle["image"],
                              fit: BoxFit.contain,
                              color: isSelected ? Colors.orange : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            vehicle["label"],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.orange : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              if (isLoadingProfile)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              
              if (!isLoadingProfile && selectedVehicleType != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your Preferences",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Preferred Vehicle: $selectedVehicleType",
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              if (driverProfile['experience'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "Experience: ${driverProfile['experience']}",
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}