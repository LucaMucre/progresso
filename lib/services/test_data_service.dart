import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'db_service.dart' as db_service;
import '../utils/logging_service.dart';

class TestDataService {
  /// Create test data for development - Web-compatible version
  static Future<void> createTestData() async {
    if (!kDebugMode) return; // Only in debug mode
    
    try {
      if (kDebugMode) debugPrint('=== CREATING WEB TEST DATA ===');
      
      final now = DateTime.now();
      
      // Create test activities with varied dates for the last 14 days
      for (int i = 0; i < 20; i++) {
        final logDate = now.subtract(Duration(days: i % 14));
        final categories = ['fitness', 'learning', 'health', 'work', 'social'];
        final category = categories[i % categories.length];
        
        await db_service.createQuickLog(
          activityName: 'Test Activity ${i + 1}',
          category: category,
          durationMin: 15 + (i * 5),
          notes: jsonEncode({
            'title': 'Test Activity ${i + 1}',
            'category': category,
            'content': 'This is test data created for development purposes. Activity ${i + 1}.',
            'area': category,
          }),
        );
        
        if (kDebugMode && i % 5 == 0) {
          debugPrint('Created ${i + 1}/20 test activities...');
        }
      }
      
      if (kDebugMode) debugPrint('✅ Test data created successfully - 20 activities');
    } catch (e, stackTrace) {
      LoggingService.error('Failed to create test data', e, stackTrace, 'TestDataService');
      if (kDebugMode) debugPrint('❌ Failed to create test data: $e');
    }
  }
  
  /// Clear all test data
  static Future<void> clearTestData() async {
    if (!kDebugMode) return; // Only in debug mode
    
    try {
      if (kDebugMode) debugPrint('=== CLEARING TEST DATA ===');
      
      // This would need to be implemented in the local database service
      // For now, we just log that we would clear data
      if (kDebugMode) debugPrint('Test data clearing not implemented yet');
    } catch (e, stackTrace) {
      LoggingService.error('Failed to clear test data', e, stackTrace, 'TestDataService');
    }
  }
  
  /// Check if we have any local data
  static Future<bool> hasLocalData() async {
    try {
      final info = await db_service.getDatabaseInfo();
      final logCount = info['logs'] ?? 0;
      return logCount > 0;
    } catch (e) {
      return false;
    }
  }
  
  /// Get local data statistics
  static Future<Map<String, dynamic>> getLocalStats() async {
    try {
      return await db_service.getDatabaseInfo();
    } catch (e) {
      return {};
    }
  }
}