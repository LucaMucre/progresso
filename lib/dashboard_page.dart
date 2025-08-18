import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'life_area_detail_page.dart';
import 'log_action_page.dart';
import 'services/db_service.dart' as db_service;
import 'services/life_areas_service.dart';
import 'widgets/bubble_widget.dart';
import 'dashboard/widgets/gallery_filters.dart';
import 'widgets/activity_details_dialog.dart';
import 'services/level_up_service.dart';
import 'models/action_models.dart' as models;
import 'services/achievement_service.dart';
import 'utils/parsed_activity_data.dart';
import 'widgets/optimized_image.dart';
import 'navigation.dart';
import 'dashboard/widgets/calendar_header.dart';
import 'dashboard/widgets/calendar_grid.dart';
import 'widgets/skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/app_state.dart';
import 'utils/logging_service.dart';
import 'utils/app_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with RouteAware {
  // Add a counter to force FutureBuilder rebuild
  int _refreshCounter = 0;
  Future<List<LifeArea>>? _lifeAreasFuture; // cache to avoid refetch on minor rebuilds
  Future<Map<String, dynamic>>? _globalStatsFuture;
  Future<List<int>>? _globalActivity7dFuture;
  Future<Map<String, dynamic>>? _globalDurationStacksFuture;
  // View mode for life areas container: 0 = bubbles, 1 = calendar, 2 = gallery, 3 = table
  int _viewMode = 0;
  // Current month displayed in the calendar view
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  // Optional filter: show only activities for this life area name
  String? _selectedAreaFilterName;

  // Ensure default life areas are only created once even if multiple builders call _loadLifeAreas()
  Future<void>? _ensureDefaultsFuture;
  // Debounce timer for realtime refreshes
  Timer? _realtimeDebounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // subscribe to route changes
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  // moved: gallery filters extracted into GalleryFilters widget

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Returning to dashboard: show any queued achievements/level-ups now
    if (!mounted) return;
    // Direkt anzeigen ohne extra Checks – Events triggern sich selbst nach Pop
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await LevelUpService.showPendingAchievements(context: context);
      // Nach Rückkehr Daten aktualisieren (Stats/Charts/Streak)
      setState(() {
        _globalStatsFuture = _calculateGlobalStatistics();
        _globalActivity7dFuture = _getGlobalLast7DaysActivity();
        _globalDurationStacksFuture = _getGlobalLast7DaysDurationStacks();
      });
      try {
        // Riverpod Provider invalidieren, damit Streak neu berechnet wird
        if (mounted) {
          final container = ProviderScope.containerOf(context, listen: false);
          container.refresh(streakNotifierProvider);
        }
      } catch (e, stackTrace) {
        LoggingService.error('Error in dashboard operation', e, stackTrace, 'Dashboard');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _lifeAreasFuture = _loadLifeAreas();
    _globalStatsFuture = _calculateGlobalStatistics();
    _globalActivity7dFuture = _getGlobalLast7DaysActivity();
    _globalDurationStacksFuture = _getGlobalLast7DaysDurationStacks();
    // Automatische Aktualisierung beim Start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initial leichter Rebuild ist okay, aber keine wiederholten Trigger
      if (mounted) setState(() {});
      // Level-up popup listener (dashboard-wide). If the event happened just
      // before the dashboard mounted, setOnLevelUp will trigger immediately.
      LevelUpService.setOnLevelUp((level) async {
        if (!mounted) return;
        await LevelUpService.showLevelThenPending(context: context, level: level);
      });
      // Listen for achievement unlocks globally and queue them
      AchievementService.setOnAchievementUnlocked((a) {
        LevelUpService.queueAchievement(a);
      });
    // Ensure achievements are loaded for the current session user on dashboard start
    // This prevents re-showing already unlocked achievements after login/logout
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AchievementService.loadUnlockedAchievements();
    });
      // If any achievements were queued while another page was open, show them now
      LevelUpService.showPendingAchievements(context: context);
      // Nach Schließen von Dialogen nichts forcieren
      LevelUpService.addOnDialogsClosed(() {
        // bewusst leer – kein setState/Reload
      });
    });

    // Realtime: Änderungen an action_logs triggern Refresh (sanft ohne aggressive setState)
    try {
      final client = Supabase.instance.client;
      client
          .channel('realtime-logs')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'action_logs',
            callback: (PostgresChangePayload payload) {
              if (!mounted || LevelUpService.isShowingDialogs) return;
              _realtimeDebounce?.cancel();
              _realtimeDebounce = Timer(const Duration(milliseconds: 250), () {
                if (!mounted) return;
                setState(() {
                  _refreshCounter++;
                  _globalStatsFuture = _calculateGlobalStatistics();
                  _globalActivity7dFuture = _getGlobalLast7DaysActivity();
                  _globalDurationStacksFuture = _getGlobalLast7DaysDurationStacks();
                });
              });
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'action_logs',
            callback: (PostgresChangePayload payload) {
              if (!mounted || LevelUpService.isShowingDialogs) return;
              _realtimeDebounce?.cancel();
              _realtimeDebounce = Timer(const Duration(milliseconds: 250), () {
                if (!mounted) return;
                setState(() {
                  _refreshCounter++;
                  _globalStatsFuture = _calculateGlobalStatistics();
                  _globalActivity7dFuture = _getGlobalLast7DaysActivity();
                  _globalDurationStacksFuture = _getGlobalLast7DaysDurationStacks();
                });
              });
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'action_logs',
            callback: (PostgresChangePayload payload) {
              if (!mounted || LevelUpService.isShowingDialogs) return;
              _realtimeDebounce?.cancel();
              _realtimeDebounce = Timer(const Duration(milliseconds: 250), () {
                if (!mounted) return;
                setState(() {
                  _refreshCounter++;
                  _globalStatsFuture = _calculateGlobalStatistics();
                  _globalActivity7dFuture = _getGlobalLast7DaysActivity();
                  _globalDurationStacksFuture = _getGlobalLast7DaysDurationStacks();
                });
              });
            },
          )
          .subscribe();
    } catch (e, stackTrace) {
      LoggingService.error('Error in dashboard operation', e, stackTrace, 'Dashboard');
    }
  }


  
  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('SignOut Fehler: $e');
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

  // Supabase Image Transformations thumbnail helper
  String _thumbUrl(String publicUrl, {int width = 600, int quality = 80}) {
    try {
      final uri = Uri.parse(publicUrl);
      if (!uri.path.contains('/storage/v1/object/public/')) return publicUrl;
      final params = {
        'width': width.toString(),
        'quality': quality.toString(),
        'resize': 'contain',
      };
      final newUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...params,
      });
      return newUri.toString();
    } catch (_) {
      return publicUrl;
    }
  }

  Future<List<models.ActionLog>> _fetchLogsForDay(DateTime day) async {
    try {
      // Use local storage via db_service
      final logs = await db_service.fetchLogs();
      
      // Filter to only include logs that occurred on the specified day in local time
      return logs.where((log) {
        final localTime = log.occurredAt.toLocal();
        final logDay = DateTime(localTime.year, localTime.month, localTime.day);
        final targetDay = DateTime(day.year, day.month, day.day);
        return logDay.isAtSameMomentAs(targetDay);
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching logs for day: $e');
      return [];
    }
  }

  Future<void> _openDayDetails(DateTime day) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    // Fetch data in parallel for better performance
    final results = await Future.wait<dynamic>([
      _fetchLogsForDay(day),
      client
        .from('action_templates')
        .select('id,name,category')
        .eq('user_id', user.id),
      client
        .from('life_areas')
        .select('name,category,color')
        .eq('user_id', user.id),
    ]);
    
    final logs = results[0] as List<models.ActionLog>;
    final templatesRes = results[1] as List<dynamic>;
    final lifeAreasRes = results[2] as List<dynamic>;

    final templateMap = {
      for (final t in (templatesRes as List)) (t['id'] as String): (t['name'] as String)
    };
    final templateIdToCategory = {
      for (final t in (templatesRes as List)) (t['id'] as String): LifeAreasService.canonicalCategory((t['category'] as String?) ?? '')
    };
    final List<_AreaTag> areaTags = (lifeAreasRes as List).map((m) => _AreaTag(
      // Nutze kanonische Schlüssel (englisch, lowercase) für stabilen Match
      name: LifeAreasService.canonicalAreaName((m['name'] as String).trim()),
      category: LifeAreasService.canonicalCategory((m['category'] as String).trim()),
      color: _parseHexColor((m['color'] as String?) ?? '#2196F3'),
    )).toList();
    
    if (kDebugMode) {
      debugPrint('AREA TAGS DEBUG: Loaded ${areaTags.length} area tags');
      for (final tag in areaTags) {
        debugPrint('  - ${tag.name} (${tag.category}) -> ${tag.color}');
      }
    }

    String titleForLog(models.ActionLog log) {
      if (log.activityName != null && log.activityName!.trim().isNotEmpty) {
        return log.activityName!.trim();
      }
      
      // Use parsed data instead of re-parsing JSON
      final parsed = ParsedActivityData.fromNotes(log.notes);
      final title = parsed.displayTitle;
      if (title != 'Activity') return title;
      
      if (log.templateId != null && templateMap[log.templateId!] != null) {
        return templateMap[log.templateId!]!;
      }
      return 'Activity';
    }

    Color? tagColorForLog(models.ActionLog log) {
      try {
        if (log.notes != null && log.notes!.isNotEmpty) {
          final parsed = ParsedActivityData.fromNotes(log.notes);
          if (parsed.isValid) {
            final areaName = LifeAreasService.canonicalAreaName(parsed.area);
            final lifeArea = LifeAreasService.canonicalAreaName(parsed.lifeArea);
            final category = LifeAreasService.canonicalCategory(parsed.category);
            
            // Verwende den präzisesten verfügbaren Area-Namen für Match
            final effectiveAreaName = areaName.isNotEmpty ? areaName : lifeArea;
            final match = _matchAreaTag(areaTags, effectiveAreaName, category);
            if (match != null) {
              return match.color;
            }
            
            // Direkte Area-Ableitung falls kein Tag-Match
            String areaKey = effectiveAreaName;
            // Normalize nutrition to health
            if (areaKey == 'nutrition') areaKey = 'health';
            if (areaKey.isEmpty) {
              switch (category) {
                case 'inner':
                  areaKey = 'spirituality';
                  break;
                case 'social':
                  areaKey = 'relationships';
                  break;
                case 'work':
                  areaKey = 'career';
                  break;
                case 'development':
                  areaKey = 'learning';
                  break;
                case 'finance':
                  areaKey = 'finance';
                  break;
                case 'health':
                  areaKey = 'health';
                  break;
                case 'vitality':
                  areaKey = 'vitality';
                  break;
                case 'creativity':
                  areaKey = 'art';
                  break;
              }
            }
            if (areaKey.isNotEmpty) {
              return _colorForAreaKey(areaKey);
            }
          }
        }
      } catch (e, stackTrace) {
        LoggingService.error('Error in dashboard operation', e, stackTrace, 'Dashboard');
      }
      
      // Template-Kategorie Fallback
      if (log.templateId != null) {
        final cat = templateIdToCategory[log.templateId!];
        if (cat != null && cat.isNotEmpty) {
          String areaKey = '';
          switch (cat) {
            case 'inner':
              areaKey = 'spirituality';
              break;
            case 'social':
              areaKey = 'relationships';
              break;
            case 'work':
              areaKey = 'career';
              break;
            case 'development':
              areaKey = 'learning';
              break;
            case 'finance':
              areaKey = 'finance';
              break;
            case 'health':
              areaKey = 'health';
              break;
            case 'vitality':
              areaKey = 'vitality';
              break;
            case 'creativity':
              areaKey = 'art';
              break;
          }
          if (areaKey.isNotEmpty) {
            return _colorForAreaKey(areaKey);
          }
        }
      }
      
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
                Builder(
                  builder: (context) {
                    // Aggregation basierend auf den tatsächlich angezeigten Logs
                    final List<Map<String, dynamic>> acc = [];
                    final Map<String, Map<String, int>> tmp = {};
                    for (final log in logs) {
                      // Bestimme Area-Key analog zur Tag-Farbe
                      String areaKey = 'unknown';
                      try {
                        if (log.notes != null && log.notes!.isNotEmpty) {
                          final obj = jsonDecode(log.notes!);
                          if (obj is Map<String, dynamic>) {
                            final areaName = LifeAreasService.canonicalAreaName(obj['area'] as String?);
                            final category = LifeAreasService.canonicalCategory(obj['category'] as String?);
                            final match = _matchAreaTag(areaTags, areaName, category);
                            if (match != null) areaKey = match.name.toLowerCase();
                            // Normalize nutrition to health
                            if (areaKey == 'nutrition') areaKey = 'health';
                            // Fallbacks wie in der RPC-Logik
                            if (areaKey == 'unknown' || areaKey.isEmpty) {
                              switch (category) {
                                case 'inner':
                                  areaKey = 'spirituality';
                                  break;
                                case 'social':
                                  areaKey = 'relationships';
                                  break;
                                case 'work':
                                  areaKey = 'career';
                                  break;
                                case 'development':
                                  areaKey = 'learning';
                                  break;
                                case 'finance':
                                  areaKey = 'finance';
                                  break;
                                case 'health':
                                  areaKey = 'health';
                                  break;
                                case 'creativity':
                                  areaKey = 'art';
                                  break;
                              }
                            }
                          }
                        }
                      } catch (e, stackTrace) {
        LoggingService.error('Error in dashboard operation', e, stackTrace, 'Dashboard');
      }
                      final bucket = tmp.putIfAbsent(areaKey, () => {'total': 0, 'sum_duration': 0, 'sum_xp': 0});
                      bucket['total'] = (bucket['total'] ?? 0) + 1;
                      bucket['sum_duration'] = (bucket['sum_duration'] ?? 0) + (log.durationMin ?? 0);
                      bucket['sum_xp'] = (bucket['sum_xp'] ?? 0) + log.earnedXp;
                    }
                    tmp.forEach((k, v) {
                      acc.add({'area_key': k, 'total': v['total'] ?? 0, 'sum_duration': v['sum_duration'] ?? 0, 'sum_xp': v['sum_xp'] ?? 0});
                    });
                    if (acc.isEmpty) return const SizedBox.shrink();
                    acc.sort((a, b) {
                      final c = (b['total'] as int).compareTo(a['total'] as int);
                      if (c != 0) return c;
                      final d = (b['sum_duration'] as int).compareTo(a['sum_duration'] as int);
                      if (d != 0) return d;
                      final x = (b['sum_xp'] as int).compareTo(a['sum_xp'] as int);
                      if (x != 0) return x;
                      return ((a['area_key'] as String?) ?? '').compareTo(((b['area_key'] as String?) ?? ''));
                    });
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: acc.map((r) {
                          final String area = (r['area_key'] as String?) ?? 'unknown';
                          final int total = (r['total'] as num?)?.toInt() ?? 0;
                          final int mins = (r['sum_duration'] as num?)?.toInt() ?? 0;
                          final int xp = (r['sum_xp'] as num?)?.toInt() ?? 0;
                          final color = _getAreaColor(area, areaTags);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(color: color.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text('$area: $total • ${mins}m • +$xp'),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
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
                        final c = tagColorForLog(log) ?? (() {
                          // Deterministische Farbe ableiten, kein Theme-Fallback
                          String areaKey = '';
                          try {
                            if (log.notes != null && log.notes!.isNotEmpty) {
                              final obj = jsonDecode(log.notes!);
                              if (obj is Map<String, dynamic>) {
                                final areaName = LifeAreasService.canonicalAreaName(obj['area'] as String?);
                                final lifeArea = LifeAreasService.canonicalAreaName(obj['life_area'] as String?);
                                final category = LifeAreasService.canonicalCategory(obj['category'] as String?);
                                final match = _matchAreaTag(areaTags, areaName.isNotEmpty ? areaName : lifeArea, category);
                                if (match != null) return match.color;
                                areaKey = areaName.isNotEmpty ? areaName : lifeArea;
                                // Normalize nutrition to health
                                if (areaKey == 'nutrition') areaKey = 'health';
                                if (areaKey.isEmpty) {
                                  switch (category) {
                                    case 'inner':
                                      areaKey = 'spirituality';
                                      break;
                                    case 'social':
                                      areaKey = 'relationships';
                                      break;
                                    case 'work':
                                      areaKey = 'career';
                                      break;
                                    case 'development':
                                      areaKey = 'learning';
                                      break;
                                    case 'finance':
                                      areaKey = 'finance';
                                      break;
                                    case 'health':
                                      areaKey = 'health';
                                      break;
                                    case 'creativity':
                                      areaKey = 'art';
                                      break;
                                  }
                                }
                              }
                            }
                          } catch (e, stackTrace) {
        LoggingService.error('Error in dashboard operation', e, stackTrace, 'Dashboard');
      }
                          if (areaKey.isEmpty && log.templateId != null) {
                            final cat = templateIdToCategory[log.templateId!];
                            if (cat != null && cat.isNotEmpty) {
                              switch (cat) {
                                case 'inner':
                                  areaKey = 'spirituality';
                                  break;
                                case 'social':
                                  areaKey = 'relationships';
                                  break;
                                case 'work':
                                  areaKey = 'career';
                                  break;
                                case 'development':
                                  areaKey = 'learning';
                                  break;
                                case 'finance':
                                  areaKey = 'finance';
                                  break;
                                case 'health':
                                  areaKey = 'health';
                                  break;
                                case 'creativity':
                                  areaKey = 'art';
                                  break;
                              }
                            }
                          }
                          return _getAreaColor(areaKey.isNotEmpty ? areaKey : 'unknown', areaTags);
                        })();
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
                                  logs.removeWhere((l) => (l as dynamic).id == log.id);
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
    try {
      // Use local storage via db_service
      final logs = await db_service.fetchLogs();
      final templates = await db_service.fetchTemplates();

      final Map<String, String> templateIdToName = {
        for (final t in templates) t.id: t.name
      };

      // Filter logs to the specified month
      final filteredLogs = logs.where((log) {
        final occurredAt = log.occurredAt.toLocal();
        final dayKey = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
        return dayKey.year == month.year && dayKey.month == month.month;
      }).toList();

      // Load life areas for color tagging
      final lifeAreas = await LifeAreasService.getLifeAreas();
      final List<_AreaTag> areaTags = lifeAreas.map((area) => _AreaTag(
        name: LifeAreasService.canonicalAreaName(area.name.trim()),
        category: LifeAreasService.canonicalCategory(area.category.trim()),
        color: _parseHexColor(area.color),
      )).toList();

      final Map<DateTime, List<_DayEntry>> dayToTitles = {};

      for (final log in filteredLogs) {
        final occurredAt = log.occurredAt.toLocal();
        final dayKey = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
        
        final String? activityName = log.activityName;
        final String? templateId = log.templateId;
        final String? notes = log.notes;
        final int? durationMin = log.durationMin;

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
            if (areaName.isNotEmpty || category.isNotEmpty) {
              matched = _matchAreaTag(areaTags, areaName, category);
              if (matched != null) tagColor = matched.color;
            }
          }
        } catch (e, stackTrace) {
        LoggingService.error('Error in dashboard operation', e, stackTrace, 'Dashboard');
      }
      }

      // Apply filter: skip if a filter is set and this log doesn't match
      if (areaFilterName != null) {
        if (matched == null || matched.name.toLowerCase() != areaFilterName.toLowerCase()) {
          continue;
        }
      }

      String? areaKey = matched != null
          ? matched.name.toLowerCase()  // Use just the name, not name|category
          : null;
      // Normalize nutrition to health in areaKey
      if (areaKey == 'nutrition') {
        areaKey = 'health';
      }
      
      // Debug for day 16
      if (dayKey.day == 16 && kDebugMode) {
        debugPrint('Entry: $title, areaKey: $areaKey, color: ${tagColor != null ? '#${tagColor!.value.toRadixString(16).padLeft(8, '0').substring(2)}' : 'null'}, duration: $durationMin');
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

    Future<List<Map<String, dynamic>>> _fetchAllImages({int limit = 60, int offset = 0}) async {
      try {
        // Use local storage via db_service
        final logs = await db_service.fetchLogs();
        
        // Filter for logs with images, sort by date descending, then paginate
        final logsWithImages = logs
            .where((log) => log.imageUrl != null && log.imageUrl!.isNotEmpty)
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

        // Apply pagination
        final paginatedLogs = logsWithImages
            .skip(offset)
            .take(limit)
            .map((log) => {
              'id': log.id,
              'occurred_at': log.occurredAt.toIso8601String(),
              'image_url': log.imageUrl,
              'notes': log.notes,
            })
            .toList();

        return paginatedLogs;
      } catch (e) {
        if (kDebugMode) debugPrint('Error fetching images: $e');
        return [];
      }
    }

  Widget _buildTableContainer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
              Icon(
                Icons.table_rows,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Activity Table',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Table with all activities - wrapped in RepaintBoundary for performance
          RepaintBoundary(
            child: FutureBuilder<List<List>>(
            future: Future.wait([_loadAllActivities(), _lifeAreasFuture ?? _loadLifeAreas()]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text('Error loading activities: ${snapshot.error}'),
                  ),
                );
              }
              
              final results = snapshot.data;
              if (results == null || results.length < 2) return Container();
              
              final activities = results[0] as List<Map<String, dynamic>>;
              final lifeAreas = results[1] as List<LifeArea>;
              
              if (activities.isEmpty) {
                return Container(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: AppTheme.spacing16),
                        Text(
                          'No activities yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start logging activities to see them here',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return _buildActivitiesTable(activities, lifeAreas);
            },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadAllActivities() async {
    try {
      // Use local storage via db_service
      final logs = await db_service.fetchLogs();
      
      // Convert to the expected format, limit to 500 most recent
      final result = logs
          .take(500)
          .map((log) => {
            'id': log.id,
            'activity_name': log.activityName,
            'occurred_at': log.occurredAt.toIso8601String(),
            'duration_min': log.durationMin,
            'notes': log.notes,
            'image_url': log.imageUrl,
            'earned_xp': log.earnedXp,
            'template_id': log.templateId,
          })
          .toList();
      
      if (kDebugMode) debugPrint('Loaded ${result.length} activities for table view from local storage');
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading all activities: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Widget _buildActivitiesTable(List<Map<String, dynamic>> activities, List<LifeArea> lifeAreas) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Activity',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Life Area',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Duration',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Table Body
          SizedBox(
            height: 400, // Fixed height for scrolling
            child: ListView.builder(
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                final isEven = index % 2 == 0;
                
                // Extract activity name from activity_name field or notes - optimized parsing
                String activityName = activity['activity_name'] as String? ?? '';
                if (activityName.isEmpty) {
                  final parsed = ParsedActivityData.fromNotes(activity['notes'] as String?);
                  activityName = parsed.displayTitle;
                }
                final imageUrl = activity['image_url'] as String?;
                final occurredAt = DateTime.parse(activity['occurred_at'] as String);
                final durationMin = activity['duration_min'] as int?;
                
                // Extract life area information using actual life areas
                String areaName = 'Activity';
                String areaColor = '#6366f1';
                
                // Extract life area information from notes - optimized parsing
                final parsed = ParsedActivityData.fromNotes(activity['notes'] as String?);
                final extractedArea = parsed.effectiveAreaName;
                final extractedCategory = parsed.category;
                
                // Convert LifeAreas to AreaTags for matching
                final areaTags = lifeAreas.map((la) => _AreaTag(
                  name: la.name,
                  category: la.category,
                  color: _parseHexColor(la.color),
                )).toList();
                
                // Try to match with actual life areas
                final matchedArea = _matchAreaTag(areaTags, extractedArea, extractedCategory);
                if (matchedArea != null) {
                  areaName = matchedArea.name;
                  areaColor = '#${matchedArea.color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                } else if (extractedArea.isNotEmpty) {
                  areaName = extractedArea;
                } else if (extractedCategory != null && extractedCategory.trim().isNotEmpty) {
                  areaName = extractedCategory.trim();
                }
                
                return InkWell(
                  onTap: () {
                    // Convert activity data to ActionLog and show details dialog
                    final actionLog = models.ActionLog(
                      id: activity['id'].toString(),
                      occurredAt: occurredAt,
                      durationMin: durationMin,
                      notes: activity['notes'] as String?,
                      earnedXp: activity['earned_xp'] as int? ?? 0,
                      templateId: activity['template_id'] as String?,
                      activityName: activity['activity_name'] as String?,
                      imageUrl: imageUrl,
                    );
                    
                    showDialog(
                      context: context,
                      builder: (_) => ActivityDetailsDialog(
                        log: actionLog,
                        onUpdate: () {
                          // Refresh the activities when updated
                          setState(() {
                            // Force rebuild to refresh the activity table
                          });
                        },
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isEven ? Colors.grey[50] : Colors.white,
                    ),
                    child: Row(
                    children: [
                      // Activity Name
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            if (imageUrl != null)
                              Container(
                                width: 32,
                                height: 32,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: OptimizedImage(
                                  imageUrl: imageUrl,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 64,
                                  memCacheHeight: 64,
                                ),
                              ),
                            Flexible(
                              child: Text(
                                activityName,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Life Area
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Color(int.parse(areaColor.replaceFirst('#', '0xFF'))),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                areaName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Date
                      Expanded(
                        child: Text(
                          _formatDate(occurredAt),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      
                      // Duration
                      Expanded(
                        child: Text(
                          durationMin != null 
                              ? '${durationMin}min'
                              : '-',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final activityDate = DateTime(date.year, date.month, date.day);

    if (activityDate == today) {
      return 'Today ${_formatTime(date)}';
    } else if (activityDate == yesterday) {
      return 'Yesterday ${_formatTime(date)}';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildGalleryContainer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
              Icon(
                Icons.photo_library,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Photo Gallery',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Text(
                'All your memories',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Gallery filter chips by life area
          GalleryFilters(
            selectedAreaFilterName: _selectedAreaFilterName,
            onSelected: (name) => setState(() {
              _selectedAreaFilterName = name;
              _refreshCounter++;
            }),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400, // Fixed height for gallery
            child: Consumer(
              builder: (context, ref, _) {
                final logsAsync = ref.watch(logsNotifierProvider);
                return logsAsync.when(
                  loading: () => const Center(child: SkeletonCard(height: 180)),
                  error: (e, st) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        SizedBox(height: AppTheme.spacing16),
                        Text(
                          'Error loading photos',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                  data: (_) {
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      key: ValueKey(_refreshCounter),
                      future: _fetchAllImages(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: SkeletonCard(height: 180));
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                SizedBox(height: AppTheme.spacing16),
                                Text(
                                  'Error loading photos',
                                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                                ),
                              ],
                            ),
                          );
                        }
                        List<Map<String, dynamic>> images = List<Map<String, dynamic>>.from(snapshot.data ?? const []);
                        // Apply client-side filter by life area if selected
                        if (_selectedAreaFilterName != null && _selectedAreaFilterName!.trim().isNotEmpty) {
                          final selectedCanonical = LifeAreasService.canonicalAreaName(_selectedAreaFilterName);
                          images = images.where((img) {
                            final area = _extractActivityArea(img);
                            final name = area['name'] as String?;
                            return LifeAreasService.canonicalAreaName(name) == selectedCanonical;
                          }).toList();
                        }
                        if (images.isEmpty) {
                          return const Center(child: Text('No photos yet'));
                        }
                        return _buildImageGrid(images);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

    String _extractActivityTitle(Map<String, dynamic> imageData) {
    // Parse title from notes JSON
    try {
      final notes = imageData['notes'];
      if (notes != null) {
        final obj = jsonDecode(notes);
        if (obj is Map<String, dynamic> && obj['title'] != null) {
          return obj['title'].toString();
        }
      }
    } catch (e, stackTrace) {
      LoggingService.error('Error in dashboard operation', e, stackTrace, 'Dashboard');
    }

    return 'Activity';
  }

  Map<String, dynamic> _extractActivityArea(Map<String, dynamic> imageData) {
    // Parse area from notes JSON
    try {
      final notes = imageData['notes'];
      if (notes != null) {
        final obj = jsonDecode(notes);
        if (obj is Map<String, dynamic> && obj['area'] != null) {
          final areaName = obj['area'].toString();
          
          // Default life areas with their properties
          final defaultAreas = [
            {'name': 'Fitness', 'icon': Icons.fitness_center, 'color': '#FF5722'},
            {'name': 'Nutrition', 'icon': Icons.restaurant, 'color': '#4CAF50'},
            {'name': 'Learning', 'icon': Icons.school, 'color': '#2196F3'},
            {'name': 'Finance', 'icon': Icons.account_balance, 'color': '#FFC107'},
            {'name': 'Art', 'icon': Icons.palette, 'color': '#9C27B0'},
            {'name': 'Relationships', 'icon': Icons.people, 'color': '#E91E63'},
            {'name': 'Spirituality', 'icon': Icons.self_improvement, 'color': '#607D8B'},
            {'name': 'Career', 'icon': Icons.work, 'color': '#795548'},
          ];
          
          // Find matching area
          final area = defaultAreas.firstWhere(
            (a) => a['name'] == areaName || 
                   LifeAreasService.canonicalAreaName(a['name'] as String?) == LifeAreasService.canonicalAreaName(areaName),
            orElse: () => {'name': 'General', 'icon': Icons.circle, 'color': '#666666'},
          );
          
          return {
            'name': area['name'],
            'icon': area['icon'],
            'color': area['color'],
          };
        }
      }
    } catch (e, stackTrace) {
      LoggingService.error('Error in dashboard operation', e, stackTrace, 'Dashboard');
    }

    return {
      'name': 'General',
      'icon': Icons.circle,
      'color': '#666666',
    };
  }

  void _showImageFullscreen(BuildContext context, Map<String, dynamic> imageData, List<Map<String, dynamic>> allImages, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: allImages.length,
              itemBuilder: (context, index) {
                final data = allImages[index];
                final imageUrl = data['image_url'] as String;
                final date = DateTime.parse(data['occurred_at']);
                final title = _extractActivityTitle(data);
                final area = _extractActivityArea(data);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      child: CachedNetworkImage(
                        imageUrl: _thumbUrl(imageUrl, width: 2000, quality: 90),
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                    // Bottom info overlay
                    Positioned(
                      bottom: 40,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(area['color'].substring(1), radix: 16) + 0xFF000000),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        area['icon'],
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        area['name'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, MMMM d, y • h:mm a').format(date),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            // Image counter
            Positioned(
              top: 40,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${initialIndex + 1} of ${allImages.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarContainer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<List<LifeArea>>(
            future: _lifeAreasFuture,
            builder: (context, snap) {
              final areas = snap.data ?? const <LifeArea>[];
              return CalendarHeader(
                month: _calendarMonth,
                onPrev: _goToPreviousMonth,
                onNext: _goToNextMonth,
                areaNames: areas.map((a) => a.name).toList(),
                selectedAreaName: _selectedAreaFilterName,
                onAreaSelected: (v) => setState(() => _selectedAreaFilterName = v),
              );
            },
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
          FutureBuilder<List<LifeArea>>(
            future: _lifeAreasFuture,
            builder: (context, areasSnapshot) {
              final areas = areasSnapshot.data ?? const <LifeArea>[];
              
              return Consumer(
                builder: (context, ref, _) {
                  final logsAsync = ref.watch(logsNotifierProvider);
                  return logsAsync.when(
                    loading: () {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    error: (e, st) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Error loading calendar')),
                      );
                    },
                    data: (logs) {
                  final data = <DateTime, List<_DayEntry>>{};
                  for (final l in logs) {
                    final d = l.occurredAt.toLocal();
                    final key = DateTime(d.year, d.month, d.day);
                    if (key.year != _calendarMonth.year || key.month != _calendarMonth.month) continue;
                    if (_selectedAreaFilterName != null) {
                      try {
                        if (l.notes != null) {
                          final obj = jsonDecode(l.notes!);
                          final area = obj is Map<String, dynamic> ? (obj['area'] as String?) : null;
                          if (area != null && area != _selectedAreaFilterName) continue;
                        }
                      } catch (e, stackTrace) {
        LoggingService.error('Error in dashboard operation', e, stackTrace, 'Dashboard');
      }
                    }
                    final parsedData = ParsedActivityData.fromNotes(l.notes);
                    final fromNotes = parsedData.displayTitle;
                    final title = l.activityName ?? fromNotes ?? 'Activity';
                    Color? color;
                    try {
                      if (l.notes != null && l.notes!.isNotEmpty) {
                        final obj = jsonDecode(l.notes!);
                        if (obj is Map<String, dynamic>) {
                          final area = obj['area'] as String?;
                          final cat = obj['category'] as String?;

                          // Try to match with actual life areas first
                          if (area != null) {
                            for (final lifeArea in areas) {
                              if (lifeArea.name.toLowerCase() == area.toLowerCase()) {
                                try {
                                  String colorHex = lifeArea.color;
                                  if (colorHex.startsWith('#')) {
                                    colorHex = colorHex.substring(1);
                                  }
                                  if (colorHex.length == 6) {
                                    colorHex = 'FF$colorHex';
                                  }
                                  color = Color(int.parse(colorHex, radix: 16));
                                  break;
                                } catch (e) {
                                  // Fallback to category matching if color parsing fails
                                }
                              }
                            }
                          }
                          
                          // Fallback to category matching if area not found
                          if (color == null && cat != null) {
                            for (final lifeArea in areas) {
                              if (lifeArea.category.toLowerCase() == cat.toLowerCase()) {
                                try {
                                  String colorHex = lifeArea.color;
                                  if (colorHex.startsWith('#')) {
                                    colorHex = colorHex.substring(1);
                                  }
                                  if (colorHex.length == 6) {
                                    colorHex = 'FF$colorHex';
                                  }
                                  color = Color(int.parse(colorHex, radix: 16));
                                  break;
                                } catch (e) {
                                  // Continue to next area
                                }
                              }
                            }
                          }
                          
                          // Final fallback to default color
                          if (color == null) {
                            color = const Color(0xFF9CA3AF); // Neutral gray
                          }
                        }
                      }
                    } catch (e, stackTrace) {
        LoggingService.error('Error in dashboard operation', e, stackTrace, 'Dashboard');
      }
                    (data[key] ??= []).add(_DayEntry(title: title, color: color, durationMin: l.durationMin));
                  }
                  final mapped = <DateTime, List<CalendarDayEntry>>{};
                  data.forEach((k, v) {
                    mapped[k] = v.map((e) => CalendarDayEntry(title: e.title, color: e.color)).toList();
                  });
                  // Dominante Farbe je Tag basierend auf kumulierter Zeit ableiten (nutzt Nutzerfarben)
                  final Map<DateTime, Color> dominant = {};
                  data.forEach((day, dayEntries) {
                    final durationByColor = <int, int>{}; // color value -> total duration in minutes
                    for (final e in dayEntries) {
                      final c = e.color?.value;
                      if (c == null) continue;
                      final duration = e.durationMin ?? 1; // fallback to 1 minute if no duration
                      durationByColor[c] = (durationByColor[c] ?? 0) + duration;
                    }
                    if (durationByColor.isNotEmpty) {
                      int bestColor = durationByColor.entries.first.key;
                      int bestDuration = 0;
                      durationByColor.forEach((color, duration) { 
                        if (duration > bestDuration) { 
                          bestDuration = duration; 
                          bestColor = color; 
                        } 
                      });
                      dominant[day] = Color(bestColor);
                    }
                  });
                      return RepaintBoundary(
                        child: CalendarGrid(
                          month: _calendarMonth,
                          dayEntries: mapped,
                          dayDominantColors: dominant.isEmpty ? null : dominant,
                          onOpenDay: _openDayDetails,
                        ),
                      );
                    },
                  );
                },
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
            color: Colors.brown.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Icon(Icons.emoji_events, color: Colors.brown, size: 24),
        );
      case 2:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Icon(Icons.emoji_events, color: Colors.grey, size: 24),
        );
      case 3:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Color _colorForAreaKey(String area) {
    // Use improved color mapping that matches typical life area colors
    switch (area.toLowerCase()) {
      case 'spirituality':
      case 'inner':
        return const Color(0xFF6B7280); // Gray - match actual life area
      case 'finance':
        return const Color(0xFFF59E0B); // Gold/Amber
      case 'career':
      case 'work':
        return const Color(0xFF92400E); // Brown - match actual life area
      case 'learning':
      case 'development':
        return const Color(0xFF3B82F6); // Light Blue / hellblau
      case 'relationships':
      case 'social':
        return const Color(0xFFEC4899); // Pink
      case 'health':
      case 'nutrition':
        return const Color(0xFF22C55E); // Green
      case 'fitness':
      case 'vitality':
        return const Color(0xFFF97316); // Orange
      case 'creativity':
      case 'art':
        return const Color(0xFFF97316); // Orange for creativity
      default:
        return const Color(0xFF9CA3AF); // Neutral gray
    }
  }

  // Helper method to get color for an area, trying to use actual life area colors when available
  Color _getAreaColor(String area, List<_AreaTag>? areaTags) {
    if (areaTags != null) {
      // Try to find exact match by area name
      final exactMatch = areaTags.where((tag) => 
        tag.name.toLowerCase() == area.toLowerCase()).firstOrNull;
      if (exactMatch != null) {
        return exactMatch.color;
      }
      
      // Try to find match by category
      final categoryMatch = areaTags.where((tag) => 
        tag.category.toLowerCase() == area.toLowerCase()).firstOrNull;
      if (categoryMatch != null) {
        return categoryMatch.color;
      }
    }
    
    // Fallback to improved hardcoded colors
    return _colorForAreaKey(area);
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
                    // Quick add: default life areas
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Quick add (defaults):',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        {
                          'name': 'Fitness', 'category': 'Health', 'color': '#FF5722', 'icon': 'fitness_center'
                        },
                        {
                          'name': 'Nutrition', 'category': 'Health', 'color': '#4CAF50', 'icon': 'restaurant'
                        },
                        {
                          'name': 'Learning', 'category': 'Development', 'color': '#2196F3', 'icon': 'school'
                        },
                        {
                          'name': 'Finance', 'category': 'Finance', 'color': '#FFC107', 'icon': 'account_balance'
                        },
                        {
                          'name': 'Art', 'category': 'Creativity', 'color': '#9C27B0', 'icon': 'palette'
                        },
                        {
                          'name': 'Relationships', 'category': 'Social', 'color': '#E91E63', 'icon': 'people'
                        },
                        {
                          'name': 'Spirituality', 'category': 'Inner', 'color': '#607D8B', 'icon': 'self_improvement'
                        },
                        {
                          'name': 'Career', 'category': 'Work', 'color': '#795548', 'icon': 'work'
                        },
                      ].map((d) {
                        final Color chipColor = Color(int.parse((d['color'] as String).replaceAll('#', '0xFF')));
                        return InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          onTap: () {
                            setDialogState(() {
                              nameController.text = d['name'] as String;
                              categoryController.text = d['category'] as String;
                              selectedColor = d['color'] as String;
                              selectedIcon = d['icon'] as String;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: chipColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(color: chipColor.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getIconData(d['icon'] as String), color: chipColor, size: 16),
                                const SizedBox(width: 6),
                                Text(d['name'] as String, style: TextStyle(color: chipColor)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Name Field
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                         labelText: 'Name',
                         hintText: 'e.g. Fitness, Learning, etc.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing16),
                    
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
                                  color: Colors.black.withValues(alpha: 0.3),
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
                                  ? Color(int.parse(selectedColor.replaceAll('#', '0xFF'))).withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      // Refresh cached data immediately
                      setState(() {
                        _lifeAreasFuture = _loadLifeAreas();
                        _globalStatsFuture = _calculateGlobalStatistics();
                        _globalActivity7dFuture = _getGlobalLast7DaysActivity();
                        _globalDurationStacksFuture = _getGlobalLast7DaysDurationStacks();
                        _refreshCounter++;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Life area created')),
                      );
                    } catch (e) {
                      if (!mounted) return;
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
  if (kDebugMode) debugPrint('Error calculating streak: $e');
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
  if (kDebugMode) debugPrint('Error loading log data: $e');
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


            // Chat/Settings/Logout controls removed; settings and logout available via Settings tab
         ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Life Areas Section - Two-line layout
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First line: Title and Add button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Life Areas',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add_rounded, size: 24),
                        color: Colors.white,
                        onPressed: () => _showAddLifeAreaDialog(context),
                        padding: EdgeInsets.zero,
                        tooltip: 'Add new area',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Second line: View selector toolbar
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTabButton(0, Icons.apps_rounded, 'Grid'),
                      _buildTabButton(1, Icons.calendar_month_rounded, 'Calendar'),
                      _buildTabButton(2, Icons.photo_library_rounded, 'Gallery'),
                      _buildTabButton(3, Icons.list_alt_rounded, 'List'),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.spacing16),

            // Life Areas content (Bubbles, Calendar, Gallery, or Table)
            _viewMode == 1
          ? _buildCalendarContainer(context)
                : _viewMode == 2
                    ? _buildGalleryContainer(context)
                    : _viewMode == 3
                        ? _buildTableContainer(context)
                        : Container(
                    padding: const EdgeInsets.all(AppTheme.spacing20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FutureBuilder<List<LifeArea>>(
                       key: ValueKey(_refreshCounter), // still used for explicit refreshes
                       future: _lifeAreasFuture,
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
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                ),
                                SizedBox(height: AppTheme.spacing16),
                                Text(
                                  'No life areas yet',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                   onPressed: () async {
                                     try {
                                       await LifeAreasService.createDefaultLifeAreas();
                                       // Refresh cached future
                                       setState(() {
                                         _lifeAreasFuture = _loadLifeAreas();
                                         _refreshCounter++;
                                       });
                                     } catch (e) {
  if (kDebugMode) debugPrint('Error creating default areas: $e');
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
                             // Optimistic UI update: refresh cached futures immediately
                             setState(() {
                               _lifeAreasFuture = _loadLifeAreas();
                               _globalStatsFuture = _calculateGlobalStatistics();
                               _globalActivity7dFuture = _getGlobalLast7DaysActivity();
                               _globalDurationStacksFuture = _getGlobalLast7DaysDurationStacks();
                             });
                           },
                         );
                      },
                    ),
                  ),

            SizedBox(height: AppTheme.spacing24),

            // Global Statistics Section
            _buildGlobalStatisticsSection(context),
            SizedBox(height: AppTheme.spacing24),

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
            SizedBox(height: AppTheme.spacing16),

            // Quick Actions Grid
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
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
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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
                                 ).then((_) { if (mounted) setState(() { _refreshCounter++; _lifeAreasFuture = _loadLifeAreas(); }); });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _parseColor(area.color).withValues(alpha: 0.1),
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
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _parseColor(area.color).withValues(alpha: 0.1),
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
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
  if (kDebugMode) debugPrint('Error loading life areas: $e');
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
          padding: const EdgeInsets.all(AppTheme.spacing20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Consumer(
            builder: (context, ref, _) {
              final logsAsync = ref.watch(logsNotifierProvider);
              return logsAsync.when(
                loading: () => Column(
                  children: const [
                    SkeletonCard(height: 100),
                    SkeletonCard(height: 100),
                  ],
                ),
                error: (e, st) => const Padding(
                  padding: EdgeInsets.all(AppTheme.spacing20),
                  child: Center(child: Text('Error loading statistics')),
                ),
                data: (logs) {
                  final totalXp = logs.fold<int>(0, (sum, l) => sum + l.earnedXp);
                  final activityCount = logs.length;
                  final totalDurationMinutes = logs.where((l) => l.durationMin != null).fold<int>(0, (s, l) => s + (l.durationMin ?? 0));

                  return Column(
                    children: [
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
                              title: 'Time',
                              value: _formatDuration(totalDurationMinutes.toDouble()),
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spacing16),
                      _buildGlobalActivityGraph(context),
                      const SizedBox(height: 12),
                      _buildGlobalDurationGraph(context),
                    ],
                  );
                },
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
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
              color: color.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalActivityGraph(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: _globalActivity7dFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonCard(height: 220);
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
                            color: Colors.grey.withValues(alpha: 0.7),
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
                                  color: Colors.grey.withValues(alpha: 0.15),
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
                                          color: Colors.grey.withValues(alpha: 0.7),
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
      future: _globalDurationStacksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonCard(height: 220);
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
                                color: Colors.grey.withValues(alpha: 0.7),
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
                                  color: Colors.grey.withValues(alpha: 0.2),
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
                                          color: Colors.grey.withValues(alpha: 0.7),
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
      final logs = await db_service.fetchLogs();
      
      final totalXp = logs.fold<int>(0, (sum, log) => sum + log.earnedXp);
      final activityCount = logs.length;
      final totalDurationMinutes = logs
          .where((log) => log.durationMin != null)
          .fold<int>(0, (sum, log) => sum + (log.durationMin ?? 0));
      
      return {
        'totalXp': totalXp,
        'activityCount': activityCount,
        'totalDuration': totalDurationMinutes.toDouble(),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('Fehler beim Berechnen der globalen Statistiken: $e');
      return {};
    }
  }

  Future<List<int>> _getGlobalLast7DaysActivity() async {
    try {
      final logs = await db_service.fetchLogs();
      final now = DateTime.now();
      final last7Days = List.generate(7, (index) {
        return DateTime(now.year, now.month, now.day - index);
      }).reversed.toList();
      
      return last7Days.map<int>((date) {
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
  if (kDebugMode) debugPrint('Error loading 7-day activities: $e');
      return List.filled(7, 0);
    }
  }

  Future<List<int>> _getGlobalLast7DaysDurationMinutes() async {
    try {
      final logs = await db_service.fetchLogs();
      final now = DateTime.now();
      final last7Days = List.generate(7, (index) {
        return DateTime(now.year, now.month, now.day - index);
      }).reversed.toList();

      return last7Days.map<int>((date) {
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
      if (kDebugMode) debugPrint('Fehler beim Laden der 7-Tage-Dauer: $e');
      return List.filled(7, 0);
    }
  }
  
  Future<Map<String, dynamic>> _getGlobalLast7DaysDurationStacks() async {
    try {
      final logs = await db_service.fetchLogs();
      final now = DateTime.now();
      final last7Days = List.generate(7, (index) => DateTime(now.year, now.month, now.day - index)).reversed.toList();

      // Collect area colors
      final lifeAreasRes = await Supabase.instance.client
          .from('life_areas')
          .select('name,category,color')
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id);
      final List<_AreaTag> areaTags = (lifeAreasRes as List)
          .map((m) => _AreaTag(
                name: (m['name'] as String).trim(),
                category: (m['category'] as String).trim(),
                color: _parseHexColor((m['color'] as String?) ?? '#2196F3'),
              ))
          .toList();

      Color resolveColorForLog(models.ActionLog log) {
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
        } catch (e, stackTrace) {
        LoggingService.error('Error in dashboard operation', e, stackTrace, 'Dashboard');
      }
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
          colorToMinutes[color.value] = (colorToMinutes[color.value] ?? 0) + mins.toInt();
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
      if (kDebugMode) debugPrint('Fehler beim Laden der 7-Tage-Stacks: $e');
      return {
        'stacks': List.generate(7, (_) => <_StackSlice>[]),
        'totals': List.filled(7, 0),
      };
    }
  }

  String _formatDuration(double minutes) {
    if (minutes <= 0) return '0 m';
    
    final totalMinutes = minutes.round();
    
    // Weeks (7 days = 10080 minutes)
    if (totalMinutes >= 10080) {
      final weeks = (totalMinutes / 10080).floor();
      final remainingMinutes = totalMinutes - (weeks * 10080);
      final days = (remainingMinutes / 1440).floor();
      
      if (weeks == 1) {
        if (days > 0) {
          return days == 1 ? '1 w, 1 d' : '1 w, $days d';
        } else {
          return '1 w';
        }
      } else {
        if (days > 0) {
          return days == 1 ? '$weeks w, 1 d' : '$weeks w, $days d';
        } else {
          return '$weeks w';
        }
      }
    }
    
    // Days (24 hours = 1440 minutes)
    if (totalMinutes >= 1440) {
      final days = (totalMinutes / 1440).floor();
      final remainingMinutes = totalMinutes - (days * 1440);
      final hours = (remainingMinutes / 60).floor();
      
      final d = days == 1 ? '1 d' : '$days d';
      if (hours > 0) {
        final h = '$hours h';
        return '$d, $h';
      }
      return d;
    }
    
    // Hours (60 minutes)
    if (totalMinutes >= 60) {
      final hours = (totalMinutes / 60).floor();
      final remainingMinutes = totalMinutes - (hours * 60);
      
      final h = '$hours h';
      if (remainingMinutes > 0) {
        return '$h, ${remainingMinutes} m';
      }
      return h;
    }
    
  return '$totalMinutes m';
  }

  Color _parseColor(String hex) {
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  }

  Widget _buildImageGrid(List<Map<String, dynamic>> images) {
    final crossAxisCount = 3;
    final spacing = 8.0;
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 1,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final data = images[index];
        final imageUrl = data['image_url'] as String;
        return InkWell(
          onTap: () => _showImageFullscreen(context, data, images, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: CachedNetworkImage(
              imageUrl: _thumbUrl(imageUrl, width: 600, quality: 80),
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (context, url, error) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton(int mode, IconData icon, String label) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected 
                  ? Colors.white 
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

typedef StreakBuilder = Widget Function(BuildContext context, int streak);

class _StreakConsumer extends StatelessWidget {
  final StreakBuilder builder;
  final VoidCallback? onRetry;
  const _StreakConsumer({required this.builder, this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Proper Riverpod Consumer that rebuilds when provider resolves/changes
    return Consumer(
      builder: (ctx, ref, _) {
        final asyncStreak = ref.watch(streakNotifierProvider);
        return asyncStreak.when(
          loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, st) => Row(
            children: [
              Expanded(child: Text('Error: $e')),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Retry',
                onPressed: onRetry,
              ),
            ],
          ),
          data: (streak) => builder(ctx, streak),
        );
      },
    );
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
      if (!hasEntries) return colorScheme.outline.withValues(alpha: 0.6);
      
      // Primary approach: Use colors directly if areaKey matching fails
      final Map<int, int> colorToCount = {};
      final Map<int, int> colorToMinutes = {};
      
      for (final e in entries) {
        if (e.color != null) {
          final colorValue = e.color!.value;
          colorToCount[colorValue] = (colorToCount[colorValue] ?? 0) + 1;
          colorToMinutes[colorValue] = (colorToMinutes[colorValue] ?? 0) + (e.durationMin ?? 0);
        }
      }
      
      if (colorToCount.isNotEmpty) {
        // Find color with most activities
        int maxCount = 0;
        for (final count in colorToCount.values) {
          if (count > maxCount) maxCount = count;
        }
        
        // Get all colors with max count
        final List<int> candidates = [];
        colorToCount.forEach((colorValue, count) {
          if (count == maxCount) candidates.add(colorValue);
        });
        
        if (candidates.length == 1) {
          return Color(candidates.first);
        }
        
        // Tie-breaker: use color with most minutes
        int? chosenColor;
        int chosenMinutes = -1;
        for (final colorValue in candidates) {
          final minutes = colorToMinutes[colorValue] ?? 0;
          if (minutes > chosenMinutes) {
            chosenColor = colorValue;
            chosenMinutes = minutes;
          }
        }
        
        if (day == 16 && kDebugMode) {
          debugPrint('=== Day $day Color-Based Debug ===');
          debugPrint('Color counts: ${colorToCount.map((k, v) => MapEntry('#${k.toRadixString(16).padLeft(8, '0').substring(2)}', v))}');
          debugPrint('Color minutes: ${colorToMinutes.map((k, v) => MapEntry('#${k.toRadixString(16).padLeft(8, '0').substring(2)}', v))}');
          debugPrint('Chosen color: #${chosenColor?.toRadixString(16).padLeft(8, '0').substring(2)}');
        }
        
        return Color(chosenColor!);
      }
      
      // Fallback to area-based logic
      final Map<String, int> areaToCount = {};
      final Map<String, int> areaToMinutes = {};
      final Map<String, Color> areaToColor = {};
      for (final e in entries) {
        if (e.areaKey == null) continue;
        final key = e.areaKey!;
        areaToCount[key] = (areaToCount[key] ?? 0) + 1;
        areaToMinutes[key] = (areaToMinutes[key] ?? 0) + (e.durationMin ?? 0);
        if (e.color != null) areaToColor[key] = e.color!;
      }
      
      // Debug output for day 16
      if (day == 16 && kDebugMode) {
        debugPrint('=== Day $day Debug ===');
        debugPrint('Total entries: ${entries.length}');
        for (final e in entries) {
          debugPrint('  Entry: ${e.title}, areaKey: ${e.areaKey}, duration: ${e.durationMin}');
        }
        debugPrint('Area counts: $areaToCount');
        debugPrint('Area minutes: $areaToMinutes');
        debugPrint('Area colors: ${areaToColor.map((k, v) => MapEntry(k, '#${v.value.toRadixString(16).padLeft(8, '0').substring(2)}'))}');
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
      // Tie-Breaker: wähle die Farbe mit den meisten Minuten
      String? chosen;
      int? chosenMinutes;
      for (final key in candidates) {
        final minutes = areaToMinutes[key] ?? 0;
        if (chosen == null || minutes > (chosenMinutes ?? -1)) {
          chosen = key;
          chosenMinutes = minutes;
        }
      }
      final chosenColor = areaToColor[chosen!] ?? colorScheme.primary;
      
      // Debug output for day 16
      if (day == 16 && kDebugMode) {
        debugPrint('Chosen area: $chosen');
        debugPrint('Chosen color: #${chosenColor.value.toRadixString(16).padLeft(8, '0').substring(2)}');
        debugPrint('=== End Day $day Debug ===');
      }
      
      return chosenColor;
    }
    final Color accentColor = dominantColor();
    // Maximal 2 Zeilen anzeigen: erste Aktivität + ggf. "+N"
    final List<_DayEntry> shown = () {
      if (entries.isEmpty) return const <_DayEntry>[];
      if (entries.length == 1) return <_DayEntry>[entries.first];
      return <_DayEntry>[entries.first, _DayEntry(title: '+${entries.length - 1}', durationMin: 0)];
    }();

    // Base content
    final content = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: hasEntries ? accentColor.withValues(alpha: 0.06) : null,
        border: Border.all(
          color: hasEntries
              ? accentColor.withValues(alpha: 0.35)
              : colorScheme.outline.withValues(alpha: 0.18),
        ),
        boxShadow: hasEntries
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
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
                      ? accentColor.withValues(alpha: 0.9)
                      : colorScheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          ...shown.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (e.color ?? colorScheme.primary).withValues(alpha: e.title.startsWith('+') ? 0.0 : 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    e.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          height: 1.1,
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
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
  final int? durationMin; // duration in minutes for tie-breaking
  const _DayEntry({required this.title, this.color, this.areaKey, this.durationMin});
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
  
  // Priorität 1: Exakter Area-Name-Match
  if (an != null && an.isNotEmpty) {
    for (final t in tags) {
      if (t.name.toLowerCase() == an) return t;
    }
  }
  
  // Priorität 2: Kategorie-Match nur als Fallback, wenn kein Area-Name
  if ((an == null || an.isEmpty) && cat != null && cat.isNotEmpty) {
    for (final t in tags) {
      if (t.category.toLowerCase() == cat) return t;
    }
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
      ..color = color.withValues(alpha: 0.85)
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
        final paint = Paint()..color = slice.color.withValues(alpha: 0.9);
        canvas.drawRRect(rect, paint);
        accumulated += sliceHeight;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}