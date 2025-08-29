import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/life_areas_service.dart';
import '../services/character_service.dart';
import '../services/avatar_sync_service.dart';
import '../services/db_service.dart' as db_service;
import '../navigation.dart';
import 'dart:convert'; // Added for jsonDecode
import '../utils/animation_utils.dart';
import '../utils/app_theme.dart';
import '../utils/parsed_activity_data.dart';

// Separate Character Widget to prevent rebuilding on hover
class CharacterWidget extends StatefulWidget {
  const CharacterWidget({super.key});

  @override
  State<CharacterWidget> createState() => _CharacterWidgetState();
}

class _CharacterWidgetState extends State<CharacterWidget> {
  Character? _character;
  bool _isLoading = true;
  String? _error;
  String? _userAvatarUrl;
  RealtimeChannel? _usersChannel;
  int _cacheBust = 0;

  @override
  void initState() {
    super.initState();
    _loadCharacter();
    _loadUserAvatar();
    _subscribeToUserChanges();
    // Lokaler Broadcast: sofort updaten, wenn Avatar-Version steigt
    AvatarSyncService.avatarVersion.addListener(_loadUserAvatar);
    // Automatische Aktualisierung beim Start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCharacter();
        _loadUserAvatar();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lade die Daten neu, wenn die Abhängigkeiten sich ändern
    _loadCharacter();
    _loadUserAvatar();
  }



  Future<void> _loadCharacter() async {
    try {
      final character = await CharacterService.getOrCreateCharacter();
      if (mounted) {
        setState(() {
          _character = character;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserAvatar() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Lade Avatar-URL direkt aus der users Tabelle
        final res = await Supabase.instance.client
            .from('users')
            .select('avatar_url')
            .eq('id', user.id)
            .single();
        
        if (mounted) {
          setState(() {
            _userAvatarUrl = res['avatar_url'];
            _cacheBust = DateTime.now().millisecondsSinceEpoch;
          });
          if (kDebugMode) debugPrint('DEBUG: BubbleWidget - Loaded avatar_url: $_userAvatarUrl');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Fehler beim Laden des User-Avatars: $e');
    }
  }

  void _subscribeToUserChanges() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    _usersChannel?.unsubscribe();
    final channel = client
        .channel('public:users:id=eq.${user.id}:bubble')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (PostgresChangePayload payload) async {
            await _loadUserAvatar();
            if (mounted) setState(() {});
          },
        );
    channel.subscribe();
    _usersChannel = channel;
  }

  @override
  void dispose() {
    _usersChannel?.unsubscribe();
    AvatarSyncService.avatarVersion.removeListener(_loadUserAvatar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withValues(alpha: 0.3),
        ),
        child: const CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withValues(alpha: 0.3),
        ),
        child: const Icon(Icons.error, color: Colors.red),
      );
    }

    final character = _character!;
    // Verwende das User-Avatar, falls verfügbar, sonst das Character-Avatar
    final rawAvatarUrl = _userAvatarUrl ?? character.avatarUrl;
    final avatarUrl = rawAvatarUrl != null
        ? '$rawAvatarUrl?cb=$_cacheBust'
        : null;
    
