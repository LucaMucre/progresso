import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'local_database.dart';
import '../models/action_models.dart';
import '../utils/logging_service.dart';
import '../utils/production_logger.dart';

class DataExportService {
  static final LocalDatabase _db = LocalDatabase();

  /// Export all user data to JSON format
  static Future<Map<String, dynamic>> exportAllData() async {
    try {
      ProductionLogger.data('Starting full data export');

      final templates = await _db.getTemplates();
      final logs = await _db.getLogs();
      final achievements = await _db.getAchievements();
      final dbInfo = await _db.getDatabaseInfo();

      final exportData = {
        'export_info': {
          'version': '1.0',
          'exported_at': DateTime.now().toIso8601String(),
          'app_name': 'progresso',
          'total_templates': templates.length,
          'total_logs': logs.length,
          'total_achievements': achievements.length,
        },
        'templates': templates.map((t) => {
          'id': t.id,
          'name': t.name,
          'category': t.category,
          'base_xp': t.baseXp,
          'attr_strength': t.attrStrength,
          'attr_endurance': t.attrEndurance,
          'attr_knowledge': t.attrKnowledge,
        }).toList(),
        'logs': logs.map((l) => {
          'id': l.id,
          'template_id': l.templateId,
          'occurred_at': l.occurredAt.toIso8601String(),
          'duration_min': l.durationMin,
          'notes': l.notes,
          'image_url': l.imageUrl,
          'earned_xp': l.earnedXp,
        }).toList(),
        'achievements': achievements,
        'database_info': dbInfo,
      };

      ProductionLogger.data('Export completed', recordCount: templates.length + logs.length + achievements.length);

      return exportData;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to export data', e, stackTrace, 'DataExportService');
      rethrow;
    }
  }

  /// Export data to JSON string
  static Future<String> exportToJsonString() async {
    final data = await exportAllData();
    return jsonEncode(data);
  }

  /// Import data from JSON format
  static Future<ImportResult> importFromJson(Map<String, dynamic> importData) async {
    try {
      ProductionLogger.data('Starting data import');

      final result = ImportResult();

      // Validate import format
      if (!importData.containsKey('export_info')) {
        throw Exception('Invalid import format: missing export_info');
      }

      final exportInfo = importData['export_info'] as Map<String, dynamic>?;
      if (exportInfo?['app_name'] != 'progresso') {
        throw Exception('Invalid import format: not a progresso export');
      }

      // Import templates
      if (importData.containsKey('templates')) {
        final templatesData = importData['templates'] as List<dynamic>;
        for (final templateData in templatesData) {
          try {
            final template = ActionTemplate(
              id: templateData['id'],
              name: templateData['name'],
              category: templateData['category'],
              baseXp: templateData['base_xp'],
              attrStrength: templateData['attr_strength'],
              attrEndurance: templateData['attr_endurance'],
              attrKnowledge: templateData['attr_knowledge'],
            );
            await _db.insertTemplate(template);
            result.templatesImported++;
          } catch (e) {
            result.errors.add('Failed to import template ${templateData['id']}: $e');
          }
        }
      }

      // Import logs
      if (importData.containsKey('logs')) {
        final logsData = importData['logs'] as List<dynamic>;
        for (final logData in logsData) {
          try {
            final log = ActionLog(
              id: logData['id'],
              templateId: logData['template_id'],
              occurredAt: DateTime.parse(logData['occurred_at']),
              durationMin: logData['duration_min'],
              notes: logData['notes'],
              imageUrl: logData['image_url'],
              earnedXp: logData['earned_xp'],
            );
            await _db.insertLog(log);
            result.logsImported++;
          } catch (e) {
            result.errors.add('Failed to import log ${logData['id']}: $e');
          }
        }
      }

      // Import achievements
      if (importData.containsKey('achievements')) {
        final achievementsData = importData['achievements'] as List<dynamic>;
        for (final achievementData in achievementsData) {
          try {
            await _db.insertAchievement(
              achievementData['achievement_type'],
              data: achievementData['data'],
            );
            result.achievementsImported++;
          } catch (e) {
            result.errors.add('Failed to import achievement ${achievementData['achievement_type']}: $e');
          }
        }
      }

      result.success = result.errors.isEmpty;

      ProductionLogger.data('Import completed', recordCount: result.templatesImported + result.logsImported + result.achievementsImported);
      if (result.errors.isNotEmpty) {
        ProductionLogger.warning('Import had ${result.errors.length} errors');
      }

      return result;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to import data', e, stackTrace, 'DataExportService');
      return ImportResult()
        ..success = false
        ..errors.add('Critical import error: $e');
    }
  }

