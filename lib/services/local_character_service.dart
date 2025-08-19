import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'character_service.dart' as remote;
import 'anonymous_user_service.dart';
import '../utils/logging_service.dart';

/// Lokaler Character Service für anonyme Nutzer
/// Speichert Character-Daten in SharedPreferences
class LocalCharacterService {
  static const String _characterKey = 'local_character';
  static const String _characterStatsKey = 'local_character_stats';
  
  /// Erstellt oder lädt einen lokalen Character
  static Future<remote.Character> getOrCreateLocalCharacter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await AnonymousUserService.getCurrentUserId();
      
      // Versuche existierenden Character zu laden
      final characterJson = prefs.getString('${_characterKey}_$userId');
      if (characterJson != null) {
        final characterData = jsonDecode(characterJson);
        return remote.Character.fromJson(characterData);
      }
      
      // Erstelle neuen lokalen Character
      final now = DateTime.now();
      final newCharacter = {
        'id': 'local_${userId}_character',
        'user_id': userId,
        'name': 'Anonymous Hero',
        'level': 1,
        'total_xp': 0,
        'stats': remote.CharacterStats(
          strength: 1,
          intelligence: 1,
          wisdom: 1,
          charisma: 1,
          endurance: 1,
          agility: 1,
        ).toJson(),
        'avatar_url': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      
      // Speichere den neuen Character
      await prefs.setString('${_characterKey}_$userId', jsonEncode(newCharacter));
      
      LoggingService.info('Neuen lokalen Character erstellt für User: $userId');
      return remote.Character.fromJson(newCharacter);
      
    } catch (e) {
      LoggingService.error('Fehler beim Laden/Erstellen des lokalen Characters', e);
      rethrow;
    }
  }
  
  /// Aktualisiert lokale Character Stats
  static Future<void> updateLocalCharacterStats(remote.CharacterStats newStats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await AnonymousUserService.getCurrentUserId();
      
      // Lade existierenden Character
      final characterJson = prefs.getString('${_characterKey}_$userId');
      if (characterJson == null) {
        throw Exception('Lokaler Character nicht gefunden');
      }
      
      final characterData = jsonDecode(characterJson);
      characterData['stats'] = newStats.toJson();
      characterData['updated_at'] = DateTime.now().toIso8601String();
      
      await prefs.setString('${_characterKey}_$userId', jsonEncode(characterData));
      
      LoggingService.info('Lokale Character Stats aktualisiert');
    } catch (e) {
      LoggingService.error('Fehler beim Aktualisieren der lokalen Character Stats', e);
      rethrow;
    }
  }
  
  /// Fügt XP hinzu und aktualisiert Stats entsprechend
  static Future<void> addXpAndUpdateLocalStats(int xp, String statType) async {
    try {
      final character = await getOrCreateLocalCharacter();
      final newTotalXp = character.totalXp + xp;
      final newLevel = _calculateLevel(newTotalXp);
      
      // Berechne neue Stats basierend auf StatType
      final currentStats = character.stats;
      remote.CharacterStats newStats;
      
      switch (statType.toLowerCase()) {
        case 'strength':
          newStats = currentStats.copyWith(strength: currentStats.strength + 1);
          break;
        case 'intelligence':
          newStats = currentStats.copyWith(intelligence: currentStats.intelligence + 1);
          break;
        case 'wisdom':
          newStats = currentStats.copyWith(wisdom: currentStats.wisdom + 1);
          break;
        case 'charisma':
          newStats = currentStats.copyWith(charisma: currentStats.charisma + 1);
          break;
        case 'endurance':
          newStats = currentStats.copyWith(endurance: currentStats.endurance + 1);
          break;
        case 'agility':
          newStats = currentStats.copyWith(agility: currentStats.agility + 1);
          break;
        default:
          newStats = currentStats;
      }
      
      // Speichere aktualisierte Character-Daten
      final prefs = await SharedPreferences.getInstance();
      final userId = await AnonymousUserService.getCurrentUserId();
      
      final updatedCharacterData = {
        'id': character.id,
        'user_id': character.userId,
        'name': character.name,
        'level': newLevel,
        'total_xp': newTotalXp,
        'stats': newStats.toJson(),
        'avatar_url': character.avatarUrl,
        'created_at': character.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString('${_characterKey}_$userId', jsonEncode(updatedCharacterData));
      
      LoggingService.info('Lokale Character XP und Stats aktualisiert: +$xp XP, $statType +1');
    } catch (e) {
      LoggingService.error('Fehler beim Hinzufügen von XP zu lokalem Character', e);
      rethrow;
    }
  }
  
  /// Aktualisiert Character Name
  static Future<void> updateLocalCharacterName(String newName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await AnonymousUserService.getCurrentUserId();
      
      final characterJson = prefs.getString('${_characterKey}_$userId');
      if (characterJson == null) {
        throw Exception('Lokaler Character nicht gefunden');
      }
      
      final characterData = jsonDecode(characterJson);
      characterData['name'] = newName;
      characterData['updated_at'] = DateTime.now().toIso8601String();
      
      await prefs.setString('${_characterKey}_$userId', jsonEncode(characterData));
      
      LoggingService.info('Lokaler Character Name aktualisiert: $newName');
    } catch (e) {
      LoggingService.error('Fehler beim Aktualisieren des lokalen Character Names', e);
      rethrow;
    }
  }
  
  /// Berechnet Level basierend auf total XP
  static int _calculateLevel(int totalXp) {
    if (totalXp < 100) return 1;
    if (totalXp < 300) return 2;
    if (totalXp < 600) return 3;
    if (totalXp < 1000) return 4;
    if (totalXp < 1500) return 5;
    if (totalXp < 2100) return 6;
    if (totalXp < 2800) return 7;
    if (totalXp < 3600) return 8;
    if (totalXp < 4500) return 9;
    if (totalXp < 5500) return 10;
    
    // Für Level > 10: +1000 XP pro Level
    return 10 + ((totalXp - 5500) ~/ 1000);
  }
  
  /// Exportiert lokale Character-Daten für Migration
  static Future<Map<String, dynamic>?> exportLocalCharacterData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await AnonymousUserService.getCurrentUserId();
      
      final characterJson = prefs.getString('${_characterKey}_$userId');
      if (characterJson == null) return null;
      
      return jsonDecode(characterJson);
    } catch (e) {
      LoggingService.error('Fehler beim Exportieren lokaler Character-Daten', e);
      return null;
    }
  }
  
  /// Löscht lokale Character-Daten (nach erfolgreicher Migration)
  static Future<void> clearLocalCharacterData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await AnonymousUserService.getCurrentUserId();
      
      await prefs.remove('${_characterKey}_$userId');
      await prefs.remove('${_characterStatsKey}_$userId');
      
      LoggingService.info('Lokale Character-Daten gelöscht');
    } catch (e) {
      LoggingService.error('Fehler beim Löschen lokaler Character-Daten', e);
    }
  }
}