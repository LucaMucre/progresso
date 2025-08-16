import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as frp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ErrorService {
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        return 'Authentifizierung erforderlich.';
      }
    return 'Database error. Please try again.';
    }
    
    // Auth-Fehler
    if (errorString.contains('auth') || errorString.contains('jwt')) {
      if (errorString.contains('invalid_credentials')) {
        return 'Ungültige Anmeldedaten.';
      }
      if (errorString.contains('email_not_confirmed')) {
        return 'Bitte bestätige deine E-Mail-Adresse.';
      }
      if (errorString.contains('weak_password')) {
        return 'Das Passwort ist zu schwach.';
      }
      if (errorString.contains('email_already_in_use')) {
        return 'Diese E-Mail-Adresse wird bereits verwendet.';
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

  static void logError(Object error, [StackTrace? st]) {
    if (kDebugMode) {
      // In Debug: direkte Ausgabe zur Konsole
      if (kDebugMode) debugPrint('Error: $error');
      if (st != null && kDebugMode) debugPrint(st.toString());
    }
    _maybeCapture(error, st);
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

  // Globale Fehlerbehandlung
  static void handleGlobalError(BuildContext context, dynamic error, StackTrace? stackTrace) {
    final message = getErrorMessage(error);
    
    // Log für Debugging
    if (kDebugMode) debugPrint('Global Error: $error');
    if (stackTrace != null) {
      if (kDebugMode) debugPrint('StackTrace: $stackTrace');
    }
    
    // User-freundliche Nachricht anzeigen
    showErrorSnackBar(context, message);
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
          return 'Authentifizierung erforderlich.';
        default:
    return 'Database error: ${error.message}';
      }
    }
    
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'Ungültige Anmeldedaten.';
        case 'Email not confirmed':
          return 'Bitte bestätige deine E-Mail-Adresse.';
        case 'Weak password':
          return 'Das Passwort ist zu schwach.';
        case 'User already registered':
          return 'Diese E-Mail-Adresse wird bereits verwendet.';
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