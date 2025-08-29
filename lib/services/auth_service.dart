import 'dart:convert'; // *** ADDED: Required for jsonEncode/jsonDecode ***
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Save auth token to SharedPreferences
  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('authToken', token);
  }

  // Get stored auth token
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  // Get a fresh auth token by forcing a refresh
  static Future<String?> getFreshAuthToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      
      // Force token refresh
      final idToken = await user.getIdToken(true);
      if (idToken == null || idToken.isEmpty) return null;
      
      // Save the fresh token
      await saveAuthToken(idToken);
      return idToken;
    } catch (e) {
      print("Token refresh error: $e");
      return null;
    }
  }

  // Check if user is authenticated with valid token
  static Future<bool> isAuthenticated() async {
    try {
      // First check if we have a token
      final token = await getAuthToken();
      if (token == null) return false;
      
      // Get a fresh token to ensure it's valid
      final freshToken = await getFreshAuthToken();
      return freshToken != null;
    } catch (e) {
      print("Authentication check error: $e");
      return false;
    }
  }

  // *** ENHANCED: Clear all auth data for proper logout ***
  static Future<void> clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear auth-related keys
      await prefs.remove('authToken');
      await prefs.remove('userData');
      
      // *** ADDITIONAL: Clear any other user-related data ***
      await prefs.remove('userRole');
      await prefs.remove('isLoggedIn');
      await prefs.remove('driverProfile');
      await prefs.remove('ownerProfile');
      await prefs.remove('verificationStatus');
      
      print('✅ Auth data cleared successfully');
    } catch (e) {
      print('❌ Error clearing auth data: $e');
      throw e;
    }
  }

  // *** NEW: Save user data to SharedPreferences ***
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', jsonEncode(userData)); // Now works with import
    } catch (e) {
      print("Save user data error: $e");
    }
  }

  // *** NEW: Get user data from SharedPreferences ***
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('userData');
      if (userDataString != null) {
        return jsonDecode(userDataString); // Now works with import
      }
      return null;
    } catch (e) {
      print("Get user data error: $e");
      return null;
    }
  }

  // *** NEW: Update availability status locally ***
  static Future<void> updateLocalAvailability(bool isAvailable) async {
    try {
      final userData = await getUserData();
      if (userData != null) {
        userData['isAvailable'] = isAvailable;
        await saveUserData(userData);
      }
    } catch (e) {
      print("Update local availability error: $e");
    }
  }

  // *** NEW: Get current availability status ***
  static Future<bool> getCurrentAvailability() async {
    try {
      final userData = await getUserData();
      return userData?['isAvailable'] ?? false;
    } catch (e) {
      print("Get availability error: $e");
      return false;
    }
  }

  // *** NEW: Check if user has completed profile ***
  static Future<bool> hasCompletedProfile() async {
    try {
      final userData = await getUserData();
      return userData?['profileCompleted'] ?? false;
    } catch (e) {
      print("Check profile completion error: $e");
      return false;
    }
  }

  // *** NEW: Get user role ***
  static Future<String?> getUserRole() async {
    try {
      final userData = await getUserData();
      return userData?['role'];
    } catch (e) {
      print("Get user role error: $e");
      return null;
    }
  }

  // *** NEW: Complete logout process ***
  static Future<void> performLogout() async {
    try {
      print('🚪 Starting complete logout process...');
      
      // 1. Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      print('✅ Firebase signout successful');
      
      // 2. Clear all local data
      await clearAuthData();
      print('✅ Local data cleared');
      
    } catch (e) {
      print('❌ Logout error: $e');
      throw e;
    }
  }
}
