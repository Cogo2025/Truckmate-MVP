
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('authToken', token);
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  static Future<void> saveProfileStatus(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ownerProfileCompleted', completed);
  }

  static Future<bool> isProfileCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('ownerProfileCompleted') ?? false;
  }
}
