import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/action_models.dart' as models;

typedef ActionTemplate = models.ActionTemplate;

class TemplatesRepository {
  final SupabaseClient db;
  TemplatesRepository(this.db);

  Future<List<ActionTemplate>> fetchTemplates() async {
    if (kDebugMode) {
      debugPrint('=== REPO FETCH TEMPLATES ===');
      debugPrint('Current User ID: ${db.auth.currentUser?.id}');
    }
    final res = await db
        .from('action_templates')
        .select()
        .eq('user_id', db.auth.currentUser!.id)
        .order('created_at', ascending: true);
    return (res as List).map((e) => models.ActionTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }
}

