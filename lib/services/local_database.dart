import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/action_models.dart';
import '../utils/web_storage_stub.dart' 
    if (dart.library.html) '../utils/web_storage_web.dart' as web_storage;

class LocalDatabase {
  static Database? _database;
  static const String _dbName = 'progresso.db';
  static const int _dbVersion = 1;

  // Singleton instance
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite database not supported on web. Use web-specific methods instead.');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Action Templates Tabelle
    await db.execute('''
      CREATE TABLE action_templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        base_xp INTEGER NOT NULL DEFAULT 0,
        attr_strength INTEGER NOT NULL DEFAULT 0,
        attr_endurance INTEGER NOT NULL DEFAULT 0,
        attr_knowledge INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Action Logs Tabelle
    await db.execute('''
      CREATE TABLE action_logs (
        id TEXT PRIMARY KEY,
        template_id TEXT,
        occurred_at TEXT NOT NULL,
        duration_min INTEGER,
        notes TEXT,
        image_url TEXT,
        earned_xp INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (template_id) REFERENCES action_templates (id)
      )
    ''');

    // User Profile Tabelle
    await db.execute('''
      CREATE TABLE user_profile (
        id TEXT PRIMARY KEY,
        username TEXT,
        display_name TEXT,
        avatar_url TEXT,
        total_xp INTEGER NOT NULL DEFAULT 0,
        level INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // User Achievements Tabelle
    await db.execute('''
      CREATE TABLE user_achievements (
        id TEXT PRIMARY KEY,
        achievement_type TEXT NOT NULL,
        achieved_at TEXT NOT NULL,
        data TEXT
      )
    ''');

    // Indices für bessere Performance
    await db.execute('CREATE INDEX idx_logs_occurred_at ON action_logs (occurred_at)');
    await db.execute('CREATE INDEX idx_logs_template_id ON action_logs (template_id)');
    await db.execute('CREATE INDEX idx_achievements_type ON user_achievements (achievement_type)');

    if (kDebugMode) debugPrint('Local database created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future database schema upgrades would go here
    if (kDebugMode) debugPrint('Database upgraded from $oldVersion to $newVersion');
  }

  // Action Templates CRUD
  Future<String> insertTemplate(ActionTemplate template) async {
    if (kIsWeb) {
      return await _insertTemplateWeb(template);
    }
    
    final db = await database;
    final id = template.id;
    final now = DateTime.now().toIso8601String();
    
    await db.insert(
      'action_templates',
      {
        'id': id,
        'name': template.name,
        'category': template.category,
        'base_xp': template.baseXp,
        'attr_strength': template.attrStrength,
        'attr_endurance': template.attrEndurance,
        'attr_knowledge': template.attrKnowledge,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    return id;
  }

  Future<List<ActionTemplate>> getTemplates() async {
    if (kIsWeb) {
      return await _getTemplatesWeb();
    }
    
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'action_templates',
      orderBy: 'name ASC',
    );

    return maps.map((map) => ActionTemplate(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      baseXp: map['base_xp'],
      attrStrength: map['attr_strength'],
      attrEndurance: map['attr_endurance'],
      attrKnowledge: map['attr_knowledge'],
    )).toList();
  }

  Future<ActionTemplate?> getTemplate(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'action_templates',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    
    final map = maps.first;
    return ActionTemplate(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      baseXp: map['base_xp'],
      attrStrength: map['attr_strength'],
      attrEndurance: map['attr_endurance'],
      attrKnowledge: map['attr_knowledge'],
    );
  }

  // Action Logs CRUD
  Future<String> insertLog(ActionLog log) async {
    if (kIsWeb) {
      return await _insertLogWeb(log);
    }
    
    final db = await database;
    final id = log.id;
    final now = DateTime.now().toIso8601String();
    
    await db.insert(
      'action_logs',
      {
        'id': id,
        'template_id': log.templateId,
        'occurred_at': log.occurredAt.toIso8601String(),
        'duration_min': log.durationMin,
        'notes': log.notes,
        'image_url': log.imageUrl,
        'earned_xp': log.earnedXp,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    return id;
  }

  Future<List<ActionLog>> getLogs({DateTime? since, int? limit}) async {
    if (kIsWeb) {
      return await _getLogsWeb(since: since, limit: limit);
    }
    
    final db = await database;
    
    String sql = 'SELECT * FROM action_logs';
    List<dynamic> whereArgs = [];
    
    if (since != null) {
      sql += ' WHERE occurred_at >= ?';
      whereArgs.add(since.toIso8601String());
    }
    
    sql += ' ORDER BY occurred_at DESC';
    
    if (limit != null) {
      sql += ' LIMIT ?';
      whereArgs.add(limit);
    }
    
    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, whereArgs);

    return maps.map((map) => ActionLog(
      id: map['id'],
      templateId: map['template_id'],
      occurredAt: DateTime.parse(map['occurred_at']),
      durationMin: map['duration_min'],
      notes: map['notes'],
      imageUrl: map['image_url'],
      earnedXp: map['earned_xp'],
    )).toList();
  }

  Future<int> getTotalXp() async {
    if (kIsWeb) {
      final logs = await _getLogsWeb();
      return logs.fold<int>(0, (sum, log) => sum + log.earnedXp);
    }
    
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(earned_xp) as total FROM action_logs');
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getLogCount() async {
    if (kIsWeb) {
      final logs = await _getLogsWeb();
      return logs.length;
    }
    
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM action_logs');
    return result.first['count'] as int;
  }

  // Additional web implementations
  Future<int> _calculateStreakWeb() async {
    try {
      final logs = await _getLogsWeb();
      if (logs.isEmpty) return 0;

      // Get distinct dates, sorted descending
      final dates = logs
          .map((log) => DateTime(log.occurredAt.year, log.occurredAt.month, log.occurredAt.day))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

      if (dates.isEmpty) return 0;

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      int streak = 0;
      DateTime checkDate = todayDate;

      // Check if today has activity
      if (dates.isNotEmpty && dates.first.isAtSameMomentAs(todayDate)) {
        streak = 1;
        checkDate = todayDate.subtract(const Duration(days: 1));
      } else if (dates.isNotEmpty && dates.first.isAtSameMomentAs(todayDate.subtract(const Duration(days: 1)))) {
        // Yesterday was the last activity day
        streak = 1;
        checkDate = todayDate.subtract(const Duration(days: 2));
      } else {
        return 0; // No recent activity
      }

      // Count consecutive days
      for (int i = (streak == 1 && dates.first.isAtSameMomentAs(todayDate)) ? 1 : 0; i < dates.length; i++) {
        if (dates[i].isAtSameMomentAs(checkDate)) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      if (kDebugMode) debugPrint('Web: Error calculating streak: $e');
      return 0;
    }
  }

  Future<Map<DateTime, Map<String, int>>> _getDailyAreaTotalsWeb(DateTime month) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 1);
      
      final logs = await _getLogsWeb(since: startOfMonth);
      final monthLogs = logs.where((log) => log.occurredAt.isBefore(endOfMonth)).toList();
      
      final Map<DateTime, Map<String, int>> aggregated = {};
      
      for (final log in monthLogs) {
        final date = DateTime(log.occurredAt.year, log.occurredAt.month, log.occurredAt.day);
        
        // Extract category/area from notes
        String category = 'other';
        if (log.notes != null) {
          try {
            final notesObj = jsonDecode(log.notes!);
            if (notesObj is Map<String, dynamic>) {
              category = notesObj['category'] as String? ?? 
                        notesObj['area'] as String? ?? 
                        notesObj['life_area'] as String? ?? 'other';
            }
          } catch (_) {
            // Ignore JSON parsing errors
          }
        }
        
        aggregated[date] ??= {};
        aggregated[date]![category] = (aggregated[date]![category] ?? 0) + 1;
      }
      
      return aggregated;
    } catch (e) {
      if (kDebugMode) debugPrint('Web: Error getting daily area totals: $e');
      return {};
    }
  }

  // Streak calculation (days with logged activities)
  Future<int> calculateStreak() async {
    if (kIsWeb) {
      return await _calculateStreakWeb();
    }
    
    final db = await database;
    
    // Get distinct dates with activities, ordered by date desc
    final result = await db.rawQuery('''
      SELECT DISTINCT DATE(occurred_at) as date 
      FROM action_logs 
      ORDER BY date DESC
    ''');
    
    if (result.isEmpty) return 0;
    
    final dates = result.map((row) => DateTime.parse(row['date'] as String)).toList();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    int streak = 0;
    DateTime checkDate = todayDate;
    
    // Check if today has activity
    if (dates.isNotEmpty && dates.first.isAtSameMomentAs(todayDate)) {
      streak = 1;
      checkDate = todayDate.subtract(const Duration(days: 1));
    } else if (dates.isNotEmpty && dates.first.isAtSameMomentAs(todayDate.subtract(const Duration(days: 1)))) {
      // Yesterday was the last activity day
      streak = 1;
      checkDate = todayDate.subtract(const Duration(days: 2));
    } else {
      return 0; // No recent activity
    }
    
    // Count consecutive days
    for (int i = (streak == 1 && dates.first.isAtSameMomentAs(todayDate)) ? 1 : 0; i < dates.length; i++) {
      if (dates[i].isAtSameMomentAs(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }

  // Daily aggregation for statistics
  Future<Map<DateTime, Map<String, int>>> getDailyAreaTotals(DateTime month) async {
    if (kIsWeb) {
      return await _getDailyAreaTotalsWeb(month);
    }
    
    final db = await database;
    
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 1);
    
    final result = await db.rawQuery('''
      SELECT 
        DATE(occurred_at) as date,
        notes,
        COUNT(*) as count
      FROM action_logs 
      WHERE occurred_at >= ? AND occurred_at < ?
      GROUP BY DATE(occurred_at), notes
      ORDER BY date
    ''', [startOfMonth.toIso8601String(), endOfMonth.toIso8601String()]);
    
    final Map<DateTime, Map<String, int>> aggregated = {};
    
    for (final row in result) {
      final date = DateTime.parse(row['date'] as String);
      final notes = row['notes'] as String?;
      final count = row['count'] as int;
      
      // Extract category/area from notes
      String category = 'other';
      if (notes != null) {
        try {
          final notesObj = jsonDecode(notes);
          if (notesObj is Map<String, dynamic>) {
            category = notesObj['category'] as String? ?? 
                      notesObj['area'] as String? ?? 
                      notesObj['life_area'] as String? ?? 'other';
          }
        } catch (_) {
          // Ignore JSON parsing errors
        }
      }
      
      aggregated[date] ??= {};
      aggregated[date]![category] = (aggregated[date]![category] ?? 0) + count;
    }
    
    return aggregated;
  }

  // User Achievements CRUD
  Future<void> insertAchievement(String achievementType, {Map<String, dynamic>? data}) async {
    final db = await database;
    final id = '${achievementType}_${DateTime.now().millisecondsSinceEpoch}';
    
    await db.insert(
      'user_achievements',
      {
        'id': id,
        'achievement_type': achievementType,
        'achieved_at': DateTime.now().toIso8601String(),
        'data': data != null ? jsonEncode(data) : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAchievements() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_achievements',
      orderBy: 'achieved_at DESC',
    );

    return maps.map((map) => {
      'id': map['id'],
      'achievement_type': map['achievement_type'],
      'achieved_at': DateTime.parse(map['achieved_at']),
      'data': map['data'] != null ? jsonDecode(map['data']) : null,
    }).toList();
  }

  Future<bool> hasAchievement(String achievementType) async {
    final db = await database;
    final result = await db.query(
      'user_achievements',
      where: 'achievement_type = ?',
      whereArgs: [achievementType],
      limit: 1,
    );
    
    return result.isNotEmpty;
  }

  // Database maintenance
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('action_logs');
      await txn.delete('action_templates');
      await txn.delete('user_profile');
      await txn.delete('user_achievements');
    });
    
    if (kDebugMode) debugPrint('All local data cleared');
  }

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    if (kIsWeb) {
      // Web implementation using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final templatesKeys = keys.where((k) => k.contains('_templates')).length;
      final logsKeys = keys.where((k) => k.contains('_logs')).length;
      final achievementsKeys = keys.where((k) => k.contains('_achievements')).length;
      
      return {
        'templates': templatesKeys,
        'logs': logsKeys,
        'achievements': achievementsKeys,
        'total_xp': await getTotalXp(),
        'storage_type': 'SharedPreferences (Web)',
      };
    }
    
    final db = await database;
    
    final templatesCount = await db.rawQuery('SELECT COUNT(*) as count FROM action_templates');
    final logsCount = await db.rawQuery('SELECT COUNT(*) as count FROM action_logs');
    final achievementsCount = await db.rawQuery('SELECT COUNT(*) as count FROM user_achievements');
    
    return {
      'templates': templatesCount.first['count'],
      'logs': logsCount.first['count'],
      'achievements': achievementsCount.first['count'],
      'total_xp': await getTotalXp(),
      'db_path': await getDatabasesPath(),
      'storage_type': 'SQLite',
    };
  }

  // Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // Web implementations using SharedPreferences with user-specific keys
  String _getUserSpecificKey(String baseKey) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (kDebugMode) debugPrint('DEBUG LocalDB: User not authenticated - cannot access local storage');
      throw Exception('User not authenticated - cannot access local storage');
    }
    final key = '${baseKey}_$userId';
    if (kDebugMode) debugPrint('DEBUG LocalDB: Generated key "$key" for user $userId');
    return key;
  }

