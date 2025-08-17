import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/action_models.dart' as models;
import '../utils/logging_service.dart';
import '../utils/xp_calculator.dart';

typedef ActionLog = models.ActionLog;

class LogsRepository {
  final SupabaseClient db;
  LogsRepository(this.db);

  Future<ActionLog> createLog({
    required String templateId,
    int? durationMin,
    String? notes,
    String? imageUrl,
  }) async {
    final insert = <String, dynamic>{
      'user_id': db.auth.currentUser!.id,
      'template_id': templateId,
      'duration_min': durationMin,
      'notes': notes,
      'earned_xp': 0,
    };
    if (imageUrl != null) insert['image_url'] = imageUrl;

    final out = await db
        .from('action_logs')
        .insert(insert)
        .select()
        .single() as Map<String, dynamic>;

    try {
      final fnRes = await db.functions.invoke('calculate-xp', body: {
        'action_log_id': out['id'],
      });
      if (kDebugMode) debugPrint('calculate-xp ok: ${fnRes.data}');
      try {
        final data = fnRes.data as Map<String, dynamic>?;
        final int? earned = (data?['earned_xp'] as num?)?.toInt();
        if (earned != null) out['earned_xp'] = earned;
      } catch (e, stackTrace) {
        LoggingService.error('Failed to parse XP calculation response', e, stackTrace, 'LogsRepository');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('calculate-xp failed: $e - applying client fallback');
      final int fallbackXp = XpCalculator.calculateFallback(
        durationMin: durationMin,
        notes: notes,
        imageUrl: insert['image_url'] as String?,
      );
      try {
        await db.from('action_logs').update({'earned_xp': fallbackXp}).eq('id', out['id']);
        out['earned_xp'] = fallbackXp;
      } catch (e, stackTrace) {
        LoggingService.error('Failed to update earned_xp in database', e, stackTrace, 'LogsRepository');
      }
    }

    return models.ActionLog.fromJson(out);
  }

  Future<ActionLog> createQuickLog({
    required String activityName,
    required String category,
    int? durationMin,
    String? notes,
    String? imageUrl,
  }) async {
    final insertBase = <String, dynamic>{
      'user_id': db.auth.currentUser!.id,
      'duration_min': durationMin,
      'notes': notes,
      'earned_xp': 0,
    };
    if (imageUrl != null) insertBase['image_url'] = imageUrl;

    Map<String, dynamic> out;
    try {
      final insertWithTitle = Map<String, dynamic>.from(insertBase)..['activity_name'] = activityName;
      out = await db.from('action_logs').insert(insertWithTitle).select().single() as Map<String, dynamic>;
    } catch (_) {
      out = await db.from('action_logs').insert(insertBase).select().single() as Map<String, dynamic>;
    }

    try {
      final fnRes = await db.functions.invoke('calculate-xp', body: {
        'action_log_id': out['id'],
      });
      if (kDebugMode) debugPrint('calculate-xp ok: ${fnRes.data}');
      try {
        final data = fnRes.data as Map<String, dynamic>?;
        final int? earned = (data?['earned_xp'] as num?)?.toInt();
        if (earned != null) out['earned_xp'] = earned;
      } catch (e, stackTrace) {
        LoggingService.error('Failed to parse XP calculation response', e, stackTrace, 'LogsRepository');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('calculate-xp failed: $e - applying client fallback');
      final int fallbackXp = XpCalculator.calculateFallback(
        durationMin: durationMin,
        notes: notes,
        imageUrl: insertBase['image_url'] as String?,
      );
      try {
        await db.from('action_logs').update({'earned_xp': fallbackXp}).eq('id', out['id']);
        out['earned_xp'] = fallbackXp;
      } catch (e, stackTrace) {
        LoggingService.error('Failed to update earned_xp in database', e, stackTrace, 'LogsRepository');
      }
    }

    return models.ActionLog.fromJson(out);
  }

  Future<List<ActionLog>> fetchLogs() async {
    if (kDebugMode) {
      debugPrint('=== REPO FETCH LOGS ===');
      debugPrint('Current User ID: ${db.auth.currentUser?.id}');
    }
    final res = await db
        .from('action_logs')
        .select()
        .eq('user_id', db.auth.currentUser!.id)
        .order('occurred_at', ascending: false);
    return (res as List)
        .map((e) => models.ActionLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> fetchTotalXp() async {
    if (kDebugMode) debugPrint('=== REPO FETCH TOTAL XP ===');
    final uid = db.auth.currentUser?.id;
    if (uid == null) return 0;
    try {
      final rpc = await db.rpc('sum_user_xp', params: {'uid': uid}).single();
      final value = rpc['sum'] ?? rpc['total'] ?? rpc['sum_earned_xp'];
      final parsed = value is int
          ? value
          : (value is String ? int.tryParse(value) : null);
      if (parsed != null) return parsed;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to fetch total XP via RPC', e, stackTrace, 'LogsRepository');
    }
    final rows = await db
        .from('action_logs')
        .select('earned_xp')
        .eq('user_id', uid);
    return (rows as List)
        .fold<int>(0, (acc, e) => acc + ((e['earned_xp'] as int?) ?? 0));
  }

  Future<int> calculateStreak() async {
    if (kDebugMode) debugPrint('=== REPO CALCULATE STREAK (RPC) ===');
    final uid = db.auth.currentUser?.id;
    if (uid == null) return 0;
    try {
      final res = await db.rpc('calculate_streak', params: {'uid': uid});
      final rpc = (res is int) ? res : int.tryParse('$res') ?? 0;
      if (rpc > 0) return rpc;
    } catch (e, stackTrace) {
      LoggingService.error('Failed to calculate streak via RPC', e, stackTrace, 'LogsRepository');
    }
    // Fallback: lokale Berechnung (leichtgewichtig)
    final since = DateTime.now().subtract(const Duration(days: 60));
    final rows = await db
        .from('action_logs')
        .select('occurred_at')
        .gte('occurred_at', since.toIso8601String());
    final dates = (rows as List)
        .map((e) => DateTime.parse(e['occurred_at'] as String).toLocal())
        .map((dt) => DateTime(dt.year, dt.month, dt.day))
        .toSet()
        .toList()
      ..sort();
    if (dates.isEmpty) return 0;
    int streak = 0;
    DateTime cursor = dates.last;
    final set = dates.toSet();
    while (set.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

