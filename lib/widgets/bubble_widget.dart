import 'package:flutter/material.dart';
import 'dart:math';
import '../services/life_areas_service.dart';
import '../services/character_service.dart';

class BubblesGrid extends StatefulWidget {
  final List<LifeArea> areas;
  final Function(LifeArea) onBubbleTap;

  const BubblesGrid({
    Key? key,
    required this.areas,
    required this.onBubbleTap,
  }) : super(key: key);

  @override
  State<BubblesGrid> createState() => _BubblesGridState();
}

class _BubblesGridState extends State<BubblesGrid> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.areas.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          // Real Character in the center - isolated from hover effects
          Positioned(
            left: 110, // Center position (150 - 40)
            top: 110,  // Center position (150 - 40)
            child: IgnorePointer(
              child: FutureBuilder<Character>(
                future: CharacterService.getOrCreateCharacter(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
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

                  if (snapshot.hasError) {
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

                  final character = snapshot.data!;
                  
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
                },
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
} 