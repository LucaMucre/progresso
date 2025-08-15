import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'level_up_service.dart';
import 'achievement_service.dart';
import 'life_areas_service.dart';
import '../models/action_models.dart' as models;
import '../navigation.dart';

final _db = Supabase.instance.client;

/// Modell für eine Action-Vorlage
typedef ActionTemplate = models.ActionTemplate;

/// Modell für einen Action-Log
typedef ActionLog = models.ActionLog;

// Try to extract a 'title' from notes JSON wrapper (top-level helper)
String? extractTitleFromNotes(dynamic notesValue) {
  try {
    if (notesValue is String && notesValue.trim().isNotEmpty) {
      final obj = jsonDecode(notesValue);
      if (obj is Map<String, dynamic>) {
        final t = obj['title'];
        if (t is String && t.trim().isNotEmpty) return t.trim();
      }
    }
  } catch (_) {}
  return null;
}

/// Templates laden
Future<List<ActionTemplate>> fetchTemplates() async {
  if (kDebugMode) {
    debugPrint('=== FETCH TEMPLATES DEBUG ===');
    debugPrint('Current User ID: ${_db.auth.currentUser?.id}');
  }
  
  try {
    final res = await _db
        .from('action_templates')
        .select()
        .eq('user_id', _db.auth.currentUser!.id)
        .order('created_at', ascending: true);
    if (kDebugMode) debugPrint('Templates Result: $res');
    return (res as List)
        .map((e) => ActionTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    if (kDebugMode) debugPrint('Error fetching templates: $e');
    rethrow;
  }
}

/// Grobe Textlänge aus dem Notes-Feld bestimmen (robust gegen JSON/Delta)
int _estimatePlainTextLength(String? notes) {
  if (notes == null || notes.trim().isEmpty) return 0;
  try {
    final obj = jsonDecode(notes);
    if (obj is Map<String, dynamic>) {
      int len = 0;
      final title = obj['title'];
      if (title is String) len += title.trim().length;
      final content = obj['content'];
      if (content is String) len += content.trim().length;
      // Quill Delta eventuell als 'ops'
      final ops = obj['ops'];
      if (ops is List) {
        for (final o in ops) {
          if (o is Map && o['insert'] is String) {
            len += (o['insert'] as String).length;
          }
        }
      }
      if (len > 0) return len;
      // Fallback: stringify und filtern
      return obj.toString().replaceAll(RegExp(r'[{}\[\]",:]+'), ' ').trim().length;
    }
    if (obj is List) {
      // Mögliche Quill Delta
      int len = 0;
      for (final e in obj) {
        if (e is Map && e['insert'] is String) {
          len += (e['insert'] as String).length;
        }
      }
      if (len > 0) return len;
    }
  } catch (_) {
    // ignore and fall back
  }
  return notes.replaceAll(RegExp(r"\s+"), ' ').trim().length;
}

/// Client-seitige XP-Berechnung (spiegelt Edge Function)
int calculateEarnedXp({int? durationMin, String? notes, String? imageUrl}) {
  // Grundidee: hauptsächlich Zeit, plus Textlänge, plus +10% bei Bild
  final timeMinutes = durationMin ?? 0;
  // 1 XP je 5 Minuten
  int xp = timeMinutes ~/ 5;
  // Textbonus: 1 XP je 100 Zeichen
  final textLen = _estimatePlainTextLength(notes);
  xp += textLen ~/ 100;
  // Bildbonus: +10%
  final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
  if (hasImage) {
    xp = (xp * 1.1).round();
  }
  // Sicherheitsnetz: mindestens 1 XP, wenn überhaupt etwas geloggt wurde
  if (xp <= 0 && (timeMinutes > 0 || textLen > 0 || hasImage)) xp = 1;
  
  if (kDebugMode) {
    debugPrint('=== XP CALCULATION DEBUG ===');
    debugPrint('Duration: $timeMinutes min -> ${timeMinutes ~/ 5} XP');
    debugPrint('Notes length: $textLen -> ${textLen ~/ 100} XP');
    debugPrint('Has Image: $hasImage -> ${hasImage ? "+10%" : "no bonus"}');
    debugPrint('Final XP: $xp');
  }
  
  return xp;
}

/// Log anlegen mit client-seitiger XP-Berechnung
Future<ActionLog> createLog({
  required String templateId,
  int? durationMin,
  String? notes,
  String? imageUrl,
}) async {
  // Basis-XP der Vorlage holen
  final tplMap = await _db
      .from('action_templates')
      .select()
      .eq('id', templateId)
      .single() as Map<String, dynamic>;
  final baseXp = tplMap['base_xp'] as int;

  // Neue, vereinheitlichte XP-Berechnung (unabhängig von Kategorie/BaseXP)
  final earnedXp = calculateEarnedXp(
    durationMin: durationMin,
    notes: notes,
    imageUrl: imageUrl,
  );

  // Eintrag zusammenbauen und schreiben
  final insert = <String, dynamic>{
    'user_id':      _db.auth.currentUser!.id,
    'template_id':  templateId,
    'duration_min': durationMin,
    'notes':        notes,
    'earned_xp':    earnedXp,
  };
  
  // Add image_url only if it's not null and the column exists
  if (imageUrl != null) {
    insert['image_url'] = imageUrl;
  }
  
  final out = await _db
      .from('action_logs')
      .insert(insert)
      .select()
      .single() as Map<String, dynamic>;

  // Achievements nach erfolgreichem Insert prüfen
  _checkAchievementsAfterLogInsert();
  // Global notification for UI to refresh profile/dashboard stats
  try { notifyLogsChanged(); } catch (_) {}
  // Level-Up check and notification
  try {
    final totalXp = await fetchTotalXp();
    final newLevel = calculateLevel(totalXp);
    // Fetch previous level based on stored baseline logic? We only check against previous fetch.
    // Level boundary detection uses 100 XP per level
    // Compute previous XP as totalXp - earnedXp
    final prevTotal = totalXp - earnedXp;
    final prevLevel = calculateLevel(prevTotal);
    // Do NOT trigger LevelUp popup here; UI handles it after navigation to avoid navigator lock
  } catch (_) {}

  return ActionLog.fromJson(out);
}

/// Quick Log ohne Template erstellen
Future<ActionLog> createQuickLog({
  required String activityName,
  required String category,
  int? durationMin,
  String? notes,
  String? imageUrl,
}) async {
  // Neue, vereinheitlichte XP-Berechnung (Quick-Log ohne Template)
  final earnedXp = calculateEarnedXp(
    durationMin: durationMin,
    notes: notes,
    imageUrl: imageUrl,
  );

  // Eintrag zusammenbauen
  final insertBase = <String, dynamic>{
    'user_id':      _db.auth.currentUser!.id,
    'duration_min': durationMin,
    'notes':        notes,
    'earned_xp':    earnedXp,
  };
  
  // Add image_url only if it's not null and the column exists
  if (imageUrl != null) {
    insertBase['image_url'] = imageUrl;
  }
  
  Map<String, dynamic> out;
  try {
    // Versuche mit activity_name (falls Spalte existiert)
    final insertWithTitle = Map<String, dynamic>.from(insertBase)
      ..['activity_name'] = activityName;
    out = await _db
        .from('action_logs')
        .insert(insertWithTitle)
        .select()
        .single() as Map<String, dynamic>;
  } catch (e) {
    // Fallback ohne activity_name, wenn Spalte nicht existiert
    out = await _db
        .from('action_logs')
        .insert(insertBase)
        .select()
        .single() as Map<String, dynamic>;
  }

  // Level-Up-Berechnung ZUERST, dann Achievements
  try {
    final totalXp = await fetchTotalXp();
    final newLevel = calculateLevel(totalXp);
    final prevTotal = totalXp - earnedXp;
    final prevLevel = calculateLevel(prevTotal);
    // Do NOT trigger LevelUp popup here; UI handles it after navigation to avoid navigator lock
  } catch (_) {}
  
  // Achievements NACH Level-Up-Berechnung prüfen (damit Level-Up-Flag gesetzt ist, falls nötig)
  await _checkAchievementsAfterLogInsert();
  try { notifyLogsChanged(); } catch (_) {}

  return ActionLog.fromJson(out);
}

Future<void> _checkAchievementsAfterLogInsert() async {
  try {
    // Gesamt-XP (über alle Logs)
    final totalXp = await fetchTotalXp();

    // Gesamtzahl Aktivitäten
    final logs = await fetchLogs();
    final totalActions = logs.length;

    // Streak serverseitig berechnen (bestehende Funktion)
    final currentStreak = await calculateStreak();

    // Anzahl aktiver Lebensbereiche: parent-rollup wie im Kalender/Profil
    int lifeAreaCount = 0;
    try {
      final rolledParents = <String>{};
      for (final l in logs) {
        try {
          if (l.notes == null) continue;
          final obj = jsonDecode(l.notes!);
          if (obj is Map<String, dynamic>) {
            String? area = (obj['area'] as String?)?.trim().toLowerCase();
            String? lifeArea = (obj['life_area'] as String?)?.trim().toLowerCase();
            area ??= lifeArea;
            final category = (obj['category'] as String?)?.trim().toLowerCase();
            String key;
            bool isKnownParent(String? v) => const {
              'spirituality','finance','career','learning','relationships','health','creativity','fitness','nutrition','art'
            }.contains(v);
            if (isKnownParent(area)) {
              key = area!;
            } else {
              switch (category) {
                case 'inner': key = 'spirituality'; break;
                case 'social': key = 'relationships'; break;
                case 'work': key = 'career'; break;
                case 'development': key = 'learning'; break;
                case 'finance': key = 'finance'; break;
                case 'health': key = 'health'; break;
                case 'fitness': key = 'fitness'; break;
                case 'nutrition': key = 'nutrition'; break;
                case 'art': key = 'art'; break;
                default: key = area ?? 'unknown';
              }
            }
            rolledParents.add(key);
          }
        } catch (_) {}
      }
      lifeAreaCount = rolledParents.where((k) => k != 'unknown').length;
    } catch (_) {}

    // Heutige Aktionen für Tages-Achievements
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    int dailyActions = logs.where((l) => l.occurredAt.isAfter(start) && l.occurredAt.isBefore(end)).length;

    await AchievementService.reconcileLifeAreaAchievements(lifeAreaCount);
    await AchievementService.checkAndUnlockAchievements(
      currentStreak: currentStreak,
      totalActions: totalActions,
      totalXP: totalXp,
      level: calculateLevel(totalXp),
      lifeAreaCount: lifeAreaCount,
      dailyActions: dailyActions,
      // Verwende lokale aktuelle Zeit als sichere Referenz für Special-Achievements (z. B. Wochenende),
      // da das frisch eingefügte Log evtl. noch nicht in fetchLogs() erscheint (Replikationsverzögerung)
      lastActionTime: DateTime.now(),
    );
  } catch (e) {
    // still continue silently
    // ignore
  }
}

/// Alle Logs laden
Future<List<ActionLog>> fetchLogs() async {
  if (kDebugMode) {
    debugPrint('=== FETCH LOGS DEBUG ===');
    debugPrint('Current User ID: ${_db.auth.currentUser?.id}');
  }
  
  try {
    final res = await _db
        .from('action_logs')
        .select()
        .eq('user_id', _db.auth.currentUser!.id)
        .order('occurred_at', ascending: false);
    if (kDebugMode) debugPrint('Logs Result: $res');
    return (res as List)
        .map((e) => ActionLog.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    if (kDebugMode) debugPrint('Error fetching logs: $e');
    rethrow;
  }
}

/// Gesamt-XP berechnen
Future<int> fetchTotalXp() async {
  if (kDebugMode) debugPrint('=== FETCH TOTAL XP DEBUG ===');
  try {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return 0;
    // Prefer RPC for aggregation to avoid PostgREST relationship constraints
    try {
      final rpc = await _db.rpc('sum_user_xp', params: {'uid': uid}).single();
      final value = rpc['sum'] ?? rpc['total'] ?? rpc['sum_earned_xp'];
      final parsed = value is int ? value : (value is String ? int.tryParse(value) : null);
      if (parsed != null) {
        if (kDebugMode) debugPrint('Total XP: $parsed');
        return parsed;
      }
    } catch (_) {
      // ignore and fall back
    }

    // Fallback: lightweight projection and fold
    final rows = await _db
        .from('action_logs')
        .select('earned_xp')
        .eq('user_id', uid);
    final sum = (rows as List).fold<int>(0, (acc, e) => acc + ((e['earned_xp'] as int?) ?? 0));
    if (kDebugMode) debugPrint('Total XP: $sum');
    return sum;
  } catch (e) {
    if (kDebugMode) debugPrint('Error calculating total XP: $e');
    rethrow;
  }
}

/// Aggregierte Aktivitäten pro Tag und Bereich (serverseitig via RPC)
Future<Map<DateTime, Map<String, int>>> fetchDailyAreaTotals({
  required DateTime month,
}) async {
  final uid = _db.auth.currentUser?.id;
  if (uid == null) return {};
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0);
  final res = await _db.rpc('daily_activity_totals', params: {
    'uid': uid,
    'start_date': '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
    'end_date': '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
    'tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
  });
  final out = <DateTime, Map<String, int>>{};
  if (res is List) {
    for (final row in res) {
      final String? dayStr = row['day'] as String?;
      if (dayStr == null) continue;
      final String area = (row['area_key'] as String?) ?? 'unknown';
      final int total = (row['total'] as num?)?.toInt() ?? 0;
      final day = DateTime.parse(dayStr);
      final key = DateTime(day.year, day.month, day.day);
      final bucket = out.putIfAbsent(key, () => <String, int>{});
      bucket[area] = total;
    }
  }
  return out;
}

/// Detaillierte Aggregation (Count, Dauer, XP) pro Tag und Bereich via RPC
Future<Map<DateTime, List<Map<String, dynamic>>>> fetchDailyAreaTotalsDetailed({
  required DateTime month,
}) async {
  final uid = _db.auth.currentUser?.id;
  if (uid == null) return {};
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0);
  final res = await _db.rpc('daily_activity_totals', params: {
    'uid': uid,
    'start_date': '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
    'end_date': '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
    'tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
  });
  final out = <DateTime, List<Map<String, dynamic>>>{};
  if (res is List) {
    for (final row in res) {
      final String? dayStr = row['day'] as String?;
      if (dayStr == null) continue;
      final day = DateTime.parse(dayStr);
      final key = DateTime(day.year, day.month, day.day);
      final item = {
        'area_key': (row['area_key'] as String?) ?? 'unknown',
        'total': (row['total'] as num?)?.toInt() ?? 0,
        'sum_duration': (row['sum_duration'] as num?)?.toInt() ?? 0,
        'sum_xp': (row['sum_xp'] as num?)?.toInt() ?? 0,
      };
      (out[key] ??= <Map<String, dynamic>>[]).add(item);
    }
  }
  return out;
}

