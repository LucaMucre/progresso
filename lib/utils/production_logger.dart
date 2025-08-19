import 'package:flutter/foundation.dart';

/// Production-safe logging utility
/// Only outputs logs in debug mode, silent in release builds
class ProductionLogger {
  /// Log info messages - only in debug mode
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }
  
  /// Log warning messages - only in debug mode  
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('[WARN] $message');
    }
  }
  
  /// Log error messages - only in debug mode
  static void error(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message${error != null ? ': $error' : ''}');
    }
  }
  
  /// Log debug messages - only in debug mode
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }
  
  /// Log performance metrics - only in debug mode
  static void performance(String operation, Duration duration) {
    if (kDebugMode) {
      debugPrint('[PERF] $operation took ${duration.inMilliseconds}ms');
    }
  }
  
  /// Log cache operations - only in debug mode
  static void cache(String operation, {int? itemCount}) {
    if (kDebugMode) {
      final countInfo = itemCount != null ? ' ($itemCount items)' : '';
      debugPrint('[CACHE] $operation$countInfo');
    }
  }
  
  /// Log data operations - only in debug mode
  static void data(String operation, {int? recordCount}) {
    if (kDebugMode) {
      final countInfo = recordCount != null ? ' ($recordCount records)' : '';
      debugPrint('[DATA] $operation$countInfo');
    }
  }
}