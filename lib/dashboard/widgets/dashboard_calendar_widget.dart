import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../../services/life_areas_service.dart';
import '../../services/app_state.dart';
import '../../models/action_models.dart' as models;
import '../../widgets/activity_details_dialog.dart';
import '../../utils/parsed_activity_data.dart';
import 'calendar_header.dart';
import 'calendar_grid.dart';

class _DayEntry {
  final String title;
  final Color color;
  final String areaKey;
  final int durationMin;

  _DayEntry({
    required this.title,
    required this.color,
    required this.areaKey,
    required this.durationMin,
  });
}

/// Extrahiertes Kalender-Widget aus dem Dashboard
/// Reduziert die Dashboard-Komplexität erheblich
class DashboardCalendarWidget extends ConsumerStatefulWidget {
  final String? selectedAreaFilterName;
  final Function(String?) onAreaSelected;
  final Function(DateTime, List<models.ActionLog>) onOpenDay;
  final List<models.ActionLog>? logs; // Pass logs directly from dashboard
  final List<LifeArea>? lifeAreas; // Pass life areas directly from dashboard

  const DashboardCalendarWidget({
    super.key,
    this.selectedAreaFilterName,
    required this.onAreaSelected,
    required this.onOpenDay,
    this.logs,
    this.lifeAreas,
  });

  @override
  ConsumerState<DashboardCalendarWidget> createState() => _DashboardCalendarWidgetState();
}

class _DashboardCalendarWidgetState extends ConsumerState<DashboardCalendarWidget> {
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Future<List<LifeArea>>? _lifeAreasFuture;
  Map<DateTime, List<_DayEntry>>? _cachedCalendarData;
  List<models.ActionLog>? _lastLogs;
  List<LifeArea>? _lastAreas;

  @override
  void initState() {
    super.initState();
    _loadLifeAreas();
  }

  Future<void> _loadLifeAreas() async {
    _lifeAreasFuture = LifeAreasService.getLifeAreas();
  }

  void _goToPreviousMonth() {
    setState(() {
      _calendarMonth = DateTime(
        _calendarMonth.year,
        _calendarMonth.month - 1,
      );
      // Clear cache when month changes
      _cachedCalendarData = null;
    });
  }

  void _goToNextMonth() {
    setState(() {
      _calendarMonth = DateTime(
        _calendarMonth.year,
        _calendarMonth.month + 1,
      );
      // Clear cache when month changes
      _cachedCalendarData = null;
    });
  }

  bool _dataChanged(List<models.ActionLog> logs, List<LifeArea> areas) {
    if (_lastLogs == null || _lastAreas == null) return true;
    if (_lastLogs!.length != logs.length || _lastAreas!.length != areas.length) return true;
    // Simple comparison - could be optimized further if needed
    return false;
  }

  Future<Map<DateTime, List<_DayEntry>>> _getCachedCalendarData(
    List<models.ActionLog> logs,
    List<LifeArea> areas,
  ) async {
    // Return cached data if nothing changed
    if (_cachedCalendarData != null && !_dataChanged(logs, areas)) {
      return _cachedCalendarData!;
    }

    // Recompute and cache
    final newData = await _loadCalendarData(logs, areas);
    _cachedCalendarData = newData;
    _lastLogs = List.from(logs);
    _lastAreas = List.from(areas);
    return newData;
  }

