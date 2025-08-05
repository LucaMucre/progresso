import 'package:flutter/material.dart';
import 'dart:math';
import '../services/life_areas_service.dart';
import '../services/character_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCharacter();
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
            child: character.avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      character.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
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

  @override
  Widget build(BuildContext context) {
    if (widget.areas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        height: 300,
        width: 300,
        child: Stack(
          children: [
            // Character in the center - clickable to navigate to profile
            Positioned(
              left: 110, // Center position (150 - 40)
              top: 110,  // Center position (150 - 40)
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: const CharacterWidget(),
                ),
              ),
            ),

            // Life Area Bubbles arranged in a circle around the character
            ...widget.areas.asMap().entries.map((entry) {
              final index = entry.key;
              final area = entry.value;
              final angle = (2 * pi * index) / widget.areas.length;
              final radius = 120.0; // Increased distance from center to avoid overlap
              final centerX = 150.0; // Center X position
              final centerY = 150.0; // Center Y position
              
              final x = centerX + radius * cos(angle);
              final y = centerY + radius * sin(angle);
              final isHovered = _hoveredIndex == index;
              final scale = isHovered ? 1.15 : 1.0;
              final size = 50.0 * scale;

              return Positioned(
                left: x - (size / 2),
                top: y - (size / 2),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredIndex = index),
                  onExit: (_) => setState(() => _hoveredIndex = null),
                  child: GestureDetector(
                    onTap: () => widget.onBubbleTap(area),
                    onSecondaryTapDown: (details) {
                      _lastMousePosition = details.globalPosition;
                      _showContextMenu(context, area);
                    },
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
                        size: 20 * scale,
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
        // Temporarily disable visibility toggle until migration is applied
        // PopupMenuItem(
        //   value: 'toggle',
        //   child: Row(
        //     children: [
        //       Icon(
        //         area.isVisible ? Icons.visibility_off : Icons.visibility,
        //         size: 20,
        //       ),
        //       const SizedBox(width: 8),
        //       Text(area.isVisible ? 'Ausblenden' : 'Einblenden'),
        //     ],
        //   ),
        // ),
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
    });
  }

  void _showDeleteConfirmation(BuildContext context, LifeArea area) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Lebensbereich löschen'),
          content: Text('Möchten Sie "${area.name}" wirklich löschen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
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
                      content: Text('Fehler beim Löschen: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Löschen'),
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