  String get _webTemplatesKey => _getUserSpecificKey('web_templates');
  String get _webLogsKey => _getUserSpecificKey('web_logs'); 
  String get _webAchievementsKey => _getUserSpecificKey('web_achievements');

  Future<String> _insertTemplateWeb(ActionTemplate template) async {
    final templates = await _getTemplatesWeb();
    final updatedTemplates = [...templates, template];
    
    final templateJson = updatedTemplates.map((t) => {
      'id': t.id,
      'name': t.name,
      'category': t.category,
      'base_xp': t.baseXp,
      'attr_strength': t.attrStrength,
      'attr_endurance': t.attrEndurance,
      'attr_knowledge': t.attrKnowledge,
    }).toList();

    // Use window.localStorage directly for persistence
    await web_storage.writeLocalStorage(_webTemplatesKey, jsonEncode(templateJson));
    return template.id;
  }

  Future<List<ActionTemplate>> _getTemplatesWeb() async {
    try {
      // Use window.localStorage directly for persistence
      final stored = await web_storage.readLocalStorage(_webTemplatesKey);
      if (stored == null) return [];

      final List<dynamic> templatesList = jsonDecode(stored);
      return templatesList.map((json) => ActionTemplate(
        id: json['id'],
        name: json['name'],
        category: json['category'],
        baseXp: json['base_xp'],
        attrStrength: json['attr_strength'],
        attrEndurance: json['attr_endurance'],
        attrKnowledge: json['attr_knowledge'],
      )).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Web: Error getting templates: $e');
      return [];
    }
  }

