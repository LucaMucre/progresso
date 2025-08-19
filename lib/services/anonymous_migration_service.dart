import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'anonymous_user_service.dart';
import 'local_character_service.dart';
import 'character_service.dart';
import '../repository/local_logs_repository.dart';
import '../repository/local_templates_repository.dart';
import '../utils/logging_service.dart';

/// Service für die Migration anonymer Daten zu echten Accounts
class AnonymousMigrationService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final LocalLogsRepository _localLogsRepo = LocalLogsRepository();
  static final LocalTemplatesRepository _localTemplatesRepo = LocalTemplatesRepository();

  /// Führt eine vollständige Migration anonymer Daten zu einem echten Account durch
  static Future<void> migrateAnonymousDataToAccount(String realUserId) async {
    try {
      LoggingService.info('Starte Migration anonymer Daten zu Account: $realUserId');
      
      // 1. Character-Daten migrieren
      await _migrateCharacterData(realUserId);
      
      // 2. Action Logs migrieren
      await _migrateActionLogs(realUserId);
      
      // 3. Templates migrieren
      await _migrateTemplates(realUserId);
      
      // 4. Profile-Daten migrieren
      await _migrateProfileData(realUserId);
      
      // 5. Achievements migrieren (falls vorhanden)
      await _migrateAchievements(realUserId);
      
      // 6. Anonyme User-Service aktualisieren
      await AnonymousUserService.migrateToRealAccount(realUserId);
      
      // 7. Lokale Daten löschen (nach erfolgreicher Migration)
      await _cleanupLocalData();
      
      LoggingService.info('Migration erfolgreich abgeschlossen');
      
    } catch (e, stackTrace) {
      LoggingService.error('Fehler bei der Datenmigration', e, stackTrace, 'AnonymousMigrationService');
      rethrow;
    }
  }

  /// Migriert Character-Daten von lokal zu Cloud
  static Future<void> _migrateCharacterData(String realUserId) async {
    try {
      // Lade lokale Character-Daten
      final localCharacterData = await LocalCharacterService.exportLocalCharacterData();
      if (localCharacterData == null) {
        LoggingService.info('Keine lokalen Character-Daten zum Migrieren gefunden');
        return;
      }

      // Erstelle Character in der Cloud
      final characterData = {
        'user_id': realUserId,
        'name': localCharacterData['name'] ?? 'Hero',
        'level': localCharacterData['level'] ?? 1,
        'total_xp': localCharacterData['total_xp'] ?? 0,
        'stats': localCharacterData['stats'],
        'avatar_url': null, // Lokale Avatars werden nicht migriert
        'created_at': localCharacterData['created_at'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _client
          .from('characters')
          .insert(characterData);

      LoggingService.info('Character-Daten erfolgreich migriert');
    } catch (e) {
      LoggingService.error('Fehler bei der Character-Migration', e);
      rethrow;
    }
  }

  /// Migriert Action Logs von lokal zu Cloud
  static Future<void> _migrateActionLogs(String realUserId) async {
    try {
      // Lade alle lokalen Action Logs
      final localLogs = await _localLogsRepo.getAllLocalLogs();
      if (localLogs.isEmpty) {
        LoggingService.info('Keine lokalen Action Logs zum Migrieren gefunden');
        return;
      }

      // Bereite Logs für Cloud-Insert vor
      final cloudLogs = localLogs.map((log) {
        return {
          'user_id': realUserId,
          'template_id': log.templateId,
          'occurred_at': log.occurredAt.toIso8601String(),
          'duration_min': log.durationMin,
          'notes': log.notes,
          'earned_xp': log.earnedXp,
          'created_at': log.occurredAt.toIso8601String(), // Verwende occurredAt als created_at
        };
      }).toList();

      // Batch-Insert in die Cloud
      await _client
          .from('action_logs')
          .insert(cloudLogs);

      LoggingService.info('${cloudLogs.length} Action Logs erfolgreich migriert');
    } catch (e) {
      LoggingService.error('Fehler bei der Action Logs Migration', e);
      rethrow;
    }
  }

  /// Migriert Templates von lokal zu Cloud
  static Future<void> _migrateTemplates(String realUserId) async {
    try {
      // Lade alle lokalen Templates
      final localTemplates = await _localTemplatesRepo.getAllLocalTemplates();
      if (localTemplates.isEmpty) {
        LoggingService.info('Keine lokalen Templates zum Migrieren gefunden');
        return;
      }

      // Bereite Templates für Cloud-Insert vor
      final cloudTemplates = localTemplates.map((template) {
        return {
          'user_id': realUserId,
          'name': template.name,
          'category': template.category,
          'base_xp': template.baseXp,
          'attr_strength': template.attrStrength,
          'attr_endurance': template.attrEndurance,
          'attr_knowledge': template.attrKnowledge,
          'created_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      // Batch-Insert in die Cloud
      await _client
          .from('action_templates')
          .insert(cloudTemplates);

      LoggingService.info('${cloudTemplates.length} Templates erfolgreich migriert');
    } catch (e) {
      LoggingService.error('Fehler bei der Templates Migration', e);
      rethrow;
    }
  }

  /// Migriert Profile-Daten von lokal zu Cloud
  static Future<void> _migrateProfileData(String realUserId) async {
    try {
      // Lade anonyme Profile-Daten
      final profileData = await AnonymousUserService.getAnonymousUserData();
      if (profileData == null) {
        LoggingService.info('Keine lokalen Profil-Daten zum Migrieren gefunden');
        return;
      }

      // Erstelle/Update User-Profil in der Cloud
      final userData = {
        'id': realUserId,
        'name': profileData['name'] ?? 'User',
        'bio': profileData['bio'] ?? '',
        'avatar_url': null, // Lokale Avatars werden nicht migriert
      };

      await _client
          .from('users')
          .upsert(userData);

      LoggingService.info('Profil-Daten erfolgreich migriert');
    } catch (e) {
      LoggingService.error('Fehler bei der Profil-Migration', e);
      rethrow;
    }
  }

  /// Migriert Achievements von lokal zu Cloud
  static Future<void> _migrateAchievements(String realUserId) async {
    try {
      // TODO: Implementiere Achievement-Migration wenn Achievement-System erweitert wird
      LoggingService.info('Achievement-Migration übersprungen (noch nicht implementiert)');
    } catch (e) {
      LoggingService.error('Fehler bei der Achievement-Migration', e);
      // Nicht kritisch - Migration kann fortgesetzt werden
    }
  }

  /// Löscht alle lokalen Daten nach erfolgreicher Migration
  static Future<void> _cleanupLocalData() async {
    try {
      // Character-Daten löschen
      await LocalCharacterService.clearLocalCharacterData();
      
      // Action Logs löschen
      await _localLogsRepo.clearAllLocalLogs();
      
      // Templates löschen
      await _localTemplatesRepo.clearAllLocalTemplates();
      
      // Anonyme User-Daten löschen
      await AnonymousUserService.clearAnonymousData();
      
      LoggingService.info('Lokale Daten nach Migration erfolgreich gelöscht');
    } catch (e) {
      LoggingService.error('Fehler beim Löschen lokaler Daten', e);
      // Nicht kritisch - Daten können manuell gelöscht werden
    }
  }

  /// Prüft, ob anonyme Daten für Migration vorhanden sind
  static Future<Map<String, int>> getAnonymousDataSummary() async {
    try {
      final localLogs = await _localLogsRepo.getAllLocalLogs();
      final localTemplates = await _localTemplatesRepo.getAllLocalTemplates();
      final characterData = await LocalCharacterService.exportLocalCharacterData();
      
      return {
        'action_logs': localLogs.length,
        'templates': localTemplates.length,
        'character_exists': characterData != null ? 1 : 0,
        'total_xp': characterData?['total_xp'] ?? 0,
      };
    } catch (e) {
      LoggingService.error('Fehler beim Ermitteln der Daten-Zusammenfassung', e);
      return {};
    }
  }

  /// Validiert, ob Migration möglich ist
  static Future<bool> canMigrateData() async {
    try {
      final isAnonymous = await AnonymousUserService.isAnonymousUser();
      if (!isAnonymous) return false;

      final summary = await getAnonymousDataSummary();
      final hasData = summary['action_logs']! > 0 || 
                     summary['templates']! > 0 || 
                     summary['character_exists']! > 0;

      return hasData;
    } catch (e) {
      LoggingService.error('Fehler bei der Migrations-Validierung', e);
      return false;
    }
  }

  /// Zeigt eine Migrations-Vorschau
  static Future<String> getMigrationPreview() async {
    try {
      final summary = await getAnonymousDataSummary();
      
      final preview = StringBuffer();
      preview.writeln('📊 Daten-Migration Vorschau:');
      preview.writeln('');
      preview.writeln('✓ ${summary['action_logs']} Aktivitäten');
      preview.writeln('✓ ${summary['templates']} Templates');
      if (summary['character_exists']! > 0) {
        preview.writeln('✓ Character (${summary['total_xp']} XP)');
      }
      preview.writeln('');
      preview.writeln('Alle diese Daten werden in deinen neuen Account übertragen.');
      
      return preview.toString();
    } catch (e) {
      LoggingService.error('Fehler beim Erstellen der Migrations-Vorschau', e);
      return 'Fehler beim Laden der Daten-Vorschau';
    }
  }
}