import 'package:flutter/foundation.dart';

/// Centralized logging service for the application
class LoggingService {
  static const String _tag = 'Progresso';

  /// Log info messages (debug mode only)
  static void info(String message, [String? component]) {
    if (kDebugMode) {
      final prefix = component != null ? '[$_tag:$component]' : '[$_tag]';
      debugPrint('$prefix INFO: $message');
    }
  }

  /// Log warning messages (debug mode only)
  static void warning(String message, [String? component]) {
    if (kDebugMode) {
      final prefix = component != null ? '[$_tag:$component]' : '[$_tag]';
      debugPrint('$prefix WARNING: $message');
    }
  }

  /// Log error messages with optional error object and stack trace
  static void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {
    if (kDebugMode) {
      final prefix = component != null ? '[$_tag:$component]' : '[$_tag]';
      debugPrint('$prefix ERROR: $message');
      if (error != null) {
        debugPrint('$prefix ERROR Details: $error');
      }
      if (stackTrace != null) {
        debugPrint('$prefix ERROR Stack Trace: $stackTrace');
      }
    }
    // In production, you could send errors to crash reporting service like Crashlytics
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
  }

  /// Log network requests and responses
  static void network(String message, [Map<String, dynamic>? data]) {
    if (kDebugMode) {
      debugPrint('[$_tag:Network] $message');
      if (data != null) {
        debugPrint('[$_tag:Network] Data: $data');
      }
    }
  }

  /// Log database operations
  static void database(String message, [Map<String, dynamic>? data]) {
    if (kDebugMode) {
      debugPrint('[$_tag:Database] $message');
      if (data != null) {
        debugPrint('[$_tag:Database] Data: $data');
      }
    }
  }

  /// Log authentication operations
  static void auth(String message, [Map<String, dynamic>? data]) {
    if (kDebugMode) {
      debugPrint('[$_tag:Auth] $message');
      if (data != null) {
        debugPrint('[$_tag:Auth] Data: $data');
      }
    }
  }

  /// Log UI state changes
  static void ui(String message, [String? component]) {
    if (kDebugMode) {
      final prefix = component != null ? '[$_tag:UI:$component]' : '[$_tag:UI]';
      debugPrint('$prefix $message');
    }
  }
}