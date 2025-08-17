import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Centralized XP calculation utility to avoid code duplication
class XpCalculator {
  /// Calculate XP based on activity parameters using the fallback algorithm
  static int calculateFallback({
    int? durationMin, 
    String? notes, 
    String? imageUrl
  }) {
    final int timeMinutes = durationMin ?? 0;
    
    // Base XP from time: 1 XP per 5 minutes
    int xp = timeMinutes ~/ 5;
    
    // Bonus XP from notes length
    final int textLen = _estimatePlainTextLength(notes);
    xp += textLen ~/ 100; // 1 XP per 100 characters
    
    // Bonus XP for image attachment
    final bool hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    if (hasImage) xp += 2;
    
    // Ensure minimum XP if any activity was recorded
    if (xp <= 0 && (timeMinutes > 0 || textLen > 0 || hasImage)) {
      xp = 1;
    }
    
    return xp;
  }
  
  /// Estimate plain text length from notes, handling Quill Delta format
  static int _estimatePlainTextLength(String? notes) {
    if (notes == null || notes.isEmpty) return 0;
    
    // Try to parse as Quill Delta JSON first
    try {
      final obj = jsonDecode(notes);
      if (obj is Map<String, dynamic> && obj['delta'] != null) {
        final delta = obj['delta'];
        if (delta is Map<String, dynamic> && delta['ops'] is List) {
          int len = 0;
          for (final op in delta['ops']) {
            if (op is Map<String, dynamic> && op['insert'] is String) {
              len += (op['insert'] as String).length;
            }
          }
          if (len > 0) return len;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[XpCalculator] Failed to parse Quill Delta: $e');
      }
    }
    
    // Fallback: treat as plain text, normalize whitespace
    return notes.replaceAll(RegExp(r"\s+"), ' ').trim().length;
  }
}