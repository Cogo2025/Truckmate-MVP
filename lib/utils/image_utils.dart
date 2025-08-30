// lib/utils/image_utils.dart
import 'dart:convert';
import 'dart:typed_data';

class ImageUtils {
  static Uint8List? decodeBase64Image(String? data) {
    if (data == null || data.isEmpty) return null;
    
    try {
      // Handle data URLs like data:image/jpeg;base64,xxxxx
      final parts = data.split(',');
      final base64String = parts.length > 1 ? parts.last : data;
      return base64Decode(base64String);
    } catch (e) {
      print('Error decoding Base64 image: $e');
      return null;
    }
  }
  
  static String encodeImageToBase64(Uint8List imageBytes) {
    return base64Encode(imageBytes);
  }
}
