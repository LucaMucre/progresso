import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/character_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/avatar_sync_service.dart';
import '../utils/accessibility_utils.dart';

class CharacterWidget extends StatefulWidget {
  const CharacterWidget({super.key});

  @override
  State<CharacterWidget> createState() => _CharacterWidgetState();
}

class _CharacterWidgetState extends State<CharacterWidget> {
  String? _userAvatarUrl;
  RealtimeChannel? _usersChannel;
  int _cacheBust = 0;

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
    _subscribeToUserChanges();
    AvatarSyncService.avatarVersion.addListener(_loadUserAvatar);
  }

  Future<void> _loadUserAvatar() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
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
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        });
      }
  if (kDebugMode) debugPrint('Error loading user avatar: $e');
    }
  }

  void _subscribeToUserChanges() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    _usersChannel?.unsubscribe();
    final channel = client
        .channel('public:users:id=eq.${user.id}:character-card')
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

  Widget _buildStatBar(String label, int value, int maxValue, Color color) {
    final percentage = value / maxValue;
    
    return Semantics(
      label: '$label: $value out of $maxValue points, ${(percentage * 100).round()}% complete',
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$value/$maxValue',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildStatIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Character>(
      future: CharacterService.getOrCreateCharacter(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Column(
              children: [
                Icon(Icons.error, color: Colors.red, size: 48),
                SizedBox(height: 8),
                Text('Error loading character'),
              ],
            ),
          );
        }

        final character = snapshot.data!;
        final stats = character.stats;

        // Verwende das User-Avatar, falls verfügbar, sonst das Character-Avatar
        final rawAvatarUrl = _userAvatarUrl ?? character.avatarUrl;
        final avatarUrl = rawAvatarUrl != null ? '$rawAvatarUrl?cb=$_cacheBust' : null;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // Character Avatar & Level
              Stack(
                alignment: Alignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 120,
                    height: 120,
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
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              avatarUrl,
                              key: ValueKey(avatarUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                if (kDebugMode) debugPrint('Avatar load error: $error');
                                return const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                  ),
                  
                  // Level Badge - Jetzt sichtbar positioniert
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Lv.${character.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Character Name
              Text(
                character.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Total XP
              Text(
                '${character.totalXp} XP',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Stats Grid
              Column(
                children: [
                  // First Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildStatIcon(Icons.fitness_center, Colors.red),
                            const SizedBox(height: 8),
                            _buildStatBar('Stärke', stats.strength, 100, Colors.red),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            _buildStatIcon(Icons.psychology, Colors.blue),
                            const SizedBox(height: 8),
                            _buildStatBar('Intelligenz', stats.intelligence, 100, Colors.blue),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Second Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildStatIcon(Icons.lightbulb, Colors.yellow),
                            const SizedBox(height: 8),
                            _buildStatBar('Weisheit', stats.wisdom, 100, Colors.yellow),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            _buildStatIcon(Icons.chat_bubble, Colors.green),
                            const SizedBox(height: 8),
                            _buildStatBar('Charisma', stats.charisma, 100, Colors.green),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Third Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildStatIcon(Icons.favorite, Colors.purple),
                            const SizedBox(height: 8),
                            _buildStatBar('Ausdauer', stats.endurance, 100, Colors.purple),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            _buildStatIcon(Icons.directions_run, Colors.orange),
                            const SizedBox(height: 8),
                            _buildStatBar('Geschick', stats.agility, 100, Colors.orange),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
} 