  Future<Map<DateTime, List<_DayEntry>>> _loadCalendarData(
    List<models.ActionLog> logs,
    List<LifeArea> areas,
  ) async {
    try {
      // Loading calendar data
      
      // Create area map with ALL areas (including subcategories) and complete areas list
      final areaMap = <String, LifeArea>{};
      final allAreas = <LifeArea>[...areas]; // Start with top-level areas
      
      // First add all top-level areas
      for (final a in areas) {
        areaMap[a.name] = a;
        areaMap[a.name.toLowerCase()] = a; // Also add lowercase version for case-insensitive matching
      }
      
      // Then recursively add all subcategories
      for (final area in areas) {
        try {
          final childAreas = await LifeAreasService.getChildAreas(area.id);
          for (final child in childAreas) {
            allAreas.add(child); // Add to complete areas list for parent lookup
            areaMap[child.name] = child;
            areaMap[child.name.toLowerCase()] = child; // Also add lowercase version
            if (kDebugMode && child.name == 'drei') {
              if (kDebugMode) debugPrint('Calendar Loading: Subcategory ${child.name} has parentId: ${child.parentId}, parent: ${area.name}');
            }
            // Added subcategory to areaMap
          }
        } catch (e) {
          if (kDebugMode) {
            if (kDebugMode) debugPrint('Error loading child areas for ${area.name}: $e');
          }
        }
      }

      final dayToTitles = <DateTime, List<_DayEntry>>{};

      if (kDebugMode) debugPrint('Calendar: Processing ${logs.length} logs for month ${_calendarMonth.month}/${_calendarMonth.year}');
      
      for (final log in logs) {
        final d = log.occurredAt.toLocal();
        final dayKey = DateTime(d.year, d.month, d.day);
        
        if (dayKey.year != _calendarMonth.year || dayKey.month != _calendarMonth.month) {
          continue;
        }

        String title = 'Activity';
        Color tagColor = Colors.grey;
        String areaKey = 'unknown';
        int durationMin = log.durationMin ?? 0;
        
        // Processing log entry

        if (log.notes != null) {
          try {
            final obj = jsonDecode(log.notes!);
            if (obj is Map<String, dynamic>) {
              // Extract title from JSON - same logic as List view
              if (obj['title'] != null && obj['title'].toString().trim().isNotEmpty) {
                title = obj['title'].toString().trim();
              } else {
                // Try to extract from Quill delta format  
                final delta = obj['delta'] ?? obj['ops'];
                if (delta is List && delta.isNotEmpty) {
                  final textParts = <String>[];
                  for (final op in delta) {
                    if (op is Map && op['insert'] is String) {
                      textParts.add(op['insert'].toString());
                    }
                  }
                  if (textParts.isNotEmpty) {
                    final allText = textParts.join('').trim();
                    final firstLine = allText.split('\n').first.trim();
                    if (firstLine.isNotEmpty && firstLine.length <= 30) {
                      title = firstLine;
                    }
                  }
                }
              }
              
              // Extract area information
              final area = obj['area'] as String?;
              final lifeArea = obj['life_area'] as String?;
              final category = obj['category'] as String?; // For quick logs
              
              final searchName = area?.trim() ?? lifeArea?.trim() ?? category?.trim() ?? '';
              if (searchName.isNotEmpty) {
                areaKey = searchName;
                // Try both exact match and lowercase match
                final areaObj = areaMap[searchName] ?? areaMap[searchName.toLowerCase()];
                if (areaObj != null) {
                  try {
                    String colorString;
                    
                    // If this is a subcategory (has parentId), use parent's color
                    if (areaObj.parentId != null) {
                      if (kDebugMode) debugPrint('Calendar Color: Subcategory ${areaObj.name} has parentId: ${areaObj.parentId}');
                      // Find parent area and use its color
                      final parentArea = allAreas.firstWhere(
                        (area) => area.id == areaObj.parentId,
                        orElse: () => areaObj, // Fallback to own color
                      );
                      if (kDebugMode) debugPrint('Calendar Color: Found parent: ${parentArea.name} with color: ${parentArea.color}');
                      colorString = parentArea.color;
                    } else {
                      colorString = areaObj.color;
                      if (kDebugMode && searchName == 'drei') {
                        if (kDebugMode) debugPrint('Calendar Color: Area ${areaObj.name} has no parentId, using own color: ${colorString}');
                      }
                    }
                    
                    if (colorString.startsWith('#')) {
                      colorString = colorString.substring(1);
                    }
                    if (colorString.length == 6) {
                      colorString = 'FF$colorString';
                    }
                    tagColor = Color(int.parse(colorString, radix: 16));
                  } catch (e) {
                    tagColor = Colors.grey;
                  }
                }
              }
            }
          } catch (e) {
            // If JSON parsing fails, try to use first line as title
            if (log.notes!.isNotEmpty) {
              final lines = log.notes!.split('\n');
              if (lines.isNotEmpty) {
                final firstLine = lines.first.trim();
                if (firstLine.isNotEmpty && firstLine.length <= 50) {
                  title = firstLine.length > 30 ? '${firstLine.substring(0, 30)}...' : firstLine;
                }
              }
            }
          }
        }

        dayToTitles
            .putIfAbsent(dayKey, () => <_DayEntry>[])
            .add(_DayEntry(title: title, color: tagColor, areaKey: areaKey, durationMin: durationMin));
            
        // Activity added to calendar
      }
      
      // Calendar data loaded successfully
      
      return dayToTitles;
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading calendar data: $e');
      return {};
    }
  }

