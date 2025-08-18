import 'package:flutter/foundation.dart';
import '../services/local_database.dart';
import '../utils/logging_service.dart';

class LocalStatsRepository {
  final LocalDatabase _db = LocalDatabase();

  Future<Map<DateTime, Map<String, int>>> fetchDailyAreaTotals({
    required DateTime month,
  }) async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL STATS REPO FETCH DAILY AREA TOTALS ===');
      
      final totals = await _db.getDailyAreaTotals(month);
      
      if (kDebugMode) debugPrint('Fetched daily area totals for ${totals.length} days from local database');
      return totals;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to fetch daily area totals from local database', e, stackTrace, 'LocalStatsRepository');
      return {};
    }
  }

  Future<Map<DateTime, List<Map<String, dynamic>>>> fetchDailyAreaTotalsDetailed({
    required DateTime month,
  }) async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL STATS REPO FETCH DAILY AREA TOTALS DETAILED ===');
      
      // Get the basic totals and enhance with detailed information
      final basicTotals = await _db.getDailyAreaTotals(month);
      final Map<DateTime, List<Map<String, dynamic>>> detailed = {};
      
      // Convert basic totals to detailed format
      for (final entry in basicTotals.entries) {
        final date = entry.key;
        final areaTotals = entry.value;
        
        final List<Map<String, dynamic>> dayDetails = [];
        
        for (final areaEntry in areaTotals.entries) {
          final areaKey = areaEntry.key;
          final total = areaEntry.value;
          
          // For detailed stats, we'd need to query logs for that specific date and area
          // For now, provide basic info with calculated estimates
          dayDetails.add({
            'area_key': areaKey,
            'total': total,
            'sum_duration': total * 30, // Estimate: 30 min average per activity
            'sum_xp': total * 5, // Estimate: 5 XP average per activity
          });
        }
        
        if (dayDetails.isNotEmpty) {
          detailed[date] = dayDetails;
        }
      }
      
      if (kDebugMode) debugPrint('Generated detailed stats for ${detailed.length} days');
      return detailed;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to fetch detailed daily area totals from local database', e, stackTrace, 'LocalStatsRepository');
      return {};
    }
  }

  Future<Map<String, dynamic>> getMonthlyStats(DateTime month) async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL STATS REPO GET MONTHLY STATS ===');
      
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 1);
      
      final logs = await _db.getLogs(since: startOfMonth);
      final monthLogs = logs.where((log) => 
        log.occurredAt.isBefore(endOfMonth) && 
        log.occurredAt.isAfter(startOfMonth.subtract(const Duration(days: 1)))
      ).toList();
      
      // Calculate stats
      final totalActivities = monthLogs.length;
      final totalXp = monthLogs.fold<int>(0, (sum, log) => sum + log.earnedXp);
      final totalDuration = monthLogs.fold<int>(0, (sum, log) => sum + (log.durationMin ?? 0));
      
      // Count unique days with activities
      final activeDays = monthLogs
          .map((log) => DateTime(log.occurredAt.year, log.occurredAt.month, log.occurredAt.day))
          .toSet()
          .length;
      
      // Count activities per category
      final Map<String, int> categoryBreakdown = {};
      for (final log in monthLogs) {
        String category = 'other';
        if (log.notes != null) {
          try {
            final notesData = log.notes!;
            // Simple category extraction - could be enhanced
            if (notesData.contains('"category"')) {
              final categoryMatch = RegExp(r'"category"\s*:\s*"([^"]+)"').firstMatch(notesData);
              if (categoryMatch != null) {
                category = categoryMatch.group(1) ?? 'other';
              }
            }
          } catch (_) {
            // Ignore parsing errors
          }
        }
        categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + 1;
      }
      
      final stats = {
        'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
        'total_activities': totalActivities,
        'total_xp': totalXp,
        'total_duration_minutes': totalDuration,
        'active_days': activeDays,
        'average_xp_per_day': activeDays > 0 ? (totalXp / activeDays).round() : 0,
        'average_activities_per_day': activeDays > 0 ? (totalActivities / activeDays).round() : 0,
        'category_breakdown': categoryBreakdown,
      };
      
      if (kDebugMode) debugPrint('Generated monthly stats: ${stats['total_activities']} activities, ${stats['total_xp']} XP');
      return stats;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to get monthly stats from local database', e, stackTrace, 'LocalStatsRepository');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getTopCategories({int limit = 5}) async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL STATS REPO GET TOP CATEGORIES ===');
      
      final logs = await _db.getLogs();
      final Map<String, Map<String, dynamic>> categoryStats = {};
      
      for (final log in logs) {
        String category = 'other';
        if (log.notes != null) {
          try {
            final notesData = log.notes!;
            if (notesData.contains('"category"')) {
              final categoryMatch = RegExp(r'"category"\s*:\s*"([^"]+)"').firstMatch(notesData);
              if (categoryMatch != null) {
                category = categoryMatch.group(1) ?? 'other';
              }
            }
          } catch (_) {
            // Ignore parsing errors
          }
        }
        
        if (!categoryStats.containsKey(category)) {
          categoryStats[category] = {
            'category': category,
            'count': 0,
            'total_xp': 0,
            'total_duration': 0,
          };
        }
        
        categoryStats[category]!['count'] = (categoryStats[category]!['count'] as int) + 1;
        categoryStats[category]!['total_xp'] = (categoryStats[category]!['total_xp'] as int) + log.earnedXp;
        categoryStats[category]!['total_duration'] = (categoryStats[category]!['total_duration'] as int) + (log.durationMin ?? 0);
      }
      
      final sortedCategories = categoryStats.values.toList()
        ..sort((a, b) => (b['total_xp'] as int).compareTo(a['total_xp'] as int));
      
      final topCategories = sortedCategories.take(limit).toList();
      
      if (kDebugMode) debugPrint('Found top ${topCategories.length} categories');
      return topCategories;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to get top categories from local database', e, stackTrace, 'LocalStatsRepository');
      return [];
    }
  }

  Future<Map<String, dynamic>> getOverallStats() async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL STATS REPO GET OVERALL STATS ===');
      
      final dbInfo = await _db.getDatabaseInfo();
      final totalXp = await _db.getTotalXp();
      final streak = await _db.calculateStreak();
      
      final stats = {
        'total_logs': dbInfo['logs'] ?? 0,
        'total_templates': dbInfo['templates'] ?? 0,
        'total_xp': totalXp,
        'current_streak': streak,
        'level': _calculateLevel(totalXp),
        'database_info': dbInfo,
      };
      
      if (kDebugMode) debugPrint('Overall stats: ${stats['total_logs']} logs, ${stats['total_xp']} XP, level ${stats['level']}');
      return stats;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to get overall stats from local database', e, stackTrace, 'LocalStatsRepository');
      return {};
    }
  }

  int _calculateLevel(int totalXp) {
    if (totalXp <= 0) return 1;
    return (totalXp / 100).floor() + 1;
  }
}