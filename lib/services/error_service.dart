import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      return 'Datenbankfehler. Bitte versuche es erneut.';
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
      return 'Authentifizierungsfehler. Bitte melde dich erneut an.';
    }
    
    // Netzwerk-Fehler
    if (errorString.contains('network') || 
        errorString.contains('connection') || 
        errorString.contains('timeout') ||
        errorString.contains('socket')) {
      return 'Netzwerkfehler. Bitte überprüfe deine Internetverbindung.';
    }
    
    // Storage-Fehler
    if (errorString.contains('storage') || errorString.contains('bucket')) {
      if (errorString.contains('not_found')) {
        return 'Datei nicht gefunden.';
      }
      if (errorString.contains('insufficient_permissions')) {
        return 'Keine Berechtigung für diese Datei.';
      }
      return 'Fehler beim Hochladen der Datei.';
    }
    
    // JSON-Parsing-Fehler
    if (errorString.contains('json') || errorString.contains('format')) {
      return 'Datenformatfehler. Bitte starte die App neu.';
    }
    
    // Unbekannte Fehler
    return 'Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es erneut.';
  }

  // Globale Fehlerbehandlung
  static void handleGlobalError(BuildContext context, dynamic error, StackTrace? stackTrace) {
    final message = getErrorMessage(error);
    
    // Log für Debugging
    print('Global Error: $error');
    if (stackTrace != null) {
      print('StackTrace: $stackTrace');
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
          return 'Datenbankfehler: ${error.message}';
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
          return 'Authentifizierungsfehler: ${error.message}';
      }
    }
    
    return getErrorMessage(error);
  }
}

// Riverpod Provider für Error Handling
final errorServiceProvider = Provider<ErrorService>((ref) {
  return ErrorService();
});

// Global Error Handler Provider
final globalErrorHandlerProvider = Provider<Function(BuildContext, dynamic, StackTrace?)>((ref) {
  return ErrorService.handleGlobalError;
}); 