  import 'package:flutter/material.dart';
  import 'package:carousel_slider/carousel_slider.dart';
  import 'package:flutter/services.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'dart:convert';
  import 'package:http/http.dart' as http;
  import 'package:truckmate_app/api_config.dart';
  import 'package:truckmate_app/screens/driver/driver_main_navigation.dart';

  class DriverDashboard extends StatefulWidget {
    const DriverDashboard({super.key});

    @override
    State createState() => _DriverDashboardState();
  }

  class _DriverDashboardState extends State<DriverDashboard> with SingleTickerProviderStateMixin {
    final List<String> carouselImages = [
      'assets/images/banner1.jpg',
      'assets/images/banner2.jpg',
      'assets/images/banner3.jpg',
      'assets/images/banner4.jpg',
      'assets/images/banner5.jpg',
    ];

    final List<Map<String, String>> vehicleTypes = [
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

    late AnimationController _animationController;
    late Animation<double> _fadeAnimation;

    @override
    void initState() {
      super.initState();
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
      _fadeAnimation = CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      );
      _animationController.forward();
    }

    @override
    void dispose() {
      _animationController.dispose();
      super.dispose();
    }

    void _onVehicleTypeSelected(String vehicleType) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              DriverMainNavigation(
                initialTabIndex: 2,
                filterByVehicle: vehicleType,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      return Theme(
        data: ThemeData.light().copyWith(
          primaryColor: Colors.blueAccent,
          scaffoldBackgroundColor: const Color.fromARGB(255, 244, 243, 255),
          textTheme: TextTheme(
            headlineLarge: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            bodyLarge: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            bodyMedium: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 4,
              textStyle: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        child: WillPopScope(
          onWillPop: () async {
            final shouldExit = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Are you quitting?'),
                content: const Text('Do you want to exit the app?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
            );
            if (shouldExit == true) {
              SystemNavigator.pop();
              return true;
            }
            return false;
          },
          child: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Text(
                              "Welcome 👋",
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.notifications_none_rounded, size: 28),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 180,
                          autoPlay: true,
                          enlargeCenterPage: true,
                          viewportFraction: 0.85,
                        ),
                        items: carouselImages.map((image) {
                          return Builder(
                            builder: (BuildContext context) {
                              return ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: _animationController,
                                  curve: Curves.easeOut,
                                ),
                                child: Container(
                                  width: MediaQuery.of(context).size.width * 0.85,
                                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: AssetImage(image),
                                      fit: BoxFit.cover,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        "Choose Vehicle Type",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      AnimationLimiter(
                        child: GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 8),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          children: vehicleTypes.asMap().entries.map((entry) {
                            int index = entry.key;
                            var vehicle = entry.value;
                            return AnimationConfiguration.staggeredGrid(
                              position: index,
                              duration: const Duration(milliseconds: 600),
                              columnCount: 3,
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: ScaleAnimation(
                                  child: GestureDetector(
                                    onTap: () {
                                      print("🚚 Selected: ${vehicle["label"]}");
                                      _onVehicleTypeSelected(vehicle["label"]!);
                                    },
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          child: Center(
                                            child: Image.asset(
                                              vehicle["image"]!,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          vehicle["label"]!,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
