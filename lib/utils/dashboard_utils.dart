import 'dart:convert';
import 'package:flutter/material.dart';

/// Utility functions for dashboard components

class DashboardUtils {
  /// Parse hex color from string, with fallback
  static Color parseHexColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return fallback;
    }
  }

  /// Format duration in a human-readable way
  static String formatDuration(int? minutes) {
    if (minutes == null || minutes == 0) return '';
    
    if (minutes < 60) {
      return '${minutes}min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}min';
      }
    }
  }

  /// Generate thumbnail URL for images
  static String? thumbUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) return null;
    
    // If it's a Supabase storage URL, add thumbnail transformation
    if (originalUrl.contains('supabase')) {
      final uri = Uri.parse(originalUrl);
      return '${uri.scheme}://${uri.host}${uri.path}?width=200&height=200&resize=cover';
    }
    
    return originalUrl;
  }

  /// Extract area key from activity data
  static String extractAreaKey(Map<String, dynamic>? data) {
    if (data == null) return 'unknown';
    
    final area = data['area'] as String?;
    final category = data['category'] as String?;
    
    if (area != null && category != null) {
      return '$area|$category';
    } else if (area != null) {
      return area;
    } else if (category != null) {
      return category;
    }
    
    return 'unknown';
  }

  /// Parse activity data from notes JSON
  static Map<String, dynamic>? parseActivityData(String? notes) {
    if (notes == null || notes.isEmpty) return null;
    
    try {
      final data = jsonDecode(notes);
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (e) {
      // Ignore JSON parsing errors
    }
    
    return null;
  }

  /// Get initials from a name
  static String getInitials(String name) {
    if (name.isEmpty) return '';
    
    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    } else {
      return '${words[0].substring(0, 1)}${words[1].substring(0, 1)}'.toUpperCase();
    }
  }

  /// Calculate progress percentage
  static double calculateProgress(int current, int target) {
    if (target <= 0) return 0.0;
    return (current / target).clamp(0.0, 1.0);
  }

  /// Get color intensity based on count
  static Color getIntensityColor(Color baseColor, int count, int maxCount) {
    if (maxCount <= 0 || count <= 0) {
      return baseColor.withValues(alpha: 0.1);
    }
    
    final intensity = (count / maxCount).clamp(0.0, 1.0);
    return baseColor.withValues(alpha: 0.3 + (intensity * 0.7));
  }
}