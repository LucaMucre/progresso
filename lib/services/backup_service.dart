import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'data_export_service.dart';
import '../utils/production_logger.dart';
import '../utils/web_file_download_stub.dart'
    if (dart.library.html) '../utils/web_file_download_web.dart' as web_download;

/// Service for creating and managing data backups
class BackupService {
  
  /// Create and share a backup file
  static Future<BackupResult> createAndShareBackup() async {
    try {
      ProductionLogger.info('Creating user data backup');
      
      // Create backup data
      final backupJson = await DataExportService.createBackup();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = 'progresso_backup_$timestamp.json';
      
      if (kIsWeb) {
        // For web, download as file
        web_download.downloadFile(backupJson, filename, 'application/json');
        return BackupResult.success('Backup downloaded as $filename');
      } else {
        // For mobile, use share dialog
        await Share.shareXFiles([
          XFile.fromData(
            utf8.encode(backupJson),
            name: filename,
            mimeType: 'application/json',
          )
        ], subject: 'Progresso Data Backup');
        
        return BackupResult.success('Backup shared successfully');
      }
    } catch (e) {
      ProductionLogger.error('Failed to create backup: $e');
      return BackupResult.error('Failed to create backup: $e');
    }
  }
  
  /// Get backup statistics before creating backup
  static Future<Map<String, dynamic>> getBackupStats() async {
    try {
      return await DataExportService.getExportStats();
    } catch (e) {
      ProductionLogger.error('Failed to get backup stats: $e');
      return {};
    }
  }
  
  /// Validate backup file format
  static bool validateBackupFormat(String jsonContent) {
    try {
      final data = jsonDecode(jsonContent);
      if (data is! Map<String, dynamic>) return false;
      
      final exportInfo = data['export_info'];
      if (exportInfo == null || exportInfo['app_name'] != 'progresso') {
        return false;
      }
      
      // Check for required sections
      return data.containsKey('templates') || 
             data.containsKey('logs') || 
             data.containsKey('achievements');
    } catch (e) {
      return false;
    }
  }
  
  /// Restore data from backup
  static Future<BackupResult> restoreFromBackup(String backupContent) async {
    try {
      ProductionLogger.info('Starting backup restore');
      
      if (!validateBackupFormat(backupContent)) {
        return BackupResult.error('Invalid backup file format');
      }
      
      // Create current data backup before restore
      final currentBackup = await DataExportService.createBackup();
      ProductionLogger.info('Created safety backup before restore');
      
      // Import the backup data
      final importResult = await DataExportService.importFromJsonString(backupContent);
      
      if (importResult.success) {
        ProductionLogger.info('Backup restored successfully');
        return BackupResult.success(
          'Backup restored successfully: ${importResult.totalImported} items imported',
          metadata: {
            'templates_imported': importResult.templatesImported,
            'logs_imported': importResult.logsImported,
            'achievements_imported': importResult.achievementsImported,
            'safety_backup': currentBackup,
          }
        );
      } else {
        ProductionLogger.error('Backup restore failed with errors');
        return BackupResult.error(
          'Backup restore failed: ${importResult.errors.join(', ')}',
          metadata: {'safety_backup': currentBackup}
        );
      }
    } catch (e) {
      ProductionLogger.error('Failed to restore backup: $e');
      return BackupResult.error('Failed to restore backup: $e');
    }
  }
  
  /// Copy backup data to clipboard
  static Future<BackupResult> copyBackupToClipboard() async {
    try {
      ProductionLogger.info('Copying backup to clipboard');
      
      final backupJson = await DataExportService.createBackup();
      await Clipboard.setData(ClipboardData(text: backupJson));
      
      return BackupResult.success('Backup copied to clipboard');
    } catch (e) {
      ProductionLogger.error('Failed to copy backup to clipboard: $e');
      return BackupResult.error('Failed to copy backup: $e');
    }
  }
  
  /// Restore from clipboard data
  static Future<BackupResult> restoreFromClipboard() async {
    try {
      ProductionLogger.info('Restoring from clipboard');
      
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text == null || clipboardData!.text!.isEmpty) {
        return BackupResult.error('No data found in clipboard');
      }
      
      return await restoreFromBackup(clipboardData.text!);
    } catch (e) {
      ProductionLogger.error('Failed to restore from clipboard: $e');
      return BackupResult.error('Failed to restore from clipboard: $e');
    }
  }
}

class BackupResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? metadata;
  
  const BackupResult._({
    required this.success,
    required this.message,
    this.metadata,
  });
  
  factory BackupResult.success(String message, {Map<String, dynamic>? metadata}) {
    return BackupResult._(
      success: true,
      message: message,
      metadata: metadata,
    );
  }
  
  factory BackupResult.error(String message, {Map<String, dynamic>? metadata}) {
    return BackupResult._(
      success: false,
      message: message,
      metadata: metadata,
    );
  }
}