/// XP-Schwelle für Level n (lineares System: 50 XP pro Level)
int xpForLevel(int level) => level * 50;

/// Level aus Gesamt-XP berechnen (lineares System: 50 XP pro Level)
int calculateLevel(int totalXp) {
  if (totalXp <= 0) return 1;
  return (totalXp / 50).floor() + 1;
}

/// Ausführliche Level-Progress-Infos: aktuelles Level, XP seit Levelstart, XP bis nächstes Level
Map<String, int> calculateLevelDetailed(int totalXp) {
  final level = calculateLevel(totalXp);
  // 50 XP pro Level
  final xpInto = totalXp % 50; // XP im aktuellen Level (Rest der Division)
  final xpNeeded = 50; // Jedes Level benötigt 50 XP
  
  return {
    'level': level,
    'xpInto': xpInto,
    'xpNext': xpNeeded,
  };
}

/// Lade alle Datumswerte (ohne Zeit) der letzten [days] Tage, an denen geloggt wurde
Future<List<DateTime>> fetchLoggedDates(int days) async {
  if (kDebugMode) {
    debugPrint('=== FETCH LOGGED DATES DEBUG ===');
    debugPrint('Days: $days');
  }
  
  try {
    final since = DateTime.now().subtract(Duration(days: days));
    final res = await _db
        .from('action_logs')
        .select('occurred_at')
        .gte('occurred_at', since.toIso8601String());
    if (kDebugMode) debugPrint('Logged dates result: $res');
    
    final dates = (res as List)
        .map((e) => DateTime.parse(e['occurred_at'] as String).toLocal())
        .map((dt) => DateTime(dt.year, dt.month, dt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (kDebugMode) debugPrint('Processed dates: $dates');
    return dates;
  } catch (e) {
    if (kDebugMode) debugPrint('Error fetching logged dates: $e');
    rethrow;
  }
}

/// Berechnet die aktuelle Streak basierend auf zusammenhängenden Tagen,
/// ausgehend vom zuletzt geloggten Tag (nicht zwingend heute).
Future<int> calculateStreak() async {
  if (kDebugMode) debugPrint('=== CALCULATE STREAK DEBUG (RPC) ===');
  try {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return 0;
    final res = await _db.rpc('calculate_streak', params: {'uid': uid});
    final rpc = (res is int) ? res : int.tryParse('$res') ?? 0;
    if (kDebugMode) debugPrint('Calculated streak (RPC): $rpc');
    // Fallback auf lokale Berechnung, falls RPC 0 liefert aber Daten vorhanden sind
    if (rpc > 0) return rpc;
    final dates = await fetchLoggedDates(60);
    if (dates.isEmpty) return 0;
    final normalized = dates.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()..sort();
    final DateTime last = normalized.last;
    int streak = 0;
    DateTime cursor = last;
    while (normalized.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  } catch (e) {
    if (kDebugMode) debugPrint('Error calculating streak (RPC/local): $e');
    return 0;
  }
}

/// Alias für fetchStreak, damit der Dashboard-Code passt
Future<int> fetchStreak() => calculateStreak();

/// Badge-Level (0=keine,1=Bronze,2=Silber,3=Gold)
int badgeLevel(int streak) {
  if (streak >= 30) return 3;
  if (streak >= 7)  return 2;
  if (streak >= 3)  return 1;
  return 0;
}