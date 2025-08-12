import 'dart:math';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'level_up_service.dart';
import 'achievement_service.dart';
import 'life_areas_service.dart';

final _db = Supabase.instance.client;

/// Modell für eine Action-Vorlage
class ActionTemplate {
  final String id, name, category;
  final int baseXp, attrStrength, attrEndurance, attrKnowledge;

  ActionTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.baseXp,
    required this.attrStrength,
    required this.attrEndurance,
    required this.attrKnowledge,
  });

  factory ActionTemplate.fromMap(Map<String, dynamic> m) => ActionTemplate(
        id:            m['id']           as String,
        name:          m['name']         as String,
        category:      m['category']     as String,
        baseXp:        m['base_xp']       as int,
        attrStrength:  m['attr_strength'] as int,
        attrEndurance: m['attr_endurance'] as int,
        attrKnowledge: m['attr_knowledge'] as int,
      );
}

/// Modell für einen Action-Log
class ActionLog {
  final String id;
  final DateTime occurredAt;
  final int? durationMin;
  final String? notes;
  final int earnedXp;
  final String? templateId;
  final String? activityName;
  final String? imageUrl;

  ActionLog({
    required this.id,
    required this.occurredAt,
    this.durationMin,
    this.notes,
    required this.earnedXp,
    this.templateId,
    this.activityName,
    this.imageUrl,
  });

