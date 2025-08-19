import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/action_models.dart' as models;
import '../services/local_database.dart';
import '../utils/logging_service.dart';
import '../utils/xp_calculator.dart';

typedef ActionLog = models.ActionLog;

class LocalLogsRepository {
  final LocalDatabase _db = LocalDatabase();

  Future<ActionLog> createLog({
    required String templateId,
    int? durationMin,
    String? notes,
    String? imageUrl,
  }) async {
    try {
      // Calculate XP locally
      final earnedXp = XpCalculator.calculateFallback(
        durationMin: durationMin,
        notes: notes,
        imageUrl: imageUrl,
      );

      final log = ActionLog(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}',
        templateId: templateId,
        occurredAt: DateTime.now(),
        durationMin: durationMin,
        notes: notes,
        imageUrl: imageUrl,
        earnedXp: earnedXp,
      );

      await _db.insertLog(log);
      
      if (kDebugMode) debugPrint('Created local log: ${log.id} with ${log.earnedXp} XP');
      return log;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to create log locally', e, stackTrace, 'LocalLogsRepository');
      rethrow;
    }
  }

  Future<ActionLog> createQuickLog({
    required String activityName,
    required String category,
    int? durationMin,
    String? notes,
    String? imageUrl,
  }) async {
    try {
      // Enhance notes with activity name and category for Quick Logs
      Map<String, dynamic> notesData = {};
      
      if (notes != null && notes.trim().isNotEmpty) {
        try {
          notesData = jsonDecode(notes);
        } catch (_) {
          // If notes is not JSON, treat as plain text content
          notesData = {'content': notes};
        }
      }
      
      // Add activity metadata
      notesData['title'] = activityName;
      notesData['category'] = category;
      notesData['quick_log'] = true;
      
      final enhancedNotes = jsonEncode(notesData);

      // Calculate XP locally
      final earnedXp = XpCalculator.calculateFallback(
        durationMin: durationMin,
        notes: enhancedNotes,
        imageUrl: imageUrl,
      );

      final log = ActionLog(
        id: 'quick_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}',
        templateId: null, // Quick logs don't have templates
        occurredAt: DateTime.now(),
        durationMin: durationMin,
        notes: enhancedNotes,
        imageUrl: imageUrl,
        earnedXp: earnedXp,
      );

      await _db.insertLog(log);
      
      if (kDebugMode) debugPrint('Created quick log: ${log.id} for activity "$activityName" with ${log.earnedXp} XP');
      return log;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to create quick log locally', e, stackTrace, 'LocalLogsRepository');
      rethrow;
    }
  }

  Future<List<ActionLog>> fetchLogs({DateTime? since, int? limit}) async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL REPO FETCH LOGS ===');
      
      final logs = await _db.getLogs(since: since, limit: limit);
      
      if (kDebugMode) debugPrint('Fetched ${logs.length} logs from local database');
      return logs;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to fetch logs from local database', e, stackTrace, 'LocalLogsRepository');
      return [];
    }
  }

  Future<int> fetchTotalXp() async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL REPO FETCH TOTAL XP ===');
      
      final totalXp = await _db.getTotalXp();
      
      if (kDebugMode) debugPrint('Total XP from local database: $totalXp');
      return totalXp;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to fetch total XP from local database', e, stackTrace, 'LocalLogsRepository');
      return 0;
    }
  }

  Future<int> calculateStreak() async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL REPO CALCULATE STREAK ===');
      
      final streak = await _db.calculateStreak();
      
      if (kDebugMode) debugPrint('Calculated streak from local database: $streak');
      return streak;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to calculate streak from local database', e, stackTrace, 'LocalLogsRepository');
      return 0;
    }
  }

  Future<Map<DateTime, Map<String, int>>> fetchDailyAreaTotals({
    required DateTime month,
  }) async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL REPO FETCH DAILY AREA TOTALS ===');
      
      final totals = await _db.getDailyAreaTotals(month);
      
      if (kDebugMode) debugPrint('Fetched daily area totals for ${totals.length} days');
      return totals;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to fetch daily area totals from local database', e, stackTrace, 'LocalLogsRepository');
      return {};
    }
  }

  Future<List<DateTime>> fetchLoggedDates(int days) async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL REPO FETCH LOGGED DATES ===');
      
      final since = DateTime.now().subtract(Duration(days: days));
      final logs = await _db.getLogs(since: since);
      
      final dates = logs
          .map((log) => DateTime(log.occurredAt.year, log.occurredAt.month, log.occurredAt.day))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      
      if (kDebugMode) debugPrint('Fetched ${dates.length} logged dates from local database');
      return dates;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to fetch logged dates from local database', e, stackTrace, 'LocalLogsRepository');
      return [];
    }
  }

  Future<int> getLogCount() async {
    try {
      return await _db.getLogCount();
    } catch (e, stackTrace) {
      LoggingService.error('Failed to get log count from local database', e, stackTrace, 'LocalLogsRepository');
      return 0;
    }
  }

  // Achievement support
  Future<void> insertAchievement(String achievementType, {Map<String, dynamic>? data}) async {
    try {
      await _db.insertAchievement(achievementType, data: data);
      if (kDebugMode) debugPrint('Inserted achievement: $achievementType');
    } catch (e, stackTrace) {
      LoggingService.error('Failed to insert achievement locally', e, stackTrace, 'LocalLogsRepository');
    }
  }

  Future<List<Map<String, dynamic>>> getAchievements() async {
    try {
      return await _db.getAchievements();
    } catch (e, stackTrace) {
      LoggingService.error('Failed to get achievements from local database', e, stackTrace, 'LocalLogsRepository');
      return [];
    }
  }

  Future<bool> hasAchievement(String achievementType) async {
    try {
      return await _db.hasAchievement(achievementType);
    } catch (e, stackTrace) {
      LoggingService.error('Failed to check achievement from local database', e, stackTrace, 'LocalLogsRepository');
      return false;
    }
  }

  // Database info and maintenance
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      return await _db.getDatabaseInfo();
    } catch (e, stackTrace) {
      LoggingService.error('Failed to get database info', e, stackTrace, 'LocalLogsRepository');
      return {};
    }
  }

  Future<void> clearAllData() async {
    try {
      await _db.clearAllData();
      if (kDebugMode) debugPrint('Cleared all local data');
    } catch (e, stackTrace) {
      LoggingService.error('Failed to clear all data from local database', e, stackTrace, 'LocalLogsRepository');
      rethrow;
    }
  }

  /// Holt alle lokalen Logs für Migration
  Future<List<ActionLog>> getAllLocalLogs() async {
    try {
      return await _db.getLogs(); // Ohne limit für alle Logs
    } catch (e, stackTrace) {
      LoggingService.error('Failed to get all local logs', e, stackTrace, 'LocalLogsRepository');
      return [];
    }
  }

  /// Löscht alle lokalen Logs (für Migration)
  Future<void> clearAllLocalLogs() async {
    try {
      await clearAllData(); // Nutzt die bestehende Methode
    } catch (e, stackTrace) {
      LoggingService.error('Failed to clear all local logs', e, stackTrace, 'LocalLogsRepository');
      rethrow;
    }
  }

  /// Holt lokale Statistiken für anonyme User
  Future<Map<String, int>> getLocalStatistics() async {
    try {
      final totalActions = await getLogCount();
      final totalXp = await fetchTotalXp();
      final currentStreak = await calculateStreak();
      
      return {
        'totalActions': totalActions,
        'totalXP': totalXp,
        'currentStreak': currentStreak,
        'longestStreak': currentStreak, // Vereinfacht für jetzt
      };
    } catch (e, stackTrace) {
      LoggingService.error('Failed to get local statistics', e, stackTrace, 'LocalLogsRepository');
      return {
        'totalActions': 0,
        'totalXP': 0,
        'currentStreak': 0,
        'longestStreak': 0,
      };
    }
  }
}