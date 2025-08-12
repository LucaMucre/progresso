import 'package:flutter/material.dart';
import 'services/life_areas_service.dart';
import 'services/db_service.dart';
import 'log_action_page.dart';
import 'widgets/activity_details_dialog.dart';
import 'dart:math';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class LifeAreaDetailPage extends StatefulWidget {
  final LifeArea area;
  final LifeArea? parentArea;

  const LifeAreaDetailPage({
    Key? key,
    required this.area,
    this.parentArea,
  }) : super(key: key);

  @override
  State<LifeAreaDetailPage> createState() => _LifeAreaDetailPageState();
}

class _LifeAreaDetailPageState extends State<LifeAreaDetailPage> {
  bool _isLoading = true;
  List<ActionTemplate> _templates = [];
  List<ActionLog> _logs = [];
  // Direkt zugeordnete Logs (für Bubble-View im Parent-Bereich)
  List<ActionLog> _logsForBubbles = [];
  LifeArea? _parentArea;
  int _totalXp = 0;
  int _activityCount = 0;
  double _averageDuration = 0;
  final Random _random = Random();
  bool _isBubbleView = true; // Toggle between bubble and table view
  List<LifeArea> _subAreas = [];

  @override
  void initState() {
    super.initState();
    // Parent, falls vorgeladen, sofort setzen (verhindert Header-Flackern)
    if (widget.parentArea != null) {
      _parentArea = widget.parentArea;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final templates = await fetchTemplates();
      final logs = await fetchLogs();
      final subs = await LifeAreasService.getChildAreas(widget.area.id);
      final parent = widget.area.parentId != null
          ? await LifeAreasService.getAreaById(widget.area.parentId!)
          : null;
      
      // Filter templates for this area
      final filteredTemplates = templates.where((template) {
        return template.category.toLowerCase() == widget.area.category.toLowerCase() ||
               template.name.toLowerCase().contains(widget.area.name.toLowerCase());
      }).toList();
      
      // Filter logs for this specific area
      // Für Statistiken/Tabelle: Parent soll Sub-Logs einschließen
      final filteredLogs = logs
          .where((l) => _isLogForArea(l,
              templatesOverride: templates,
              subAreasOverride: subs,
              includeSubareasForParent: true))
          .toList();

      // Für Bubble-View im Parent: nur direkt zugeordnete Logs (keine Sub-Logs)
      final bubbleLogs = logs
          .where((l) => _isLogForArea(l,
              templatesOverride: templates,
              subAreasOverride: subs,
              includeSubareasForParent: false))
          .toList();
      
      // Calculate statistics
      final totalXp = filteredLogs.fold<int>(0, (sum, log) => sum + log.earnedXp);
      final activityCount = filteredLogs.length;
      final totalDuration = filteredLogs
          .where((log) => log.durationMin != null)
          .fold<int>(0, (sum, log) => sum + (log.durationMin ?? 0));
      final averageDuration = activityCount > 0 ? totalDuration / activityCount : 0.0;
      
      setState(() {
        _templates = filteredTemplates;
        _logs = filteredLogs;
        _logsForBubbles = bubbleLogs;
        _subAreas = subs;
        _parentArea = parent;
        _totalXp = totalXp;
        _activityCount = activityCount;
        _averageDuration = averageDuration;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Fehler beim Laden der Daten: $e');
    }
  }

  bool _isLogForArea(
    ActionLog log, {
    List<ActionTemplate>? templatesOverride,
    List<LifeArea>? subAreasOverride,
    bool includeSubareasForParent = true,
  }) {
    final areaName = widget.area.name.toLowerCase();
    final category = widget.area.category.toLowerCase();
    final isSub = widget.area.parentId != null;
    final templatesRef = templatesOverride ?? _templates;
    final subNames = (subAreasOverride ?? _subAreas).map((a) => a.name.toLowerCase()).toList();

    if (log.notes != null && log.notes!.isNotEmpty) {
      final raw = log.notes!;
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) {
          final nArea = (parsed['area'] as String?)?.toLowerCase();
          final nSub = (parsed['subarea'] as String?)?.toLowerCase();
          final nCat  = (parsed['category'] as String?)?.toLowerCase();
          if (isSub) {
            return nArea == areaName || nSub == areaName;
          } else {
            // Parent: nur direkt zugeordnete Logs, wenn includeSubareasForParent=false
            if (!includeSubareasForParent) {
              // Wenn eine Subarea explizit gesetzt ist, ausschließen
              if (nSub != null && nSub.trim().isNotEmpty) return false;
              // Falls area einem Subnamen entspricht, ebenfalls ausschließen
              if (nArea != null && subNames.contains(nArea)) return false;
            }
            // parent: match own area/category
            if (nArea == areaName || nCat == category) return true;
            // optional: Subareas mitzählen
            if (includeSubareasForParent) {
              if (nArea != null && subNames.contains(nArea)) return true;
              if (nSub != null && subNames.contains(nSub)) return true;
            }
            return false;
          }
        } else if (parsed is List) {
          try {
            final doc = quill.Document.fromJson(parsed);
            final plain = doc.toPlainText().toLowerCase();
            if (isSub) {
              return plain.contains(areaName);
            } else {
              // Bei Bubble-View des Parents: Sub-Namen ausschließen
              if (!includeSubareasForParent) {
                for (final s in subNames) {
                  if (plain.contains(s)) return false;
                }
              }
              if (plain.contains(areaName) || plain.contains(category)) return true;
              if (includeSubareasForParent) {
                for (final s in subNames) {
                  if (plain.contains(s)) return true;
                }
              }
              return false;
            }
          } catch (_) {
            return false;
          }
        }
      } catch (_) {
        final text = raw.toLowerCase();
        if (isSub) return text.contains(areaName);
        // Bei Bubble-View des Parents: Sub-Namen ausschließen
        if (!includeSubareasForParent) {
          for (final s in subNames) {
            if (text.contains(s)) return false;
          }
        }
        if (text.contains(areaName) || text.contains(category)) return true;
        if (includeSubareasForParent) {
          for (final s in subNames) {
            if (text.contains(s)) return true;
          }
        }
        return false;
      }
    }

    if (log.templateId != null) {
      final template = templatesRef.firstWhere(
        (t) => t.id == log.templateId,
        orElse: () => ActionTemplate(
          id: '', name: '', category: '', baseXp: 0, attrStrength: 0, attrEndurance: 0, attrKnowledge: 0
        ),
      );
      if (isSub) {
        return template.name.toLowerCase().contains(areaName);
      }
      // Bei Bubble-View des Parents: Sub-Namen im Template explizit ausschließen
      if (!includeSubareasForParent) {
        for (final s in subNames) {
          if (template.name.toLowerCase().contains(s)) return false;
        }
      }
      if (template.category.toLowerCase() == category ||
          template.name.toLowerCase().contains(areaName)) return true;
      if (includeSubareasForParent) {
        for (final s in subNames) {
          if (template.name.toLowerCase().contains(s)) return true;
        }
      }
      return false;
    }
    return false;
  }

