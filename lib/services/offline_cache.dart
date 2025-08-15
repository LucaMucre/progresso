import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'db_service.dart';
import '../models/action_models.dart' as models;

class OfflineCache {
  static const String _templatesKey = 'cached_templates';
  static const String _logsKey = 'cached_logs';
  static const String _profileKey = 'cached_profile';
  static const String _lastSyncKey = 'last_sync';
  static const String _cacheVersionKey = 'cache_version';
  
  // Cache-Version für Invalidation
  static const int _currentVersion = 1;
  
  // TTL in Stunden
  static const int _cacheTtlHours = 1;

  // Hilfsfunktion: Namespacing pro Benutzer
  static Future<String> _nsKey(String baseKey) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    // Zusätzlich letzten eingeloggten User mitschreiben (für Debug/Invalidation)
    if (uid != null) {
      await prefs.setString('last_uid', uid);
    }
    return uid == null ? baseKey : '${baseKey}_$uid';
  }

  // Templates cachen
  static Future<void> cacheTemplates(List<ActionTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _nsKey(_templatesKey);
    final templatesJson = templates.map((t) => {
      'id': t.id,
      'name': t.name,
      'category': t.category,
      'base_xp': t.baseXp,
      'attr_strength': t.attrStrength,
      'attr_endurance': t.attrEndurance,
      'attr_knowledge': t.attrKnowledge,
    }).toList();
    
    await prefs.setString(key, jsonEncode(templatesJson));
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_cacheVersionKey, _currentVersion);
  }

  // Templates aus Cache laden
  static Future<List<ActionTemplate>> getCachedTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _nsKey(_templatesKey);
    
    // Prüfe Cache-Version
    final version = prefs.getInt(_cacheVersionKey);
    if (version != _currentVersion) {
      await clearCache();
      return [];
    }
    
    // Prüfe TTL
    if (await isCacheStale()) {
      await clearCache();
      return [];
    }
    
    final templatesJson = prefs.getString(key);
    if (templatesJson == null) return [];
    
    try {
      final List<dynamic> templatesList = jsonDecode(templatesJson);
      return templatesList.map((json) => models.ActionTemplate.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading cached templates: $e');
      await clearCache();
      return [];
    }
  }

  // Logs cachen
  static Future<void> cacheLogs(List<ActionLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _nsKey(_logsKey);
    final logsJson = logs.map((l) => {
      'id': l.id,
      'occurred_at': l.occurredAt.toIso8601String(),
      'duration_min': l.durationMin,
      'notes': l.notes,
      'earned_xp': l.earnedXp,
      'template_id': l.templateId,
    }).toList();
    
    await prefs.setString(key, jsonEncode(logsJson));
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_cacheVersionKey, _currentVersion);
  }

  // Logs aus Cache laden
  static Future<List<ActionLog>> getCachedLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _nsKey(_logsKey);
    
    // Prüfe Cache-Version
    final version = prefs.getInt(_cacheVersionKey);
    if (version != _currentVersion) {
      await clearCache();
      return [];
    }
    
    // Prüfe TTL
    if (await isCacheStale()) {
      await clearCache();
      return [];
    }
    
    final logsJson = prefs.getString(key);
    if (logsJson == null) return [];
    
    try {
      final List<dynamic> logsList = jsonDecode(logsJson);
      return logsList.map((json) => models.ActionLog.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading cached logs: $e');
      await clearCache();
      return [];
    }
  }

  // Profile cachen
  static Future<void> cacheProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _nsKey(_profileKey);
    await prefs.setString(key, jsonEncode(profile));
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_cacheVersionKey, _currentVersion);
  }

  // Profile aus Cache laden
  static Future<Map<String, dynamic>?> getCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _nsKey(_profileKey);
    
    // Prüfe Cache-Version
    final version = prefs.getInt(_cacheVersionKey);
    if (version != _currentVersion) {
      await clearCache();
      return null;
    }
    
    // Prüfe TTL
    if (await isCacheStale()) {
      await clearCache();
      return null;
    }
    
    final profileJson = prefs.getString(key);
    if (profileJson == null) return null;
    
    try {
      return jsonDecode(profileJson) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading cached profile: $e');
      await clearCache();
      return null;
    }
  }

  // Prüfen ob Cache veraltet ist (älter als TTL)
  static Future<bool> isCacheStale() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey);
    
    if (lastSync == null) return true;
    
    final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final now = DateTime.now();
    final difference = now.difference(lastSyncTime);
    
    return difference.inHours > _cacheTtlHours;
  }

  // Cache löschen
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final tKey = uid == null ? _templatesKey : '${_templatesKey}_$uid';
    final lKey = uid == null ? _logsKey : '${_logsKey}_$uid';
    final pKey = uid == null ? _profileKey : '${_profileKey}_$uid';
    await prefs.remove(tKey);
    await prefs.remove(lKey);
    await prefs.remove(pKey);
    await prefs.remove(_lastSyncKey);
    await prefs.remove(_cacheVersionKey);
    // Do NOT clear achievements here; they are user-scoped and persistent
  }

  // Cache-Größe prüfen
  static Future<int> getCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final tKey = uid == null ? _templatesKey : '${_templatesKey}_$uid';
    final lKey = uid == null ? _logsKey : '${_logsKey}_$uid';
    final pKey = uid == null ? _profileKey : '${_profileKey}_$uid';
    int size = 0;
    
    final templates = prefs.getString(tKey);
    if (templates != null) size += templates.length;
    
    final logs = prefs.getString(lKey);
    if (logs != null) size += logs.length;
    
    final profile = prefs.getString(pKey);
    if (profile != null) size += profile.length;
    
    return size;
  }

  // Cache-Status prüfen
  static Future<Map<String, dynamic>> getCacheStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey);
    final version = prefs.getInt(_cacheVersionKey);
    final isStale = await isCacheStale();
    final size = await getCacheSize();
    
    return {
      'hasCache': lastSync != null,
      'lastSync': lastSync != null ? DateTime.fromMillisecondsSinceEpoch(lastSync) : null,
      'isStale': isStale,
      'version': version,
      'size': size,
      'ttlHours': _cacheTtlHours,
    };
  }

  // Cache manuell invalidieren
  static Future<void> invalidateCache() async {
    await clearCache();
    if (kDebugMode) debugPrint('Cache invalidated');
  }
} 