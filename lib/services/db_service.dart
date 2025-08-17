import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'achievement_service.dart';
import '../repository/logs_repository.dart';
import '../repository/templates_repository.dart';
import '../repository/stats_repository.dart';
import '../models/action_models.dart' as models;
import '../navigation.dart';
import '../utils/logging_service.dart';
import '../utils/xp_calculator.dart';

final _db = Supabase.instance.client;
final LogsRepository _logsRepo = LogsRepository(_db);
final TemplatesRepository _templatesRepo = TemplatesRepository(_db);
final StatsRepository _statsRepo = StatsRepository(_db);

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
  } catch (e) {
    if (kDebugMode) debugPrint('Error extracting title from notes: $e');
  }
  return null;
}

/// Templates laden
Future<List<ActionTemplate>> fetchTemplates() async => _templatesRepo.fetchTemplates();

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

// Clientseitige XP-Berechnung abgeschafft; Quelle ist die Edge Function `calculate-xp`.
// Für Ausfallsicherheit behalten wir eine Fallback-Berechnung im Client bei,
// falls der Edge-Call (Netzwerk/CORS) fehlschlägt.
int calculateEarnedXpFallback({int? durationMin, String? notes, String? imageUrl}) {
  final int timeMinutes = durationMin ?? 0;
  int xp = timeMinutes ~/ 5; // 1 XP je 5 Minuten
  final int textLen = _estimatePlainTextLength(notes);
  xp += textLen ~/ 100; // 1 XP je 100 Zeichen
  final bool hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
  if (hasImage) {
    xp += 2; // statischer Bildbonus
  }
  if (xp <= 0 && (timeMinutes > 0 || textLen > 0 || hasImage)) xp = 1;
  return xp;
}

/// Log anlegen mit client-seitiger XP-Berechnung
Future<ActionLog> createLog({
  required String templateId,
  int? durationMin,
  String? notes,
  String? imageUrl,
}) async {
  final log = await _logsRepo.createLog(
    templateId: templateId,
    durationMin: durationMin,
    notes: notes,
    imageUrl: imageUrl,
  );
  _checkAchievementsAfterLogInsert();
  try { 
    notifyLogsChanged(); 
  } catch (e, stackTrace) {
    LoggingService.error('Failed to notify logs changed after createLog', e, stackTrace, 'DbService');
  }
  return log;
}

/// Quick Log ohne Template erstellen
Future<ActionLog> createQuickLog({
  required String activityName,
  required String category,
  int? durationMin,
  String? notes,
  String? imageUrl,
}) async {
  final log = await _logsRepo.createQuickLog(
    activityName: activityName,
    category: category,
    durationMin: durationMin,
    notes: notes,
    imageUrl: imageUrl,
  );
  await _checkAchievementsAfterLogInsert();
  try { 
    notifyLogsChanged(); 
  } catch (e, stackTrace) {
    LoggingService.error('Failed to notify logs changed after createLog', e, stackTrace, 'DbService');
  }
  return log;
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
        } catch (e) {
          if (kDebugMode) debugPrint('Error parsing log notes for achievements: $e');
        }
      }
      lifeAreaCount = rolledParents.where((k) => k != 'unknown').length;
    } catch (e) {
      if (kDebugMode) debugPrint('Error calculating life area count for achievements: $e');
    }

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
Future<List<ActionLog>> fetchLogs() async => _logsRepo.fetchLogs();

/// Gesamt-XP berechnen
Future<int> fetchTotalXp() async => _logsRepo.fetchTotalXp();

/// Aggregierte Aktivitäten pro Tag und Bereich (serverseitig via RPC)
Future<Map<DateTime, Map<String, int>>> fetchDailyAreaTotals({
  required DateTime month,
}) async => _statsRepo.fetchDailyAreaTotals(month: month);

/// Detaillierte Aggregation (Count, Dauer, XP) pro Tag und Bereich via RPC
Future<Map<DateTime, List<Map<String, dynamic>>>> fetchDailyAreaTotalsDetailed({
  required DateTime month,
}) async => _statsRepo.fetchDailyAreaTotalsDetailed(month: month);

/// XP-Schwelle für Level n (lineares System: 100 XP pro Level)
int xpForLevel(int level) => level * 100;

/// Level aus Gesamt-XP berechnen (lineares System: 100 XP pro Level)
int calculateLevel(int totalXp) {
  if (totalXp <= 0) return 1;
  return (totalXp / 100).floor() + 1;
}

/// Ausführliche Level-Progress-Infos: aktuelles Level, XP seit Levelstart, XP bis nächstes Level
Map<String, int> calculateLevelDetailed(int totalXp) {
  final level = calculateLevel(totalXp);
  // 100 XP pro Level
  final xpInto = totalXp % 100; // XP im aktuellen Level (Rest der Division)
  const xpNeeded = 100; // Jedes Level benötigt 100 XP
  
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
Future<int> calculateStreak() async => _logsRepo.calculateStreak();

/// Alias für fetchStreak, damit der Dashboard-Code passt
Future<int> fetchStreak() => calculateStreak();

/// Badge-Level (0=keine,1=Bronze,2=Silber,3=Gold)
int badgeLevel(int streak) {
  if (streak >= 30) return 3;
  if (streak >= 7)  return 2;
  if (streak >= 3)  return 1;
  return 0;
}