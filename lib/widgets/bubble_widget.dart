import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/life_areas_service.dart';
import '../services/character_service.dart';
import '../services/avatar_sync_service.dart';
import '../profile_page.dart';
import '../navigation.dart';
import 'dart:convert'; // Added for jsonDecode

// Separate Character Widget to prevent rebuilding on hover
class CharacterWidget extends StatefulWidget {
  const CharacterWidget({Key? key}) : super(key: key);

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
        .on(
          RealtimeListenTypes.postgresChanges,
          ChannelFilter(
            event: 'UPDATE',
            schema: 'public',
            table: 'users',
            filter: 'id=eq.${user.id}',
          ),
          (payload, [ref]) async {
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
          color: Colors.grey.withOpacity(0.3),
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
          color: Colors.red.withOpacity(0.3),
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
    
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    color: Colors.black.withOpacity(0.2),
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
    );
  }
}

class BubblesGrid extends StatefulWidget {
  final List<LifeArea> areas;
  final Function(LifeArea) onBubbleTap;
  final Function(LifeArea)? onToggleVisibility;
  final Function(LifeArea)? onDelete;

  const BubblesGrid({
    Key? key,
    required this.areas,
    required this.onBubbleTap,
    this.onToggleVisibility,
    this.onDelete,
  }) : super(key: key);

  @override
  State<BubblesGrid> createState() => _BubblesGridState();
}

