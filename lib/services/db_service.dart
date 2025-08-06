import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        activityName: m['activity_name']   as String?,
        imageUrl:    m['image_url']       as String?,
      );
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

/// Client-seitige XP-Berechnung (spiegelt Edge Function)
int calculateEarnedXp(int baseXp, int? durationMin, int streak) {
  int earnedXp = baseXp;
  
  // Duration bonus (every 10 minutes = +1 XP)
  if (durationMin != null) {
    earnedXp += durationMin ~/ 10;
  }
  
  // Streak bonus (if user has a streak >= 7 days)
  if (streak >= 7) {
    earnedXp += 2;
  }
  
  return earnedXp;
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

  // Aktuelle Streak holen für XP-Berechnung
  final currentStreak = await calculateStreak();
  
  // Client-seitige XP-Berechnung
  final earnedXp = calculateEarnedXp(baseXp, durationMin, currentStreak);

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
  // Aktuelle Streak holen für XP-Berechnung
  final currentStreak = await calculateStreak();
  
  // Standard-XP für Quick-Logs (25 XP)
  final baseXp = 25;
  
  // Client-seitige XP-Berechnung
  final earnedXp = calculateEarnedXp(baseXp, durationMin, currentStreak);

  // Eintrag zusammenbauen und schreiben (ohne template_id und activity_name für jetzt)
  final insert = <String, dynamic>{
    'user_id':      _db.auth.currentUser!.id,
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

  return ActionLog.fromMap(out);
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

/// XP-Schwelle für Level n
int xpForLevel(int level) => (100 * pow(level.toDouble(), 1.5)).round();

/// Level aus Gesamt-XP berechnen
/// Gibt ein Map mit 'level', 'xpInto' und 'xpNext' zurück.
Map<String, int> calculateLevel(int totalXp) {
  int level = 1;
  while (totalXp >= xpForLevel(level + 1)) level++;
  final xpThis = xpForLevel(level);
  final xpNext = xpForLevel(level + 1);
  return {
    'level':  level,
    'xpInto': totalXp - xpThis,
    'xpNext': xpNext - xpThis,
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

/// Berechnet die aktuelle Streak basierend auf fetchLoggedDates
Future<int> calculateStreak() async {
  print('=== CALCULATE STREAK DEBUG ===');
  try {
    final dates = await fetchLoggedDates(30);
    if (dates.isEmpty) return 0;
    int streak = 0;
    DateTime cursor = DateTime.now();
    while (true) {
      final day = DateTime(cursor.year, cursor.month, cursor.day);
      if (dates.contains(day)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    print('Calculated streak: $streak');
    return streak;
  } catch (e) {
    print('Error calculating streak: $e');
    rethrow;
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