  factory ActionLog.fromMap(Map<String, dynamic> m) => ActionLog(
        id:          m['id']             as String,
        occurredAt:  DateTime.parse(m['occurred_at'] as String),
        durationMin: m['duration_min']    as int?,
        notes:       m['notes']           as String?,
        earnedXp:    m['earned_xp']       as int,
        templateId:  m['template_id']     as String?,
        // Support both top-level and nested (in notes JSON) titles
        activityName: (m['activity_name'] as String?) ?? extractTitleFromNotes(m['notes']),
        imageUrl:    m['image_url']       as String?,
      );
}

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
  print('=== FETCH TEMPLATES DEBUG ===');
  print('Current User ID: ${_db.auth.currentUser?.id}');
  
  try {
    final res = await _db
        .from('action_templates')
        .select()
        .eq('user_id', _db.auth.currentUser!.id)
        .order('created_at', ascending: true);
    print('Templates Result: $res');
    return (res as List)
        .map((e) => ActionTemplate.fromMap(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    print('Error fetching templates: $e');
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
  
  print('=== XP CALCULATION DEBUG ===');
  print('Duration: $timeMinutes min -> ${timeMinutes ~/ 5} XP');
  print('Notes: "$notes" -> $textLen chars -> ${textLen ~/ 100} XP');
  print('Has Image: $hasImage -> ${hasImage ? "+10%" : "no bonus"}');
  print('Final XP: $xp');
  
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
  // Level-Up check and notification
  try {
    final totalXp = await fetchTotalXp();
    final newLevel = calculateLevel(totalXp);
    // Fetch previous level based on stored baseline logic? We only check against previous fetch.
    // For simplicity, notify if xpInto==0 (exact multiple of 50) or if the inserted earned_xp pushed over a boundary.
    // Compute previous XP as totalXp - earnedXp
    final prevTotal = totalXp - earnedXp;
    final prevLevel = calculateLevel(prevTotal);
    if (newLevel > prevLevel) {
      LevelUpService.notifyLevelUp(newLevel);
    }
  } catch (_) {}

  return ActionLog.fromMap(out);
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

  // Achievements nach erfolgreichem Insert prüfen
  _checkAchievementsAfterLogInsert();
  try {
    final totalXp = await fetchTotalXp();
    final newLevel = calculateLevel(totalXp);
    final prevTotal = totalXp - earnedXp;
    final prevLevel = calculateLevel(prevTotal);
    if (newLevel > prevLevel) {
      LevelUpService.notifyLevelUp(newLevel);
    }
  } catch (_) {}

  return ActionLog.fromMap(out);
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

    // Anzahl aktiver Lebensbereiche: Bereiche, in denen mindestens eine Aktivität existiert
    int lifeAreaCount = 0;
    try {
      final logsByArea = <String>{};
      for (final l in logs) {
        try {
          if (l.notes == null) continue;
          final obj = jsonDecode(l.notes!);
          if (obj is Map<String, dynamic>) {
            final name = (obj['area'] as String?)?.trim();
            final category = (obj['category'] as String?)?.trim();
            if (name != null && name.isNotEmpty) {
              logsByArea.add('n:$name');
            } else if (category != null && category.isNotEmpty) {
              logsByArea.add('c:$category');
            }
          }
        } catch (_) {}
      }
      lifeAreaCount = logsByArea.length;
    } catch (_) {}

    // Heutige Aktionen für Tages-Achievements
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    int dailyActions = logs.where((l) => l.occurredAt.isAfter(start) && l.occurredAt.isBefore(end)).length;

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
  print('=== FETCH LOGS DEBUG ===');
  print('Current User ID: ${_db.auth.currentUser?.id}');
  
  try {
    final res = await _db
        .from('action_logs')
        .select()
        .eq('user_id', _db.auth.currentUser!.id)
        .order('occurred_at', ascending: false);
    print('Logs Result: $res');
    return (res as List)
        .map((e) => ActionLog.fromMap(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    print('Error fetching logs: $e');
    rethrow;
  }
}

/// Gesamt-XP berechnen
Future<int> fetchTotalXp() async {
  print('=== FETCH TOTAL XP DEBUG ===');
  try {
    final logs = await fetchLogs();
    final totalXp = logs.fold<int>(0, (sum, log) => sum + log.earnedXp);
    print('Total XP: $totalXp');
    return totalXp;
  } catch (e) {
    print('Error calculating total XP: $e');
    rethrow;
  }
}

/// XP-Schwelle für Level n (lineares System)
/// Jedes Level benötigt konstant 50 XP
/// Level 1: 0-50 XP, Level 2: 50-100 XP, Level 3: 100-150 XP, etc.
int xpForLevel(int level) => level * 50;

/// Level aus Gesamt-XP berechnen (lineares System)
int calculateLevel(int totalXp) {
  // Bei linearem System: Level = (totalXp / 50) + 1, mindestens Level 1
  if (totalXp <= 0) return 1;
  return (totalXp / 50).floor() + 1;
}

/// Ausführliche Level-Progress-Infos: aktuelles Level, XP seit Levelstart, XP bis nächstes Level
Map<String, int> calculateLevelDetailed(int totalXp) {
  final level = calculateLevel(totalXp);
  
  // Bei linearem System: jedes Level benötigt genau 50 XP
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
  print('=== FETCH LOGGED DATES DEBUG ===');
  print('Days: $days');
  
  try {
    final since = DateTime.now().subtract(Duration(days: days));
    final res = await _db
        .from('action_logs')
        .select('occurred_at')
        .gte('occurred_at', since.toIso8601String());
    print('Logged dates result: $res');
    
    final dates = (res as List)
        .map((e) => DateTime.parse(e['occurred_at'] as String).toLocal())
        .map((dt) => DateTime(dt.year, dt.month, dt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    print('Processed dates: $dates');
    return dates;
  } catch (e) {
    print('Error fetching logged dates: $e');
    rethrow;
  }
}

/// Berechnet die aktuelle Streak basierend auf zusammenhängenden Tagen,
/// ausgehend vom zuletzt geloggten Tag (nicht zwingend heute).
Future<int> calculateStreak() async {
  print('=== CALCULATE STREAK DEBUG (RPC) ===');
  try {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return 0;
    final res = await _db.rpc('calculate_streak', params: {'uid': uid});
    final rpc = (res is int) ? res : int.tryParse('$res') ?? 0;
    print('Calculated streak (RPC): $rpc');
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
    print('Error calculating streak (RPC/local): $e');
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