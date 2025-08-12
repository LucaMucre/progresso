import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart';
import 'dashboard_page.dart';
import 'history_page.dart';
import 'life_area_detail_page.dart';
import 'log_action_page.dart';
import 'profile_page.dart';
import 'services/db_service.dart';
import 'services/life_areas_service.dart';
import 'services/avatar_sync_service.dart';
import 'widgets/bubble_widget.dart';
import 'widgets/profile_header_widget.dart';
import 'templates_page.dart';
import 'chat_page.dart';
import 'widgets/activity_details_dialog.dart';
import 'widgets/level_up_dialog.dart';
import 'services/level_up_service.dart';
import 'settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Add a counter to force FutureBuilder rebuild
  int _refreshCounter = 0;
  // Toggle between bubbles view and calendar view for life areas container
  bool _isCalendarView = false;
  // Current month displayed in the calendar view
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  // Optional filter: show only activities for this life area name
  String? _selectedAreaFilterName;

  // Ensure default life areas are only created once even if multiple builders call _loadLifeAreas()
  Future<void>? _ensureDefaultsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Force rebuild wenn Abhängigkeiten sich ändern
    setState(() {});
    // Zusätzliche Aktualisierung nach kurzer Verzögerung
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Automatische Aktualisierung beim Start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {});
      // Level-up popup listener (dashboard-wide)
      LevelUpService.setOnLevelUp((level) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => LevelUpDialog(level: level),
        );
      });
    });
    // Zusätzliche Aktualisierung nach kurzer Verzögerung
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
      }
    });

    // Realtime: Änderungen an action_logs triggern Refresh
    try {
      final client = Supabase.instance.client;
      client
          .channel('realtime-logs')
          .on(
            RealtimeListenTypes.postgresChanges,
            ChannelFilter(event: 'INSERT', schema: 'public', table: 'action_logs'),
            (payload, [ref]) { if (mounted) setState(() => _refreshCounter++); },
          )
          .on(
            RealtimeListenTypes.postgresChanges,
            ChannelFilter(event: 'UPDATE', schema: 'public', table: 'action_logs'),
            (payload, [ref]) { if (mounted) setState(() => _refreshCounter++); },
          )
          .on(
            RealtimeListenTypes.postgresChanges,
            ChannelFilter(event: 'DELETE', schema: 'public', table: 'action_logs'),
            (payload, [ref]) { if (mounted) setState(() => _refreshCounter++); },
          )
          .subscribe();
    } catch (_) {}
  }


  
  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      print('SignOut Fehler: $e');
    }
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

  Future<List<ActionLog>> _fetchLogsForDay(DateTime day) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return [];

    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    try {
      final res = await client
          .from('action_logs')
          .select('id, occurred_at, duration_min, notes, earned_xp, template_id, activity_name, image_url')
          .eq('user_id', user.id)
          .gte('occurred_at', start.toIso8601String())
          .lt('occurred_at', end.toIso8601String())
          .order('occurred_at');
      return (res as List).map((m) => ActionLog.fromMap(m as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      // Fallback when activity_name column doesn't exist
      if ((e.message ?? '').contains('activity_name')) {
        final res = await client
            .from('action_logs')
            .select('id, occurred_at, duration_min, notes, earned_xp, template_id, image_url')
            .eq('user_id', user.id)
            .gte('occurred_at', start.toIso8601String())
            .lt('occurred_at', end.toIso8601String())
            .order('occurred_at');
        return (res as List).map((m) => ActionLog.fromMap(m as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Future<void> _openDayDetails(DateTime day) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    // Fetch data (sequential for compatibility)
    final logs = await _fetchLogsForDay(day);
    final templatesRes = await client
        .from('action_templates')
        .select('id,name')
        .eq('user_id', user.id);
    final lifeAreasRes = await client
        .from('life_areas')
        .select('name,category,color')
        .eq('user_id', user.id);

    final templateMap = {
      for (final t in (templatesRes as List)) (t['id'] as String): (t['name'] as String)
    };
    final List<_AreaTag> areaTags = (lifeAreasRes as List).map((m) => _AreaTag(
      name: (m['name'] as String).trim(),
      category: (m['category'] as String).trim(),
      color: _parseHexColor((m['color'] as String?) ?? '#2196F3'),
    )).toList();

    String titleForLog(ActionLog log) {
      if (log.activityName != null && log.activityName!.trim().isNotEmpty) {
        return log.activityName!.trim();
      }
      final fromNotes = extractTitleFromNotes(log.notes);
      if (fromNotes != null && fromNotes.trim().isNotEmpty) return fromNotes.trim();
      if (log.templateId != null && templateMap[log.templateId!] != null) {
        return templateMap[log.templateId!]!;
      }
              return 'Activity';
    }

    Color? tagColorForLog(ActionLog log) {
      try {
        if (log.notes == null || log.notes!.isEmpty) return null;
        final obj = jsonDecode(log.notes!);
        if (obj is Map<String, dynamic>) {
          final areaName = LifeAreasService.canonicalAreaName(obj['area'] as String?);
          final category = LifeAreasService.canonicalCategory(obj['category'] as String?);
          final match = _matchAreaTag(areaTags, areaName, category);
          return match?.color;
        }
      } catch (_) {}
      return null;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final dayLabel = DateFormat.yMMMMd('de_DE').format(day);
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: 560,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dayLabel,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (logs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
            child: Text('No activities on this day', style: Theme.of(context).textTheme.bodyMedium),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final log = logs[i];
                        final t = titleForLog(log);
                        final c = tagColorForLog(log) ?? Theme.of(context).colorScheme.primary;
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                          ),
                          title: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Row(
                            children: [
                              if (log.durationMin != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Row(children: [const Icon(Icons.timer, size: 12), const SizedBox(width: 4), Text('${log.durationMin} min')]),
                                ),
                              Row(children: [const Icon(Icons.star, size: 12), const SizedBox(width: 4), Text('+${log.earnedXp}')]),
                            ],
                          ),
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => ActivityDetailsDialog(
                              log: log,
                              onUpdate: () {
                                // Entferne gelöschten/angepassten Eintrag aus der Tagesliste
                                setDialogState(() {
                                  logs.removeWhere((l) => l.id == log.id);
                                });
                                // Triggere Rebuilds (Statistiken, Diagramme, Kalender)
                                if (mounted) {
                                  setState(() {
                                    _refreshCounter++;
                                  });
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Future<Map<DateTime, List<_DayEntry>>> _loadCalendarLogsForMonth(
    DateTime month, {
    String? areaFilterName,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return {};

    // Build range for the month [start, nextMonthStart)
    final startOfMonth = DateTime(month.year, month.month, 1);
    final startOfNextMonth = DateTime(month.year, month.month + 1, 1);

    // Fetch templates once to resolve template_id to names
    final templatesRes = await client
        .from('action_templates')
        .select('id,name')
        .eq('user_id', user.id);

    final Map<String, String> templateIdToName = {
      for (final t in (templatesRes as List)) (t['id'] as String): (t['name'] as String)
    };

    List logsRes;
    try {
      // Preferred selection including activity_name (if the column exists)
      logsRes = await client
          .from('action_logs')
          .select('occurred_at, template_id, activity_name, notes')
          .eq('user_id', user.id)
          .gte('occurred_at', startOfMonth.toIso8601String())
          .lt('occurred_at', startOfNextMonth.toIso8601String())
          .order('occurred_at') as List;
    } on PostgrestException catch (e) {
      // Fallback for schemas without activity_name
      if ((e.message ?? '').contains('activity_name')) {
        logsRes = await client
            .from('action_logs')
            .select('occurred_at, template_id, notes')
            .eq('user_id', user.id)
            .gte('occurred_at', startOfMonth.toIso8601String())
            .lt('occurred_at', startOfNextMonth.toIso8601String())
            .order('occurred_at') as List;
      } else {
        rethrow;
      }
    } catch (e) {
  print('Error loading calendar data: $e');
      return {};
    }

    // Load life areas for color tagging
    final lifeAreasRes = await client
        .from('life_areas')
        .select('name,category,color')
        .eq('user_id', user.id);
    final List<_AreaTag> areaTags = (lifeAreasRes as List).map((m) => _AreaTag(
      name: LifeAreasService.canonicalAreaName((m['name'] as String).trim()),
      category: LifeAreasService.canonicalCategory((m['category'] as String).trim()),
      color: _parseHexColor((m['color'] as String?) ?? '#2196F3'),
    )).toList();

    final Map<DateTime, List<_DayEntry>> dayToTitles = {};

    for (final row in logsRes) {
      final occurredAt = DateTime.parse(row['occurred_at'] as String).toLocal();
      final dayKey = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
      final String? activityName = row['activity_name'] as String?; // may be null if not selected
      final String? templateId = row['template_id'] as String?;
      final String? notes = row['notes'] as String?;

    String title = activityName ?? (templateId != null ? (templateIdToName[templateId] ?? 'Activity') : 'Activity');
      Color? tagColor;
      _AreaTag? matched;
      if (notes != null && notes.isNotEmpty) {
        try {
          final obj = jsonDecode(notes);
          if (obj is Map<String, dynamic>) {
            final t = obj['title'];
            if (t is String && t.trim().isNotEmpty) {
              title = t.trim();
            }
            final areaName = LifeAreasService.canonicalAreaName(obj['area'] as String?);
            final category = LifeAreasService.canonicalCategory(obj['category'] as String?);
            if (areaName is String || category is String) {
              matched = _matchAreaTag(areaTags, areaName, category);
              if (matched != null) tagColor = matched!.color;
            }
          }
        } catch (_) {}
      }

      // Apply filter: skip if a filter is set and this log doesn't match
      if (areaFilterName != null) {
        if (matched == null || matched!.name.toLowerCase() != areaFilterName.toLowerCase()) {
          continue;
        }
      }

      final String? areaKey = matched != null
          ? '${matched!.name.toLowerCase()}|${matched!.category.toLowerCase()}'
          : null;
      dayToTitles
          .putIfAbsent(dayKey, () => <_DayEntry>[])
          .add(_DayEntry(title: title, color: tagColor, areaKey: areaKey));
    }

    return dayToTitles;
  }

  Widget _buildCalendarContainer(BuildContext context) {
  final monthLabel = DateFormat.yMMMM('en_US').format(_calendarMonth);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _goToPreviousMonth,
  tooltip: 'Previous month',
              ),
              Text(
                monthLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _goToNextMonth,
  tooltip: 'Next month',
              ),
              const Spacer(),
              FutureBuilder<List<LifeArea>>(
                future: _loadLifeAreas(),
                builder: (context, snap) {
                  final areas = snap.data ?? const <LifeArea>[];
                  final items = <DropdownMenuItem<String?>>[
                    const DropdownMenuItem(value: null, child: Text('Alle Bereiche')),
                    ...areas.map((a) => DropdownMenuItem<String?>(value: a.name, child: Text(a.name))).toList(),
                  ];
                  final availableNames = areas.map((a) => a.name).toSet();
                  final dropdownValue = (availableNames.contains(_selectedAreaFilterName))
                      ? _selectedAreaFilterName
                      : null;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                    ),
                    child: DropdownButton<String?>
                    (
                      value: dropdownValue,
                      items: items,
                      underline: const SizedBox.shrink(),
                      onChanged: (v) {
                        setState(() {
                          _selectedAreaFilterName = v;
                        });
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(child: Center(child: Text('Mo'))),
              Expanded(child: Center(child: Text('Di'))),
              Expanded(child: Center(child: Text('Mi'))),
              Expanded(child: Center(child: Text('Do'))),
              Expanded(child: Center(child: Text('Fr'))),
              Expanded(child: Center(child: Text('Sa'))),
              Expanded(child: Center(child: Text('So'))),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<Map<DateTime, List<_DayEntry>>>(
            future: _loadCalendarLogsForMonth(_calendarMonth, areaFilterName: _selectedAreaFilterName),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final data = snapshot.data ?? {};
              // Zähle pro Lebensbereich (areaKey) die Anzahl im Monat
              final Map<String, int> monthAreaCounts = {};
              data.values.forEach((list) {
                for (final e in list) {
                  if (e.areaKey != null) {
                    monthAreaCounts[e.areaKey!] = (monthAreaCounts[e.areaKey!] ?? 0) + 1;
                  }
                }
              });

              final firstDayOfMonth = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
              final daysInMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
              final leadingEmpty = (firstDayOfMonth.weekday + 6) % 7; // 0 for Monday, ... 6 for Sunday

              final totalCells = leadingEmpty + daysInMonth;
              final rows = <TableRow>[];
              int dayCounter = 1;

              for (int r = 0; r < (totalCells / 7.0).ceil(); r++) {
                final cells = <Widget>[];
                for (int c = 0; c < 7; c++) {
                  final cellIndex = r * 7 + c;
                  if (cellIndex < leadingEmpty || dayCounter > daysInMonth) {
                    cells.add(Container(height: 84));
                  } else {
                    final dayDate = DateTime(_calendarMonth.year, _calendarMonth.month, dayCounter);
                    final entries = data[dayDate] ?? const <_DayEntry>[];
                    cells.add(_CalendarDayCell(
                      day: dayCounter,
                      entries: entries,
                      onTap: () => _openDayDetails(dayDate),
                      monthAreaCounts: monthAreaCounts,
                    ));
                    dayCounter++;
                  }
                }
                rows.add(TableRow(children: cells));
              }

              return Table(
                columnWidths: const {
                  0: FlexColumnWidth(),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(),
                  3: FlexColumnWidth(),
                  4: FlexColumnWidth(),
                  5: FlexColumnWidth(),
                  6: FlexColumnWidth(),
                },
                children: rows,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _badgeIcon(int badge) {
    switch (badge) {
      case 1:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.brown.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.emoji_events, color: Colors.brown, size: 24),
        );
      case 2:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.emoji_events, color: Colors.grey, size: 24),
        );
      case 3:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _onBubbleTap(BuildContext context, LifeArea area) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LifeAreaDetailPage(area: area),
      ),
    );
  }

  void _showAddLifeAreaDialog(BuildContext context) {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    String selectedColor = '#2196F3';
    String selectedIcon = 'fitness_center';

    final List<Map<String, dynamic>> colorOptions = [
      {'name': 'Blau', 'color': '#2196F3'},
      {'name': 'Grün', 'color': '#4CAF50'},
      {'name': 'Orange', 'color': '#FF9800'},
      {'name': 'Rot', 'color': '#F44336'},
      {'name': 'Lila', 'color': '#9C27B0'},
      {'name': 'Pink', 'color': '#E91E63'},
      {'name': 'Türkis', 'color': '#00BCD4'},
      {'name': 'Gelb', 'color': '#FFEB3B'},
      {'name': 'Grau', 'color': '#607D8B'},
      {'name': 'Braun', 'color': '#795548'},
    ];

    final List<Map<String, dynamic>> iconOptions = [
      {'name': 'Fitness', 'icon': 'fitness_center'},
      {'name': 'Nutrition', 'icon': 'restaurant'},
      {'name': 'Learning', 'icon': 'school'},
      {'name': 'Finance', 'icon': 'account_balance'},
      {'name': 'Art', 'icon': 'palette'},
      {'name': 'Relationships', 'icon': 'people'},
      {'name': 'Career', 'icon': 'work'},
      {'name': 'Home', 'icon': 'home'},
      {'name': 'Health', 'icon': 'local_hospital'},
      {'name': 'Travel', 'icon': 'flight'},
      {'name': 'Music', 'icon': 'music_note'},
      {'name': 'Sports', 'icon': 'sports_soccer'},
      {'name': 'Technology', 'icon': 'computer'},
      {'name': 'Nature', 'icon': 'eco'},
      {'name': 'Reading', 'icon': 'book'},
      {'name': 'Writing', 'icon': 'edit'},
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Add new life area'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name Field
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                         labelText: 'Name',
                         hintText: 'e.g. Fitness, Learning, etc.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Category Field
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                         labelText: 'Category (optional)',
                         hintText: 'e.g. Health, Personal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Color Selection
                     const Text(
                       'Choose color:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colorOptions.map((colorOption) {
                        bool isSelected = selectedColor == colorOption['color'];
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = colorOption['color'];
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(int.parse(colorOption['color'].replaceAll('#', '0xFF'))),
                              borderRadius: BorderRadius.circular(20),
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ] : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    
                    // Icon Selection
                     const Text(
                       'Choose icon:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: iconOptions.map((iconOption) {
                        bool isSelected = selectedIcon == iconOption['icon'];
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = iconOption['icon'];
                            });
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? Color(int.parse(selectedColor.replaceAll('#', '0xFF'))).withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected 
                                  ? Border.all(color: Color(int.parse(selectedColor.replaceAll('#', '0xFF'))), width: 2)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getIconData(iconOption['icon']),
                                  color: isSelected 
                                      ? Color(int.parse(selectedColor.replaceAll('#', '0xFF')))
                                      : Colors.grey[600],
                                  size: 24,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  iconOption['name'],
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: isSelected 
                                        ? Color(int.parse(selectedColor.replaceAll('#', '0xFF')))
                                        : Colors.grey[600],
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a name')),
                      );
                      return;
                    }
                    
                    try {
                      await LifeAreasService.createLifeArea(
                        name: nameController.text.trim(),
                         category: categoryController.text.trim().isEmpty ? 'General' : categoryController.text.trim(),
                        color: selectedColor,
                        icon: selectedIcon,
                      );
                      Navigator.of(context).pop();
                      // Force rebuild
                      setState(() {
                        _refreshCounter++;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Life area created')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error creating area: $e')),
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'restaurant':
        return Icons.restaurant;
      case 'school':
        return Icons.school;
      case 'account_balance':
        return Icons.account_balance;
      case 'palette':
        return Icons.palette;
      case 'people':
        return Icons.people;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'favorite':
        return Icons.favorite;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'music_note':
        return Icons.music_note;
      case 'book':
        return Icons.book;
      case 'computer':
        return Icons.computer;
      case 'psychology':
        return Icons.psychology;
      case 'nature':
        return Icons.nature;
      case 'directions_car':
        return Icons.directions_car;
      case 'flight':
        return Icons.flight;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'camera_alt':
        return Icons.camera_alt;
      case 'eco':
        return Icons.eco;
      case 'pets':
        return Icons.pets;
      case 'child_care':
        return Icons.child_care;
      default:
        return Icons.circle;
    }
  }

  int badgeLevel(int streak) {
    if (streak >= 30) return 3;
    if (streak >= 7) return 2;
    if (streak >= 1) return 1;
    return 0;
  }

  Future<int> calculateStreak() async {
    try {
      final dates = await fetchLoggedDates();
      if (dates.isEmpty) return 0;

      // Streak zählt vom zuletzt geloggten Tag zurück. "Heute ohne Log" bricht NICHT ab,
      // solange gestern (oder ein vorheriger Tag) ein Log hat.
      final normalized = dates
          .map((d) => DateTime(d.year, d.month, d.day))
          .toSet()
          .toList()
        ..sort();

      final DateTime last = normalized.last; // letzter geloggter Tag

      int streak = 0;
      DateTime cursor = last;
      while (normalized.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }

      return streak;
    } catch (e) {
  print('Error calculating streak: $e');
      return 0;
    }
  }

  Future<List<DateTime>> fetchLoggedDates() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client
          .from('action_logs')
          .select('occurred_at')
          .eq('user_id', user.id);

      final dates = (response as List)
          .map((log) => DateTime.parse(log['occurred_at']))
          .toList();

      return dates;
    } catch (e) {
  print('Error loading log data: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: const Text(
          'Progresso',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
                 actions: [
           IconButton(
             icon: const Icon(Icons.refresh),
          tooltip: 'Reload dashboard',
             onPressed: () async {
               // Force Avatar-Sync und Dashboard-Rebuild
               await AvatarSyncService.forceSync();
               setState(() {
                 // Force rebuild des Dashboards
               });
               // Kurze Verzögerung für UI-Update
               await Future.delayed(const Duration(milliseconds: 200));
               setState(() {
                 // Zweiter Force rebuild
               });
             },
           ),
           IconButton(
             icon: const Icon(Icons.history),
             tooltip: 'Meine Logs',
             onPressed: () => Navigator.of(context).push(
               MaterialPageRoute(builder: (_) => const HistoryPage()),
             ),
           ),
            IconButton(
              icon: const Icon(Icons.chat),
              tooltip: 'Chat (Beta)',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatPage()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Einstellungen',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
           // Avatar Debug entfernt
           IconButton(
             icon: const Icon(Icons.exit_to_app),
             tooltip: 'Abmelden',
             onPressed: _signOut,
           ),
         ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header links, Streak rechts (bei großer Breite). Auf kleineren Screens untereinander.
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;

                final streakCard = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FutureBuilder<int>(
                    future: calculateStreak(),
                    builder: (ctx, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
  return Text('Error: ${snap.error}');
                      }
                      final streak = snap.data ?? 0;
                      final badge = badgeLevel(streak);

                      return Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.orange, Colors.deepOrange],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.local_fire_department,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$streak day streak!',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          _badgeIcon(badge),
                        ],
                      );
                    },
                  ),
                );

                if (isWide) {
                  const double heroRowHeight = 74;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: SizedBox(
                          height: heroRowHeight,
                          child: ProfileHeaderWidget(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(width: 320, height: heroRowHeight, child: streakCard),
                    ],
                  );
                }

                return Column(
                  children: [
                    const ProfileHeaderWidget(),
                    const SizedBox(height: 24),
                    streakCard,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Life Areas Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Life areas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Manage your personal areas',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: ToggleButtons(
                        isSelected: [!_isCalendarView, _isCalendarView],
                        onPressed: (index) {
                          setState(() {
                            _isCalendarView = index == 1;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        selectedColor: Theme.of(context).colorScheme.onPrimary,
                        fillColor: Theme.of(context).colorScheme.primary,
                        color: Theme.of(context).colorScheme.onSurface,
                        constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.bubble_chart),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.calendar_today),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () {
                          _showAddLifeAreaDialog(context);
                        },
                        tooltip: 'Neuen Bereich hinzufügen',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Life Areas content (Bubbles or Calendar)
            _isCalendarView
                ? _buildCalendarContainer(context)
                : Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                                   child: FutureBuilder<List<LifeArea>>(
                       key: ValueKey(_refreshCounter), // Force rebuild when counter changes
                       future: _loadLifeAreas(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Loading life areas...'),
                              ],
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              children: [
                                Icon(Icons.error, color: Colors.red, size: 48),
                                const SizedBox(height: 8),
                                Text('Error loading life areas'),
                                const SizedBox(height: 8),
                                                           ElevatedButton(
                                   onPressed: () {
                                     // Force rebuild
                                     setState(() {
                                       _refreshCounter++;
                                     });
                                   },
                                   child: const Text('Try again'),
                                 ),
                              ],
                            ),
                          );
                        }

                        final areas = snapshot.data ?? [];
                        
                        if (areas.isEmpty) {
                          return Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No life areas yet',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                                           onPressed: () async {
                                     try {
                                       await LifeAreasService.createDefaultLifeAreas();
                                       // Force rebuild
                                       setState(() {
                                         _refreshCounter++;
                                       });
                                     } catch (e) {
  print('Error creating default areas: $e');
                                     }
                                   },
                                   child: const Text('Create default areas'),
                                ),
                              ],
                            ),
                          );
                        }

                                           return BubblesGrid(
                           areas: areas,
                           onBubbleTap: (area) => _onBubbleTap(context, area),
                           onDelete: (area) {
                             // Force rebuild when a life area is deleted
                             setState(() {
                               _refreshCounter++;
                             });
                           },
                         );
                      },
                    ),
                  ),

            const SizedBox(height: 24),

            // Global Statistics Section
            _buildGlobalStatisticsSection(context),
            const SizedBox(height: 24),

            // Quick Actions for All Life Areas
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick access to all activities',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Direct activities across all life areas',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Actions Grid
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FutureBuilder<List<LifeArea>>(
                future: _loadLifeAreas(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text('Error loading life areas'),
                          ],
                        ),
                      ),
                    );
                  }

                  final areas = snapshot.data ?? [];
                  
                  if (areas.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text('No life areas available'),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: areas.map((area) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LogActionPage(
                                      selectedArea: area.name,
                                      selectedCategory: area.category,
                                      areaColorHex: area.color,
                                      areaIcon: area.icon,
                                    ),
                                  ),
                                ).then((_) { if (mounted) setState(() => _refreshCounter++); });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _parseColor(area.color).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _getIconData(area.icon),
                                        color: _parseColor(area.color),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Oben: Bereich - Kategorie
                                          Text(
                                            '${area.name} - ${area.category}',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Unten: Aktion
                                          Text(
          'Add activity',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _parseColor(area.color).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Icon(
                                        Icons.add,
                                        size: 16,
                                        color: _parseColor(area.color),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<LifeArea>> _loadLifeAreas() async {
    try {
      // Migrate existing default German areas to English names/categories once
      await LifeAreasService.migrateDefaultsToEnglish();
      final areas = await LifeAreasService.getLifeAreas();
      if (areas.isEmpty) {
        // Standardbereiche nur einmalig anlegen (schutz vor parallelen FutureBuilder-Aufrufen)
        _ensureDefaultsFuture ??= LifeAreasService.createDefaultLifeAreas();
        await _ensureDefaultsFuture;
        return await LifeAreasService.getLifeAreas();
      }
      return areas;
    } catch (e) {
  print('Error loading life areas: $e');
      rethrow;
    }
  }

  Widget _buildGlobalStatisticsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'All activities across all life areas',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _calculateGlobalStatistics(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('Error loading statistics')),
                );
              }
              
              final stats = snapshot.data ?? {};
              final totalXp = stats['totalXp'] ?? 0;
              final activityCount = stats['activityCount'] ?? 0;
              final averageDuration = stats['averageDuration'] ?? 0.0;
              
              return Column(
                children: [
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildGlobalStatCard(
                          context,
                          icon: Icons.star,
                          title: 'Total XP',
                          value: '$totalXp',
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGlobalStatCard(
                          context,
                          icon: Icons.trending_up,
        title: 'Activities',
                          value: '$activityCount',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGlobalStatCard(
                          context,
                          icon: Icons.timer,
                          title: 'Avg duration',
                          value: _formatDuration(averageDuration),
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Aktivitätsanzahl der letzten 7 Tage
                  if (activityCount > 0) _buildGlobalActivityGraph(context),
                  const SizedBox(height: 12),
                  // Dauer in Minuten pro Tag (letzte 7 Tage)
                  _buildGlobalDurationGraph(context),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalActivityGraph(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: _getGlobalLast7DaysActivity(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final activityCounts = snapshot.data!;
        final int maxCount = activityCounts.isEmpty ? 1 : activityCounts.reduce((a, b) => a > b ? a : b);
        
        // Dynamic Y max (nice rounding)
        int yMax;
        if (maxCount <= 4) {
          yMax = 4;
        } else if (maxCount <= 6) {
          yMax = 6;
        } else if (maxCount <= 8) {
          yMax = 8;
        } else if (maxCount <= 10) {
          yMax = 10;
        } else {
          yMax = ((maxCount + 4) / 5).ceil() * 5; // round up to multiple of 5
        }
        
        final now = DateTime.now();
        final last7Days = List.generate(7, (index) {
          return DateTime(now.year, now.month, now.day - index);
        }).reversed.toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
          'Activities in the last 7 days',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  // Y-axis labels
                  SizedBox(
                    width: 36,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(5, (i) {
                        final value = ((yMax / 4) * i).round();
                        return Text(
                          '$value',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: Colors.grey.withOpacity(0.7),
                          ),
                        );
                      }).reversed.toList(),
                    ),
                  ),
                  
                  // Chart area (uses exact constraints for consistent geometry)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final chartWidth = constraints.maxWidth;
                        const chartHeight = 220.0;
                        const topPad = 6.0;
                        const bottomPad = 20.0;
                        final usableHeight = chartHeight - topPad - bottomPad;

                        double yFor(int value) {
                          if (yMax <= 0) return chartHeight - bottomPad;
                          final ratio = (value / yMax).clamp(0.0, 1.0);
                          return topPad + (1 - ratio) * usableHeight;
                        }

                        double xFor(int index) {
                          if (activityCounts.length == 1) return 0;
                          return (index / (activityCounts.length - 1)) * chartWidth;
                        }

                        return Stack(
                          children: [
                            // Grid lines
                            ...List.generate(4, (i) {
                              final y = topPad + ((i + 1) / 4.0) * usableHeight;
                              return Positioned(
                                top: y,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 1,
                                  color: Colors.grey.withOpacity(0.15),
                                ),
                              );
                            }),

                            // Line chart (paint first, then overlay points computed with same mapping)
                            CustomPaint(
                              size: Size(chartWidth, chartHeight),
                              painter: _GlobalLineChartPainter(
                                data: activityCounts,
                                maxValue: yMax.toDouble(),
                                color: Colors.blue,
                              ),
                            ),

                            // Data points with tooltips
                            ...last7Days.asMap().entries.map((entry) {
                              final index = entry.key;
                              final date = entry.value;
                              final count = activityCounts[index];
                              final x = xFor(index);
                              final y = yFor(count);
                              // clamp to avoid clipping at edges
                              final cx = x.clamp(4.0, chartWidth - 4.0);
                              return Positioned(
                                left: cx - 8,
                                top: y - 8,
                                child: Tooltip(
          message: '${date.day}/${date.month}: $count activities',
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),

                            // Date labels
                            ...last7Days.asMap().entries.map((entry) {
                              final index = entry.key;
                              final date = entry.value;
                              final x = xFor(index);
                              final isFirst = index == 0;
                              final isLast = index == last7Days.length - 1;
                              return Positioned(
                                bottom: 0,
                                left: isFirst ? 0 : (isLast ? null : (x - 12)),
                                right: isLast ? 0 : null,
                                child: SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${date.day}/${date.month}',
                                    textAlign: isFirst ? TextAlign.left : (isLast ? TextAlign.right : TextAlign.center),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontSize: 10,
                                          color: Colors.grey.withOpacity(0.7),
                                        ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlobalDurationGraph(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getGlobalLast7DaysDurationStacks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final dataMap = snapshot.data!;
        final List<int> totals = List<int>.from(dataMap['totals'] as List);
        final List<List<_StackSlice>> stacks = (dataMap['stacks'] as List).cast<List<_StackSlice>>();
        final int maxMinutes = totals.isEmpty ? 0 : totals.reduce((a, b) => a > b ? a : b);

        // Y-Achse in Stunden anzeigen, Skalierung intern weiter in Minuten
        final double maxHours = maxMinutes / 60.0;
        double yMaxHours;
        if (maxHours <= 1) {
          yMaxHours = 1;
        } else if (maxHours <= 2) {
          yMaxHours = 2;
        } else if (maxHours <= 3) {
          yMaxHours = 3;
        } else if (maxHours <= 4) {
          yMaxHours = 4;
        } else if (maxHours <= 6) {
          yMaxHours = 6;
        } else if (maxHours <= 8) {
          yMaxHours = 8;
        } else if (maxHours <= 10) {
          yMaxHours = 10;
        } else {
          yMaxHours = (((maxHours + 4) / 5).ceil() * 5).toDouble();
        }
        final int yMax = (yMaxHours * 60).round();

        final now = DateTime.now();
        final last7Days = List.generate(7, (index) {
          return DateTime(now.year, now.month, now.day - index);
        }).reversed.toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
          'Duration of last 7 days (hours)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  // Y-axis labels
                  SizedBox(
                    width: 30,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(5, (i) {
                        final double labelHours = (yMaxHours / 4.0) * i;
                        final String label = labelHours.round().toString();
                        return Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: Colors.grey.withOpacity(0.7),
                              ),
                        );
                      }).reversed.toList(),
                    ),
                  ),

                  // Chart area
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final chartWidth = constraints.maxWidth;
                        const chartHeight = 220.0;
                        const topPad = 6.0;
                        const bottomPad = 20.0;
                        final usableHeight = chartHeight - topPad - bottomPad;

                        double yFor(int value) {
                          if (yMax <= 0) return chartHeight - bottomPad;
                          final ratio = (value / yMax).clamp(0.0, 1.0);
                          return topPad + (1 - ratio) * usableHeight;
                        }

                        double xFor(int index) {
                          if (totals.length == 1) return 0;
                          return (index / (totals.length - 1)) * chartWidth;
                        }

                        return Stack(
                          children: [
                            // Grid lines
                            ...List.generate(4, (i) {
                              final y = topPad + ((i + 1) / 4.0) * usableHeight;
                              return Positioned(
                                top: y,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 1,
                                  color: Colors.grey.withOpacity(0.2),
                                ),
                              );
                            }),

                            // Column chart (bar)
                            CustomPaint(
                              size: Size(chartWidth, chartHeight),
                              painter: _StackedBarChartPainter(
                                stacks: stacks,
                                maxValue: yMax.toDouble(),
                              ),
                            ),

                            // Tooltips per bar (transparent hit area per slot)
                            ...last7Days.asMap().entries.map((entry) {
                              final index = entry.key;
                              final date = entry.value;
                              final minutes = totals[index];
                              final slotWidth = chartWidth / totals.length;
                              final barWidth = slotWidth * 0.6;
                              final left = (index * slotWidth) + (slotWidth - barWidth) / 2;
                              return Positioned(
                                left: left,
                                top: topPad,
                                child: Tooltip(
                                  message: _formatDuration(minutes.toDouble()),
                                  child: Container(
                                    width: barWidth,
                                    height: usableHeight,
                                    color: Colors.transparent,
                                  ),
                                ),
                              );
                            }).toList(),

                            // Date labels
                            ...last7Days.asMap().entries.map((entry) {
                              final index = entry.key;
                              final date = entry.value;
                              final slotWidth = chartWidth / totals.length;
                              final center = (index * slotWidth) + slotWidth / 2.0;
                              return Positioned(
                                bottom: 0,
                                left: (center - 12).clamp(0.0, chartWidth - 24),
                                child: SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${date.day}/${date.month}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontSize: 10,
                                          color: Colors.grey.withOpacity(0.7),
                                        ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _calculateGlobalStatistics() async {
    try {
      final logs = await fetchLogs();
      
      final totalXp = logs.fold<int>(0, (sum, log) => sum + log.earnedXp);
      final activityCount = logs.length;
      final totalDuration = logs
          .where((log) => log.durationMin != null)
          .fold<int>(0, (sum, log) => sum + (log.durationMin ?? 0));
      final averageDuration = activityCount > 0 ? totalDuration / activityCount : 0.0;
      
      return {
        'totalXp': totalXp,
        'activityCount': activityCount,
        'averageDuration': averageDuration,
      };
    } catch (e) {
      print('Fehler beim Berechnen der globalen Statistiken: $e');
      return {};
    }
  }

  Future<List<int>> _getGlobalLast7DaysActivity() async {
    try {
      final logs = await fetchLogs();
      final now = DateTime.now();
      final last7Days = List.generate(7, (index) {
        return DateTime(now.year, now.month, now.day - index);
      }).reversed.toList();
      
      return last7Days.map((date) {
        final targetDate = DateTime(date.year, date.month, date.day);
        return logs.where((log) {
          final local = log.occurredAt.toLocal();
          final logDate = DateTime(local.year, local.month, local.day);
          return logDate.year == targetDate.year &&
              logDate.month == targetDate.month &&
              logDate.day == targetDate.day;
        }).length;
      }).toList();
    } catch (e) {
  print('Error loading 7-day activities: $e');
      return List.filled(7, 0);
    }
  }

  Future<List<int>> _getGlobalLast7DaysDurationMinutes() async {
    try {
      final logs = await fetchLogs();
      final now = DateTime.now();
      final last7Days = List.generate(7, (index) {
        return DateTime(now.year, now.month, now.day - index);
      }).reversed.toList();

      return last7Days.map((date) {
        final targetDate = DateTime(date.year, date.month, date.day);
        final minutes = logs.where((log) {
          final local = log.occurredAt.toLocal();
          final logDate = DateTime(local.year, local.month, local.day);
          return logDate.year == targetDate.year &&
              logDate.month == targetDate.month &&
              logDate.day == targetDate.day;
        }).fold<int>(0, (sum, log) => sum + (log.durationMin ?? 0));
        return minutes;
      }).toList();
    } catch (e) {
      print('Fehler beim Laden der 7-Tage-Dauer: $e');
      return List.filled(7, 0);
    }
  }
  
  Future<Map<String, dynamic>> _getGlobalLast7DaysDurationStacks() async {
    try {
      final logs = await fetchLogs();
      final now = DateTime.now();
      final last7Days = List.generate(7, (index) => DateTime(now.year, now.month, now.day - index)).reversed.toList();

      // Collect area colors
      final lifeAreasRes = await Supabase.instance.client
          .from('life_areas')
          .select('name,category,color')
          .eq('user_id', Supabase.instance.client.auth.currentUser?.id);
      final List<_AreaTag> areaTags = (lifeAreasRes as List)
          .map((m) => _AreaTag(
                name: (m['name'] as String).trim(),
                category: (m['category'] as String).trim(),
                color: _parseHexColor((m['color'] as String?) ?? '#2196F3'),
              ))
          .toList();

      Color resolveColorForLog(ActionLog log) {
        try {
          if (log.notes != null && log.notes!.isNotEmpty) {
            final obj = jsonDecode(log.notes!);
            if (obj is Map<String, dynamic>) {
              final areaName = obj['area'] as String?;
              final category = obj['category'] as String?;
              final match = _matchAreaTag(areaTags, areaName, category);
              if (match != null) return match.color;
            }
          }
        } catch (_) {}
        return Colors.green; // fallback
      }

      final stacks = <List<_StackSlice>>[];
      final totals = <int>[];

      for (final date in last7Days) {
        final targetDate = DateTime(date.year, date.month, date.day);
        final dayLogs = logs.where((log) {
          final local = log.occurredAt.toLocal();
          final logDate = DateTime(local.year, local.month, local.day);
          return logDate.year == targetDate.year &&
              logDate.month == targetDate.month &&
              logDate.day == targetDate.day;
        });

        final Map<int, int> colorToMinutes = {};
        for (final l in dayLogs) {
          final mins = l.durationMin ?? 0;
          if (mins <= 0) continue;
          final color = resolveColorForLog(l);
          colorToMinutes[color.value] = (colorToMinutes[color.value] ?? 0) + mins;
        }
        final list = colorToMinutes.entries
            .map((e) => _StackSlice(minutes: e.value, color: Color(e.key)))
            .toList();
        stacks.add(list);
        totals.add(list.fold<int>(0, (s, x) => s + x.minutes));
      }

      return {
        'stacks': stacks,
        'totals': totals,
      };
    } catch (e) {
      print('Fehler beim Laden der 7-Tage-Stacks: $e');
      return {
        'stacks': List.generate(7, (_) => <_StackSlice>[]),
        'totals': List.filled(7, 0),
      };
    }
  }

  String _formatDuration(double minutes) {
    if (minutes <= 0) return '0 min';
    
    final totalMinutes = minutes.round();
    
    // Weeks (7 days = 10080 minutes)
    if (totalMinutes >= 10080) {
      final weeks = (totalMinutes / 10080).floor();
      final remainingMinutes = totalMinutes - (weeks * 10080);
      final days = (remainingMinutes / 1440).floor();
      
      if (weeks == 1) {
        if (days > 0) {
          return days == 1 ? '1 week, 1 day' : '1 week, $days days';
        } else {
          return '1 week';
        }
      } else {
        if (days > 0) {
          return days == 1 ? '$weeks weeks, 1 day' : '$weeks weeks, $days days';
        } else {
          return '$weeks weeks';
        }
      }
    }
    
    // Days (24 hours = 1440 minutes)
    if (totalMinutes >= 1440) {
      final days = (totalMinutes / 1440).floor();
      final remainingMinutes = totalMinutes - (days * 1440);
      final hours = (remainingMinutes / 60).floor();
      
      if (days == 1) {
        if (hours > 0) {
          return hours == 1 ? '1 day, 1 hr' : '1 day, $hours hrs';
        } else {
          return '1 day';
        }
      } else {
        if (hours > 0) {
          return hours == 1 ? '$days days, 1 hr' : '$days days, $hours hrs';
        } else {
          return '$days days';
        }
      }
    }
    
    // Hours (60 minutes)
    if (totalMinutes >= 60) {
      final hours = (totalMinutes / 60).floor();
      final remainingMinutes = totalMinutes - (hours * 60);
      
      if (hours == 1) {
        if (remainingMinutes > 0) {
          return '1 hr, $remainingMinutes min';
        } else {
          return '1 hr';
        }
      } else {
        if (remainingMinutes > 0) {
          return '$hours hrs, $remainingMinutes min';
        } else {
          return '$hours hrs';
        }
      }
    }
    
  return '$totalMinutes min';
  }

  Color _parseColor(String hex) {
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final List<_DayEntry> entries;
  final VoidCallback? onTap;
  final Map<String, int>? monthAreaCounts; // areaKey -> count in current month

  const _CalendarDayCell({
    Key? key,
    required this.day,
    required this.entries,
    this.onTap,
    this.monthAreaCounts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool hasEntries = entries.isNotEmpty;
    // Dominante Farbe per Lebensbereich bestimmen, mit Tie-Breaker nach Monats-Häufigkeit
    Color dominantColor() {
      if (!hasEntries) return colorScheme.outline.withOpacity(0.6);
      final Map<String, int> areaToCount = {};
      final Map<String, Color> areaToColor = {};
      for (final e in entries) {
        if (e.areaKey == null) continue;
        final key = e.areaKey!;
        areaToCount[key] = (areaToCount[key] ?? 0) + 1;
        if (e.color != null) areaToColor[key] = e.color!;
      }
      if (areaToCount.isEmpty) {
        // Fallback auf Farbhäufigkeit, wenn kein areaKey vorhanden
        final Map<int, int> colorToCount = {};
        for (final e in entries) {
          final c = e.color;
          if (c == null) continue;
          colorToCount[c.value] = (colorToCount[c.value] ?? 0) + 1;
        }
        if (colorToCount.isEmpty) return colorScheme.primary;
        int bestColor = colorToCount.entries.first.key;
        int bestCountLocal = colorToCount[bestColor] ?? 0;
        colorToCount.forEach((val, cnt) {
          if (cnt > bestCountLocal) {
            bestColor = val;
            bestCountLocal = cnt;
          }
        });
        return Color(bestColor);
      }
      // Max Count bestimmen
      int bestCount = 0;
      for (final count in areaToCount.values) {
        if (count > bestCount) bestCount = count;
      }
      // Kandidaten mit max Count
      final candidates = <String>[]; // area keys
      areaToCount.forEach((key, count) {
        if (count == bestCount) candidates.add(key);
      });
      if (candidates.length == 1) {
        final key = candidates.first;
        return areaToColor[key] ?? colorScheme.primary;
      }
      // Tie-Breaker: wähle die Farbe mit geringerer Monatsanzahl
      String? chosen;
      int? chosenMonthCount;
      for (final key in candidates) {
        final monthCount = monthAreaCounts?[key] ?? 0;
        if (chosen == null || monthCount < (chosenMonthCount ?? 1 << 30)) {
          chosen = key;
          chosenMonthCount = monthCount;
        }
      }
      return areaToColor[chosen!] ?? colorScheme.primary;
    }
    final Color accentColor = dominantColor();
    // Maximal 2 Zeilen anzeigen: erste Aktivität + ggf. "+N"
    final List<_DayEntry> shown = () {
      if (entries.isEmpty) return const <_DayEntry>[];
      if (entries.length == 1) return <_DayEntry>[entries.first];
      return <_DayEntry>[entries.first, _DayEntry(title: '+${entries.length - 1}')];
    }();

    // Base content
    final content = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: hasEntries ? accentColor.withOpacity(0.06) : null,
        border: Border.all(
          color: hasEntries
              ? accentColor.withOpacity(0.35)
              : colorScheme.outline.withOpacity(0.18),
        ),
        boxShadow: hasEntries
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$day',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: hasEntries
                      ? accentColor.withOpacity(0.9)
                      : colorScheme.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          ...shown.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (e.color ?? colorScheme.primary).withOpacity(e.title.startsWith('+') ? 0.0 : 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    e.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          height: 1.1,
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                  ),
                ),
              )),
        ],
      ),
    );

    final tappable = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          debugPrint('Calendar day tapped: $day');
          if (onTap != null) onTap!();
        },
        child: content,
      ),
    );

    // Einheitliche Höhe für alle Tageskacheln, auch bei nur einer Aktivität
    final padded = Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(height: 84, child: tappable),
    );
    final withTooltip = entries.isEmpty
        ? padded
        : Tooltip(message: entries.map((e) => e.title).join('\n'), child: padded);

    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: withTooltip,
    );
  }
}

class _DayEntry {
  final String title;
  final Color? color;
  final String? areaKey; // canonical key to identify life area (name|category)
  const _DayEntry({required this.title, this.color, this.areaKey});
}

class _AreaTag {
  final String name;
  final String category;
  final Color color;
  const _AreaTag({required this.name, required this.category, required this.color});
}

Color _parseHexColor(String hex) {
  try {
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  } catch (_) {
    return Colors.blue;
  }
}

_AreaTag? _matchAreaTag(List<_AreaTag> tags, String? areaName, String? category) {
  final an = areaName?.toLowerCase();
  final cat = category?.toLowerCase();
  for (final t in tags) {
    if (an != null && an.isNotEmpty && t.name.toLowerCase() == an) return t;
    if (cat != null && cat.isNotEmpty && t.category.toLowerCase() == cat) return t;
  }
  return null;
}

class _GlobalLineChartPainter extends CustomPainter {
  final List<int> data;
  final double maxValue;
  final Color color;

  _GlobalLineChartPainter({
    required this.data,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    // Use the same paddings as in the layout (must stay in sync)
    const double topPad = 6.0;
    const double bottomPad = 20.0;
    final double usableHeight = size.height - topPad - bottomPad;

    for (int i = 0; i < data.length; i++) {
      final x = data.length == 1 ? 0.0 : (i / (data.length - 1)) * width;
      final ratio = maxValue <= 0 ? 0.0 : (data[i] / maxValue).clamp(0.0, 1.0);
      final y = topPad + (1 - ratio) * usableHeight;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GlobalBarChartPainter extends CustomPainter {
  final List<int> data;
  final double maxValue;
  final Color color;

  _GlobalBarChartPainter({
    required this.data,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxValue <= 0) return;

    const double topPad = 6.0;
    const double bottomPad = 20.0;
    final double usableHeight = size.height - topPad - bottomPad;

    final double slotWidth = size.width / data.length;
    final double barWidth = slotWidth * 0.6;

    final paint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final value = data[i];
      final ratio = (value / maxValue).clamp(0.0, 1.0);
      final barHeight = ratio * usableHeight;
      final left = (i * slotWidth) + (slotWidth - barWidth) / 2.0;
      final top = topPad + (usableHeight - barHeight);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _StackSlice {
  final int minutes;
  final Color color;
  _StackSlice({required this.minutes, required this.color});
}

class _StackedBarChartPainter extends CustomPainter {
  final List<List<_StackSlice>> stacks;
  final double maxValue;

  _StackedBarChartPainter({required this.stacks, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (stacks.isEmpty || maxValue <= 0) return;

    const double topPad = 6.0;
    const double bottomPad = 20.0;
    final double usableHeight = size.height - topPad - bottomPad;
    final double slotWidth = size.width / stacks.length;
    final double barWidth = slotWidth * 0.6;

    for (int i = 0; i < stacks.length; i++) {
      final left = (i * slotWidth) + (slotWidth - barWidth) / 2.0;
      double accumulated = 0.0;
      for (final slice in stacks[i]) {
        final sliceHeight = ((slice.minutes / maxValue).clamp(0.0, 1.0)) * usableHeight;
        final top = topPad + (usableHeight - (accumulated + sliceHeight));
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, sliceHeight),
          const Radius.circular(3),
        );
        final paint = Paint()..color = slice.color.withOpacity(0.9);
        canvas.drawRRect(rect, paint);
        accumulated += sliceHeight;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}