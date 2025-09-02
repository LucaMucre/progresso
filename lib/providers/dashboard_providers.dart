import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/action_models.dart' as models;
import '../services/db_service.dart';
import '../services/life_areas_service.dart';

/// Provider for loading dashboard logs
final dashboardLogsProvider = FutureProvider.autoDispose<List<models.ActionLog>>((ref) async {
  return await fetchLogs();
});

/// Provider for loading life areas
final lifeAreasProvider = FutureProvider.autoDispose<List<LifeArea>>((ref) async {
  return await LifeAreasService.getLifeAreas();
});

/// State provider for area filter
final areaFilterProvider = StateProvider<String?>((ref) => null);

/// State provider for calendar view mode
final calendarViewModeProvider = StateProvider<CalendarViewMode>((ref) => CalendarViewMode.month);

/// State provider for selected calendar date
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Computed provider for filtered logs based on area filter
final filteredLogsProvider = Provider.autoDispose<AsyncValue<List<models.ActionLog>>>((ref) {
  final logsAsync = ref.watch(dashboardLogsProvider);
  final areaFilter = ref.watch(areaFilterProvider);
  
  return logsAsync.when(
    data: (logs) {
      if (areaFilter == null) {
        return AsyncValue.data(logs);
      }
      final filtered = logs.where((log) {
        // Implement area filtering logic here
        return _logMatchesArea(log, areaFilter);
      }).toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for dashboard statistics
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final logs = await ref.watch(dashboardLogsProvider.future);
  return _calculateStats(logs);
});

/// Enum for calendar view modes
enum CalendarViewMode { month, week }

/// Dashboard statistics model
class DashboardStats {
  final int totalActions;
  final int totalXp;
  final int currentStreak;
  final Map<String, int> areaActivityCounts;
  
  DashboardStats({
    required this.totalActions,
    required this.totalXp,
    required this.currentStreak,
    required this.areaActivityCounts,
  });
}

/// Helper function to check if log matches area filter
bool _logMatchesArea(models.ActionLog log, String areaFilter) {
  // This would contain the logic from the original dashboard
  // for matching logs to area filters
  return true; // Simplified for now
}

/// Helper function to calculate dashboard statistics
DashboardStats _calculateStats(List<models.ActionLog> logs) {
  final totalActions = logs.length;
  final totalXp = logs.fold<int>(0, (sum, log) => sum + log.earnedXp.toInt());
  
  // Calculate area activity counts
  final Map<String, int> areaActivityCounts = {};
  for (final _ in logs) {
    // Parse area from notes or template
    final area = 'General'; // Simplified for now
    areaActivityCounts[area] = (areaActivityCounts[area] ?? 0) + 1;
  }
  
  return DashboardStats(
    totalActions: totalActions,
    totalXp: totalXp,
    currentStreak: 0, // Would calculate from logs
    areaActivityCounts: areaActivityCounts,
  );
}