  Future<String> _insertLogWeb(ActionLog log) async {
    final logs = await _getLogsWeb();
    final updatedLogs = [...logs, log];
    
    final logsJson = updatedLogs.map((l) => {
      'id': l.id,
      'template_id': l.templateId,
      'occurred_at': l.occurredAt.toIso8601String(),
      'duration_min': l.durationMin,
      'notes': l.notes,
      'image_url': l.imageUrl,
      'earned_xp': l.earnedXp,
    }).toList();

    final key = _webLogsKey;
    if (kDebugMode) debugPrint('DEBUG LocalDB: Saving ${updatedLogs.length} logs to key "$key"');
    
    // Use window.localStorage directly for persistence
    await web_storage.writeLocalStorage(key, jsonEncode(logsJson));
    
    if (kDebugMode) debugPrint('DEBUG LocalDB: Successfully saved log ${log.id} to localStorage');
    return log.id;
  }

  Future<List<ActionLog>> _getLogsWeb({DateTime? since, int? limit}) async {
    try {
      final key = _webLogsKey;
      if (kDebugMode) debugPrint('DEBUG LocalDB: Loading logs from key "$key" from localStorage');
      
      // Use window.localStorage directly for persistence
      final stored = await web_storage.readLocalStorage(key);
      
      if (stored == null) {
        if (kDebugMode) debugPrint('DEBUG LocalDB: No stored data found for key "$key" in localStorage');
        return [];
      }

      final List<dynamic> logsList = jsonDecode(stored);
      var logs = logsList.map((json) => ActionLog(
        id: json['id'],
        templateId: json['template_id'],
        occurredAt: DateTime.parse(json['occurred_at']),
        durationMin: json['duration_min'],
        notes: json['notes'],
        imageUrl: json['image_url'],
        earnedXp: json['earned_xp'],
      )).toList();

      // Apply filters
      if (since != null) {
        logs = logs.where((log) => log.occurredAt.isAfter(since)).toList();
      }

      // Sort by date (newest first)
      logs.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

      if (limit != null && logs.length > limit) {
        logs = logs.take(limit).toList();
      }

      if (kDebugMode) debugPrint('DEBUG LocalDB: Loaded ${logs.length} logs from storage');
      return logs;
    } catch (e) {
      if (kDebugMode) debugPrint('Web: Error getting logs: $e');
      return [];
    }
  }

  // Delete log entry
  Future<void> deleteLog(String logId) async {
    if (kIsWeb) {
      await _deleteLogWeb(logId);
    } else {
      await _deleteLogNative(logId);
    }
  }

  Future<void> _deleteLogNative(String logId) async {
    final db = await database;
    await db.delete(
      'logs',
      where: 'id = ?',
      whereArgs: [logId],
    );
    if (kDebugMode) debugPrint('Deleted log from native SQLite: $logId');
  }

  Future<void> _deleteLogWeb(String logId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final storageKey = userId != null ? 'logs_$userId' : 'logs_anonymous';
      
      final existingData = await web_storage.readLocalStorage(storageKey) ?? '[]';
      final List<dynamic> logs = jsonDecode(existingData);
      
      // Remove the log with matching ID
      logs.removeWhere((log) => log['id'] == logId);
      
      // Save back to storage
      await web_storage.writeLocalStorage(storageKey, jsonEncode(logs));
      
      if (kDebugMode) debugPrint('Deleted log from web storage: $logId');
    } catch (e) {
      if (kDebugMode) debugPrint('Web: Error deleting log: $e');
      rethrow;
    }
  }

}