class _BubblesGridState extends State<BubblesGrid> {
  int? _hoveredIndex;
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
  }

  Future<void> _loadAreaDurations() async {
    setState(() => _loadingDurations = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() { _minutesByKey = {}; _loadingDurations = false; });
        return;
      }
      final rows = await client
          .from('action_logs')
          .select('duration_min, notes')
          .eq('user_id', user.id);

      final Map<String, double> agg = {};
      String resolveKey(Map<String, dynamic> obj) {
        String? area = (obj['area'] as String?)?.trim().toLowerCase();
        final lifeArea = (obj['life_area'] as String?)?.trim().toLowerCase();
        area ??= lifeArea;
        final category = (obj['category'] as String?)?.trim().toLowerCase();
        bool isKnownParent(String? v) => const {
          'spirituality','finance','career','learning','relationships','health','creativity','fitness','nutrition','art'
        }.contains(v);
        if (isKnownParent(area)) return area!;
        switch (category) {
          case 'inner': return 'spirituality';
          case 'social': return 'relationships';
          case 'work': return 'career';
          case 'development': return 'learning';
          case 'finance': return 'finance';
          case 'health': return 'health';
          default: return area ?? 'unknown';
        }
      }
      for (final r in (rows as List)) {
        final int mins = (r['duration_min'] as int?) ?? 0;
        String key = 'unknown';
        try {
          if (r['notes'] != null) {
            final obj = jsonDecode(r['notes'] as String);
            if (obj is Map<String, dynamic>) key = resolveKey(obj);
          }
        } catch (_) {}
        agg[key] = (agg[key] ?? 0) + (mins > 0 ? mins.toDouble() : 0.0);
      }
      setState(() { _minutesByKey = agg; _loadingDurations = false; });
    } catch (_) {
      setState(() { _minutesByKey = {}; _loadingDurations = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.areas.isEmpty) {
      return const SizedBox.shrink();
    }

    // Responsive Canvas: skaliert nach Bildschirmgröße
    final screenSize = MediaQuery.of(context).size;
    double canvasSize = min(screenSize.width * 0.6, screenSize.height * 0.55);
    canvasSize = canvasSize.clamp(320.0, 800.0);
    const double baseCanvas = 300.0;
    final double scale = canvasSize / baseCanvas;

    return Center(
      child: SizedBox(
        height: canvasSize,
        width: canvasSize,
        child: Stack(
          children: [
            if (_loadingDurations)
              const Center(child: CircularProgressIndicator())
            else
              ..._buildRandomBubbles(canvasSize, scale),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRandomBubbles(double canvasSize, double scale) {
    final List<Widget> widgets = [];
    if (widget.areas.isEmpty) return widgets;
    final Map<LifeArea, double> minutes = {};
    for (final area in widget.areas) {
      final key = LifeAreasService.canonicalAreaName(area.name);
      minutes[area] = _minutesByKey[key] ?? 0.0;
    }
    final double maxMin = (minutes.values.isEmpty ? 0.0 : minutes.values.reduce(max)).clamp(0.0, double.infinity);
    // Bigger lead bubble ~32% of canvas; allow larger upper bound on wide screens
    final double maxSize = (canvasSize * 0.32).clamp(54.0, 240.0);
    // Ensure a minimum of 30% of the biggest bubble
    final double minSize = maxSize * 0.30;

    final ordered = minutes.keys.toList()
      ..sort((a, b) => (minutes[b] ?? 0).compareTo(minutes[a] ?? 0));

    // Pre-compute base size per area
    final Map<String, double> sizeById = {
      for (final a in ordered)
        a.id: max(minSize, maxSize * (maxMin > 0 ? (minutes[a]! / maxMin).clamp(0.0, 1.0) : 0.5))
    };

    // Build a signature so we only place when inputs changed
    final sig = StringBuffer()
      ..write(canvasSize.toStringAsFixed(0))
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
      final List<Rect> placed = [];
      final double radiusBound = canvasSize * 0.90; // use almost full canvas
      final Offset center = Offset(canvasSize / 2, canvasSize / 2);

      for (final area in ordered) {
        final double size = sizeById[area.id]!;
        final rnd = Random(area.id.hashCode);
        Offset? pos;
        for (int attempt = 0; attempt < 240; attempt++) {
          final angle = rnd.nextDouble() * 2 * pi;
          final r = rnd.nextDouble() * (radiusBound - size * 0.6);
          final x = center.dx + r * cos(angle);
          final y = center.dy + r * sin(angle);
          final rect = Rect.fromLTWH(x - size / 2, y - size / 2, size, size);
          final safe = rect.left >= 0 && rect.top >= 0 && rect.right <= canvasSize && rect.bottom <= canvasSize;
          if (!safe) continue;
          bool overlaps = false;
          for (final placedRect in placed) {
            if (rect.overlaps(placedRect.inflate(6))) { overlaps = true; break; }
          }
          if (!overlaps) { pos = Offset(x, y); placed.add(rect); _layoutByAreaId[area.id] = rect; break; }
        }
        // Fallback to center if no non-overlapping position was found
        _layoutByAreaId.putIfAbsent(area.id, () => Rect.fromCenter(center: center, width: size, height: size));
      }
      _layoutSignature = signature;
    }

    for (int idx = 0; idx < ordered.length; idx++) {
      final area = ordered[idx];
      final rect = _layoutByAreaId[area.id]!;
      final size = rect.width;
      final mins = minutes[area] ?? 0.0;
      final isHovered = _hoveredIndex == idx;
      final hoverScale = isHovered ? 1.10 : 1.0; // scale visual only, keep position stable

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
            child: Tooltip(
              message: '${area.name} • ${mins.toInt()} min',
              waitDuration: const Duration(milliseconds: 400),
              child: Transform.scale(
                scale: hoverScale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isHovered 
                        ? _parseColor(area.color).withOpacity(0.9)
                        : _parseColor(area.color),
                    border: Border.all(
                      color: isHovered 
                          ? Colors.white.withOpacity(0.6)
                          : Colors.white.withOpacity(0.3),
                      width: isHovered ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _parseColor(area.color).withOpacity(isHovered ? 0.6 : 0.4),
                        blurRadius: isHovered ? 16 : 12,
                        offset: const Offset(0, 4),
                        spreadRadius: isHovered ? 2 : 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(isHovered ? 0.15 : 0.1),
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
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete, size: 20, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Löschen', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'toggle' && widget.onToggleVisibility != null) {
        widget.onToggleVisibility!(area);
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

  void _showDeleteConfirmation(BuildContext context, LifeArea area) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
      title: const Text('Delete life area'),
          content: Text('Do you really want to delete "${area.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await LifeAreasService.deleteLifeArea(area.id);
                  Navigator.of(context).pop();
                  // Call the parent's onDelete callback to trigger rebuild
                  if (widget.onDelete != null) {
                    widget.onDelete!(area);
                  }
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