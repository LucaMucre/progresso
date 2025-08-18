import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/action_models.dart' as models;
import '../navigation.dart';
import 'storage_service.dart';
import 'xp_service.dart';
import 'streak_service.dart';

/// Statistics data model for caching
class CachedStatistics {
  final int totalActions;
  final int totalXP;
  final int currentStreak;
  final Map<String, int> areaActivityCounts;
  final Map<DateTime, Map<String, int>> dailyAreaTotals;
  final DateTime lastCalculated;
  final String cacheKey;

  const CachedStatistics({
    required this.totalActions,
    required this.totalXP,
    required this.currentStreak,
    required this.areaActivityCounts,
    required this.dailyAreaTotals,
    required this.lastCalculated,
    required this.cacheKey,
  });

  Map<String, dynamic> toJson() => {
    'totalActions': totalActions,
    'totalXP': totalXP,
    'currentStreak': currentStreak,
    'areaActivityCounts': areaActivityCounts,
    'dailyAreaTotals': dailyAreaTotals.map((k, v) => MapEntry(k.toIso8601String(), v)),
    'lastCalculated': lastCalculated.toIso8601String(),
    'cacheKey': cacheKey,
  };

  static CachedStatistics fromJson(Map<String, dynamic> json) => CachedStatistics(
    totalActions: json['totalActions'] ?? 0,
    totalXP: json['totalXP'] ?? 0,
    currentStreak: json['currentStreak'] ?? 0,
    areaActivityCounts: Map<String, int>.from(json['areaActivityCounts'] ?? {}),
    dailyAreaTotals: (json['dailyAreaTotals'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(DateTime.parse(k), Map<String, int>.from(v))),
    lastCalculated: DateTime.parse(json['lastCalculated']),
    cacheKey: json['cacheKey'] ?? '',
  );
}

/// Service for caching and optimizing statistics calculations
class StatisticsCacheService {
  static const String _cacheKeyPrefix = 'stats_cache_';
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  static const Duration _dailyStatsValidDuration = Duration(hours: 1);
  
  static final Map<String, CachedStatistics> _memoryCache = {};
  static final Map<String, Timer> _cacheTimers = {};
  static bool _initialized = false;

  /// Initialize the cache service and listen for data changes
  static Future<void> initialize() async {
    if (_initialized) return;
    
    // Listen for log changes to invalidate cache
    logsChangedTick.addListener(_invalidateAllCaches);
    _initialized = true;
    
    if (kDebugMode) debugPrint('StatisticsCacheService initialized');
  }

  /// Generate cache key based on parameters
  static String _generateCacheKey(String type, [Map<String, dynamic>? params]) {
    final userId = StorageService.isUsingLocalStorage ? 'local' : 'remote';
    final paramsStr = params != null ? '_${params.hashCode}' : '';
    return '${_cacheKeyPrefix}${type}_${userId}$paramsStr';
  }

  /// Check if cache is valid
  static bool _isCacheValid(CachedStatistics cache, Duration validDuration) {
    return DateTime.now().difference(cache.lastCalculated) < validDuration;
  }

  /// Get cached statistics from memory or SharedPreferences
  static Future<CachedStatistics?> _getCachedStats(String cacheKey) async {
    // Check memory cache first
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // Check persistent cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final stats = CachedStatistics.fromJson(jsonDecode(cached));
        _memoryCache[cacheKey] = stats;
        return stats;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading cached stats: $e');
    }
    
    return null;
  }

