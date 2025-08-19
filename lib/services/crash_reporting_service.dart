import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/production_logger.dart';

/// Service for handling crash reporting and analytics
class CrashReportingService {
  static bool _isInitialized = false;
  static bool _userOptedIn = true;
  
  /// Initialize crash reporting if user opted in
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _userOptedIn = prefs.getBool('crash_opt_in') ?? true;
      
      if (!_userOptedIn) {
        ProductionLogger.info('Crash reporting disabled by user preference');
        return;
      }
      
      if (kReleaseMode) {
        // Sentry is already initialized in main.dart for release builds
        _isInitialized = true;
        ProductionLogger.info('Crash reporting initialized for release build');
      } else {
        ProductionLogger.info('Crash reporting disabled in debug mode');
      }
    } catch (e) {
      ProductionLogger.error('Failed to initialize crash reporting: $e');
    }
  }
  
  /// Report a custom exception
  static Future<void> reportException(
    dynamic exception, 
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? extra,
  }) async {
    if (!_userOptedIn || !_isInitialized) return;
    
    try {
      await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (context != null) {
            scope.setTag('context', context);
          }
          if (extra != null) {
            for (final entry in extra.entries) {
              scope.setExtra(entry.key, entry.value);
            }
          }
        },
      );
      ProductionLogger.info('Exception reported to crash service');
    } catch (e) {
      ProductionLogger.error('Failed to report exception: $e');
    }
  }
  
  /// Add breadcrumb for tracking user actions
  static void addBreadcrumb(
    String message, {
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    if (!_userOptedIn || !_isInitialized) return;
    
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: message,
          category: category,
          level: level,
          data: data,
        ),
      );
    } catch (e) {
      ProductionLogger.error('Failed to add breadcrumb: $e');
    }
  }
  
  /// Set user information for crash reports
  static Future<void> setUser({
    String? id,
    String? email,
    String? username,
    Map<String, String>? extras,
  }) async {
    if (!_userOptedIn || !_isInitialized) return;
    
    try {
      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(
          id: id,
          email: email,
          username: username,
          extras: extras,
        ));
      });
      ProductionLogger.info('User info set for crash reporting');
    } catch (e) {
      ProductionLogger.error('Failed to set user info: $e');
    }
  }
  
  /// Clear user information
  static Future<void> clearUser() async {
    if (!_userOptedIn || !_isInitialized) return;
    
    try {
      await Sentry.configureScope((scope) {
        scope.setUser(null);
      });
      ProductionLogger.info('User info cleared from crash reporting');
    } catch (e) {
      ProductionLogger.error('Failed to clear user info: $e');
    }
  }
  
  /// Update user opt-in preference
  static Future<void> setUserOptIn(bool optIn) async {
    _userOptedIn = optIn;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('crash_opt_in', optIn);
      
      if (optIn) {
        ProductionLogger.info('User opted in to crash reporting');
        // Re-initialize if needed
        if (!_isInitialized) {
          await initialize();
        }
      } else {
        ProductionLogger.info('User opted out of crash reporting');
        await clearUser();
      }
    } catch (e) {
      ProductionLogger.error('Failed to update crash reporting preference: $e');
    }
  }
  
  /// Check if user has opted in
  static bool get isUserOptedIn => _userOptedIn;
  
  /// Track performance
  static ISentrySpan? startTransaction(
    String name,
    String operation, {
    String? description,
  }) {
    if (!_userOptedIn || !_isInitialized) return null;
    
    try {
      return Sentry.startTransaction(
        name,
        operation,
        description: description,
      );
    } catch (e) {
      ProductionLogger.error('Failed to start transaction: $e');
      return null;
    }
  }
  
  /// Track feature usage
  static void trackFeatureUsage(String featureName, {Map<String, dynamic>? properties}) {
    addBreadcrumb(
      'Feature used: $featureName',
      category: 'user.action',
      level: SentryLevel.info,
      data: properties,
    );
  }
  
  /// Track app lifecycle events
  static void trackAppLifecycle(String event) {
    addBreadcrumb(
      'App lifecycle: $event',
      category: 'app.lifecycle',
      level: SentryLevel.info,
    );
  }
  
  /// Track database operations
  static void trackDatabaseOperation(String operation, {int? recordCount}) {
    addBreadcrumb(
      'Database: $operation${recordCount != null ? ' ($recordCount records)' : ''}',
      category: 'database',
      level: SentryLevel.debug,
    );
  }
  
  /// Track authentication events
  static void trackAuthEvent(String event) {
    addBreadcrumb(
      'Auth: $event',
      category: 'auth',
      level: SentryLevel.info,
    );
  }
}