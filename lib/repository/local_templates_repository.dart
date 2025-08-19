import 'package:flutter/foundation.dart';
import '../models/action_models.dart' as models;
import '../services/local_database.dart';
import '../utils/logging_service.dart';

typedef ActionTemplate = models.ActionTemplate;

class LocalTemplatesRepository {
  final LocalDatabase _db = LocalDatabase();

  Future<List<ActionTemplate>> fetchTemplates() async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL REPO FETCH TEMPLATES ===');
      
      final templates = await _db.getTemplates();
      
      if (kDebugMode) debugPrint('Fetched ${templates.length} templates from local database');
      return templates;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to fetch templates from local database', e, stackTrace, 'LocalTemplatesRepository');
      return [];
    }
  }

  Future<ActionTemplate?> getTemplate(String id) async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL REPO GET TEMPLATE: $id ===');
      
      final template = await _db.getTemplate(id);
      
      if (kDebugMode) debugPrint(template != null ? 'Found template: ${template.name}' : 'Template not found');
      return template;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to get template from local database', e, stackTrace, 'LocalTemplatesRepository');
      return null;
    }
  }

  Future<String> createTemplate(ActionTemplate template) async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL REPO CREATE TEMPLATE: ${template.name} ===');
      
      final id = await _db.insertTemplate(template);
      
      if (kDebugMode) debugPrint('Created template with ID: $id');
      return id;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to create template in local database', e, stackTrace, 'LocalTemplatesRepository');
      rethrow;
    }
  }

  Future<void> seedDefaultTemplates() async {
    try {
      if (kDebugMode) debugPrint('=== LOCAL REPO SEED DEFAULT TEMPLATES ===');
      
      // Check if we already have templates
      final existingTemplates = await fetchTemplates();
      if (existingTemplates.isNotEmpty) {
        if (kDebugMode) debugPrint('Templates already exist, skipping seed');
        return;
      }

      // Default templates for common activities
      final defaultTemplates = [
        const ActionTemplate(
          id: 'fitness_workout',
          name: 'Workout',
          category: 'fitness',
          baseXp: 10,
          attrStrength: 2,
          attrEndurance: 3,
          attrKnowledge: 0,
        ),
        const ActionTemplate(
          id: 'fitness_cardio',
          name: 'Cardio Training',
          category: 'fitness',
          baseXp: 8,
          attrStrength: 1,
          attrEndurance: 4,
          attrKnowledge: 0,
        ),
        const ActionTemplate(
          id: 'learning_reading',
          name: 'Reading',
          category: 'learning',
          baseXp: 5,
          attrStrength: 0,
          attrEndurance: 1,
          attrKnowledge: 4,
        ),
        const ActionTemplate(
          id: 'learning_course',
          name: 'Online Course',
          category: 'learning',
          baseXp: 8,
          attrStrength: 0,
          attrEndurance: 2,
          attrKnowledge: 5,
        ),
        const ActionTemplate(
          id: 'health_meditation',
          name: 'Meditation',
          category: 'health',
          baseXp: 6,
          attrStrength: 0,
          attrEndurance: 2,
          attrKnowledge: 3,
        ),
        const ActionTemplate(
          id: 'health_sleep',
          name: 'Quality Sleep (8h+)',
          category: 'health',
          baseXp: 5,
          attrStrength: 1,
          attrEndurance: 3,
          attrKnowledge: 1,
        ),
        const ActionTemplate(
          id: 'nutrition_cooking',
          name: 'Healthy Cooking',
          category: 'nutrition',
          baseXp: 4,
          attrStrength: 1,
          attrEndurance: 1,
          attrKnowledge: 2,
        ),
        const ActionTemplate(
          id: 'work_project',
          name: 'Project Work',
          category: 'work',
          baseXp: 6,
          attrStrength: 0,
          attrEndurance: 2,
          attrKnowledge: 4,
        ),
        const ActionTemplate(
          id: 'social_friends',
          name: 'Social Time',
          category: 'social',
          baseXp: 4,
          attrStrength: 0,
          attrEndurance: 1,
          attrKnowledge: 2,
        ),
        const ActionTemplate(
          id: 'creativity_art',
          name: 'Creative Project',
          category: 'art',
          baseXp: 6,
          attrStrength: 0,
          attrEndurance: 2,
          attrKnowledge: 3,
        ),
      ];

      // Insert all default templates
      for (final template in defaultTemplates) {
        await _db.insertTemplate(template);
      }

      if (kDebugMode) debugPrint('Seeded ${defaultTemplates.length} default templates');
    } catch (e, stackTrace) {
      LoggingService.error('Failed to seed default templates', e, stackTrace, 'LocalTemplatesRepository');
    }
  }

  Future<void> clearAllTemplates() async {
    try {
      // This would require a specific method in LocalDatabase
      if (kDebugMode) debugPrint('Clearing all templates (would need implementation)');
    } catch (e, stackTrace) {
      LoggingService.error('Failed to clear templates', e, stackTrace, 'LocalTemplatesRepository');
    }
  }

  Future<int> getTemplateCount() async {
    try {
      final templates = await fetchTemplates();
      return templates.length;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to get template count', e, stackTrace, 'LocalTemplatesRepository');
      return 0;
    }
  }

  /// Holt alle lokalen Templates für Migration
  Future<List<ActionTemplate>> getAllLocalTemplates() async {
    try {
      return await fetchTemplates(); // Nutzt bestehende Methode
    } catch (e, stackTrace) {
      LoggingService.error('Failed to get all local templates', e, stackTrace, 'LocalTemplatesRepository');
      return [];
    }
  }

  /// Löscht alle lokalen Templates (für Migration)
  Future<void> clearAllLocalTemplates() async {
    try {
      await clearAllTemplates(); // Nutzt die bestehende Methode
    } catch (e, stackTrace) {
      LoggingService.error('Failed to clear all local templates', e, stackTrace, 'LocalTemplatesRepository');
      rethrow;
    }
  }
}