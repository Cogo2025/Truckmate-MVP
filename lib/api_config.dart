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
  
  // Profile endpoints for specific owner
  static String getOwnerProfileById(String ownerId) => '$ownerProfile/$ownerId';
  static String getOwnerJobs(String ownerId) => '$ownerProfile/$ownerId/jobs';
  
  // Job endpoints
  static const String jobs = '$baseUrl/api/jobs';
  static String getJobDetails(String jobId) => '$jobs/$jobId';
  static const String ownerJobs = '$baseUrl/api/jobs/owner';
  static const String driverJobs = '$baseUrl/api/jobs/driver';
  static const String jobFilterOptions = '$driverJobs/filter-options';
  
  // Like endpoints
  static const String likes = '$baseUrl/api/likes';
  static String getLikesForItem(String itemId) => '$likes?likedItemId=$itemId';
  static String deleteLike(String likeId) => '$likes/$likeId';
  static const String checkLike = '$likes/check';
  static const String userLikes = '$likes/user'; // Add this line
  
  // Notification endpoints
  static const String notifications = '$baseUrl/api/notifications';
  static const String driverNotifications = '$baseUrl/api/notifications/driver';
  
  // Upload endpoints
  static const String uploads = '$baseUrl/api/uploads';
  
  // Utility methods for building query parameters
  static Uri buildUriWithQuery(String baseUrl, Map<String, dynamic> params) {
    final uri = Uri.parse(baseUrl);
    return uri.replace(queryParameters: params);
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