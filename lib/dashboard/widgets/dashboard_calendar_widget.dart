import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import '../../services/life_areas_service.dart';
import '../../services/app_state.dart';
import '../../models/action_models.dart' as models;
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

  const DashboardCalendarWidget({
    super.key,
    this.selectedAreaFilterName,
    required this.onAreaSelected,
    required this.onOpenDay,
  });

  @override
  ConsumerState<DashboardCalendarWidget> createState() => _DashboardCalendarWidgetState();
}

class _DashboardCalendarWidgetState extends ConsumerState<DashboardCalendarWidget> {
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Future<List<LifeArea>>? _lifeAreasFuture;

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
    });
  }

  void _goToNextMonth() {
    setState(() {
      _calendarMonth = DateTime(
        _calendarMonth.year,
        _calendarMonth.month + 1,
      );
    });
  }

  Future<Map<DateTime, List<_DayEntry>>> _loadCalendarData(
    List<models.ActionLog> logs,
    List<LifeArea> areas,
  ) async {
    try {
      final areaMap = <String, LifeArea>{
        for (final a in areas) a.name: a
      };

      final dayToTitles = <DateTime, List<_DayEntry>>{};

      for (final log in logs) {
        final d = log.occurredAt.toLocal();
        final dayKey = DateTime(d.year, d.month, d.day);

        if (dayKey.year != _calendarMonth.year || dayKey.month != _calendarMonth.month) {
          continue;
        }

        String title = 'Aktivität';
        Color tagColor = Colors.grey;
        String areaKey = 'unknown';
        int durationMin = log.durationMin ?? 0;

        if (log.notes != null) {
          try {
            final obj = jsonDecode(log.notes!);
            if (obj is Map<String, dynamic>) {
              final area = obj['area'] as String?;
              final action = obj['action'] as String?;
              if (area != null) {
                areaKey = area;
                final areaObj = areaMap[area];
                if (areaObj != null) {
                  // Parse color string to Color
                  try {
                    String colorString = areaObj.color;
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
                if (action != null) {
                  title = action;
                } else {
                  title = area;
                }
              } else if (action != null) {
                title = action;
              }
            }
          } catch (e) {
            if (kDebugMode) debugPrint('Error parsing log notes: $e');
          }
        }

        dayToTitles
            .putIfAbsent(dayKey, () => <_DayEntry>[])
            .add(_DayEntry(title: title, color: tagColor, areaKey: areaKey, durationMin: durationMin));
      }
      return dayToTitles;
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading calendar data: $e');
      return {};
    }
  }

  void _openDayDetails(DateTime day) {
    final logs = ref.read(logsNotifierProvider).value ?? [];
    final dayLogs = logs.where((log) {
      final d = log.occurredAt.toLocal();
      final logDay = DateTime(d.year, d.month, d.day);
      return logDay == day;
    }).toList();

    widget.onOpenDay(day, dayLogs);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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

        // Calendar Grid
        Consumer(
          builder: (context, ref, child) {
            final logsAsync = ref.watch(logsNotifierProvider);
            
            return logsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Error loading calendar')),
                );
              },
              data: (logs) {
                return FutureBuilder<List<LifeArea>>(
                  future: _lifeAreasFuture,
                  builder: (context, areaSnap) {
                    final areas = areaSnap.data ?? const <LifeArea>[];
                    
                    return FutureBuilder<Map<DateTime, List<_DayEntry>>>(
                      future: _loadCalendarData(logs, areas),
                      builder: (context, calendarSnap) {
                        if (calendarSnap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final data = calendarSnap.data ?? <DateTime, List<_DayEntry>>{};
                        
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
                            
                            // Calculate dominant color
                            final colorCounts = <Color, int>{};
                            for (final entry in filteredEntries) {
                              colorCounts[entry.color] = (colorCounts[entry.color] ?? 0) + 1;
                            }
                            
                            if (colorCounts.isNotEmpty) {
                              final bestColor = colorCounts.entries
                                  .reduce((a, b) => a.value > b.value ? a : b)
                                  .key;
                              dominant[day] = bestColor;
                            }
                          }
                        });

                        return RepaintBoundary(
                          child: CalendarGrid(
                            month: _calendarMonth,
                            dayEntries: filteredData.map((day, entries) => MapEntry(
                              day,
                              entries.map((e) => CalendarDayEntry(title: e.title, color: e.color)).toList(),
                            )),
                            dayDominantColors: dominant.isEmpty ? null : dominant,
                            onOpenDay: _openDayDetails,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}