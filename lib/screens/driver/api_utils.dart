import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiUtils {
  // General API call handler
  static Future<Map<String, dynamic>> handleApiCall(
    Future<http.Response> apiCall,
    BuildContext context, {
    String? successMessage,
    bool showError = true,
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
        throw Exception(responseData['error'] ?? 'Request failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (showError) {
        _showSnackBar(context, e.toString());
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // Specific handler for filter options
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
      );

      if (result['success']) {
        // Merge with default options if some fields are missing
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

  // Auth headers
  static Map<String, String> getAuthHeaders(String token) {
    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };
  }

  // Helper method to show snackbar
  static void _showSnackBar(BuildContext context, String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // Helper to build query parameters from filters
  static Map<String, String> buildQueryParams(Map<String, dynamic> filters) {
    final params = <String, String>{};
    
    // Add non-null filters to params
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

  // Helper to parse salary range
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