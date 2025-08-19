import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Security utilities for input validation and data sanitization
class SecurityUtils {
  // Maximum file sizes (in bytes)
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxTextLength = 10000; // 10k characters
  
  // Allowed file extensions and MIME types for images
  static const Set<String> allowedImageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'
  };
  
  static const Set<String> allowedImageMimeTypes = {
    'image/jpeg', 'image/png', 'image/gif', 'image/webp', 
    'image/heic', 'image/heif'
  };

  /// Validates if the image file is safe to process
  static bool isValidImageFile(String filename, Uint8List? bytes) {
    // Check file extension
    final extension = _getFileExtension(filename);
    if (!allowedImageExtensions.contains(extension)) {
      if (kDebugMode) debugPrint('Security: Invalid file extension: $extension');
      return false;
    }
    
    // Check file size
    if (bytes != null && bytes.length > maxImageSize) {
      if (kDebugMode) debugPrint('Security: File too large: ${bytes.length} bytes');
      return false;
    }
    
    // Check for potential image bomb by inspecting file header
    if (bytes != null && bytes.length > 0) {
      if (!_hasValidImageHeader(bytes, extension)) {
        if (kDebugMode) debugPrint('Security: Invalid image header');
        return false;
      }
    }
    
    return true;
  }
  
  /// Validates and sanitizes text input
  static String sanitizeText(String input) {
    // Remove potentially harmful characters and limit length
    String sanitized = input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '') // Remove JS
        .replaceAll(RegExp(r'data:', caseSensitive: false), '') // Remove data URIs
        .trim();
    
    // Limit text length
    if (sanitized.length > maxTextLength) {
      sanitized = sanitized.substring(0, maxTextLength);
    }
    
    return sanitized;
  }
  
  /// Validates email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    );
    return emailRegex.hasMatch(email) && email.length <= 254;
  }
  
  /// Validates if URL is safe for external access
  static bool isSafeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Only allow HTTPS and HTTP schemes
      if (uri.scheme != 'https' && uri.scheme != 'http') {
        return false;
      }
      
      // Block localhost and private IP ranges in production
      if (kReleaseMode) {
        final host = uri.host.toLowerCase();
        if (host == 'localhost' || 
            host.startsWith('127.') ||
            host.startsWith('192.168.') ||
            host.startsWith('10.') ||
            host.contains('0.0.0.0')) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Rate limiting check for API calls (simple in-memory implementation)
  static final Map<String, List<DateTime>> _rateLimitCache = {};
  
  static bool isRateLimited(String identifier, {int maxRequests = 100, Duration window = const Duration(minutes: 15)}) {
    final now = DateTime.now();
    final windowStart = now.subtract(window);
    
    // Clean old entries
    _rateLimitCache[identifier] = _rateLimitCache[identifier]
        ?.where((time) => time.isAfter(windowStart))
        .toList() ?? [];
    
    final requestCount = _rateLimitCache[identifier]!.length;
    
    if (requestCount >= maxRequests) {
      if (kDebugMode) debugPrint('Security: Rate limit exceeded for $identifier');
      return true;
    }
    
    _rateLimitCache[identifier]!.add(now);
    return false;
  }
  
  // Private helper methods
  static String _getFileExtension(String filename) {
    final parts = filename.toLowerCase().split('.');
    return parts.length > 1 ? parts.last : '';
  }
  
  static bool _hasValidImageHeader(Uint8List bytes, String extension) {
    if (bytes.length < 4) return false;
    
    // Check common image file signatures
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return bytes[0] == 0xFF && bytes[1] == 0xD8;
      case 'png':
        return bytes[0] == 0x89 && bytes[1] == 0x50 && 
               bytes[2] == 0x4E && bytes[3] == 0x47;
      case 'gif':
        return bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;
      case 'webp':
        return bytes.length >= 12 &&
               bytes[0] == 0x52 && bytes[1] == 0x49 && 
               bytes[2] == 0x46 && bytes[3] == 0x46 &&
               bytes[8] == 0x57 && bytes[9] == 0x45 && 
               bytes[10] == 0x42 && bytes[11] == 0x50;
      default:
        // For other formats, just check that it's not obviously corrupted
        return true;
    }
  }
}