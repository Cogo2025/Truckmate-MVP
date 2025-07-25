class ApiConfig {
  // Base URL configuration
  static const String baseUrl = 'http://192.168.29.138:5000'; // Your backend IP
  
  // Health check endpoint
  static const String healthCheck = '$baseUrl/health';
  
  // Auth endpoints
  static const String authMe = '$baseUrl/api/auth/me';
  static const String googleLogin = '$baseUrl/api/auth/google-login';
  
  // Profile endpoints
  static const String ownerProfile = '$baseUrl/api/profile/owner';
  static const String driverProfile = '$baseUrl/api/profile/driver';
  static const String updateUser = '$baseUrl/api/profile/user';
  
  // Profile endpoints for specific owner
  static String getOwnerProfileById(String ownerId) => '$ownerProfile/$ownerId';
  static String getOwnerJobs(String ownerId) => '$ownerProfile/$ownerId/jobs';
  
  // Job endpoints
  static const String jobs = '$baseUrl/api/jobs';
  static String getJobDetails(String jobId) => '$jobs/$jobId';
  static const String ownerJobs = '$baseUrl/api/jobs/owner';
  static const String driverJobs = '$baseUrl/api/jobs/driver';
  static const String jobFilterOptions = '$driverJobs/filter-options';
  static const String updateAvailability = '$baseUrl/api/profile/availability';

  // UPDATED: Like endpoints to match backend routes
  static const String likes = '$baseUrl/api/likes/job';  // Changed from just /likes
  static String getLikesForItem(String itemId) => '$likes?likedItemId=$itemId';
  static String deleteLike(String likeId) => '$likes/$likeId';
  static const String checkLike = '$baseUrl/api/likes/job/check';  // Updated path
  static const String userLikes = '$baseUrl/api/likes/job/user';   // Updated path
  
  // Driver like endpoints
  static const String likeDriver = '$baseUrl/api/likes/driver';
  static const String unlikeDriver = '$baseUrl/api/likes/driver/';
  static const String ownerLikedDrivers = '$baseUrl/api/likes/driver/user';
  static const String checkDriverLike = '$baseUrl/api/likes/driver/check';
  
  // Notification endpoints
  static const String notifications = '$baseUrl/api/notifications';
  static const String driverNotifications = '$baseUrl/api/notifications/driver';
  
  // Upload endpoints
  static const String uploads = '$baseUrl/api/uploads';
  
  // Utility methods for building query parameters
  static Uri buildUriWithQuery(String baseUrl, Map<String, dynamic> params) {
    final uri = Uri.parse(baseUrl);
    final queryParams = <String, String>{};
    
    params.forEach((key, value) {
      if (value != null) {
        queryParams[key] = value.toString();
      }
    });
    
    return uri.replace(queryParameters: queryParams);
  }
  
  // Helper method for PATCH requests
  static Map<String, String> patchHeaders(String token) {
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }
  
  // Standard headers for authenticated requests
  static Map<String, String> authHeaders(String token) {
    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };
  }
  
  // Headers for file uploads
  static Map<String, String> uploadHeaders(String token) {
    return {
      "Authorization": "Bearer $token",
      // Content-Type will be set automatically for multipart requests
    };
  }
}