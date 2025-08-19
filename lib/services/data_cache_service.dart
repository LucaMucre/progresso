import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/action_models.dart' as models;
import '../services/life_areas_service.dart';
import '../utils/production_logger.dart';
import 'storage_service.dart';

/// Intelligent data caching service to prevent over-fetching
/// Implements memory cache with TTL and invalidation strategies
class DataCacheService {
  static final DataCacheService _instance = DataCacheService._internal();
  factory DataCacheService() => _instance;
  DataCacheService._internal();

  // Cache configuration
  static const Duration _defaultTTL = Duration(minutes: 5);
  static const Duration _shortTTL = Duration(seconds: 30);
  
  // Memory caches
  final Map<String, _CacheEntry<List<models.ActionLog>>> _logsCache = {};
  final Map<String, _CacheEntry<List<LifeArea>>> _lifeAreasCache = {};
  final Map<String, _CacheEntry<int>> _statsCache = {};
  
  // Active requests to prevent duplicate fetching
  final Map<String, Future<List<models.ActionLog>>> _pendingLogsRequests = {};
  final Map<String, Future<List<LifeArea>>> _pendingLifeAreasRequests = {};

  /// Get cached logs or fetch if needed
  Future<List<models.ActionLog>> getLogs({
    DateTime? since, 
    int? limit,
    Duration? ttl,
  }) async {
    final key = 'logs_${since?.millisecondsSinceEpoch ?? 'all'}_${limit ?? 'all'}';
    final cacheTTL = ttl ?? _defaultTTL;
    
    // Check cache first
    final cached = _logsCache[key];
    if (cached != null && !cached.isExpired) {
      ProductionLogger.cache('Returning cached logs', itemCount: cached.data.length);
      return cached.data;
    }

    // Check if request is already in progress
    if (_pendingLogsRequests.containsKey(key)) {
      return await _pendingLogsRequests[key]!;
    }

    // Fetch new data
    ProductionLogger.data('Fetching fresh logs data');
    final future = _fetchLogsFromStorage(since: since, limit: limit);
    _pendingLogsRequests[key] = future;

    try {
      final logs = await future;
      _logsCache[key] = _CacheEntry(logs, cacheTTL);
      return logs;
    } finally {
      _pendingLogsRequests.remove(key);
    }
  }

  /// Get cached life areas or fetch if needed
  Future<List<LifeArea>> getLifeAreas({Duration? ttl}) async {
    const key = 'life_areas';
    final cacheTTL = ttl ?? _defaultTTL;
    
    // Check cache first
    final cached = _lifeAreasCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    // Check if request is already in progress
    if (_pendingLifeAreasRequests.containsKey(key)) {
      return await _pendingLifeAreasRequests[key]!;
    }

    // Fetch new data
    final future = LifeAreasService.getLifeAreas();
    _pendingLifeAreasRequests[key] = future;

    try {
      final areas = await future;
      _lifeAreasCache[key] = _CacheEntry(areas, cacheTTL);
      return areas;
    } finally {
      _pendingLifeAreasRequests.remove(key);
    }
  }

  /// Invalidate specific cache entries
  void invalidateLogs([String? specificKey]) {
    if (specificKey != null) {
      _logsCache.remove(specificKey);
    } else {
      _logsCache.clear();
      _pendingLogsRequests.clear();
    }
  }

  void invalidateLifeAreas() {
    _lifeAreasCache.clear();
    _pendingLifeAreasRequests.clear();
  }

  void invalidateAll() {
    _logsCache.clear();
    _lifeAreasCache.clear();
    _statsCache.clear();
    _pendingLogsRequests.clear();
    _pendingLifeAreasRequests.clear();
  }

  /// Internal methods
  Future<List<models.ActionLog>> _fetchLogsFromStorage({
    DateTime? since, 
    int? limit,
  }) async {
    if (StorageService.isUsingLocalStorage) {
      return await StorageService.logsRepo.fetchLogs(since: since, limit: limit);
    } else {
      return await StorageService.logsRepo.fetchLogs(since: since, limit: limit);
    }
  }

  /// Cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'logs_cache_size': _logsCache.length,
      'life_areas_cache_size': _lifeAreasCache.length,
      'stats_cache_size': _statsCache.length,
      'pending_requests': _pendingLogsRequests.length + _pendingLifeAreasRequests.length,
    };
  }
}

/// Internal cache entry with TTL
class _CacheEntry<T> {
  final T data;
  final DateTime expires;

  _CacheEntry(this.data, Duration ttl) : expires = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expires);
}