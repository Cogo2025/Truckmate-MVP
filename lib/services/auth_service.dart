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
      if (idToken!.isEmpty) return null;
      
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

  // Clear all auth data
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('userData');
  }
}