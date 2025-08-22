import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'anonymous_user_service.dart';
import 'local_character_service.dart';
import 'character_service.dart';
import '../repository/local_logs_repository.dart';
import '../repository/local_templates_repository.dart';
import '../utils/logging_service.dart';
import 'achievement_service.dart';

/// Service für die Synchronisation lokaler Daten mit der Cloud
/// WICHTIG: Dieser Service löscht NIEMALS lokale Daten!
/// Die App ist Offline-First - lokale Daten sind die primäre Quelle
/// Die Cloud dient nur als Backup und für Geräte-Synchronisation
class AnonymousMigrationService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final LocalLogsRepository _localLogsRepo = LocalLogsRepository();
  static final LocalTemplatesRepository _localTemplatesRepo = LocalTemplatesRepository();

  /// Synchronisiert lokale Daten mit der Cloud (löscht KEINE lokalen Daten!)
  static Future<void> syncLocalDataToCloud(String realUserId) async {
    try {
      LoggingService.info('Starte Synchronisation lokaler Daten zur Cloud für User: $realUserId');
      
      // Track success of each sync step
      bool characterSynced = false;
      bool logsSynced = false;
      bool templatesSynced = false;
      
      try {
        // 1. Character-Daten zur Cloud synchronisieren
        await _syncCharacterData(realUserId);
        characterSynced = true;
        
        // 2. Action Logs zur Cloud synchronisieren
        await _syncActionLogs(realUserId);
        logsSynced = true;
        
        // 3. Templates zur Cloud synchronisieren
        await _syncTemplates(realUserId);
        templatesSynced = true;
        
        // 4. Profile-Daten synchronisieren
        await _syncProfileData(realUserId);
        
        // 5. Achievements synchronisieren (falls vorhanden)
        await _syncAchievements(realUserId);
        
        // 6. User-Service aktualisieren (markiert als synchronisiert)
        await AnonymousUserService.markAsSynced(realUserId);
        
        // WICHTIG: KEINE LÖSCHUNG DER LOKALEN DATEN!
        // Lokale Daten bleiben als primäre Quelle bestehen
        // Cloud dient nur als Backup/Sync
        
        LoggingService.info('Synchronisation erfolgreich - Lokale Daten bleiben erhalten');
        
      } catch (e) {
        LoggingService.error('Synchronisation fehlgeschlagen - lokale Daten unverändert', e);
        // Bei Fehler passiert nichts mit lokalen Daten
        rethrow;
      }
      
    } catch (e, stackTrace) {
      LoggingService.error('Fehler bei der Daten-Synchronisation', e, stackTrace, 'AnonymousMigrationService');
      rethrow;
    }
  }
  
  /// Alte Migration-Methode - DEPRECATED, nur für Rückwärtskompatibilität
  static Future<void> migrateAnonymousDataToAccount(String realUserId) async {
    // Verwende die neue Sync-Methode statt Migration
    return syncLocalDataToCloud(realUserId);
  }

  /// Synchronisiert Character-Daten zur Cloud (behält lokale Daten)
  static Future<void> _syncCharacterData(String realUserId) async {
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

  /// Synchronisiert Action Logs zur Cloud (behält lokale Daten)
  static Future<void> _syncActionLogs(String realUserId) async {
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

  /// Synchronisiert Templates zur Cloud (behält lokale Daten)
  static Future<void> _syncTemplates(String realUserId) async {
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

  /// Synchronisiert Profile-Daten zur Cloud (behält lokale Daten)
  static Future<void> _syncProfileData(String realUserId) async {
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

  /// Synchronisiert Achievements zur Cloud (behält lokale Daten)
  static Future<void> _syncAchievements(String realUserId) async {
    try {
      // Lade lokale Achievement-Daten
      final anonymousUserId = await AnonymousUserService.getOrCreateAnonymousUserId();
      final localAchievements = await AchievementService.getUnlockedAchievementsForUser(anonymousUserId);
      
      if (localAchievements.isEmpty) {
        LoggingService.info('Keine lokalen Achievements zum Migrieren gefunden');
        return;
      }

      // Migriere Achievements zur Cloud (verwende upsert um Duplikate zu vermeiden)
      if (localAchievements.isNotEmpty) {
        final achievementRows = localAchievements.map((achievementId) => {
          'user_id': realUserId,
          'achievement_id': achievementId,
          'unlocked_at': DateTime.now().toIso8601String(),
        }).toList();
        
        // Verwende upsert mit onConflict für Primary Key (user_id, achievement_id)
        await _client
            .from('user_achievements')
            .upsert(achievementRows, onConflict: 'user_id,achievement_id');
      }

      // WICHTIG: Lokale Achievements NICHT löschen - sie bleiben als primäre Quelle
      // await AchievementService.clearAchievementsForUser(anonymousUserId);
      
      LoggingService.info('${localAchievements.length} Achievements erfolgreich synchronisiert');
    } catch (e) {
      LoggingService.error('Fehler bei der Achievement-Migration', e);
      // Nicht kritisch - Migration kann fortgesetzt werden
    }
  }

  /// DEPRECATED: Lokale Daten werden NICHT mehr gelöscht!
  /// Die App ist Offline-First - lokale Daten sind die primäre Quelle
  /// Cloud dient nur als Backup/Sync
  // static Future<void> _cleanupLocalData() async {
  //   // DIESE FUNKTION WIRD NICHT MEHR VERWENDET!
  //   // Lokale Daten bleiben IMMER erhalten
  // }

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
      preview.writeln('📊 Data Sync Preview:');
      preview.writeln('');
      preview.writeln('✓ ${summary['action_logs']} Activities');
      preview.writeln('✓ ${summary['templates']} Templates');
      if (summary['character_exists']! > 0) {
        preview.writeln('✓ Character (${summary['total_xp']} XP)');
      }
      preview.writeln('');
      preview.writeln('All this data will be synchronized with your account.');
      
      return preview.toString();
    } catch (e) {
      LoggingService.error('Error creating migration preview', e);
      return 'Error loading data preview';
    }
  }
  
  /// Verifiziert, dass die Daten erfolgreich in die Cloud übertragen wurden
  static Future<bool> _verifyCloudDataExists(String realUserId) async {
    try {
      LoggingService.info('Verifiziere Cloud-Daten für User: $realUserId');
      
      // Check if action logs exist in cloud
      final logsResult = await _client
          .from('action_logs')
          .select('id')
          .eq('user_id', realUserId)
          .limit(1);
      
      // Check if templates exist in cloud
      final templatesResult = await _client
          .from('action_templates')
          .select('id')
          .eq('user_id', realUserId)
          .limit(1);
      
      // Check if character exists in cloud
      final characterResult = await _client
          .from('characters')
          .select('id')
          .eq('user_id', realUserId)
          .limit(1);
      
      // Get local data summary to compare
      final localSummary = await getAnonymousDataSummary();
      final hasLocalLogs = localSummary['action_logs']! > 0;
      final hasLocalTemplates = localSummary['templates']! > 0;
      final hasLocalCharacter = localSummary['character_exists']! > 0;
      
      // Verify that if we had local data, it now exists in cloud
      bool verificationPassed = true;
      
      if (hasLocalLogs && (logsResult as List).isEmpty) {
        LoggingService.error('Verification failed: Local logs exist but not in cloud');
        verificationPassed = false;
      }
      
      if (hasLocalTemplates && (templatesResult as List).isEmpty) {
        LoggingService.error('Verification failed: Local templates exist but not in cloud');
        verificationPassed = false;
      }
      
      if (hasLocalCharacter && (characterResult as List).isEmpty) {
        LoggingService.error('Verification failed: Local character exists but not in cloud');
        verificationPassed = false;
      }
      
      LoggingService.info('Cloud data verification result: $verificationPassed');
      return verificationPassed;
      
    } catch (e) {
      LoggingService.error('Fehler bei der Cloud-Daten-Verifizierung', e);
      // On error, assume verification failed to be safe
      return false;
    }
  }
}