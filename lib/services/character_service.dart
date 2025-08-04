import 'package:supabase_flutter/supabase_flutter.dart';

class CharacterStats {
  final int strength;
  final int intelligence;
  final int wisdom;
  final int charisma;
  final int endurance;
  final int agility;

  CharacterStats({
    required this.strength,
    required this.intelligence,
    required this.wisdom,
    required this.charisma,
    required this.endurance,
    required this.agility,
  });

  factory CharacterStats.fromJson(Map<String, dynamic> json) {
    return CharacterStats(
      strength: json['strength'] ?? 0,
      intelligence: json['intelligence'] ?? 0,
      wisdom: json['wisdom'] ?? 0,
      charisma: json['charisma'] ?? 0,
      endurance: json['endurance'] ?? 0,
      agility: json['agility'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strength': strength,
      'intelligence': intelligence,
      'wisdom': wisdom,
      'charisma': charisma,
      'endurance': endurance,
      'agility': agility,
    };
  }

  CharacterStats copyWith({
    int? strength,
    int? intelligence,
    int? wisdom,
    int? charisma,
    int? endurance,
    int? agility,
  }) {
    return CharacterStats(
      strength: strength ?? this.strength,
      intelligence: intelligence ?? this.intelligence,
      wisdom: wisdom ?? this.wisdom,
      charisma: charisma ?? this.charisma,
      endurance: endurance ?? this.endurance,
      agility: agility ?? this.agility,
    );
  }
}

class Character {
  final String id;
  final String userId;
  final String name;
  final int level;
  final int totalXp;
  final CharacterStats stats;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Character({
    required this.id,
    required this.userId,
    required this.name,
    required this.level,
    required this.totalXp,
    required this.stats,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      level: json['level'],
      totalXp: json['total_xp'],
      stats: CharacterStats.fromJson(json['stats'] ?? {}),
      avatarUrl: json['avatar_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'level': level,
      'total_xp': totalXp,
      'stats': stats.toJson(),
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class CharacterService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Character erstellen oder abrufen
  static Future<Character> getOrCreateCharacter() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User nicht angemeldet');

    try {
      // Versuche existierenden Character zu finden
      final response = await _client
          .from('characters')
          .select()
          .eq('user_id', user.id)
          .single();

      return Character.fromJson(response);
    } catch (e) {
      // Character existiert nicht, erstelle neuen
      final newCharacter = {
        'user_id': user.id,
        'name': user.email?.split('@')[0] ?? 'Hero',
        'level': 1,
        'total_xp': 0,
        'stats': CharacterStats(
          strength: 1,
          intelligence: 1,
          wisdom: 1,
          charisma: 1,
          endurance: 1,
          agility: 1,
        ).toJson(),
      };

      final response = await _client
          .from('characters')
          .insert(newCharacter)
          .select()
          .single();

      return Character.fromJson(response);
    }
  }

  // Character Stats aktualisieren
  static Future<void> updateCharacterStats(CharacterStats newStats) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User nicht angemeldet');

    await _client
        .from('characters')
        .update({
          'stats': newStats.toJson(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id);
  }

  // XP hinzufügen und Stats entsprechend erhöhen
  static Future<void> addXpAndUpdateStats(int xp, String statType) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User nicht angemeldet');

    // Aktuellen Character laden
    final character = await getOrCreateCharacter();
    
    // Neue Stats berechnen
    final currentStats = character.stats;
    CharacterStats newStats;
    
    switch (statType) {
      case 'strength':
        newStats = currentStats.copyWith(strength: currentStats.strength + 1);
        break;
      case 'intelligence':
        newStats = currentStats.copyWith(intelligence: currentStats.intelligence + 1);
        break;
      case 'wisdom':
        newStats = currentStats.copyWith(wisdom: currentStats.wisdom + 1);
        break;
      case 'charisma':
        newStats = currentStats.copyWith(charisma: currentStats.charisma + 1);
        break;
      case 'endurance':
        newStats = currentStats.copyWith(endurance: currentStats.endurance + 1);
        break;
      case 'agility':
        newStats = currentStats.copyWith(agility: currentStats.agility + 1);
        break;
      default:
        newStats = currentStats;
    }

    // Character aktualisieren
    await _client
        .from('characters')
        .update({
          'total_xp': character.totalXp + xp,
          'stats': newStats.toJson(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id);
  }

  // Character Avatar aktualisieren
  static Future<void> updateAvatar(String avatarUrl) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User nicht angemeldet');

    await _client
        .from('characters')
        .update({
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id);
  }
} 