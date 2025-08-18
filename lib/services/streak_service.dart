import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';
import 'statistics_cache_service.dart';

/// Service for streak calculations
class StreakService {
  static final _db = Supabase.instance.client;

  /// Calculate the current streak based on consecutive days,
  /// starting from the last logged day (not necessarily today).
  static Future<int> calculateStreak() async {
    return StorageService.isUsingLocalStorage
        ? await StorageService.logsRepo.calculateStreak()
        : await StorageService.logsRepo.calculateStreak();
  }

  /// Alias for calculateStreak, for dashboard code compatibility
  static Future<int> fetchStreak() => calculateStreak();

  /// Load all date values (without time) of the last [days] days that were logged
  static Future<List<DateTime>> fetchLoggedDates(int days) async {
    if (kDebugMode) {
      debugPrint('=== FETCH LOGGED DATES DEBUG ===');
      debugPrint('Days: $days');
    }
    
    try {
      if (StorageService.isUsingLocalStorage) {
        final dates = await StorageService.logsRepo.fetchLoggedDates(days);
        if (kDebugMode) debugPrint('Local logged dates: $dates');
        return dates;
      } else {
        final since = DateTime.now().subtract(Duration(days: days));
        final res = await _db
            .from('action_logs')
            .select('occurred_at')
            .gte('occurred_at', since.toIso8601String());
        if (kDebugMode) debugPrint('Logged dates result: $res');
        
        final dates = (res as List)
            .map((e) => DateTime.parse(e['occurred_at'] as String).toLocal())
            .map((dt) => DateTime(dt.year, dt.month, dt.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
        if (kDebugMode) debugPrint('Processed dates: $dates');
        return dates;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching logged dates: $e');
      rethrow;
    }
  }

  /// Badge level (0=none, 1=Bronze, 2=Silver, 3=Gold)
  static int badgeLevel(int streak) {
    if (streak >= 30) return 3;
    if (streak >= 7)  return 2;
    if (streak >= 3)  return 1;
    return 0;
  }
}