  void _logQuickAction() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LogActionPage(
          selectedCategory: widget.area.category,
          selectedArea: widget.area.name,
          areaColorHex: widget.area.color,
          areaIcon: widget.area.icon,
        ),
      ),
    ).then((_) => _loadData()); // Reload data after returning
  }

  void _logTemplateAction(ActionTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LogActionPage(
          template: template,
          selectedCategory: widget.area.category,
          selectedArea: widget.area.name,
          areaColorHex: widget.area.color,
          areaIcon: widget.area.icon,
        ),
      ),
    ).then((_) => _loadData()); // Reload data after returning
  }

  void _showActivityDetails(ActionLog log) {
    print('DEBUG: Showing activity details for log: ${log.id}');
    print('DEBUG: Image URL: ${log.imageUrl}');
    
    showDialog(
      context: context,
      builder: (context) => ActivityDetailsDialog(
        log: log,
        onUpdate: _loadData, // Reload data when log is updated
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(double minutes) {
    if (minutes <= 0) return '0 Min';
    
    final totalMinutes = minutes.round();
    
    // Wochen (7 Tage = 10080 Minuten)
    if (totalMinutes >= 10080) {
      final weeks = (totalMinutes / 10080).floor();
      final remainingMinutes = totalMinutes - (weeks * 10080);
      final days = (remainingMinutes / 1440).floor();
      
      if (weeks == 1) {
        if (days > 0) {
          return days == 1 ? '1 Woche, 1 Tag' : '1 Woche, $days Tage';
        } else {
          return '1 Woche';
        }
      } else {
        if (days > 0) {
          return days == 1 ? '$weeks Wochen, 1 Tag' : '$weeks Wochen, $days Tage';
        } else {
          return '$weeks Wochen';
        }
      }
    }
    
    // Tage (24 Stunden = 1440 Minuten)
    if (totalMinutes >= 1440) {
      final days = (totalMinutes / 1440).floor();
      final remainingMinutes = totalMinutes - (days * 1440);
      final hours = (remainingMinutes / 60).floor();
      
      if (days == 1) {
        if (hours > 0) {
          return hours == 1 ? '1 Tag, 1 Std' : '1 Tag, $hours Std';
        } else {
          return '1 Tag';
        }
      } else {
        if (hours > 0) {
          return hours == 1 ? '$days Tage, 1 Std' : '$days Tage, $hours Std';
        } else {
          return '$days Tage';
        }
      }
    }
    
    // Stunden (60 Minuten)
    if (totalMinutes >= 60) {
      final hours = (totalMinutes / 60).floor();
      final remainingMinutes = totalMinutes - (hours * 60);
      
      if (hours == 1) {
        if (remainingMinutes > 0) {
          return remainingMinutes == 1 ? '1 Std, 1 Min' : '1 Std, $remainingMinutes Min';
        } else {
          return '1 Std';
        }
      } else {
        if (remainingMinutes > 0) {
          return remainingMinutes == 1 ? '$hours Std, 1 Min' : '$hours Std, $remainingMinutes Min';
        } else {
          return '$hours Std';
        }
      }
    }
    
    // Minuten
    return '$totalMinutes Min';
  }

  String _getActivityName(ActionLog log) {
    // 1) Prefer explicit user-defined name if available
    final explicit = log.activityName;
    if (explicit != null && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }

    // 2) Try to read title from notes wrapper (added for compatibility)
    final fromWrapper = extractTitleFromNotes(log.notes);
    if (fromWrapper != null && fromWrapper.trim().isNotEmpty) {
      return fromWrapper.trim();
    }

    // 3) Fallback: parse from notes content (new or legacy)
    if (log.notes != null && log.notes!.isNotEmpty) {
      final raw = log.notes!;
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) {
          final delta = parsed['delta'];
          if (delta is List) {
            try {
              final doc = quill.Document.fromJson(delta);
              final firstLine = doc.toPlainText().split('\n').firstWhere(
                (l) => l.trim().isNotEmpty,
                orElse: () => '',
              );
              if (firstLine.trim().isNotEmpty) return firstLine.trim();
            } catch (_) {}
          }
          return 'Aktivität';
        } else if (parsed is List) {
          try {
            final doc = quill.Document.fromJson(parsed);
            final firstLine = doc.toPlainText().split('\n').firstWhere(
              (l) => l.trim().isNotEmpty,
              orElse: () => '',
            );
            if (firstLine.trim().isNotEmpty) return firstLine.trim();
          } catch (_) {}
          return 'Aktivität';
        }
      } catch (_) {}

      final parenthesisIndex = raw.indexOf('(');
      if (parenthesisIndex > 0) {
        return raw.substring(0, parenthesisIndex).trim();
      }
      return raw;
    }

    return 'Aktivität';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.area.name),
        backgroundColor: _parseColor(widget.area.color).withOpacity(0.1),
        foregroundColor: _parseColor(widget.area.color),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with area info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _parseColor(widget.area.color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _parseColor(widget.area.color).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Zeile 1: Elternbereich (falls Unterkategorie)
                    if (widget.area.parentId != null && _parentArea != null) ...[
                      Builder(builder: (context) {
                        final areaColor = _parseColor(widget.area.color);
                        final parentColor = _parseColor(_parentArea!.color);
                        final nameFontSize = Theme.of(context).textTheme.titleLarge?.fontSize ?? 22;
                        final arrowHeight = nameFontSize * 0.9;
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Hoher Icon-Block, der beide Zeilen vertikal umfasst
                              Container(
                                width: 48,
                                decoration: BoxDecoration(
                                  color: parentColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  _getIconData(_parentArea!.icon),
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Zeile: Parent
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _parentArea!.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: parentColor,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: parentColor.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: parentColor.withOpacity(0.25)),
                                          ),
                                          child: Text(
                                            _parentArea!.category,
                                            style: TextStyle(
                                              color: parentColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Zeile: L-Pfeil + eingerückte Unterkategorie
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 56,
                                          height: arrowHeight,
                                          child: CustomPaint(
                                            painter: LArrowPainter(color: areaColor),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            widget.area.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: areaColor,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ]
                    // Sonst: Normaler Header ohne Pfeil
                    else ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _parseColor(widget.area.color),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getIconData(widget.area.icon),
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.area.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: _parseColor(widget.area.color),
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _parseColor(widget.area.color).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _parseColor(widget.area.color).withOpacity(0.25)),
                                  ),
                                  child: Text(
                                    widget.area.category,
                                    style: TextStyle(
                                      color: _parseColor(widget.area.color),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Activity Canvas Section with View Toggle
              if (!_isLoading) _buildActivityCanvasWithToggle(),
              const SizedBox(height: 24),
              if (widget.area.parentId == null) _buildSubAreasSection(),
              const SizedBox(height: 24),

              // Progress Visualization Section
              if (!_isLoading) _buildProgressSection(),
              const SizedBox(height: 24),

              // Quick Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logQuickAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _parseColor(widget.area.color),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Schnell-Aktion für ${widget.area.name} loggen',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Templates Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vorlagen für ${widget.area.name}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_templates.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 48,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Keine Vorlagen für ${widget.area.name}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Erstelle eine neue Vorlage oder nutze die Schnell-Aktion',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _parseColor(widget.area.color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getCategoryIcon(template.category),
                            color: _parseColor(widget.area.color),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          template.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${template.baseXp} XP • ${template.category}',
                          style: TextStyle(
                            color: Colors.grey.withOpacity(0.7),
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: _parseColor(widget.area.color),
                          size: 16,
                        ),
                        onTap: () => _logTemplateAction(template),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCanvasWithToggle() {
    if (_logs.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 48,
                color: Colors.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Noch keine Aktivitäten',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Starte deine erste Aktivität!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // View Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleButton(
                icon: Icons.bubble_chart,
                label: 'Bubbles',
                isSelected: _isBubbleView,
                onTap: () => setState(() => _isBubbleView = true),
              ),
              const SizedBox(width: 8),
              _buildToggleButton(
                icon: Icons.table_chart,
                label: 'Tabelle',
                isSelected: !_isBubbleView,
                onTap: () => setState(() => _isBubbleView = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Canvas Content
        _isBubbleView ? _buildCombinedBubbleCanvas() : _buildTableCanvas(),
      ],
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _parseColor(widget.area.color) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleCanvas() {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: _generateBubblePositions(),
      ),
    );
  }

  Widget _buildSubAreaBubbleCanvas() {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          const height = 300.0;
          final rand = Random();
          final placed = <Rect>[];

          List<Widget> bubbles = [];
          for (final area in _subAreas) {
            final size = 80.0 + rand.nextDouble() * 40.0;
            Rect? rect;
            int tries = 0;
            while (rect == null && tries < 50) {
              final x = rand.nextDouble() * (width - size);
              final y = rand.nextDouble() * (height - size);
              final r = Rect.fromLTWH(x, y, size, size);
              if (!placed.any((p) => p.overlaps(r))) {
                rect = r;
                placed.add(r);
              }
              tries++;
            }
            rect ??= Rect.fromLTWH(rand.nextDouble() * (width - size), rand.nextDouble() * (height - size), size, size);

            final c = _parseColor(area.color);
            bubbles.add(Positioned(
              left: rect.left,
              top: rect.top,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LifeAreaDetailPage(area: area)),
                  );
                },
                child: Container(
                  width: rect.width,
                  height: rect.height,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c,
                    boxShadow: [
                      BoxShadow(color: c.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        area.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ));
          }

          return Stack(children: bubbles);
        },
      ),
    );
  }

  Widget _buildCombinedBubbleCanvas() {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          const height = 300.0;
          final rand = Random();
          final placed = <Rect>[];

          List<Widget> bubbles = [];

          void addBubble(Rect rect, Color c, Widget child, VoidCallback onTap) {
            bubbles.add(Positioned(
              left: rect.left,
              top: rect.top,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  width: rect.width,
                  height: rect.height,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c, boxShadow: [
                    BoxShadow(color: c.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                  ]),
                  child: Center(child: child),
                ),
              ),
            ));
          }

          Rect place(double size) {
            Rect? rect;
            int tries = 0;
            while (rect == null && tries < 60) {
              final x = rand.nextDouble() * (width - size);
              final y = rand.nextDouble() * (height - size);
              final r = Rect.fromLTWH(x, y, size, size);
              if (!placed.any((p) => p.overlaps(r))) {
                rect = r;
                placed.add(r);
              }
              tries++;
            }
            rect ??= Rect.fromLTWH(rand.nextDouble() * (width - size), rand.nextDouble() * (height - size), size, size);
            return rect!;
          }

          // 1) Activities (im Parent nur direkt zugeordnete)
          final sourceLogs = widget.area.parentId == null ? _logsForBubbles : _logs;
          for (final log in sourceLogs) {
            final size = 70.0 + rand.nextDouble() * 40.0;
            final rect = place(size);
            final base = _parseColor(widget.area.color);
            final hsl = HSLColor.fromColor(base);
            final c = hsl.withLightness((hsl.lightness + 0.15).clamp(0.3, 0.8)).toColor();
            addBubble(
              rect,
              c,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  _getActivityName(log),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              () => _showActivityDetails(log),
            );
          }

          // 2) Subareas (slightly larger hue)
          for (final area in _subAreas) {
            final size = 90.0 + rand.nextDouble() * 50.0;
            final rect = place(size);
            final c = _parseColor(area.color);
            addBubble(
              rect,
              c,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  area.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LifeAreaDetailPage(area: area, parentArea: widget.area)),
                );
              },
            );
          }

          return Stack(children: bubbles);
        },
      ),
    );
  }

  Widget _buildSubAreasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Unterkategorien',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            OutlinedButton.icon(
              onPressed: _createSubAreaDialog,
              icon: const Icon(Icons.add),
              label: const Text('Unterkategorie'),
            )
          ],
        ),
        const SizedBox(height: 12),
        if (_subAreas.isEmpty)
          Text(
            'Noch keine Unterkategorien. Lege die erste an.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _subAreas.map((a) {
              final c = _parseColor(a.color);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => LifeAreaDetailPage(area: a)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_getIconData(a.icon), color: c, size: 16),
                      const SizedBox(width: 8),
                      Text(a.name, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          )
      ],
    );
  }

  Future<void> _createSubAreaDialog() async {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: widget.area.category);
    String color = widget.area.color;
    String icon = widget.area.icon;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unterkategorie erstellen'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')), 
              const SizedBox(height: 8),
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Kategorie')), 
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Erstellen')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await LifeAreasService.createLifeArea(
        name: nameCtrl.text.trim(),
        category: catCtrl.text.trim().isEmpty ? widget.area.category : catCtrl.text.trim(),
        parentId: widget.area.id,
        color: color,
        icon: icon,
        orderIndex: _subAreas.length,
      );
      await _loadData();
    }
  }

  Widget _buildTableCanvas() {
    // Sort logs by date (newest first)
    final sortedLogs = List<ActionLog>.from(_logs)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              color: _parseColor(widget.area.color).withOpacity(0.1),
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
                    'Aktivität',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _parseColor(widget.area.color),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Datum',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _parseColor(widget.area.color),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'XP',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _parseColor(widget.area.color),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: sortedLogs.length,
              itemBuilder: (context, index) {
                final log = sortedLogs[index];
                final isEven = index % 2 == 0;
                
                return GestureDetector(
                  onTap: () => _showActivityDetails(log),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isEven ? Colors.grey.withOpacity(0.05) : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getActivityName(log),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (log.durationMin != null)
                                Text(
                                  '${log.durationMin} Min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.withOpacity(0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _formatDate(log.occurredAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.withOpacity(0.7),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _parseColor(widget.area.color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${log.earnedXp}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _parseColor(widget.area.color),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
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



  List<Widget> _generateBubblePositions() {
    final List<Widget> bubbles = [];
    final List<Rect> occupiedAreas = [];
    
    // Get the actual canvas width from the parent container
    final canvasWidth = MediaQuery.of(context).size.width - 40; // Account for padding
    final canvasHeight = 300.0; // Fixed height for the canvas
    
    for (int i = 0; i < _logs.length; i++) {
      final log = _logs[i];
      
      // Generate random size (75-120px for better readability)
      final size = 75.0 + _random.nextDouble() * 45.0;
      
      // Try to find a position that doesn't overlap
      Rect? position;
      int attempts = 0;
      const maxAttempts = 50;
      
      while (position == null && attempts < maxAttempts) {
        // Generate random position within canvas bounds
        final maxX = canvasWidth - size;
        final maxY = canvasHeight - size;
        final x = _random.nextDouble() * maxX;
        final y = _random.nextDouble() * maxY;
        
        final candidateRect = Rect.fromLTWH(x, y, size, size);
        
        // Check if this position overlaps with any existing bubble
        bool overlaps = false;
        for (final occupied in occupiedAreas) {
          if (candidateRect.overlaps(occupied)) {
            overlaps = true;
            break;
          }
        }
        
        if (!overlaps) {
          position = candidateRect;
          occupiedAreas.add(candidateRect);
        }
        
        attempts++;
      }
      
      // If we couldn't find a non-overlapping position, use the last attempt
      if (position == null) {
        final maxX = canvasWidth - size;
        final maxY = canvasHeight - size;
        final x = _random.nextDouble() * maxX;
        final y = _random.nextDouble() * maxY;
        position = Rect.fromLTWH(x, y, size, size);
      }
      
      // Generate random color variation
      final baseColor = _parseColor(widget.area.color);
      final hsl = HSLColor.fromColor(baseColor);
      final hue = (hsl.hue + (_random.nextDouble() - 0.5) * 30).clamp(0.0, 360.0);
      final saturation = (hsl.saturation + _random.nextDouble() * 0.2).clamp(0.3, 1.0);
      final lightness = (hsl.lightness + _random.nextDouble() * 0.2).clamp(0.4, 0.8);
      final color = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
      
      bubbles.add(
        Positioned(
          left: position!.left,
          top: position.top,
          child: GestureDetector(
            onTap: () => _showActivityDetails(log),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: position.width,
                height: position.height,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background image if available
                    if (log.imageUrl != null)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(position.width / 2),
                          child: Image.network(
                            log.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(); // Fallback to icon
                            },
                          ),
                        ),
                      ),
                    
                    // Icon and text overlay
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star,
                            color: log.imageUrl != null ? Colors.white : Colors.white,
                            size: position.width * 0.25,
                          ),
                          const SizedBox(height: 4),
                          Flexible(
                            child: Text(
                              _getActivityName(log),
                              style: TextStyle(
                                color: log.imageUrl != null ? Colors.white : Colors.white,
                                fontSize: position.width * 0.15,
                                fontWeight: FontWeight.bold,
                                shadows: log.imageUrl != null ? [
                                  const Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 2,
                                    color: Colors.black54,
                                  ),
                                ] : null,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Image indicator
                    if (log.imageUrl != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.image,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return bubbles;
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fortschritt',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // All Statistics in one row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.star,
                  title: 'Gesammelte XP',
                  value: '$_totalXp',
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  icon: _getIconData(widget.area.icon),
                  title: 'Aktivitäten',
                  value: '$_activityCount',
                  color: _parseColor(widget.area.color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.timer,
                  title: 'Ø Dauer',
                  value: _formatDuration(_averageDuration),
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Activity Graph (Simple Bar Chart)
          if (_logs.isNotEmpty) _buildActivityGraph(),

          const SizedBox(height: 16),
          if (_logs.isNotEmpty) _buildDurationBarChart(),
        ],
      ),
    );
  }

  Widget _buildStatCard({
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

  Widget _buildActivityGraph() {
    // Get last 7 days of activity
    final now = DateTime.now();
    final last7Days = List.generate(7, (index) {
      return DateTime(now.year, now.month, now.day - index);
    }).reversed.toList();
    
    // Count activities per day for THIS specific life area only (timezone safe)
    final activityCounts = last7Days.map((date) {
      final targetDate = DateTime(date.year, date.month, date.day);
      return _logs.where((log) {
        final local = log.occurredAt.toLocal();
        final logDate = DateTime(local.year, local.month, local.day);
        final isSameDate = logDate.year == targetDate.year &&
            logDate.month == targetDate.month &&
            logDate.day == targetDate.day;

        // Use same area matching as in list
        return isSameDate && _isLogForArea(log);
      }).length;
    }).toList();

    // Duration minutes per day for THIS area
    final durationPerDay = last7Days.map((date) {
      final targetDate = DateTime(date.year, date.month, date.day);
      return _logs.where((log) {
        final local = log.occurredAt.toLocal();
        final logDate = DateTime(local.year, local.month, local.day);
        final isSameDate = logDate.year == targetDate.year &&
            logDate.month == targetDate.month &&
            logDate.day == targetDate.day;
        return isSameDate && _isLogForArea(log);
      }).fold<int>(0, (sum, log) => sum + (log.durationMin ?? 0));
    }).toList();

    // Dynamic Y max (nice rounding)
    final int maxCount = activityCounts.isEmpty ? 1 : activityCounts.reduce(max);
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aktivitäten der letzten 7 Tage',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            children: [
              // Y-axis labels
              SizedBox(
                width: 30,
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
                    const chartHeight = 120.0;
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
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          );
                        }),

                        // Line chart (paint first, then overlay points computed with same mapping)
                        CustomPaint(
                          size: Size(chartWidth, chartHeight),
                          painter: LineChartPainter(
                            data: activityCounts,
                            maxValue: yMax.toDouble(),
                            color: _parseColor(widget.area.color),
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
                              message: '${date.day}/${date.month}: $count Aktivitäten',
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
                                      color: _parseColor(widget.area.color),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),

                        // Date labels aligned exactly under the data points
                        ...last7Days.asMap().entries.map((entry) {
                          final index = entry.key;
                          final date = entry.value;
                          final center = xFor(index);
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
  }

  Widget _buildDurationBarChart() {
    final now = DateTime.now();
    final last7Days = List.generate(7, (index) => DateTime(now.year, now.month, now.day - index)).reversed.toList();
    final durationPerDay = last7Days.map((date) {
      final targetDate = DateTime(date.year, date.month, date.day);
      return _logs.where((log) {
        final local = log.occurredAt.toLocal();
        final logDate = DateTime(local.year, local.month, local.day);
        final isSameDate = logDate.year == targetDate.year && logDate.month == targetDate.month && logDate.day == targetDate.day;
        return isSameDate && _isLogForArea(log);
      }).fold<int>(0, (sum, log) => sum + (log.durationMin ?? 0));
    }).toList();

    final maxMinutes = durationPerDay.isEmpty ? 0 : durationPerDay.reduce(max);
    final maxHours = maxMinutes / 60.0;
    double yMaxHours;
    if (maxHours <= 1) yMaxHours = 1; else if (maxHours <= 2) yMaxHours = 2; else if (maxHours <= 3) yMaxHours = 3; else if (maxHours <= 4) yMaxHours = 4; else if (maxHours <= 6) yMaxHours = 6; else if (maxHours <= 8) yMaxHours = 8; else if (maxHours <= 10) yMaxHours = 10; else yMaxHours = (((maxHours + 4) / 5).ceil() * 5).toDouble();
    final yMax = (yMaxHours * 60).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dauer der letzten 7 Tage (Stunden)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Builder(builder: (context) {
                  final int axisMax = yMaxHours.ceil();
                  final int step = ((axisMax / 4).ceil()).clamp(1, axisMax);
                  final List<int> ticks = [];
                  for (int v = 0; v <= axisMax; v += step) {
                    if (ticks.isEmpty || ticks.last != v) ticks.add(v);
                    if (ticks.length >= 4) break; // limit before adding max
                  }
                  if (ticks.isEmpty || ticks.last != axisMax) ticks.add(axisMax);
                  if (ticks.length == 1) ticks.insert(0, 0);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ticks.reversed
                        .map((v) => Text('$v', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey.withOpacity(0.7))))
                        .toList(),
                  );
                }),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final chartWidth = constraints.maxWidth;
                  const chartHeight = 120.0;
                  const double topPad = 6.0;
                  const double bottomPad = 20.0;
                  final usableHeight = chartHeight - topPad - bottomPad;
                  return Stack(children: [
                    ...List.generate(4, (i) {
                      final y = topPad + ((i + 1) / 4.0) * usableHeight;
                      return Positioned(top: y, left: 0, right: 0, child: Container(height: 1, color: Colors.grey.withOpacity(0.2)));
                    }),
                    CustomPaint(
                      size: Size(chartWidth, chartHeight),
                      painter: _GlobalBarChartPainter(
                        data: durationPerDay,
                        maxValue: yMax.toDouble(),
                        color: _parseColor(widget.area.color),
                      ),
                    ),
                    // Hover tooltips per bar
                    ...last7Days.asMap().entries.map((entry) {
                      final index = entry.key;
                      final minutes = durationPerDay[index];
                      final slotWidth = chartWidth / durationPerDay.length;
                      final barWidth = slotWidth * 0.6;
                      final left = (index * slotWidth) + (slotWidth - barWidth) / 2.0;
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
                    // Centered date labels
                    ...last7Days.asMap().entries.map((entry) {
                      final index = entry.key;
                      final date = entry.value;
                      final slotWidth = chartWidth / durationPerDay.length;
                      final center = (index * slotWidth) + slotWidth / 2.0;
                      return Positioned(
                        bottom: 0,
                        left: (center - 12).clamp(0.0, chartWidth - 24),
                        child: SizedBox(
                          width: 24,
                          child: Text('${date.day}/${date.month}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey.withOpacity(0.7))),
                        ),
                      );
                    }).toList(),
                  ]);
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceAll('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
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
      default:
        return Icons.circle;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fitness':
        return Icons.fitness_center;
      case 'lernen':
      case 'learning':
        return Icons.school;
      case 'arbeit':
      case 'work':
        return Icons.work;
      case 'hobby':
        return Icons.sports_esports;
      case 'gesundheit':
      case 'health':
        return Icons.favorite;
      default:
        return Icons.star;
    }
  }
}

class LineChartPainter extends CustomPainter {
  final List<int> data;
  final double maxValue;
  final Color color;

  LineChartPainter({
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

class LArrowPainter extends CustomPainter {
  final Color color;
  LArrowPainter({this.color = Colors.black87});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // L-Form: nach unten, dann rechts, mit Pfeilspitze, zentriert an der halben Höhe
    final path = Path();
    final startX = size.width * 0.15;
    final midY = size.height * 0.5;
    final arrowRightX = size.width * 0.98;

    path.moveTo(startX, 0);
    path.lineTo(startX, midY);
    path.lineTo(arrowRightX, midY);
    canvas.drawPath(path, paint);

    // Pfeilspitze
    final headSize = 6.0;
    final base = Offset(arrowRightX, midY);
    final left = Offset(arrowRightX - headSize, midY - headSize * 0.8);
    final right = Offset(arrowRightX - headSize, midY + headSize * 0.8);
    canvas.drawLine(base, left, paint);
    canvas.drawLine(base, right, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}