  void _openDayDetails(DateTime day) async {
    // Use passed logs or fall back to provider
    final allLogs = widget.logs ?? ref.read(logsNotifierProvider).value ?? [];
    
    // Filter logs to only include those from existing life areas (INCLUDING SUBCATEGORIES)
    final existingAreas = widget.lifeAreas ?? await LifeAreasService.getLifeAreas();
    final existingAreaNames = <String>{};
    final existingCanonicalNames = <String>{};
    
    // Add top-level areas
    for (final area in existingAreas) {
      existingAreaNames.add(area.name);
      existingCanonicalNames.add(LifeAreasService.canonicalAreaName(area.name));
      
      // Add all subcategories for each area
      try {
        final childAreas = await LifeAreasService.getChildAreas(area.id);
        for (final child in childAreas) {
          existingAreaNames.add(child.name);
          existingCanonicalNames.add(LifeAreasService.canonicalAreaName(child.name));
        }
      } catch (e) {
        print('Error loading child areas for ${area.name}: $e');
      }
    }
    
    final filteredLogs = allLogs.where((log) {
      final parsed = ParsedActivityData.fromNotes(log.notes);
      final activityAreaName = parsed.effectiveAreaName;
      if (activityAreaName.isEmpty) return true; // Keep activities without life area
      
      // First try exact name match
      if (existingAreaNames.contains(activityAreaName)) return true;
      
      // Then try canonical name match
      final canonicalName = LifeAreasService.canonicalAreaName(activityAreaName);
      return existingCanonicalNames.contains(canonicalName) || canonicalName == 'other' || canonicalName == 'unknown';
    }).toList();
    
    final dayLogs = filteredLogs.where((log) {
      final d = log.occurredAt.toLocal();
      final logDay = DateTime(d.year, d.month, d.day);
      return logDay == day;
    }).toList();

    // Filtered day logs ready

    // Show day details dialog
    _showDayDetailsDialog(context, day, dayLogs);
    
    // Also call the original callback
    widget.onOpenDay(day, dayLogs);
  }

  Future<Map<String, LifeArea>> _buildCompleteAreaMap(List<LifeArea> areas) async {
    final areaMap = <String, LifeArea>{};
    
    // First add all top-level areas
    for (final a in areas) {
      areaMap[a.name] = a;
      areaMap[a.name.toLowerCase()] = a; // Also add lowercase version for case-insensitive matching
    }
    
    // Then recursively add all subcategories
    for (final area in areas) {
      try {
        final childAreas = await LifeAreasService.getChildAreas(area.id);
        for (final child in childAreas) {
          areaMap[child.name] = child;
          areaMap[child.name.toLowerCase()] = child; // Also add lowercase version
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error loading child areas for ${area.name}: $e');
        }
      }
    }
    
    return areaMap;
  }

