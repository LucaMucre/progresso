import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as frp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../widgets/modern_snackbar.dart';
import '../utils/logging_service.dart';

class ErrorService {
  /// Show error message using modern UI components
  static void showError(BuildContext context, dynamic error, {String? title, StackTrace? stackTrace}) {
    final message = getErrorMessage(error);
    logError(error, stackTrace, 'UI Error');
    
    ModernSnackBar.showError(
      context: context,
      message: message,
      title: title,
    );
  }

  /// Show success message using modern UI components
  static void showSuccess(BuildContext context, String message, {String? title}) {
    ModernSnackBar.showSuccess(
      context: context,
      message: message,
      title: title,
    );
  }

  /// Show warning message using modern UI components
  static void showWarning(BuildContext context, String message, {String? title}) {
    ModernSnackBar.showWarning(
      context: context,
      message: message,
      title: title,
    );
  }

  /// Show info message using modern UI components
  static void showInfo(BuildContext context, String message, {String? title}) {
    ModernSnackBar.showInfo(
      context: context,
      message: message,
      title: title,
    );
  }

  /// Legacy method - deprecated, use showError instead
  @Deprecated('Use showError instead')
  static void showErrorSnackBar(BuildContext context, String message) {
    showError(context, message);
  }

  /// Legacy method - deprecated, use showSuccess instead  
  @Deprecated('Use showSuccess instead')
  static void showSuccessSnackBar(BuildContext context, String message) {
    showSuccess(context, message);
  }

  /// Show error dialog using modern UI components
  static Future<void> showErrorDialog(
    BuildContext context, 
    String title, 
    String message, {
    String? confirmText,
  }) {
    return ModernConfirmDialog.show(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText ?? 'OK',
      cancelText: '',
      icon: Icons.error_outline,
      confirmColor: Theme.of(context).colorScheme.error,
    ).then((_) {});
  }

  /// Show confirmation dialog using modern UI components
  static Future<bool> showConfirmDialog(
    BuildContext context,
    String title,
    String message, {
    String? confirmText,
    String? cancelText,
    Color? confirmColor,
    IconData? icon,
  }) async {
    final result = await ModernConfirmDialog.show(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText ?? 'Confirm',
      cancelText: cancelText ?? 'Cancel',
      confirmColor: confirmColor,
      icon: icon,
    );
    return result ?? false;
  }

  static String getErrorMessage(dynamic error) {
    if (error is String) return error;
    
    final errorString = error.toString().toLowerCase();
    
    // Supabase-spezifische Fehler
    if (errorString.contains('postgrest')) {
      if (errorString.contains('pgrst116')) {
        return 'Keine Daten gefunden.';
      }
      if (errorString.contains('pgrst301')) {
        return 'Keine Berechtigung für diese Aktion.';
      }
      if (errorString.contains('pgrst302')) {
        return 'Authentication required.';
      }
    return 'Database error. Please try again.';
    }
    
    // Auth-Fehler
    if (errorString.contains('auth') || errorString.contains('jwt')) {
      if (errorString.contains('invalid_credentials')) {
        return 'Invalid credentials.';
      }
      if (errorString.contains('email_not_confirmed')) {
        return 'Please confirm your email address.';
      }
      if (errorString.contains('weak_password')) {
        return 'Password is too weak.';
      }
      if (errorString.contains('email_already_in_use')) {
        return 'This email address is already in use.';
      }
    return 'Authentication error. Please sign in again.';
    }
    
    // Netzwerk-Fehler
    if (errorString.contains('network') || 
        errorString.contains('connection') || 
        errorString.contains('timeout') ||
        errorString.contains('socket')) {
    return 'Network error. Please check your internet connection.';
    }
    
    // Storage-Fehler
    if (errorString.contains('storage') || errorString.contains('bucket')) {
      if (errorString.contains('not_found')) {
        return 'Datei nicht gefunden.';
      }
      if (errorString.contains('insufficient_permissions')) {
        return 'Keine Berechtigung für diese Datei.';
      }
    return 'Error uploading file.';
    }
    
    // JSON-Parsing-Fehler
    if (errorString.contains('json') || errorString.contains('format')) {
    return 'Data format error. Please restart the app.';
    }
    
    // Unbekannte Fehler
    return 'An unexpected error occurred. Please try again.';
  }

  /// Enhanced error logging with context
  static void logError(Object error, [StackTrace? stackTrace, String? context]) {
    try {
      // Use the app's logging service for consistent formatting
      LoggingService.error(
        context ?? 'Unknown Error',
        error,
        stackTrace,
        'ErrorService',
      );
    } catch (e) {
      // Fallback to debug print if LoggingService fails
      if (kDebugMode) {
        debugPrint('Error logging failed: $e');
        debugPrint('Original error: $error');
        if (stackTrace != null) debugPrint(stackTrace.toString());
      }
    }
    _maybeCapture(error, stackTrace);
  }

  static Future<void> _maybeCapture(Object error, StackTrace? st) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final optIn = prefs.getBool('crash_opt_in') ?? true;
      if (!optIn) return;
      if (Sentry.isEnabled) {
        await Sentry.captureException(error, stackTrace: st);
      }
    } catch (_) {}
  }

  /// Enhanced global error handling
  static void handleGlobalError(BuildContext context, dynamic error, [StackTrace? stackTrace]) {
    logError(error, stackTrace, 'Global Error');
    showError(context, error, stackTrace: stackTrace);
  }

  /// Handle async operations with consistent error handling
  static Future<T?> handleAsync<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? loadingMessage,
    String? successMessage,
    String? errorTitle,
    bool showLoading = false,
    bool showSuccess = false,
  }) async {
    OverlayEntry? loadingOverlay;
    
    try {
      // Show loading overlay if requested
      if (showLoading && loadingMessage != null) {
        loadingOverlay = OverlayEntry(
          builder: (context) => ModernLoadingOverlay(
            message: loadingMessage,
            isVisible: true,
          ),
        );
        Overlay.of(context).insert(loadingOverlay);
      }

      final result = await operation();

      // Show success message if requested
      if (showSuccess && successMessage != null) {
        ErrorService.showSuccess(context, successMessage);
      }

      return result;
    } catch (error, stackTrace) {
      logError(error, stackTrace, 'Async Operation');
      showError(context, error, title: errorTitle, stackTrace: stackTrace);
      return null;
    } finally {
      // Remove loading overlay
      loadingOverlay?.remove();
    }
  }

  // Supabase-spezifische Fehlerbehandlung
  static String handleSupabaseError(dynamic error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case 'PGRST116':
          return 'Keine Daten gefunden.';
        case 'PGRST301':
          return 'Keine Berechtigung für diese Aktion.';
        case 'PGRST302':
          return 'Authentication required.';
        default:
    return 'Database error: ${error.message}';
      }
    }
    
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'Invalid credentials.';
        case 'Email not confirmed':
          return 'Please confirm your email address.';
        case 'Weak password':
          return 'Password is too weak.';
        case 'User already registered':
          return 'This email address is already in use.';
        default:
    return 'Authentication error: ${error.message}';
      }
    }
    
    return getErrorMessage(error);
  }
}

// Riverpod Provider für Error Handling
final errorServiceProvider = frp.Provider<ErrorService>((ref) {
  return ErrorService();
});

// Global Error Handler Provider
final globalErrorHandlerProvider = frp.Provider<Function(BuildContext, dynamic, StackTrace?)>((ref) {
  return ErrorService.handleGlobalError;
}); 