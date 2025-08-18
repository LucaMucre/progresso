import '../models/action_models.dart' as models;
import 'storage_service.dart';

/// Service for handling action templates
class TemplateService {
  /// Load all templates
  static Future<List<models.ActionTemplate>> fetchTemplates() async {
    if (StorageService.isUsingLocalStorage) {
      final templates = await StorageService.templatesRepo.fetchTemplates();
      // Auto-seed default templates if none exist
      if (templates.isEmpty) {
        await StorageService.templatesRepo.seedDefaultTemplates();
        return await StorageService.templatesRepo.fetchTemplates();
      }
      return templates;
    }
    return StorageService.templatesRepo.fetchTemplates();
  }
}