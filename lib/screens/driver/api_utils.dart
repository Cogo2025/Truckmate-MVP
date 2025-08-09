// screens/driver/api_utils.dart - Enhanced version
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:truckmate_app/api_config.dart';
import 'package:truckmate_app/services/auth_service.dart';

class ApiUtils {
  // Enhanced API call handler with verification status handling
  static Future<Map<String, dynamic>> handleApiCall(
    Future<http.Response> apiCall,
    BuildContext context, {
    String? successMessage,
    bool showError = true,
    bool checkVerification = false,
  }) async {
    try {
      final response = await apiCall;
      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (successMessage != null) {
          _showSnackBar(context, successMessage, isError: false);
        }
        return {'success': true, 'data': responseData};
      } else {
        // Handle verification-specific errors
        if (checkVerification && _isVerificationError(response.statusCode, responseData)) {
          return _handleVerificationError(context, responseData);
        }
        throw Exception(responseData['error'] ?? 'Request failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (showError) {
        _showSnackBar(context, e.toString());
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // Check if error is verification-related
  static bool _isVerificationError(int statusCode, Map<String, dynamic> responseData) {
    return statusCode == 403 && 
           responseData.containsKey('code') && 
           ['NO_PROFILE', 'INCOMPLETE_PROFILE', 'VERIFICATION_PENDING', 'VERIFICATION_REJECTED', 'NOT_VERIFIED']
           .contains(responseData['code']);
  }

  // Handle verification errors
  static Map<String, dynamic> _handleVerificationError(BuildContext context, Map<String, dynamic> responseData) {
    final code = responseData['code'];
    final message = responseData['message'];
    
    // Show appropriate dialog based on verification status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showVerificationDialog(context, code, message, responseData);
    });

    return {
      'success': false, 
      'error': message,
      'verificationError': true,
      'code': code,
      'data': responseData
    };
  }

  // Show verification status dialog
  static void _showVerificationDialog(BuildContext context, String code, String message, Map<String, dynamic> data) {
    String title = 'Verification Required';
    String content = message;
    List<Widget> actions = [];

    switch (code) {
      case 'NO_PROFILE':
      case 'INCOMPLETE_PROFILE':
        title = 'Complete Your Profile';
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/driver-profile-setup');
            },
            child: const Text('Complete Profile'),
          ),
        ];
        break;
      
      case 'VERIFICATION_PENDING':
        title = 'Verification Pending';
        content = 'Your profile is under review. You will be notified once approved.';
        actions = [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ];
        break;
      
      case 'VERIFICATION_REJECTED':
        title = 'Verification Rejected';
        content = data['rejectionReason'] ?? 'Your profile was rejected. Please update and resubmit.';
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resubmitVerification(context);
            },
            child: const Text('Resubmit'),
          ),
        ];
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: actions,
      ),
    );
  }

  // Resubmit verification
  static Future _resubmitVerification(BuildContext context) async {
  try {
    // Get fresh token using AuthService
    final token = await AuthService.getFreshAuthToken();
    if (token == null) {
      _showSnackBar(context, 'Authentication required. Please login again.');
      return;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/verification/resubmit'),
      headers: getAuthHeaders(token), // Use actual token instead of placeholder
    );

    if (response.statusCode == 201) {
      _showSnackBar(context, 'Verification resubmitted successfully!', isError: false);
    } else {
      final error = jsonDecode(response.body)['error'];
      _showSnackBar(context, error);
    }
  } catch (e) {
    _showSnackBar(context, 'Failed to resubmit verification');
  }
}
  // Get verification status
  static Future<Map<String, dynamic>> getVerificationStatus(String token, BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/verification/status'),
        headers: getAuthHeaders(token),
      );

      return await handleApiCall(
        Future.value(response),
        context,
        showError: false,
      );
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Check driver access
  static Future<bool> checkDriverAccess(String token, BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/verification/check-access'),
        headers: getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['canAccessJobs'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Existing helper methods...
  static Map<String, String> getAuthHeaders(String token) {
    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };
  }

  static void _showSnackBar(BuildContext context, String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // Other existing methods...
  static Future<Map<String, dynamic>> fetchFilterOptions(
    String url,
    String token,
    BuildContext context, {
    Map<String, dynamic> defaultOptions = const {},
  }) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: getAuthHeaders(token),
      );

      final result = await handleApiCall(
        Future.value(response),
        context,
        showError: false,
        checkVerification: true,
      );

      if (result['success']) {
        final options = result['data'] as Map<String, dynamic>;
        return {
          ...defaultOptions,
          ...options,
          'salaryRange': options['salaryRange'] ?? defaultOptions['salaryRange'],
        };
      } else {
        return defaultOptions;
      }
    } catch (e) {
      debugPrint('Error fetching filter options: $e');
      return defaultOptions;
    }
  }

  static Map<String, dynamic> buildQueryParams(Map<String, dynamic> filters) {
    final params = <String, dynamic>{};
    filters.forEach((key, value) {
      if (value != null) {
        if (value is String && value.isNotEmpty) {
          params[key] = value;
        } else if (value is num) {
          params[key] = value.toString();
        } else if (value is List) {
          params[key] = value.join(',');
        }
      }
    });
    return params;
  }

  static Map<String, dynamic> parseSalaryRange(Map<String, dynamic>? salaryRange) {
    if (salaryRange == null) {
      return {'min': 0, 'max': 100000};
    }

    return {
      'min': salaryRange['min']?.toDouble() ?? 0,
      'max': salaryRange['max']?.toDouble() ?? 100000,
    };
  }
}