    return AnimationUtils.bounceIn(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: AppTheme.primaryGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
      child: Stack(
        children: [
          // Avatar or default icon
          Center(
            child: avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        if (kDebugMode) debugPrint('Avatar load error: $error');
                        return const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.white,
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.white,
                  ),
          ),
          
          // Level badge
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                'Lv.${character.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class BubblesGrid extends StatefulWidget {
  final List<LifeArea> areas;
  final Function(LifeArea) onBubbleTap;
  final Function(LifeArea)? onToggleVisibility;
  final Function(LifeArea)? onDelete;

  const BubblesGrid({
    super.key,
    required this.areas,
    required this.onBubbleTap,
    this.onToggleVisibility,
    this.onDelete,
  });

  @override
  State<BubblesGrid> createState() => _BubblesGridState();
}

class _BubblesGridState extends State<BubblesGrid> {
  int? _hoveredIndex;
  int? _longPressIndex; // Track which bubble is being long-pressed
  Offset? _lastMousePosition; // Add this to store mouse position
  bool _contextMenuOpen = false;
  Map<String, double> _minutesByKey = {};
  bool _loadingDurations = false;
  // Stable layout cache to avoid jitter/teleport on hover
  final Map<String, Rect> _layoutByAreaId = {};
  String _layoutSignature = '';

  @override
  void initState() {
    super.initState();
    _loadAreaDurations();
    // Reload sizes when logs change globally
    logsChangedTick.addListener(_loadAreaDurations);
  }

  @override
  void dispose() {
    logsChangedTick.removeListener(_loadAreaDurations);
    super.dispose();
  }

  Future<void> _loadAreaDurations() async {
    setState(() => _loadingDurations = true);
    try {
      // Get existing life areas to create name mapping
      final existingAreas = await LifeAreasService.getLifeAreas();
      final Map<String, String> canonicalToActualName = {};
      for (final area in existingAreas) {
        final canonical = LifeAreasService.canonicalAreaName(area.name);
        canonicalToActualName[canonical] = area.name;
      }
      
      // Use local storage via db_service
      final logs = await db_service.fetchLogs();
      
      final Map<String, double> agg = {};
      for (final log in logs) {
        final int mins = log.durationMin ?? 0;
        if (mins <= 0) continue;
        
        // Use ParsedActivityData like other pages do
        final parsed = ParsedActivityData.fromNotes(log.notes);
        final activityAreaName = parsed.effectiveAreaName;
        
        if (activityAreaName.isNotEmpty) {
          // Find the actual life area that matches this activity
          String? matchingAreaName;
          
          // First, try exact name match
          for (final area in existingAreas) {
            if (area.name.toLowerCase() == activityAreaName.toLowerCase()) {
              matchingAreaName = area.name;
              break;
            }
          }
          
          // If no exact match, try canonical name match
          if (matchingAreaName == null) {
            final activityCanonical = LifeAreasService.canonicalAreaName(activityAreaName);
            matchingAreaName = canonicalToActualName[activityCanonical];
          }
          
          // Use the actual area name, not canonical
          final keyToUse = matchingAreaName ?? activityAreaName;
          agg[keyToUse] = (agg[keyToUse] ?? 0) + mins.toDouble();
        } else {
          // Activities without life area
          agg['unknown'] = (agg['unknown'] ?? 0) + mins.toDouble();
        }
      }
      
      if (mounted) setState(() { _minutesByKey = agg; _loadingDurations = false; });
    } catch (_) {
      if (mounted) setState(() { _minutesByKey = {}; _loadingDurations = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.areas.isEmpty) {
      return const SizedBox.shrink();
    }

    // Responsive: occupy full width; compute height from constraints
    final screenSize = MediaQuery.of(context).size;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double canvasWidth = constraints.maxWidth;
        // Height: responsive (60% of width), bounded by screen height
        double canvasHeight = canvasWidth * 0.6;
        canvasHeight = canvasHeight.clamp(300.0, screenSize.height * 0.70);
        const double baseCanvas = 300.0;
        final double scale = min(canvasWidth, canvasHeight) / baseCanvas;

        return SizedBox(
          width: canvasWidth,
          height: canvasHeight,
          child: Stack(
            children: [
              if (_loadingDurations)
                const Center(child: CircularProgressIndicator())
              else
                ..._buildRandomBubbles(canvasWidth, canvasHeight, scale),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildRandomBubbles(double canvasWidth, double canvasHeight, double scale) {
    final List<Widget> widgets = [];
    if (widget.areas.isEmpty) return widgets;
    final Map<LifeArea, double> minutes = {};
    for (final area in widget.areas) {
      // Use actual area name, not canonical
      minutes[area] = _minutesByKey[area.name] ?? 0.0;
    }
    final double maxMin = (minutes.values.isEmpty ? 0.0 : minutes.values.reduce(max)).clamp(0.0, double.infinity);
    final double minSide = min(canvasWidth, canvasHeight);
    // Bigger lead bubble ~32% of min side
    final double maxSize = (minSide * 0.32).clamp(54.0, 240.0);
    // Ensure a minimum of 30% of the biggest bubble
    final double minSize = maxSize * 0.30;

    final ordered = minutes.keys.toList()
      ..sort((a, b) => (minutes[b] ?? 0).compareTo(minutes[a] ?? 0));

    // Base size per area
    final Map<String, double> sizeById = {
      for (final a in ordered)
        a.id: max(minSize, maxSize * (maxMin > 0 ? (minutes[a]! / maxMin).clamp(0.0, 1.0) : 0.5))
    };

    // Build signature incl. width/height
    final sig = StringBuffer()
      ..write(canvasWidth.toStringAsFixed(0))
      ..write('x')
      ..write(canvasHeight.toStringAsFixed(0))
      ..write('|');
    for (final a in ordered) {
      sig
        ..write(a.id)
        ..write(':')
        ..write(sizeById[a.id]!.toStringAsFixed(1))
        ..write(',');
    }
    final signature = sig.toString();

    if (_layoutSignature != signature) {
      _layoutByAreaId.clear();
      const double padding = 16.0; // More padding
      
      // Calculate optimal grid layout to prevent overlaps
      final areas = ordered.toList();
      final int numAreas = areas.length;
      
      if (numAreas == 0) {
        _layoutSignature = signature;
      } else {
      
      // Calculate grid dimensions
      final double availableWidth = canvasWidth - (padding * 2);
      final double availableHeight = canvasHeight - (padding * 2);
      
      // Determine grid layout based on number of items
      int cols, rows;
      if (numAreas <= 4) {
        cols = min(numAreas, 2);
        rows = (numAreas / cols).ceil();
      } else if (numAreas <= 9) {
        cols = 3;
        rows = (numAreas / cols).ceil();
      } else {
        cols = 4;
        rows = (numAreas / cols).ceil();
      }
      
      // Calculate cell size
      final double cellWidth = availableWidth / cols;
      final double cellHeight = availableHeight / rows;
      final double cellSize = min(cellWidth, cellHeight) * 0.8; // 80% of cell for spacing
      
      // Adjust bubble sizes to fit in grid
      final double maxBubbleSize = min(cellSize, maxSize);
      final Map<String, double> adjustedSizes = {};
      for (final area in areas) {
        final originalSize = sizeById[area.id]!;
        adjustedSizes[area.id] = min(originalSize, maxBubbleSize);
      }
      
      // Place bubbles in grid
      for (int i = 0; i < numAreas; i++) {
        final area = areas[i];
        final size = adjustedSizes[area.id]!;
        
        final col = i % cols;
        final row = i ~/ cols;
        
        final centerX = padding + (col + 0.5) * cellWidth;
        final centerY = padding + (row + 0.5) * cellHeight;
        
        final rect = Rect.fromLTWH(
          centerX - size / 2, 
          centerY - size / 2, 
          size, 
          size
        );
        
        _layoutByAreaId[area.id] = rect;
      }
      
      _layoutSignature = signature;
      } // close else block
    }

    for (int idx = 0; idx < ordered.length; idx++) {
      final area = ordered[idx];
      final rect = _layoutByAreaId[area.id]!;
      final size = rect.width;
      final mins = minutes[area] ?? 0.0;
      final isHovered = _hoveredIndex == idx;
      final isLongPressed = _longPressIndex == idx;
      final hoverScale = isHovered ? 1.10 : 1.0;
      final longPressScale = isLongPressed ? 0.95 : 1.0; // Slightly shrink on long press

      widgets.add(Positioned(
        left: rect.left,
        top: rect.top,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            if (!mounted || _contextMenuOpen) return;
            setState(() => _hoveredIndex = idx);
          },
          onExit: (_) {
            if (!mounted || _contextMenuOpen) return;
            setState(() => _hoveredIndex = null);
          },
          child: GestureDetector(
            onTap: () => widget.onBubbleTap(area),
            onLongPressStart: (_) {
              setState(() => _longPressIndex = idx);
            },
            onLongPressEnd: (_) {
              setState(() => _longPressIndex = null);
            },
            onLongPress: () {
              if (kDebugMode) {
                print('DEBUG: Long press detected on ${area.name}');
              }
              HapticFeedback.mediumImpact();
              // Show context menu on long press for mobile
              setState(() {
                _contextMenuOpen = true;
                _hoveredIndex = null;
                _longPressIndex = null; // Reset long press state
              });
              _showMobileContextMenu(context, area);
            },
            behavior: HitTestBehavior.opaque,
            onSecondaryTapDown: (details) {
              _lastMousePosition = details.globalPosition;
              if (!mounted) return;
              setState(() {
                _contextMenuOpen = true;
                _hoveredIndex = null;
              });
              _showContextMenu(context, area);
            },
            child: Transform.scale(
                scale: hoverScale * longPressScale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLongPressed
                        ? _parseColor(area.color).withValues(alpha: 0.7) // Dimmer when long pressed
                        : isHovered 
                        ? _parseColor(area.color).withValues(alpha: 0.9)
                        : _parseColor(area.color),
                    border: Border.all(
                      color: isLongPressed
                          ? Colors.red.withValues(alpha: 0.8) // Red border when long pressing
                          : isHovered 
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.3),
                      width: isLongPressed ? 4 : isHovered ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _parseColor(area.color).withValues(alpha: isHovered ? 0.6 : 0.4),
                        blurRadius: isHovered ? 16 : 12,
                        offset: const Offset(0, 4),
                        spreadRadius: isHovered ? 2 : 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isHovered ? 0.15 : 0.1),
                        blurRadius: isHovered ? 6 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getIconData(area.icon),
                    color: Colors.white,
                    size: max(16.0, size * 0.35),
                  ),
                ),
              ),
          ),
        ),
      ));
    }
    return widgets;
  }

  void _showContextMenu(BuildContext context, LifeArea area) {
    // Use the stored mouse position or fallback to center
    final position = _lastMousePosition ?? Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20, color: Colors.blue),
              SizedBox(width: 8),
              Text('Edit', style: TextStyle(color: Colors.blue)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'toggle' && widget.onToggleVisibility != null) {
        widget.onToggleVisibility!(area);
      } else if (value == 'edit') {
        _showEditLifeAreaDialog(context, area);
      } else if (value == 'delete') {
        _showDeleteConfirmation(context, area);
      }
      if (mounted) {
        setState(() {
          _contextMenuOpen = false;
        });
      } else {
        _contextMenuOpen = false;
      }
    });
  }