  void _showDayDetailsDialog(BuildContext context, DateTime day, List<models.ActionLog> dayLogs) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, MMMM d, y').format(day),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dayLogs.length} activit${dayLogs.length == 1 ? 'y' : 'ies'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // Activities List
              if (dayLogs.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No activities on this day',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: dayLogs.length,
                    itemBuilder: (context, index) {
                      final log = dayLogs[index];
                      return _buildActivityCard(log, index);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(models.ActionLog log, int index) {
    return FutureBuilder<List<LifeArea>>(
      future: _lifeAreasFuture,
      builder: (context, areaSnap) {
        final areas = areaSnap.data ?? <LifeArea>[];
        return FutureBuilder<Map<String, LifeArea>>(
          future: _buildCompleteAreaMap(areas),
          builder: (context, areaMapSnap) {
            final areaMap = areaMapSnap.data ?? <String, LifeArea>{};

            // Extract title and color using same logic as above
            String title = 'Activity';
            Color color = Colors.grey;
            
            if (log.notes != null) {
              try {
                final obj = jsonDecode(log.notes!);
                if (obj is Map<String, dynamic>) {
                  // Extract title
                  if (obj['title'] != null && obj['title'].toString().trim().isNotEmpty) {
                    title = obj['title'].toString().trim();
                  } else {
                    final delta = obj['delta'] ?? obj['ops'];
                    if (delta is List && delta.isNotEmpty) {
                      final textParts = <String>[];
                      for (final op in delta) {
                        if (op is Map && op['insert'] is String) {
                          textParts.add(op['insert'].toString());
                        }
                      }
                      if (textParts.isNotEmpty) {
                        final allText = textParts.join('').trim();
                        final firstLine = allText.split('\n').first.trim();
                        if (firstLine.isNotEmpty) {
                          title = firstLine;
                        }
                      }
                    }
                  }
                  
                  // Extract area and color with subcategory support
                  final area = obj['area'] as String?;
                  final lifeArea = obj['life_area'] as String?;
                  final category = obj['category'] as String?;
                  final searchName = area?.trim() ?? lifeArea?.trim() ?? category?.trim() ?? '';
                  
                  if (searchName.isNotEmpty) {
                    // Try both exact match and lowercase match
                    final areaObj = areaMap[searchName] ?? areaMap[searchName.toLowerCase()];
                    if (areaObj != null) {
                      try {
                        String colorString;
                        
                        // If this is a subcategory (has parentId), use parent's color
                        if (areaObj.parentId != null) {
                          // Find parent area and use its color
                          final parentArea = areas.firstWhere(
                            (area) => area.id == areaObj.parentId,
                            orElse: () => areaObj, // Fallback to own color
                          );
                          colorString = parentArea.color;
                        } else {
                          colorString = areaObj.color;
                        }
                        
                        if (colorString.startsWith('#')) {
                          colorString = colorString.substring(1);
                        }
                        if (colorString.length == 6) {
                          colorString = 'FF$colorString';
                        }
                        color = Color(int.parse(colorString, radix: 16));
                      } catch (e) {
                        color = Colors.grey;
                      }
                    }
                  }
                }
              } catch (e) {
                // Use fallback
                if (log.notes!.isNotEmpty) {
                  final firstLine = log.notes!.split('\n').first.trim();
                  if (firstLine.isNotEmpty) {
                    title = firstLine.length > 50 ? '${firstLine.substring(0, 50)}...' : firstLine;
                  }
                }
              }
            }

        return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop(); // Close day dialog
            showDialog(
              context: context,
              builder: (_) => ActivityDetailsDialog(
                log: log,
                onUpdate: () {
                  // Clear cache to refresh calendar on next build
                  _cachedCalendarData = null;
                },
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(log.occurredAt),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (log.durationMin != null && log.durationMin! > 0)
                      Text(
                        '${log.durationMin}min',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(width: 16),
                
                // Activity info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '+${log.earnedXp} XP',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Calendar Header
          FutureBuilder<List<LifeArea>>(
          future: _lifeAreasFuture,
          builder: (context, snap) {
            final areas = snap.data ?? const <LifeArea>[];
            return CalendarHeader(
              month: _calendarMonth,
              onPrev: _goToPreviousMonth,
              onNext: _goToNextMonth,
              areaNames: areas.map((a) => a.name).toList(),
              selectedAreaName: widget.selectedAreaFilterName,
              onAreaSelected: widget.onAreaSelected,
            );
          },
        ),

        // Calendar Grid - Optimized to prevent endless rebuilds
        Consumer(
          builder: (context, ref, child) {
            // Use passed data if available, otherwise fall back to providers
            final logs = widget.logs ?? ref.watch(logsNotifierProvider).value ?? <models.ActionLog>[];
            final areas = widget.lifeAreas ?? const <LifeArea>[];
            
            // Loading calendar with ${logs.length} logs and ${areas.length} areas
            
            return FutureBuilder<Map<DateTime, List<_DayEntry>>>(
              future: _getCachedCalendarData(logs, areas),
              builder: (context, calendarSnap) {
                if (calendarSnap.connectionState == ConnectionState.waiting && _cachedCalendarData == null) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final data = calendarSnap.data ?? _cachedCalendarData ?? <DateTime, List<_DayEntry>>{};
                
                // Filter by selected area if specified
                final filteredData = <DateTime, List<_DayEntry>>{};
                final dominant = <DateTime, Color>{};

                data.forEach((day, entries) {
                  List<_DayEntry> filteredEntries = entries;
                  
                  if (widget.selectedAreaFilterName != null) {
                    filteredEntries = entries
                        .where((e) => e.areaKey == widget.selectedAreaFilterName)
                        .toList();
                  }
                  
                  if (filteredEntries.isNotEmpty) {
                    filteredData[day] = filteredEntries;
                    
                    // Calculate dominant color with improved logic
                    // 1. Group by area and count activities + total duration
                    final Map<String, List<_DayEntry>> areaGroups = {};
                    for (final entry in filteredEntries) {
                      areaGroups.putIfAbsent(entry.areaKey, () => []).add(entry);
                    }
                    
                    // 2. Calculate scores: activity count first, then duration as tiebreaker
                    String? bestArea;
                    int maxActivities = 0;
                    int maxDuration = 0;
                    
                    areaGroups.forEach((areaKey, areaEntries) {
                      final activityCount = areaEntries.length;
                      final totalDuration = areaEntries.fold(0, (sum, entry) => sum + entry.durationMin);
                      
                      if (activityCount > maxActivities || 
                          (activityCount == maxActivities && totalDuration > maxDuration)) {
                        maxActivities = activityCount;
                        maxDuration = totalDuration;
                        bestArea = areaKey;
                      }
                    });
                    
                    // 3. Set dominant color from best area
                    if (bestArea != null) {
                      final bestAreaEntries = areaGroups[bestArea]!;
                      if (bestAreaEntries.isNotEmpty) {
                        dominant[day] = bestAreaEntries.first.color;
                      }
                    }
                  }
                });

                // Convert _DayEntry to CalendarDayEntry format
                final convertedEntries = <DateTime, List<CalendarDayEntry>>{};
                filteredData.forEach((day, entries) {
                  convertedEntries[day] = entries.map((e) => CalendarDayEntry(
                    title: e.title, 
                    color: e.color,
                  )).toList();
                });

                // Converted entries for CalendarGrid

                return RepaintBoundary(
                  child: CalendarGrid(
                    month: _calendarMonth,
                    dayEntries: convertedEntries,
                    dayDominantColors: dominant.isEmpty ? null : dominant,
                    onOpenDay: _openDayDetails,
                  ),
                );
              },
            );
          },
        ),
        ],
      ),
    );
  }
}