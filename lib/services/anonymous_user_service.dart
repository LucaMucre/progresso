import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../utils/logging_service.dart';

/// Service für anonyme User-Verwaltung
/// Erstellt persistente anonyme User-IDs und verwaltet den Übergang zu echten Accounts
class AnonymousUserService {
  static const String _anonymousUserIdKey = 'anonymous_user_id';
  static const String _isAnonymousKey = 'is_anonymous_user';
  static const String _anonymousUserDataKey = 'anonymous_user_data';
  
  static String? _cachedAnonymousId;
  static bool? _cachedIsAnonymous;
  
  /// Generiert oder lädt eine persistente anonyme User-ID
  static Future<String> getOrCreateAnonymousUserId() async {
    if (_cachedAnonymousId != null) return _cachedAnonymousId!;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Prüfe zuerst, ob wir bereits einen echten User haben
      final realUser = Supabase.instance.client.auth.currentUser;
      if (realUser != null) {
        _cachedAnonymousId = realUser.id;
        _cachedIsAnonymous = false;
        return realUser.id;
      }
      
      // Lade existierende anonyme ID oder erstelle neue
      String? anonymousId = prefs.getString(_anonymousUserIdKey);
      if (anonymousId == null) {
        anonymousId = const Uuid().v4();
        await prefs.setString(_anonymousUserIdKey, anonymousId);
        await prefs.setBool(_isAnonymousKey, true);
        LoggingService.info('Neue anonyme User-ID erstellt: $anonymousId');
      }
      
      _cachedAnonymousId = anonymousId;
      _cachedIsAnonymous = true;
      return anonymousId;
    } catch (e) {
      LoggingService.error('Fehler beim Laden/Erstellen der anonymen User-ID', e);
      // Fallback: temporäre ID für diese Session
      final tempId = const Uuid().v4();
      _cachedAnonymousId = tempId;
      _cachedIsAnonymous = true;
      return tempId;
    }
  }
  
  /// Gibt die aktuelle User-ID zurück (anonym oder echt)
  static Future<String> getCurrentUserId() async {
    final realUser = Supabase.instance.client.auth.currentUser;
    if (realUser != null) {
      _cachedIsAnonymous = false;
      return realUser.id;
    }
    return await getOrCreateAnonymousUserId();
  }
  
  /// Prüft, ob der aktuelle User anonym ist
  static Future<bool> isAnonymousUser() async {
    if (_cachedIsAnonymous != null) return _cachedIsAnonymous!;
    
    final realUser = Supabase.instance.client.auth.currentUser;
    if (realUser != null) {
      _cachedIsAnonymous = false;
      return false;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedIsAnonymous = prefs.getBool(_isAnonymousKey) ?? true;
      return _cachedIsAnonymous!;
    } catch (e) {
      LoggingService.error('Fehler beim Prüfen des anonymen Status', e);
      return true; // Sicherheits-Fallback
    }
  }
  
  /// Speichert anonyme User-Daten (Name, etc.)
  static Future<void> saveAnonymousUserData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = data.toString(); // Vereinfacht für jetzt
      await prefs.setString(_anonymousUserDataKey, jsonString);
      LoggingService.info('Anonyme User-Daten gespeichert');
    } catch (e) {
      LoggingService.error('Fehler beim Speichern anonymer User-Daten', e);
    }
  }
  
  /// Lädt anonyme User-Daten
  static Future<Map<String, dynamic>?> getAnonymousUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString(_anonymousUserDataKey);
      if (dataString != null) {
        // TODO: Proper JSON parsing wenn nötig
        return {'name': 'Anonymous Hero'};
      }
      return null;
    } catch (e) {
      LoggingService.error('Fehler beim Laden anonymer User-Daten', e);
      return null;
    }
  }
  
  /// Migriert anonyme Daten zu einem echten Account
  static Future<void> migrateToRealAccount(String realUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldAnonymousId = _cachedAnonymousId ?? await getOrCreateAnonymousUserId();
      
      LoggingService.info('Starte Migration von anonymer ID $oldAnonymousId zu echter ID $realUserId');
      
      // Hier würde die eigentliche Datenmigration stattfinden
      // Das wird in einem separaten Service implementiert
      
      // Anonyme Flags löschen
      await prefs.remove(_anonymousUserIdKey);
      await prefs.remove(_isAnonymousKey);
      await prefs.remove(_anonymousUserDataKey);
      
      // Cache aktualisieren
      _cachedAnonymousId = realUserId;
      _cachedIsAnonymous = false;
      
      LoggingService.info('Migration abgeschlossen');
    } catch (e) {
      LoggingService.error('Fehler bei der Migration zu echtem Account', e);
      rethrow;
    }
  }
  
  /// Löscht alle anonymen Daten (für Tests/Reset)
  static Future<void> clearAnonymousData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_anonymousUserIdKey);
      await prefs.remove(_isAnonymousKey);
      await prefs.remove(_anonymousUserDataKey);
      
      _cachedAnonymousId = null;
      _cachedIsAnonymous = null;
      
      LoggingService.info('Anonyme Daten gelöscht');
    } catch (e) {
      LoggingService.error('Fehler beim Löschen anonymer Daten', e);
    }
  }
  
  /// Invalidiert den Cache (z.B. nach Login/Logout)
  static void invalidateCache() {
    _cachedAnonymousId = null;
    _cachedIsAnonymous = null;
  }
}