  void _showDeleteDialog(BuildContext context, LifeArea area) {
    if (kDebugMode) {
      print('DEBUG: _showDeleteDialog called for area: ${area.name}');
    }
    _showDeleteConfirmation(context, area);
  }

  void _showMobileContextMenu(BuildContext context, LifeArea area) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Life Area', style: TextStyle(color: Colors.blue)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showEditLifeAreaDialog(context, area);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Life Area', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteConfirmation(context, area);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _contextMenuOpen = false;
        });
      } else {
        _contextMenuOpen = false;
      }
    });
  }

  void _showDeleteConfirmation(BuildContext context, LifeArea area) {
    // Use actual area name, not canonical
    final activityCount = (_minutesByKey[area.name] ?? 0.0).toInt();
    final hasActivities = activityCount > 0;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
      title: const Text('Delete life area'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Do you really want to delete "${area.name}"?'),
              if (hasActivities) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$activityCount minutes of logged activities will lose their life area connection.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Store the area data for potential undo
                  final deletedArea = area;
                  
                  await LifeAreasService.deleteLifeArea(area.id);
                  Navigator.of(context).pop();
                  
                  // Call the parent's onDelete callback to trigger rebuild
                  if (widget.onDelete != null) {
                    widget.onDelete!(area);
                  }
                  
                  // Show undo snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deleted "${deletedArea.name}"'),
                      backgroundColor: Colors.green,
                      action: SnackBarAction(
                        label: 'UNDO',
                        textColor: Colors.white,
                        onPressed: () async {
                          try {
                            // Recreate the life area
                            await LifeAreasService.createLifeArea(
                              name: deletedArea.name,
                              category: deletedArea.category,
                              color: deletedArea.color,
                              icon: deletedArea.icon,
                            );
                            // Trigger UI refresh
                            notifyLifeAreasChanged();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error restoring life area: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      duration: const Duration(seconds: 8), // Longer duration for undo
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
      content: Text('Error while deleting: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showEditLifeAreaDialog(BuildContext context, LifeArea area) {
    final nameController = TextEditingController(text: area.name);
    String selectedColor = area.color;
    String selectedIcon = area.icon;
    final colors = [
      '#2196F3', '#FF5722', '#4CAF50', '#FF9800', 
      '#9C27B0', '#F44336', '#795548', '#607D8B'
    ];
    final icons = [
      'circle', 'work', 'fitness_center', 'favorite', 
      'school', 'attach_money', 'self_improvement', 'palette'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Life Area'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter life area name',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Color:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: colors.map((color) => GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(int.parse(color.replaceAll('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: selectedColor == color
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Icon:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: icons.map((iconName) => GestureDetector(
                    onTap: () => setState(() => selectedIcon = iconName),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selectedIcon == iconName
                            ? Colors.blue.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: selectedIcon == iconName
                            ? Border.all(color: Colors.blue, width: 2)
                            : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        _getIconData(iconName),
                        color: Colors.black87,
                      ),
                    ),
                  )).toList(),
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
                if (nameController.text.trim().isEmpty) return;
                
                try {
                  await LifeAreasService.updateLifeArea(area.id, {
                    'name': nameController.text.trim(),
                    'category': area.category, // Keep existing category
                    'color': selectedColor,
                    'icon': selectedIcon,
                  });
                  
                  Navigator.of(context).pop();
                  
                  // Trigger UI refresh
                  notifyLifeAreasChanged();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated "${nameController.text.trim()}"'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating life area: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
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
      case 'gardening':
        return Icons.eco;
      case 'pets':
        return Icons.pets;
      case 'child_care':
        return Icons.child_care;
      default:
        return Icons.circle;
    }
  }
} 