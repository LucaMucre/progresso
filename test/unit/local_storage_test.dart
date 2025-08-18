import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:progresso/services/local_database.dart';
import 'package:progresso/models/action_models.dart';

void main() {
  group('Local Storage Tests', () {
    late LocalDatabase db;

    setUpAll(() {
      // Initialize sqflite_ffi for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = LocalDatabase();
      // Use in-memory database for testing
      await db.database;
    });

    tearDown(() async {
      await db.clearAllData();
      await db.close();
    });

    test('Database initialization', () async {
      final database = await db.database;
      expect(database, isNotNull);
      expect(database.isOpen, isTrue);
    });

    test('Insert and retrieve template', () async {
      const template = ActionTemplate(
        id: 'test_template',
        name: 'Test Template',
        category: 'test',
        baseXp: 10,
        attrStrength: 1,
        attrEndurance: 2,
        attrKnowledge: 3,
      );

      await db.insertTemplate(template);

      final retrieved = await db.getTemplate('test_template');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Test Template'));
      expect(retrieved.category, equals('test'));
      expect(retrieved.baseXp, equals(10));
    });

    test('Insert and retrieve log', () async {
      final log = ActionLog(
        id: 'test_log',
        templateId: 'test_template',
        occurredAt: DateTime.now(),
        durationMin: 30,
        notes: 'Test notes',
        imageUrl: null,
        earnedXp: 5,
      );

      await db.insertLog(log);

      final logs = await db.getLogs();
      expect(logs.length, equals(1));
      expect(logs.first.id, equals('test_log'));
      expect(logs.first.durationMin, equals(30));
      expect(logs.first.earnedXp, equals(5));
    });

    test('Calculate total XP', () async {
      final log1 = ActionLog(
        id: 'log1',
        templateId: null,
        occurredAt: DateTime.now(),
        durationMin: 30,
        notes: null,
        imageUrl: null,
        earnedXp: 10,
      );

      final log2 = ActionLog(
        id: 'log2',
        templateId: null,
        occurredAt: DateTime.now(),
        durationMin: 45,
        notes: null,
        imageUrl: null,
        earnedXp: 15,
      );

      await db.insertLog(log1);
      await db.insertLog(log2);

      final totalXp = await db.getTotalXp();
      expect(totalXp, equals(25));
    });

    test('Calculate streak with consecutive days', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final dayBefore = today.subtract(const Duration(days: 2));

      await db.insertLog(ActionLog(
        id: 'log_today',
        templateId: null,
        occurredAt: today,
        durationMin: 30,
        notes: null,
        imageUrl: null,
        earnedXp: 5,
      ));

      await db.insertLog(ActionLog(
        id: 'log_yesterday',
        templateId: null,
        occurredAt: yesterday,
        durationMin: 30,
        notes: null,
        imageUrl: null,
        earnedXp: 5,
      ));

      await db.insertLog(ActionLog(
        id: 'log_day_before',
        templateId: null,
        occurredAt: dayBefore,
        durationMin: 30,
        notes: null,
        imageUrl: null,
        earnedXp: 5,
      ));

      final streak = await db.calculateStreak();
      expect(streak, greaterThanOrEqualTo(1)); // At least 1 day streak
    });

    test('Insert and retrieve achievements', () async {
      await db.insertAchievement('first_log', data: {'description': 'First log achievement'});

      final achievements = await db.getAchievements();
      expect(achievements.length, equals(1));
      expect(achievements.first['achievement_type'], equals('first_log'));

      final hasAchievement = await db.hasAchievement('first_log');
      expect(hasAchievement, isTrue);

      final hasOtherAchievement = await db.hasAchievement('non_existent');
      expect(hasOtherAchievement, isFalse);
    });

    test('Get database info', () async {
      // Insert some test data
      const template = ActionTemplate(
        id: 'test_template',
        name: 'Test',
        category: 'test',
        baseXp: 5,
        attrStrength: 1,
        attrEndurance: 1,
        attrKnowledge: 1,
      );
      await db.insertTemplate(template);

      final log = ActionLog(
        id: 'test_log',
        templateId: 'test_template',
        occurredAt: DateTime.now(),
        durationMin: 30,
        notes: null,
        imageUrl: null,
        earnedXp: 10,
      );
      await db.insertLog(log);

      await db.insertAchievement('test_achievement');

      final info = await db.getDatabaseInfo();
      expect(info['templates'], equals(1));
      expect(info['logs'], equals(1));
      expect(info['achievements'], equals(1));
      expect(info['total_xp'], equals(10));
    });

    test('Clear all data', () async {
      // Insert test data
      const template = ActionTemplate(
        id: 'test_template',
        name: 'Test',
        category: 'test',
        baseXp: 5,
        attrStrength: 1,
        attrEndurance: 1,
        attrKnowledge: 1,
      );
      await db.insertTemplate(template);

      final log = ActionLog(
        id: 'test_log',
        templateId: 'test_template',
        occurredAt: DateTime.now(),
        durationMin: 30,
        notes: null,
        imageUrl: null,
        earnedXp: 10,
      );
      await db.insertLog(log);

      // Verify data exists
      var templates = await db.getTemplates();
      var logs = await db.getLogs();
      expect(templates.length, equals(1));
      expect(logs.length, equals(1));

      // Clear all data
      await db.clearAllData();

      // Verify data is cleared
      templates = await db.getTemplates();
      logs = await db.getLogs();
      expect(templates.length, equals(0));
      expect(logs.length, equals(0));
    });
  });
}