  /// Save statistics to cache
  static Future<void> _setCachedStats(String cacheKey, CachedStatistics stats) async {
    // Save to memory cache
    _memoryCache[cacheKey] = stats;
    
    // Set auto-expiration timer
    _cacheTimers[cacheKey]?.cancel();
    _cacheTimers[cacheKey] = Timer(_cacheValidDuration, () {
      _memoryCache.remove(cacheKey);
      _cacheTimers.remove(cacheKey);
    });

    // Save to persistent cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(stats.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving cached stats: $e');
    }
  }

  /// Get total XP with caching
  static Future<int> getTotalXP() async {
    await initialize();
    const cacheKey = 'totalXP';
    final fullCacheKey = _generateCacheKey(cacheKey);
    
    final cached = await _getCachedStats(fullCacheKey);
    if (cached != null && _isCacheValid(cached, _cacheValidDuration)) {
      return cached.totalXP;
    }

    // Calculate fresh value
    final totalXP = StorageService.isUsingLocalStorage
        ? await StorageService.logsRepo.fetchTotalXp()
        : await StorageService.logsRepo.fetchTotalXp();

    // Cache for next time
    final stats = CachedStatistics(
      totalActions: 0,
      totalXP: totalXP,
      currentStreak: 0,
      areaActivityCounts: {},
      dailyAreaTotals: {},
      lastCalculated: DateTime.now(),
      cacheKey: fullCacheKey,
    );
    await _setCachedStats(fullCacheKey, stats);
    
    return totalXP;
  }

  /// Get current streak with caching
  static Future<int> getCurrentStreak() async {
    await initialize();
    const cacheKey = 'currentStreak';
    final fullCacheKey = _generateCacheKey(cacheKey);
    
    final cached = await _getCachedStats(fullCacheKey);
    if (cached != null && _isCacheValid(cached, _cacheValidDuration)) {
      return cached.currentStreak;
    }

    // Calculate fresh value
    final streak = await StreakService.calculateStreak();

    // Cache for next time
    final stats = CachedStatistics(
      totalActions: 0,
      totalXP: 0,
      currentStreak: streak,
      areaActivityCounts: {},
      dailyAreaTotals: {},
      lastCalculated: DateTime.now(),
      cacheKey: fullCacheKey,
    );
    await _setCachedStats(fullCacheKey, stats);
    
    return streak;
  }

  /// Get comprehensive dashboard statistics with caching
  static Future<CachedStatistics> getDashboardStats() async {
    await initialize();
    const cacheKey = 'dashboardStats';
    final fullCacheKey = _generateCacheKey(cacheKey);
    
    final cached = await _getCachedStats(fullCacheKey);
    if (cached != null && _isCacheValid(cached, _cacheValidDuration)) {
      return cached;
    }

    // Calculate fresh values
    final logs = StorageService.isUsingLocalStorage
        ? await StorageService.logsRepo.fetchLogs()
        : await StorageService.logsRepo.fetchLogs();

    final totalActions = logs.length;
    final totalXP = logs.fold<int>(0, (sum, log) => sum + log.earnedXp);
    final currentStreak = await StreakService.calculateStreak();

    // Calculate area activity counts
    final Map<String, int> areaActivityCounts = {};
    for (final log in logs) {
      final area = _extractAreaFromLog(log);
      areaActivityCounts[area] = (areaActivityCounts[area] ?? 0) + 1;
    }

    final stats = CachedStatistics(
      totalActions: totalActions,
      totalXP: totalXP,
      currentStreak: currentStreak,
      areaActivityCounts: areaActivityCounts,
      dailyAreaTotals: {},
      lastCalculated: DateTime.now(),
      cacheKey: fullCacheKey,
    );

    await _setCachedStats(fullCacheKey, stats);
    return stats;
  }

  /// Get daily area totals with longer cache duration
  static Future<Map<DateTime, Map<String, int>>> getDailyAreaTotals({
    required DateTime month,
  }) async {
    await initialize();
    final cacheKey = 'dailyAreaTotals';
    final fullCacheKey = _generateCacheKey(cacheKey, {'month': month.toString()});
    
    final cached = await _getCachedStats(fullCacheKey);
    if (cached != null && _isCacheValid(cached, _dailyStatsValidDuration)) {
      return cached.dailyAreaTotals;
    }

    // Calculate fresh values
    final dailyTotals = StorageService.isUsingLocalStorage
        ? await StorageService.statsRepo.fetchDailyAreaTotals(month: month)
        : await StorageService.statsRepo.fetchDailyAreaTotals(month: month);

    final stats = CachedStatistics(
      totalActions: 0,
      totalXP: 0,
      currentStreak: 0,
      areaActivityCounts: {},
      dailyAreaTotals: dailyTotals,
      lastCalculated: DateTime.now(),
      cacheKey: fullCacheKey,
    );

    await _setCachedStats(fullCacheKey, stats);
    return dailyTotals;
  }

  /// Extract area from log (reusing existing logic)
  static String _extractAreaFromLog(models.ActionLog log) {
    try {
      if (log.notes != null) {
        final obj = jsonDecode(log.notes!);
        if (obj is Map<String, dynamic>) {
          String? area = (obj['area'] as String?)?.trim().toLowerCase();
          String? lifeArea = (obj['life_area'] as String?)?.trim().toLowerCase();
          area ??= lifeArea;
          final category = (obj['category'] as String?)?.trim().toLowerCase();
          
          const knownParents = {
            'spirituality','finance','career','learning','relationships','health','creativity','fitness','nutrition','art'
          };
          
          if (knownParents.contains(area)) {
            return area!;
          }
          
          switch (category) {
            case 'inner': return 'spirituality';
            case 'social': return 'relationships';
            case 'work': return 'career';
            case 'development': return 'learning';
            case 'finance': return 'finance';
            case 'health': return 'health';
            case 'fitness': return 'fitness';
            case 'nutrition': return 'nutrition';
            case 'art': return 'art';
            default: return area ?? 'unknown';
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error extracting area from log: $e');
    }
    return 'unknown';
  }

  /// Invalidate all caches when data changes
  static void _invalidateAllCaches() {
    _memoryCache.clear();
    for (final timer in _cacheTimers.values) {
      timer.cancel();
    }
    _cacheTimers.clear();
    
    // Also clear persistent cache
    _clearPersistentCache();
    
    if (kDebugMode) debugPrint('Statistics cache invalidated');
  }

  /// Clear persistent cache
  static Future<void> _clearPersistentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_cacheKeyPrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing persistent cache: $e');
    }
  }

  /// Manual cache invalidation for specific types
  static Future<void> invalidateCache([String? type]) async {
    if (type != null) {
      final keysToRemove = _memoryCache.keys.where((key) => key.contains(type)).toList();
      for (final key in keysToRemove) {
        _memoryCache.remove(key);
        _cacheTimers[key]?.cancel();
        _cacheTimers.remove(key);
      }
      
      // Clear from persistent cache too
      try {
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys().where((key) => key.startsWith(_cacheKeyPrefix) && key.contains(type));
        for (final key in keys) {
          await prefs.remove(key);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error clearing specific cache: $e');
      }
    } else {
      _invalidateAllCaches();
    }
  }

  /// Get cache statistics for debugging
  static Map<String, dynamic> getCacheInfo() {
    return {
      'memoryCache': _memoryCache.length,
      'activeTimers': _cacheTimers.length,
      'cacheKeys': _memoryCache.keys.toList(),
    };
  }
}