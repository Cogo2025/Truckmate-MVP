import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
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
                      "Welcome 👋",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () {},
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Choose Vehicle Type",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                    return GestureDetector(
                      onTap: () {
                        // TODO: Implement filtering
                        print("🚚 Selected: ${vehicle["label"]}");
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.shade50,
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              vehicle["image"],
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            vehicle["label"],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}