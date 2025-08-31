import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'models/action_models.dart';
import 'services/life_areas_service.dart';
import 'services/db_service.dart' as db_service;
import 'utils/app_theme.dart';
import 'utils/parsed_activity_data.dart';

enum DateFilter {
  week7(days: 7, label: '7 Days'),
  month30(days: 30, label: '30 Days'), 
  month90(days: 90, label: '3 Months'),
  year365(days: 365, label: '1 Year'),
  all(days: null, label: 'All Time');

  const DateFilter({required this.days, required this.label});
  final int? days;
  final String label;
}

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  DateFilter _selectedDateFilter = DateFilter.month30;
  List<String> _selectedLifeAreas = [];
  
  List<ActionLog> _activities = [];
  List<LifeArea> _lifeAreas = [];
  bool _isLoading = true;
  bool _isFilterLoading = false;
  
  // Statistics data
  Map<String, dynamic> _stats = {};
  Map<String, Color> _areaColorMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load life areas and activities in parallel using local storage
      final results = await Future.wait([
        _loadLifeAreas(),
        _loadActivities(),
      ]);
      
      setState(() {
        _lifeAreas = results[0] as List<LifeArea>;
        _activities = results[1] as List<ActionLog>;
      });
      
      await _calculateStatistics();
    } catch (e) {
      debugPrint('Error loading statistics data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<LifeArea>> _loadLifeAreas() async {
    try {
      // Use LifeAreasService which should work with local storage
      return await LifeAreasService.getLifeAreas();
    } catch (e) {
      debugPrint('Error loading life areas: $e');
      return [];
    }
  }

  Future<List<ActionLog>> _loadActivities() async {
    try {
      // Use local storage via db_service
      DateTime? since;
      if (_selectedDateFilter.days != null) {
        since = DateTime.now().subtract(Duration(days: _selectedDateFilter.days!));
      }
      
      var activities = await db_service.fetchLogs();
      // Loaded ${activities.length} activities from local storage
      
      // Apply date filter
      if (since != null) {
        // Applying date filter since $since
        activities = activities.where((activity) => activity.occurredAt.isAfter(since!)).toList();
        // After date filter: ${activities.length} activities
      }
      
      // Apply life area filter if selected
      if (_selectedLifeAreas.isNotEmpty) {
        return activities.where((activity) {
          final parsed = ParsedActivityData.fromNotes(activity.notes);
          final area = parsed.effectiveAreaName.toLowerCase();
          return _selectedLifeAreas.any((selected) => selected.toLowerCase() == area);
        }).toList();
      }

      return activities;
    } catch (e) {
      debugPrint('Error loading activities: $e');
      return [];
    }
  }

  Future<void> _calculateStatistics() async {
    // Calculating statistics with ${_activities.length} activities
    if (_activities.isEmpty) {
      // No activities, clearing stats
      setState(() {
        _stats = {};
      });
      return;
    }

    final now = DateTime.now();
    final startDate = _selectedDateFilter.days != null
        ? now.subtract(Duration(days: _selectedDateFilter.days!))
        : _activities.last.occurredAt;

    // Pre-load all area colors with subcategory inheritance
    _areaColorMap.clear();
    final existingAreaNames = <String>{};
    final existingCanonicalNames = <String>{};
    final allAreas = <LifeArea>[..._lifeAreas]; // Start with top-level areas
    
    if (kDebugMode) {
      print('Statistics Debug: Starting with ${_activities.length} total activities');
    }
    
    // Add top-level areas
    for (final area in _lifeAreas) {
      existingAreaNames.add(area.name);
      existingCanonicalNames.add(LifeAreasService.canonicalAreaName(area.name));
      if (kDebugMode) {
        print('Statistics Debug: Added top-level area: ${area.name}');
      }
      
      // Store color for top-level areas
      try {
        _areaColorMap[area.name] = Color(int.parse(area.color.replaceAll('#', '0xFF')));
      } catch (_) {
        _areaColorMap[area.name] = AppTheme.primaryColor;
      }
      
      // Add all subcategories for each area
      try {
        final childAreas = await LifeAreasService.getChildAreas(area.id);
        for (final child in childAreas) {
          allAreas.add(child); // Add to complete areas list
          existingAreaNames.add(child.name);
          existingCanonicalNames.add(LifeAreasService.canonicalAreaName(child.name));
          if (kDebugMode) {
            print('Statistics Debug: Added subcategory: ${child.name} under ${area.name}');
          }
          
          // Store color for subcategory (inherit from parent)
          try {
            final parentColor = Color(int.parse(area.color.replaceAll('#', '0xFF')));
            _areaColorMap[child.name] = parentColor;
          } catch (_) {
            _areaColorMap[child.name] = AppTheme.primaryColor;
          }
        }
      } catch (e) {
        debugPrint('Error loading child areas for ${area.name}: $e');
      }
    }
    
    if (kDebugMode) {
      print('Statistics Debug: Total existing area names: ${existingAreaNames.length}');
      print('Statistics Debug: Existing areas: ${existingAreaNames.toList()}');
    }
    
    final filteredActivities = _activities.where((activity) {
      final parsed = ParsedActivityData.fromNotes(activity.notes);
      final activityAreaName = parsed.effectiveAreaName;
      
      if (kDebugMode && activityAreaName.isNotEmpty) {
        final dayStr = activity.occurredAt.day.toString().padLeft(2, '0');
        final monthStr = activity.occurredAt.month.toString().padLeft(2, '0');
        print('Statistics Debug: Activity "${parsed.displayTitle}" in area "$activityAreaName" on ${dayStr}/${monthStr}, Duration: ${activity.durationMin}min');
      }
      
      if (activityAreaName.isEmpty) return true; // Keep activities without life area
      
      // First try exact name match
      if (existingAreaNames.contains(activityAreaName)) {
        if (kDebugMode) {
          print('Statistics Debug: ✓ Activity "$activityAreaName" matched exactly');
        }
        return true;
      }
      
      // Then try canonical name match
      final canonicalName = LifeAreasService.canonicalAreaName(activityAreaName);
      final matched = existingCanonicalNames.contains(canonicalName) || canonicalName == 'other' || canonicalName == 'unknown';
      
      if (kDebugMode) {
        print('Statistics Debug: ${matched ? '✓' : '✗'} Activity "$activityAreaName" (canonical: "$canonicalName") ${matched ? 'matched' : 'filtered out'}');
      }
      
      return matched;
    }).toList();
    
    if (kDebugMode) {
      print('Statistics Debug: After filtering: ${filteredActivities.length} activities remaining');
    }

    // Basic stats (only from existing life areas)
    final totalActivities = filteredActivities.length;
    final totalXP = filteredActivities.fold<int>(0, (sum, activity) => sum + activity.earnedXp);
    final totalMinutes = filteredActivities.fold<int>(0, (sum, activity) => sum + (activity.durationMin ?? 0));
    final avgXpPerDay = _selectedDateFilter.days != null 
        ? totalXP / _selectedDateFilter.days! 
        : totalXP / (now.difference(startDate).inDays + 1);

    // Calculated totalActivities=$totalActivities, totalXP=$totalXP

    // Life areas distribution
    final lifeAreasData = <String, Map<String, dynamic>>{};
    
    for (final activity in filteredActivities) {
      final parsed = ParsedActivityData.fromNotes(activity.notes);
      final areaName = parsed.effectiveAreaName.isNotEmpty 
          ? parsed.effectiveAreaName 
          : 'Other';
      
      lifeAreasData[areaName] = {
        'count': (lifeAreasData[areaName]?['count'] ?? 0) + 1,
        'xp': (lifeAreasData[areaName]?['xp'] ?? 0) + activity.earnedXp,
        'minutes': (lifeAreasData[areaName]?['minutes'] ?? 0) + (activity.durationMin ?? 0),
        'color': _areaColorMap[areaName] ?? _getColorForArea(areaName),
      };
    }

    // Build subcategory to parent mapping for efficient lookup
    final subcategoryToParentMap = <String, String>{};
    for (final area in _lifeAreas) {
      try {
        final childAreas = await LifeAreasService.getChildAreas(area.id);
        for (final child in childAreas) {
          subcategoryToParentMap[child.name] = area.name;
          if (kDebugMode) {
            print('Statistics Debug: Subcategory mapping: "${child.name}" -> "${area.name}"');
          }
        }
      } catch (e) {
        debugPrint('Error loading child areas for ${area.name}: $e');
      }
    }
    
    if (kDebugMode) {
      print('Statistics Debug: Total subcategory mappings: ${subcategoryToParentMap.length}');
    }

    // Daily activity chart data
    final dailyData = <DateTime, Map<String, int>>{};
    // Daily data per life area for stacked bar chart
    final dailyLifeAreasData = <DateTime, Map<String, int>>{};
    
    for (final activity in filteredActivities) {
      final day = DateTime(activity.occurredAt.year, activity.occurredAt.month, activity.occurredAt.day);
      final parsed = ParsedActivityData.fromNotes(activity.notes);
      final rawAreaName = parsed.effectiveAreaName.isNotEmpty 
          ? parsed.effectiveAreaName 
          : 'Other';
      // Ensure minimum 1 minute for activities to be visible in charts
      final minutes = activity.durationMin ?? 1;
      
      // For daily charts, group subcategories under their parent life area
      final displayAreaName = subcategoryToParentMap[rawAreaName] ?? rawAreaName;
      
      if (kDebugMode) {
        final dayStr = day.day.toString().padLeft(2, '0');
        final monthStr = day.month.toString().padLeft(2, '0');
        if (rawAreaName != displayAreaName) {
          print('Daily Chart: Mapping subcategory "$rawAreaName" to parent "$displayAreaName" for ${dayStr}/${monthStr} (${minutes}min)');
        } else if (minutes > 0) {
          print('Daily Chart: Direct activity "$rawAreaName" for ${dayStr}/${monthStr} (${minutes}min)');
        }
      }
      
      // Overall daily data (only from existing life areas)
      dailyData[day] = {
        'count': (dailyData[day]?['count'] ?? 0) + 1,
        'xp': (dailyData[day]?['xp'] ?? 0) + activity.earnedXp,
        'minutes': (dailyData[day]?['minutes'] ?? 0) + minutes,
      };
      
      // Daily data per life area (use parent life area for subcategories)
      if (dailyLifeAreasData[day] == null) {
        dailyLifeAreasData[day] = {};
      }
      dailyLifeAreasData[day]![displayAreaName] = 
          (dailyLifeAreasData[day]![displayAreaName] ?? 0) + minutes;
    }
    
    if (kDebugMode) {
      print('Statistics Debug: Final daily chart data:');
      dailyLifeAreasData.forEach((date, areas) {
        final dayStr = date.day.toString().padLeft(2, '0');
        final monthStr = date.month.toString().padLeft(2, '0');
        print('  ${dayStr}/${monthStr}: $areas');
      });
    }

    // Weekly pattern (0 = Monday, 6 = Sunday)
    final weeklyPattern = List.generate(7, (index) => 0);
    for (final activity in filteredActivities) {
      final weekday = activity.occurredAt.weekday - 1; // Convert to 0-6
      weeklyPattern[weekday]++;
    }

    // Hourly pattern calculation removed

    // Current streak calculation
    int currentStreak = 0;
    final sortedDays = dailyData.keys.toList()..sort();
    if (sortedDays.isNotEmpty) {
      DateTime checkDate = DateTime.now();
      checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
      
      // Allow for today or yesterday to start the streak
      if (!dailyData.containsKey(checkDate)) {
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
      
      while (dailyData.containsKey(checkDate)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    }

    final newStats = {
      'totalActivities': totalActivities,
      'totalXP': totalXP,
      'totalMinutes': totalMinutes,
      'avgXpPerDay': avgXpPerDay,
      'currentStreak': currentStreak,
      'lifeAreasData': lifeAreasData,
      'dailyData': dailyData,
      'dailyLifeAreasData': dailyLifeAreasData,
      'weeklyPattern': weeklyPattern,
    };

    // Setting new stats with totalActivities=${newStats['totalActivities']}
    
    setState(() {
      _stats = newStats;
    });

    // Verify the state was updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // After setState, _stats[totalActivities]=${_stats['totalActivities']}
    });
  }

  Color _getColorForArea(String areaName) {
    // First try to find the actual life area and use its color
    final area = _lifeAreas.firstWhere(
      (area) => area.name.toLowerCase() == areaName.toLowerCase(),
      orElse: () => LifeArea(
        id: '', 
        name: '', 
        category: '', 
        color: '#64748B', 
        userId: '', 
        icon: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        orderIndex: 0,
      ),
    );
    
    // Use the actual life area color if found
    if (area.id.isNotEmpty) {
      try {
        return Color(int.parse(area.color.replaceAll('#', '0xFF')));
      } catch (_) {
        // If color parsing fails, continue to fallback
      }
    }
    
    // Fallback color palette for common areas (only if life area not found)
    final fallbackColors = {
      'fitness': const Color(0xFF10B981), // Emerald
      'nutrition': const Color(0xFF06B6D4), // Cyan  
      'learning': const Color(0xFF8B5CF6), // Purple
      'finance': const Color(0xFFF59E0B), // Amber
      'art': const Color(0xFFEF4444), // Red
      'relationships': const Color(0xFFEC4899), // Pink
      'spirituality': const Color(0xFF6366F1), // Indigo
      'career': const Color(0xFF0EA5E9), // Sky
      'other': const Color(0xFF64748B), // Slate
    };
    
    // Try to match fallback by name (case insensitive)
    final colorKey = fallbackColors.keys.firstWhere(
      (key) => key.toLowerCase() == areaName.toLowerCase(),
      orElse: () => '',
    );
    
    if (colorKey.isNotEmpty) {
      return fallbackColors[colorKey]!;
    }
    
    // Final fallback to primary color
    return AppTheme.primaryColor;
  }

  void _updateFilters() async {
    if (_activities.isEmpty) {
      _loadData();
      return;
    }
    
    setState(() => _isFilterLoading = true);
    
    try {
      // Instead of reloading all data, just recalculate with existing activities
      await _reloadActivitiesWithFilter();
      await _calculateStatistics();
    } catch (e) {
      debugPrint('Error updating filters: $e');
    } finally {
      setState(() => _isFilterLoading = false);
    }
  }

  Future<void> _reloadActivitiesWithFilter() async {
    try {
      // Use local storage via db_service
      DateTime? since;
      if (_selectedDateFilter.days != null) {
        since = DateTime.now().subtract(Duration(days: _selectedDateFilter.days!));
      }
      
      var activities = await db_service.fetchLogs();
      
      // Apply date filter
      if (since != null) {
        activities = activities.where((activity) => activity.occurredAt.isAfter(since!)).toList();
      }

      // Apply life area filter if selected
      if (_selectedLifeAreas.isNotEmpty) {
        _activities = activities.where((activity) {
          final parsed = ParsedActivityData.fromNotes(activity.notes);
          final area = parsed.effectiveAreaName.toLowerCase();
          return _selectedLifeAreas.any((selected) => selected.toLowerCase() == area);
        }).toList();
      } else {
        _activities = activities;
      }
    } catch (e) {
      debugPrint('Error reloading activities: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Statistics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilters(),
                    SizedBox(height: AppTheme.spacing24),
                    _buildOverviewCards(),
                    SizedBox(height: AppTheme.spacing24),
                    _buildActivityTrendChart(),
                    SizedBox(height: AppTheme.spacing24),
                    _buildDailyStackedBarChart(),
                    SizedBox(height: AppTheme.spacing24),
                    _buildLifeAreasChart(),
                    SizedBox(height: AppTheme.spacing24),
                    _buildWeeklyPatternChart(),
                    SizedBox(height: AppTheme.spacing24),
                    _buildTopActivities(),
                  ],
                ),
              ),
            ),
                
                // Filter loading overlay
                if (_isFilterLoading)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Updating...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.8),
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Date filter
          const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: DateFilter.values.map((filter) {
              return FilterChip(
                label: Text(filter.label),
                selected: _selectedDateFilter == filter,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedDateFilter = filter);
                    _updateFilters();
                  }
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Life areas filter
          const Text('Life Areas:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          if (_lifeAreas.isNotEmpty)
            Wrap(
              spacing: 8,
              children: _lifeAreas.map((area) {
                return FilterChip(
                  label: Text(area.name),
                  selected: _selectedLifeAreas.contains(area.name),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLifeAreas.add(area.name);
                      } else {
                        _selectedLifeAreas.remove(area.name);
                      }
                    });
                    _updateFilters();
                  },
                );
              }).toList(),
            ),
          
          if (_selectedLifeAreas.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() => _selectedLifeAreas.clear());
                _updateFilters();
              },
              child: const Text('Clear all filters'),
            ),
          ],
        ],
      ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final totalActivities = _stats['totalActivities'] ?? 0;
    final totalXP = _stats['totalXP'] ?? 0;
    final totalMinutes = _stats['totalMinutes'] ?? 0;
    final avgXpPerDay = _stats['avgXpPerDay'] ?? 0.0;
    final currentStreak = _stats['currentStreak'] ?? 0;

    // Building overview cards

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 1.1,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _buildStatCard(
              'Total Activities',
              totalActivities.toString(),
              Icons.check_circle_outline,
              AppTheme.primaryColor,
            ),
            _buildStatCard(
              'Total XP',
              totalXP.toString(),
              Icons.star_outline,
              AppTheme.successColor,
            ),
            _buildStatCard(
              'Time Spent',
              '${(totalMinutes / 60).toStringAsFixed(1)}h',
              Icons.schedule,
              AppTheme.warningColor,
            ),
            _buildStatCard(
              'Current Streak',
              '$currentStreak days',
              Icons.local_fire_department,
              AppTheme.errorColor,
            ),
            _buildStatCard(
              'Avg XP/Day',
              avgXpPerDay.toStringAsFixed(1),
              Icons.trending_up,
              Colors.purple,
            ),
            _buildStatCard(
              'Avg Session',
              totalActivities > 0 ? '${(totalMinutes / totalActivities).toStringAsFixed(0)}min' : '0min',
              Icons.access_time,
              Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
          ),
        ],
      ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityTrendChart() {
    final dailyData = _stats['dailyData'] as Map<DateTime, Map<String, int>>? ?? {};
    
    if (dailyData.isEmpty) {
      return _buildEmptyChart('Activity Trend', 'No activity data available');
    }

    final spots = <FlSpot>[];
    final sortedDays = dailyData.keys.toList()..sort();
    
    for (int i = 0; i < sortedDays.length; i++) {
      final day = sortedDays[i];
      final count = dailyData[day]?['count'] ?? 0;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    return _buildChartContainer(
      'Activity Trend',
      SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                  strokeWidth: 0.5,
                  dashArray: [5, 5],
                );
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: math.max(1, (spots.length / 5).ceil()).toDouble(),
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < sortedDays.length) {
                      final date = sortedDays[index];
                      return Text(
                        '${date.day}/${date.month}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.7),
                  ],
                ),
                barWidth: 4,
                isStrokeCapRound: true,
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.3),
                      AppTheme.primaryColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                dotData: FlDotData(
                  show: spots.length <= 31, // Only show dots for smaller datasets
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: AppTheme.primaryColor,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLifeAreasChart() {
    final lifeAreasData = _stats['lifeAreasData'] as Map<String, Map<String, dynamic>>? ?? {};
    
    if (lifeAreasData.isEmpty) {
      return _buildEmptyChart('Life Areas Distribution', 'No life area data available');
    }

    final sections = <PieChartSectionData>[];
    final total = lifeAreasData.values.fold<int>(0, (sum, data) => sum + (data['minutes'] as int));
    
    lifeAreasData.forEach((area, data) {
      final minutes = data['minutes'] as int;
      final percentage = total > 0 ? (minutes / total) * 100 : 0;
      
      sections.add(
        PieChartSectionData(
          value: percentage.toDouble(),
          title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '',
          color: data['color'] as Color,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return _buildChartContainer(
      'Time Distribution by Life Areas',
      Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: lifeAreasData.entries.map((entry) {
              final area = entry.key;
              final data = entry.value;
              final minutes = data['minutes'] as int;
              return Container(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: data['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$area (${(minutes / 60).toStringAsFixed(1)}h)',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPatternChart() {
    final weeklyPattern = _stats['weeklyPattern'] as List<int>? ?? [];
    
    if (weeklyPattern.isEmpty || weeklyPattern.every((count) => count == 0)) {
      return _buildEmptyChart('Weekly Pattern', 'No weekly activity data available');
    }

    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final barGroups = <BarChartGroupData>[];
    
    for (int i = 0; i < weeklyPattern.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: weeklyPattern[i].toDouble(),
              color: AppTheme.primaryColor,
              width: 30,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return _buildChartContainer(
      'Most Productive Days',
      SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: weeklyPattern.reduce(math.max).toDouble() * 1.2,
            barGroups: barGroups,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                  strokeWidth: 0.5,
                  dashArray: [5, 5],
                );
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < weekDays.length) {
                      return Text(
                        weekDays[index],
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyStackedBarChart() {
    final dailyLifeAreasData = _stats['dailyLifeAreasData'] as Map<DateTime, Map<String, int>>? ?? {};
    final lifeAreasData = _stats['lifeAreasData'] as Map<String, Map<String, dynamic>>? ?? {};
    
    if (dailyLifeAreasData.isEmpty) {
      return _buildEmptyChart('Daily Activity Hours', 'No daily activity data available');
    }

    final sortedDays = dailyLifeAreasData.keys.toList()..sort();
    final lifeAreaNames = <String>{};
    
    // Collect all life area names
    for (final dayData in dailyLifeAreasData.values) {
      lifeAreaNames.addAll(dayData.keys);
    }
    
    final sortedLifeAreas = lifeAreaNames.toList()..sort();
    final barGroups = <BarChartGroupData>[];
    
    // Create stacked bar chart data
    for (int dayIndex = 0; dayIndex < sortedDays.length; dayIndex++) {
      final day = sortedDays[dayIndex];
      final dayData = dailyLifeAreasData[day]!;
      final barRods = <BarChartRodStackItem>[];
      
      double stackY = 0.0;
      for (final lifeArea in sortedLifeAreas) {
        final minutes = dayData[lifeArea] ?? 0;
        if (minutes > 0) {
          final hours = minutes / 60.0;
          final color = _areaColorMap[lifeArea] ?? _getColorForArea(lifeArea);
          
          barRods.add(BarChartRodStackItem(
            stackY,
            stackY + hours,
            color,
          ));
          stackY += hours;
        }
      }
      
      barGroups.add(
        BarChartGroupData(
          x: dayIndex,
          barRods: [
            BarChartRodData(
              toY: stackY,
              width: 20,
              rodStackItems: barRods,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    // Calculate max Y value
    final maxHours = barGroups.isEmpty ? 1.0 : barGroups
        .map((group) => group.barRods.first.toY)
        .reduce(math.max) * 1.2;

    return _buildChartContainer(
      'Daily Activity Hours',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxHours,
                barGroups: barGroups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1.0, maxHours / 6),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                      strokeWidth: 0.5,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 1.0, // Show at every hour
                      getTitlesWidget: (value, meta) {
                        final intValue = value.toInt();
                        // Only show labels at whole hours and avoid showing the top label if it's too close
                        if (value == intValue.toDouble() && intValue >= 0 && intValue < maxHours - 0.5) {
                          return Text(
                            '${intValue}h',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sortedDays.length) {
                          final day = sortedDays[value.toInt()];
                          final monthDay = '${day.month}/${day.day}';
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              monthDay,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: sortedLifeAreas.map((lifeArea) {
              final color = _areaColorMap[lifeArea] ?? _getColorForArea(lifeArea);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    lifeArea,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActivities() {
    if (_activities.isEmpty) return const SizedBox();

    // Count activity occurrences by title
    final activityCounts = <String, int>{};
    for (final activity in _activities) {
      final parsed = ParsedActivityData.fromNotes(activity.notes);
      final title = activity.activityName?.isNotEmpty == true 
          ? activity.activityName! 
          : parsed.displayTitle;
      activityCounts[title] = (activityCounts[title] ?? 0) + 1;
    }

    final sortedActivities = activityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topActivities = sortedActivities.take(10).toList();

    return _buildChartContainer(
      'Most Frequent Activities',
      Column(
        children: topActivities.asMap().entries.map((entry) {
          final index = entry.key;
          final activityEntry = entry.value;
          final title = activityEntry.key;
          final count = activityEntry.value;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Text(
                    '$count times',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartContainer(String title, Widget chart) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                chart,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChart(String title, String message) {
    return _buildChartContainer(
      title,
      SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}