  /// Import data from JSON string
  static Future<ImportResult> importFromJsonString(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      return await importFromJson(data);
    } catch (e) {
      return ImportResult()
        ..success = false
        ..errors.add('Failed to parse JSON: $e');
    }
  }

  /// Create a backup of current data before import
  static Future<String> createBackup() async {
    try {
      final backupData = await exportAllData();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      backupData['backup_info'] = {
        'is_backup': true,
        'created_at': DateTime.now().toIso8601String(),
        'timestamp': timestamp,
      };
      return jsonEncode(backupData);
    } catch (e, stackTrace) {
      LoggingService.error('Failed to create backup', e, stackTrace, 'DataExportService');
      rethrow;
    }
  }

  /// Get export statistics
  static Future<Map<String, dynamic>> getExportStats() async {
    try {
      final dbInfo = await _db.getDatabaseInfo();
      final totalXp = await _db.getTotalXp();
      
      return {
        'templates_count': dbInfo['templates'] ?? 0,
        'logs_count': dbInfo['logs'] ?? 0,
        'achievements_count': dbInfo['achievements'] ?? 0,
        'total_xp': totalXp,
        'database_size_info': dbInfo,
        'estimated_export_size_kb': _estimateExportSize(dbInfo),
      };
    } catch (e, stackTrace) {
      LoggingService.error('Failed to get export stats', e, stackTrace, 'DataExportService');
      return {};
    }
  }

  static int _estimateExportSize(Map<String, dynamic> dbInfo) {
    // Rough estimation: 
    // - 200 bytes per template
    // - 500 bytes per log (including notes)
    // - 100 bytes per achievement
    // - 1KB overhead
    
    final templates = (dbInfo['templates'] as int?) ?? 0;
    final logs = (dbInfo['logs'] as int?) ?? 0;
    final achievements = (dbInfo['achievements'] as int?) ?? 0;
    
    final estimatedBytes = (templates * 200) + (logs * 500) + (achievements * 100) + 1024;
    return (estimatedBytes / 1024).round();
  }

  /// Clear all local data (use with caution!)
  static Future<void> clearAllData() async {
    try {
      ProductionLogger.warning('Clearing all local data');
      await _db.clearAllData();
      ProductionLogger.info('All local data cleared successfully');
    } catch (e, stackTrace) {
      LoggingService.error('Failed to clear all data', e, stackTrace, 'DataExportService');
      rethrow;
    }
  }

  /// Migrate data from Supabase to local storage
  static Future<MigrationResult> migrateFromSupabase({
    required List<ActionTemplate> templates,
    required List<ActionLog> logs,
    List<Map<String, dynamic>>? achievements,
  }) async {
    try {
      ProductionLogger.data('Starting Supabase migration');

      final result = MigrationResult();

      // Clear existing local data first
      await _db.clearAllData();

      // Migrate templates
      for (final template in templates) {
        try {
          await _db.insertTemplate(template);
          result.templatesImported++;
        } catch (e) {
          result.errors.add('Failed to migrate template ${template.id}: $e');
        }
      }

      // Migrate logs
      for (final log in logs) {
        try {
          await _db.insertLog(log);
          result.logsImported++;
        } catch (e) {
          result.errors.add('Failed to migrate log ${log.id}: $e');
        }
      }

      // Migrate achievements if provided
      if (achievements != null) {
        for (final achievement in achievements) {
          try {
            await _db.insertAchievement(
              achievement['achievement_type'],
              data: achievement['data'],
            );
            result.achievementsImported++;
          } catch (e) {
            result.errors.add('Failed to migrate achievement ${achievement['achievement_type']}: $e');
          }
        }
      }

      result.success = result.errors.isEmpty || 
          (result.templatesImported > 0 || result.logsImported > 0);

      ProductionLogger.data('Migration completed', recordCount: result.templatesImported + result.logsImported + result.achievementsImported);
      if (result.errors.isNotEmpty) {
        ProductionLogger.warning('Migration had ${result.errors.length} errors');
      }

      return result;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to migrate from Supabase', e, stackTrace, 'DataExportService');
      return MigrationResult()
        ..success = false
        ..errors.add('Critical migration error: $e');
    }
  }
}

class ImportResult {
  bool success = false;
  int templatesImported = 0;
  int logsImported = 0;
  int achievementsImported = 0;
  List<String> errors = [];

  int get totalImported => templatesImported + logsImported + achievementsImported;
  
  bool get hasErrors => errors.isNotEmpty;
  bool get hasPartialSuccess => totalImported > 0 && hasErrors;
}

class MigrationResult {
  bool success = false;
  int templatesImported = 0;
  int logsImported = 0;
  int achievementsImported = 0;
  List<String> errors = [];

  int get totalMigrated => templatesImported + logsImported + achievementsImported;
  
  bool get hasErrors => errors.isNotEmpty;
  bool get hasPartialSuccess => totalMigrated > 0 && hasErrors;
}