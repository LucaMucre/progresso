import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/life_areas_service.dart';
import '../services/character_service.dart';
import '../services/avatar_sync_service.dart';
import '../profile_page.dart';

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
            // Character in the absolute center – robust against badge overflow
            Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {
                  // Navigate to the same tabbed ProfilePage instead of stacking a second instance
                  // by switching the HomeShell index to the Profile tab (index 4)
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  // Try to find the nearest HomeShell and set its tab
                  // Fallback: push ProfilePage if shell not found (e.g., deep link)
                  try {
                    final state = context.findAncestorStateOfType<_HomeShellState>();
                    if (state != null) {
                      state.setState(() {
                        state._currentIndex = 4;
                        state._profileNonce++;
                      });
                      return;
                    }
                  } catch (_) {}
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Transform.scale(
                    scale: scale,
                    child: const CharacterWidget(),
                  ),
                ),
              ),
            ),

            // Life Area Bubbles arranged in a circle around the character
            ...widget.areas.asMap().entries.map((entry) {
              final index = entry.key;
              final area = entry.value;
              final angle = (2 * pi * index) / widget.areas.length;
              final radius = canvasSize * 0.38; // Abstand vom Zentrum
              final centerX = canvasSize / 2; // Center X position
              final centerY = canvasSize / 2; // Center Y position
              
              final x = centerX + radius * cos(angle);
              final y = centerY + radius * sin(angle);
              final isHovered = _hoveredIndex == index;
              final hoverScale = isHovered ? 1.15 : 1.0;
              final size = 50.0 * scale * hoverScale;

              return Positioned(
                left: x - (size / 2),
                top: y - (size / 2),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) {
                    if (!mounted || _contextMenuOpen) return;
                    setState(() => _hoveredIndex = index);
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
                      message: area.name,
                      waitDuration: const Duration(milliseconds: 400),
                      child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
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
                        size: 20 * scale * hoverScale,
                      ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
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