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
import 'debug_avatar_page.dart';
import 'services/db_service.dart';
import 'services/life_areas_service.dart';
import 'services/avatar_sync_service.dart';
import 'widgets/bubble_widget.dart';
import 'widgets/profile_header_widget.dart';
import 'templates_page.dart';
import 'widgets/activity_details_dialog.dart';

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
    });
    // Zusätzliche Aktualisierung nach kurzer Verzögerung
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
      }
    });
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

    final res = await client
        .from('action_logs')
        .select('id, occurred_at, duration_min, notes, earned_xp, template_id, activity_name, image_url')
        .eq('user_id', user.id)
        .gte('occurred_at', start.toIso8601String())
        .lt('occurred_at', end.toIso8601String())
        .order('occurred_at');

    return (res as List).map((m) => ActionLog.fromMap(m as Map<String, dynamic>)).toList();
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
      return 'Aktivität';
    }

    Color? tagColorForLog(ActionLog log) {
      try {
        if (log.notes == null || log.notes!.isEmpty) return null;
        final obj = jsonDecode(log.notes!);
        if (obj is Map<String, dynamic>) {
          final areaName = obj['area'] as String?;
          final category = obj['category'] as String?;
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
        return Dialog(
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
                    child: Text('Keine Aktivitäten an diesem Tag', style: Theme.of(context).textTheme.bodyMedium),
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
                                  child: Row(children: [const Icon(Icons.timer, size: 12), const SizedBox(width: 4), Text('${log.durationMin} Min')]),
                                ),
                              Row(children: [const Icon(Icons.star, size: 12), const SizedBox(width: 4), Text('+${log.earnedXp}')]),
                            ],
                          ),
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => ActivityDetailsDialog(log: log),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<DateTime, List<_DayEntry>>> _loadCalendarLogsForMonth(DateTime month) async {
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
      print('Fehler beim Laden der Kalenderdaten: $e');
      return {};
    }

    // Load life areas for color tagging
    final lifeAreasRes = await client
        .from('life_areas')
        .select('name,category,color')
        .eq('user_id', user.id);
    final List<_AreaTag> areaTags = (lifeAreasRes as List).map((m) => _AreaTag(
      name: (m['name'] as String).trim(),
      category: (m['category'] as String).trim(),
      color: _parseHexColor((m['color'] as String?) ?? '#2196F3'),
    )).toList();

    final Map<DateTime, List<_DayEntry>> dayToTitles = {};

    for (final row in logsRes) {
      final occurredAt = DateTime.parse(row['occurred_at'] as String).toLocal();
      final dayKey = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
      final String? activityName = row['activity_name'] as String?; // may be null if not selected
      final String? templateId = row['template_id'] as String?;
      final String? notes = row['notes'] as String?;

      String title = activityName ?? (templateId != null ? (templateIdToName[templateId] ?? 'Aktivität') : 'Aktivität');
      Color? tagColor;
      if (notes != null && notes.isNotEmpty) {
        try {
          final obj = jsonDecode(notes);
          if (obj is Map<String, dynamic>) {
            final t = obj['title'];
            if (t is String && t.trim().isNotEmpty) {
              title = t.trim();
            }
            final areaName = obj['area'];
            final category = obj['category'];
            if (areaName is String || category is String) {
              final match = _matchAreaTag(areaTags, areaName as String?, category as String?);
              if (match != null) tagColor = match.color;
            }
          }
        } catch (_) {}
      }

      dayToTitles.putIfAbsent(dayKey, () => <_DayEntry>[]).add(_DayEntry(title: title, color: tagColor));
    }

    return dayToTitles;
  }

  Widget _buildCalendarContainer(BuildContext context) {
    final monthLabel = DateFormat.yMMMM('de_DE').format(_calendarMonth);
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _goToPreviousMonth,
                    tooltip: 'Vorheriger Monat',
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
                    tooltip: 'Nächster Monat',
                  ),
                ],
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
            future: _loadCalendarLogsForMonth(_calendarMonth),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final data = snapshot.data ?? {};

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
      {'name': 'Ernährung', 'icon': 'restaurant'},
      {'name': 'Bildung', 'icon': 'school'},
      {'name': 'Finanzen', 'icon': 'account_balance'},
      {'name': 'Kunst', 'icon': 'palette'},
      {'name': 'Beziehungen', 'icon': 'people'},
      {'name': 'Karriere', 'icon': 'work'},
      {'name': 'Zuhause', 'icon': 'home'},
      {'name': 'Gesundheit', 'icon': 'local_hospital'},
      {'name': 'Reisen', 'icon': 'flight'},
      {'name': 'Musik', 'icon': 'music_note'},
      {'name': 'Sport', 'icon': 'sports_soccer'},
      {'name': 'Technologie', 'icon': 'computer'},
      {'name': 'Natur', 'icon': 'eco'},
      {'name': 'Lesen', 'icon': 'book'},
      {'name': 'Schreiben', 'icon': 'edit'},
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Neuen Lebensbereich hinzufügen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name Field
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'z.B. Fitness, Bildung, etc.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Category Field
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Kategorie (optional)',
                        hintText: 'z.B. Gesundheit, Persönlich',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Color Selection
                    const Text(
                      'Farbe auswählen:',
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
                      'Icon auswählen:',
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
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bitte gib einen Namen ein')),
                      );
                      return;
                    }
                    
                    try {
                      await LifeAreasService.createLifeArea(
                        name: nameController.text.trim(),
                        category: categoryController.text.trim().isEmpty ? 'Allgemein' : categoryController.text.trim(),
                        color: selectedColor,
                        icon: selectedIcon,
                      );
                      Navigator.of(context).pop();
                      // Force rebuild
                      setState(() {
                        _refreshCounter++;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lebensbereich erfolgreich erstellt')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler beim Erstellen: $e')),
                      );
                    }
                  },
                  child: const Text('Erstellen'),
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

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      
      int streak = 0;
      DateTime currentDate = todayDate;

      while (true) {
        final hasEntry = dates.any((date) {
          final entryDate = DateTime(date.year, date.month, date.day);
          return entryDate.isAtSameMomentAs(currentDate);
        });

        if (hasEntry) {
          streak++;
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      print('Fehler beim Berechnen des Streaks: $e');
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
      print('Fehler beim Laden der Log-Daten: $e');
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
             tooltip: 'Dashboard neu laden',
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
             icon: const Icon(Icons.bug_report),
             tooltip: 'Avatar Debug',
             onPressed: () => Navigator.of(context).push(
               MaterialPageRoute(builder: (_) => const DebugAvatarPage()),
             ),
           ),
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
                  child: FutureBuilder<int>(
                    future: calculateStreak(),
                    builder: (ctx, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Text('Fehler: ${snap.error}');
                      }
                      final streak = snap.data ?? 0;
                      final badge = badgeLevel(streak);

                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.orange, Colors.deepOrange],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.local_fire_department,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dein Streak',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$streak Tage',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                if (streak > 0)
                                  Text(
                                    'Du bist auf einem guten Weg!',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[500],
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
                  const double heroRowHeight = 150;
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
                      SizedBox(
                        width: 360,
                        height: heroRowHeight,
                        child: streakCard,
                      ),
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
                      'Lebensbereiche',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Verwalte deine persönlichen Bereiche',
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
                                Text('Lade Lebensbereiche...'),
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
                                Text('Fehler beim Laden der Lebensbereiche'),
                                const SizedBox(height: 8),
                                                           ElevatedButton(
                                   onPressed: () {
                                     // Force rebuild
                                     setState(() {
                                       _refreshCounter++;
                                     });
                                   },
                                   child: const Text('Erneut versuchen'),
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
                                  'Noch keine Lebensbereiche',
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
                                       print('Fehler beim Erstellen der Standard-Bereiche: $e');
                                     }
                                   },
                                  child: const Text('Standard-Bereiche erstellen'),
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

            // Quick Actions for All Life Areas
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Schnellzugriff auf alle Aktivitäten',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Direkte Aktivitäten für alle Lebensbereiche',
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
                            Text('Fehler beim Laden der Lebensbereiche'),
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
                        child: Text('Keine Lebensbereiche verfügbar'),
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
                                    ),
                                  ),
                                );
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
                                          Text(
                                            'Aktivität hinzufügen',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${area.name} - ${area.category}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _parseColor(area.color).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add,
                                            size: 16,
                                            color: _parseColor(area.color),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Schnell',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: _parseColor(area.color),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
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
      final areas = await LifeAreasService.getLifeAreas();
      if (areas.isEmpty) {
        // Erstelle Standard-Bereiche wenn keine vorhanden
        await LifeAreasService.createDefaultLifeAreas();
        return await LifeAreasService.getLifeAreas();
      }
      return areas;
    } catch (e) {
      print('Fehler beim Laden der Life Areas: $e');
      rethrow;
    }
  }

  Color _parseColor(String hex) {
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final List<_DayEntry> entries;
  final VoidCallback? onTap;

  const _CalendarDayCell({
    Key? key,
    required this.day,
    required this.entries,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Maximal 2 Zeilen anzeigen: erste Aktivität + ggf. "+N"
    final List<_DayEntry> shown = () {
      if (entries.isEmpty) return const <_DayEntry>[];
      if (entries.length == 1) return <_DayEntry>[entries.first];
      return <_DayEntry>[entries.first, _DayEntry(title: '+${entries.length - 1}')];
    }();

    final cell = Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$day',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.8),
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
        ),
      ),
    );

    if (entries.isEmpty) return cell;
    final tooltipText = entries.map((e) => e.title).join('\n');
    return Tooltip(message: tooltipText, child: cell);
  }
}

class _DayEntry {
  final String title;
  final Color? color;
  const _DayEntry({required this.title, this.color});
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