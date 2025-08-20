// Legacy compatibility wrapper for focused services
// This file provides backward compatibility while the new focused services take over

import '../models/action_models.dart' as models;
import 'storage_service.dart';
import 'template_service.dart';
import 'log_service.dart';
import 'data_cache_service.dart';
import 'xp_service.dart';
import 'streak_service.dart';

// ===== LEGACY COMPATIBILITY WRAPPERS =====
// Delegate to new focused services while maintaining API compatibility

/// Model for an action template
typedef ActionTemplate = models.ActionTemplate;

/// Model for an action log
typedef ActionLog = models.ActionLog;

// ===== STORAGE MANAGEMENT =====

/// Switch between local and remote storage
void setStorageMode({required bool useLocal}) => StorageService.setStorageMode(useLocal: useLocal);

/// Get current storage mode
bool get isUsingLocalStorage => StorageService.isUsingLocalStorage;

/// Get database info and stats
Future<Map<String, dynamic>> getDatabaseInfo() => StorageService.getDatabaseInfo();

// ===== TEMPLATES =====

/// Load templates
Future<List<ActionTemplate>> fetchTemplates() => TemplateService.fetchTemplates();

// ===== XP AND LEVELS =====

/// Try to extract a 'title' from notes JSON wrapper
String? extractTitleFromNotes(dynamic notesValue) => XpService.extractTitleFromNotes(notesValue);

/// XP threshold for level n
int xpForLevel(int level) => XpService.xpForLevel(level);

/// Calculate level from total XP
int calculateLevel(int totalXp) => XpService.calculateLevel(totalXp);

/// Detailed level progress info
Map<String, int> calculateLevelDetailed(int totalXp) => XpService.calculateLevelDetailed(totalXp);

/// Client-side fallback XP calculation
int calculateEarnedXpFallback({int? durationMin, String? notes, String? imageUrl}) => 
    XpService.calculateEarnedXpFallback(durationMin: durationMin, notes: notes, imageUrl: imageUrl);

// ===== LOGS =====

/// Create log with client-side XP calculation
Future<ActionLog> createLog({
  required String templateId,
  int? durationMin,
  String? notes,
  String? imageUrl,
}) => LogService.createLog(
  templateId: templateId,
  durationMin: durationMin,
  notes: notes,
  imageUrl: imageUrl,
);

/// Create quick log without template
Future<ActionLog> createQuickLog({
  required String activityName,
  required String category,
  int? durationMin,
  String? notes,
  String? imageUrl,
}) => LogService.createQuickLog(
  activityName: activityName,
  category: category,
  durationMin: durationMin,
  notes: notes,
  imageUrl: imageUrl,
);

/// Load all logs (cached for performance)
Future<List<ActionLog>> fetchLogs() => DataCacheService().getLogs();

/// Delete a log entry
Future<void> deleteLog(String logId) => LogService.deleteLog(logId);

/// Calculate total XP
Future<int> fetchTotalXp() => LogService.fetchTotalXp();

/// Aggregated activities per day and area
Future<Map<DateTime, Map<String, int>>> fetchDailyAreaTotals({
  required DateTime month,
}) => LogService.fetchDailyAreaTotals(month: month);

/// Detailed aggregation per day and area
Future<Map<DateTime, List<Map<String, dynamic>>>> fetchDailyAreaTotalsDetailed({
  required DateTime month,
}) => LogService.fetchDailyAreaTotalsDetailed(month: month);

// ===== STREAKS =====

/// Load all logged dates from the last [days] days
Future<List<DateTime>> fetchLoggedDates(int days) => StreakService.fetchLoggedDates(days);

/// Calculate current streak
Future<int> calculateStreak() => StreakService.calculateStreak();

/// Alias for calculateStreak, for dashboard code compatibility
Future<int> fetchStreak() => StreakService.fetchStreak();

/// Badge level (0=none, 1=Bronze, 2=Silver, 3=Gold)
int badgeLevel(int streak) => StreakService.badgeLevel(streak);