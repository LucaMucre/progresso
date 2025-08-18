import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'db_service.dart' as db_service;
import 'data_export_service.dart';
import '../models/action_models.dart';
import '../utils/logging_service.dart';

class MigrationService {
  static final _db = Supabase.instance.client;
  
  /// Check if user has data in Supabase and offer migration
  static Future<bool> hasSupabaseData() async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) return false;
      
      final logsResult = await _db
          .from('action_logs')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);
      
      return (logsResult as List).isNotEmpty;
    } catch (e) {
      LoggingService.error('Failed to check Supabase data', e, StackTrace.current, 'MigrationService');
      return false;
    }
  }
  
  /// Migrate all data from Supabase to local storage
  static Future<MigrationResult> migrateAllFromSupabase() async {
    try {
      if (kDebugMode) debugPrint('=== MIGRATING ALL DATA FROM SUPABASE ===');
      
      final user = _db.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }
      
      // Fetch templates
      final templatesResult = await _db
          .from('action_templates')
          .select('*')
          .eq('user_id', user.id);
      
      final templates = (templatesResult as List)
          .map((e) => ActionTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
      
      // Fetch logs
      final logsResult = await _db
          .from('action_logs')
          .select('*')
          .eq('user_id', user.id)
          .order('occurred_at', ascending: false);
      
      final logs = (logsResult as List)
          .map((e) => ActionLog.fromJson(e as Map<String, dynamic>))
          .toList();
      
      // Fetch achievements
      final achievementsResult = await _db
          .from('user_achievements')
          .select('*')
          .eq('user_id', user.id);
      
      final achievements = (achievementsResult as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      
      if (kDebugMode) {
        debugPrint('Found ${templates.length} templates, ${logs.length} logs, ${achievements.length} achievements');
      }
      
      // Migrate using DataExportService
      final result = await DataExportService.migrateFromSupabase(
        templates: templates,
        logs: logs,
        achievements: achievements,
      );
      
      if (result.success) {
        if (kDebugMode) debugPrint('Migration completed successfully');
      }
      
      return result;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to migrate from Supabase', e, stackTrace, 'MigrationService');
      return MigrationResult()
        ..success = false
        ..errors.add('Migration failed: $e');
    }
  }
  
  /// Get migration statistics
  static Future<Map<String, dynamic>> getMigrationStats() async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) return {};
      
      // Check Supabase data
      final supabaseStats = await Future.wait([
        _db.from('action_templates').select('id').eq('user_id', user.id),
        _db.from('action_logs').select('id').eq('user_id', user.id),
        _db.from('user_achievements').select('id').eq('user_id', user.id),
      ]);
      
      // Check local data
      final localStats = await db_service.getDatabaseInfo();
      
      return {
        'supabase': {
          'templates': (supabaseStats[0] as List).length,
          'logs': (supabaseStats[1] as List).length,
          'achievements': (supabaseStats[2] as List).length,
        },
        'local': localStats,
        'has_supabase_data': (supabaseStats[1] as List).isNotEmpty,
        'has_local_data': (localStats['logs'] ?? 0) > 0,
      };
    } catch (e) {
      LoggingService.error('Failed to get migration stats', e, StackTrace.current, 'MigrationService');
      return {};
    }
  }
  
  /// Auto-migrate if needed
  static Future<bool> autoMigrateIfNeeded() async {
    try {
      if (!db_service.isUsingLocalStorage) return false; // Not using local storage
      
      final stats = await getMigrationStats();
      final hasSupabaseData = stats['has_supabase_data'] ?? false;
      final hasLocalData = stats['has_local_data'] ?? false;
      
      if (hasSupabaseData && !hasLocalData) {
        if (kDebugMode) debugPrint('Auto-migrating data from Supabase to local storage');
        
        final result = await migrateAllFromSupabase();
        if (result.success) {
          if (kDebugMode) debugPrint('Auto-migration successful');
          return true;
        } else {
          if (kDebugMode) debugPrint('Auto-migration failed: ${result.errors}');
        }
      }
      
      return false;
    } catch (e) {
      LoggingService.error('Auto-migration failed', e, StackTrace.current, 'MigrationService');
      return false;
    }
  }
  
  /// Create test data for development
  static Future<void> createTestData() async {
    if (!kDebugMode) return; // Only in debug mode
    
    try {
      if (kDebugMode) debugPrint('=== CREATING TEST DATA ===');
      
      // Create some test logs
      final now = DateTime.now();
      for (int i = 0; i < 10; i++) {
        final logDate = now.subtract(Duration(days: i));
        
        await db_service.createQuickLog(
          activityName: 'Test Activity $i',
          category: i % 2 == 0 ? 'fitness' : 'learning',
          durationMin: 30 + (i * 5),
          notes: jsonEncode({
            'title': 'Test Activity $i',
            'category': i % 2 == 0 ? 'fitness' : 'learning',
            'content': 'This is test data created for development',
          }),
        );
        
        // Manually update the occurred_at time for testing
        // Note: This is a simplified approach for testing
      }
      
      if (kDebugMode) debugPrint('Test data created successfully');
    } catch (e, stackTrace) {
      LoggingService.error('Failed to create test data', e, stackTrace, 'MigrationService');
    }
  }
}