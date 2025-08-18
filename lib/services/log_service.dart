import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/action_models.dart' as models;
import '../navigation.dart';
import '../utils/logging_service.dart';
import 'achievement_service.dart';
import 'storage_service.dart';
import 'xp_service.dart';
import 'streak_service.dart';
import 'statistics_cache_service.dart';

/// Service for handling action logs
class LogService {
  /// Create a log entry with client-side XP calculation
  static Future<models.ActionLog> createLog({
    required String templateId,
    int? durationMin,
    String? notes,
    String? imageUrl,
  }) async {
    final log = StorageService.isUsingLocalStorage
        ? await StorageService.logsRepo.createLog(
            templateId: templateId,
            durationMin: durationMin,
            notes: notes,
            imageUrl: imageUrl,
          )
        : await StorageService.logsRepo.createLog(
            templateId: templateId,
            durationMin: durationMin,
            notes: notes,
            imageUrl: imageUrl,
          );
    _checkAchievementsAfterLogInsert();
    
    // Invalidate cache after creating new log
    StatisticsCacheService.invalidateCache();
    
    try { 
      notifyLogsChanged(); 
    } catch (e, stackTrace) {
      LoggingService.error('Failed to notify logs changed after createLog', e, stackTrace, 'LogService');
    }
    return log;
  }

  /// Create quick log without template
  static Future<models.ActionLog> createQuickLog({
    required String activityName,
    required String category,
    int? durationMin,
    String? notes,
    String? imageUrl,
  }) async {
    final log = StorageService.isUsingLocalStorage
        ? await StorageService.logsRepo.createQuickLog(
            activityName: activityName,
            category: category,
            durationMin: durationMin,
            notes: notes,
            imageUrl: imageUrl,
          )
        : await StorageService.logsRepo.createQuickLog(
            activityName: activityName,
            category: category,
            durationMin: durationMin,
            notes: notes,
            imageUrl: imageUrl,
          );
    await _checkAchievementsAfterLogInsert();
    
    // Invalidate cache after creating new log
    StatisticsCacheService.invalidateCache();
    
    try { 
      notifyLogsChanged(); 
    } catch (e, stackTrace) {
      LoggingService.error('Failed to notify logs changed after createLog', e, stackTrace, 'LogService');
    }
    return log;
  }

  /// Load all logs
  static Future<List<models.ActionLog>> fetchLogs() async {
    return StorageService.isUsingLocalStorage
        ? await StorageService.logsRepo.fetchLogs()
        : await StorageService.logsRepo.fetchLogs();
  }

  /// Calculate total XP with caching
  static Future<int> fetchTotalXp() async {
    return await StatisticsCacheService.getTotalXP();
  }

  /// Aggregated activities per day and area with caching
  static Future<Map<DateTime, Map<String, int>>> fetchDailyAreaTotals({
    required DateTime month,
  }) async {
    return await StatisticsCacheService.getDailyAreaTotals(month: month);
  }

  /// Detailed aggregation (Count, Duration, XP) per day and area via RPC
  static Future<Map<DateTime, List<Map<String, dynamic>>>> fetchDailyAreaTotalsDetailed({
    required DateTime month,
  }) async {
    return StorageService.isUsingLocalStorage
        ? await StorageService.statsRepo.fetchDailyAreaTotalsDetailed(month: month)
        : await StorageService.statsRepo.fetchDailyAreaTotalsDetailed(month: month);
  }

  static Future<void> _checkAchievementsAfterLogInsert() async {
    try {
      // Total XP (across all logs)
      final totalXp = await fetchTotalXp();

      // Total number of activities
      final logs = StorageService.isUsingLocalStorage
          ? await StorageService.logsRepo.fetchLogs()
          : await StorageService.logsRepo.fetchLogs();
      final totalActions = logs.length;

      // Calculate streak server-side (existing function)
      final currentStreak = await StreakService.calculateStreak();

      // Number of active life areas: parent-rollup like in calendar/profile
      int lifeAreaCount = 0;
      try {
        final rolledParents = <String>{};
        for (final l in logs) {
          try {
            if (l.notes == null) continue;
            final obj = jsonDecode(l.notes!);
            if (obj is Map<String, dynamic>) {
              String? area = (obj['area'] as String?)?.trim().toLowerCase();
              String? lifeArea = (obj['life_area'] as String?)?.trim().toLowerCase();
              area ??= lifeArea;
              final category = (obj['category'] as String?)?.trim().toLowerCase();
              String key;
              bool isKnownParent(String? v) => const {
                'spirituality','finance','career','learning','relationships','health','creativity','fitness','nutrition','art'
              }.contains(v);
              if (isKnownParent(area)) {
                key = area!;
              } else {
                switch (category) {
                  case 'inner': key = 'spirituality'; break;
                  case 'social': key = 'relationships'; break;
                  case 'work': key = 'career'; break;
                  case 'development': key = 'learning'; break;
                  case 'finance': key = 'finance'; break;
                  case 'health': key = 'health'; break;
                  case 'fitness': key = 'fitness'; break;
                  case 'nutrition': key = 'nutrition'; break;
                  case 'art': key = 'art'; break;
                  default: key = area ?? 'unknown';
                }
              }
              rolledParents.add(key);
            }
          } catch (e) {
            if (kDebugMode) debugPrint('Error parsing log notes for achievements: $e');
          }
        }
        lifeAreaCount = rolledParents.where((k) => k != 'unknown').length;
      } catch (e) {
        if (kDebugMode) debugPrint('Error calculating life area count for achievements: $e');
      }

      // Today's actions for daily achievements
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      int dailyActions = logs.where((l) => l.occurredAt.isAfter(start) && l.occurredAt.isBefore(end)).length;

      await AchievementService.reconcileLifeAreaAchievements(lifeAreaCount);
      await AchievementService.checkAndUnlockAchievements(
        currentStreak: currentStreak,
        totalActions: totalActions,
        totalXP: totalXp,
        level: XpService.calculateLevel(totalXp),
        lifeAreaCount: lifeAreaCount,
        dailyActions: dailyActions,
        // Use local current time as safe reference for special achievements (e.g. weekend),
        // since the freshly inserted log may not yet appear in fetchLogs() (replication delay)
        lastActionTime: DateTime.now(),
      );
    } catch (e) {
      // still continue silently
      // ignore
    }
  }
}