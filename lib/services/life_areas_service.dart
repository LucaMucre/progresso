import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'anonymous_user_service.dart';

class LifeArea {
  final String id;
  final String userId;
  final String name;
  final String category;
  final String? parentId;
  final String color;
  final String icon;
  final int orderIndex;
  // Temporarily remove isVisible until migration is applied
  // final bool isVisible;
  final DateTime createdAt;
  final DateTime updatedAt;

  LifeArea({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    this.parentId,
    required this.color,
    required this.icon,
    required this.orderIndex,
    // this.isVisible = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LifeArea.fromJson(Map<String, dynamic> json) {
    return LifeArea(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      category: json['category'],
      parentId: json['parent_id'],
      color: json['color'],
      icon: json['icon'],
      orderIndex: json['order_index'],
      // isVisible: json['is_visible'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'category': category,
      'parent_id': parentId,
      'color': color,
      'icon': icon,
      'order_index': orderIndex,
      // 'is_visible': isVisible,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class LifeAreasService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Simple DE -> EN translation map for default life areas and categories
  static const Map<String, String> _nameDeToEn = {
    'Karriere': 'Career',
    'Beziehungen': 'Relationships',
    'Spiritualität': 'Spirituality',
    'Kunst': 'Art',
    'Finanzen': 'Finance',
    'Bildung': 'Learning',
    'Ernährung': 'Nutrition',
    'Fitness': 'Fitness',
  };

  static const Map<String, String> _categoryDeToEn = {
    'Beruf': 'Work',
    'Sozial': 'Social',
    'Inneres': 'Inner',
    'Kreativität': 'Creativity',
    'Wirtschaft': 'Finance',
    'Entwicklung': 'Development',
    'Gesundheit': 'Health',
    'Vitalität': 'Vitality',
    'Allgemein': 'General',
  };

  static Map<String, String> get _nameDeToEnLower =>
      _nameDeToEn.map((k, v) => MapEntry(k.toLowerCase(), v.toLowerCase()));
  static Map<String, String> get _categoryDeToEnLower => _categoryDeToEn
      .map((k, v) => MapEntry(k.toLowerCase(), v.toLowerCase()));

  // Returns a canonical, lowercase English key for comparisons
  static String canonicalAreaName(String? name) {
    if (name == null) return '';
    final lower = name.toLowerCase();
    return _nameDeToEnLower[lower] ?? lower;
  }

  static String canonicalCategory(String? category) {
    if (category == null) return '';
    final lower = category.toLowerCase();
    return _categoryDeToEnLower[lower] ?? lower;
  }

  // Alle Life Areas für einen User abrufen
  static Future<List<LifeArea>> getLifeAreas() async {
    final user = _client.auth.currentUser;
    
    if (user == null) {
      // Anonymous user - load from local storage
      return await _getLifeAreasAnonymous();
    }

    final response = await _client
        .from('life_areas')
        .select()
        .eq('user_id', user.id)
        .isFilter('parent_id', null)
        .order('order_index');

    return (response as List).map((json) => LifeArea.fromJson(json)).toList();
  }

  /// Load life areas for anonymous users from local storage
  static Future<List<LifeArea>> _getLifeAreasAnonymous() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await AnonymousUserService.getOrCreateAnonymousUserId();
      final key = 'life_areas_$userId';
      final jsonString = prefs.getString(key);
      
      if (jsonString == null) {
        return [];
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => LifeArea.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // One-time migration: translate default German names/categories to English for current user
  static Future<void> migrateDefaultsToEnglish() async {
    final user = _client.auth.currentUser;
    if (user == null) return; // Skip migration for anonymous users

    final rows = await _client
        .from('life_areas')
        .select('id,name,category')
        .eq('user_id', user.id);

    bool changed = false;
    for (final row in rows as List) {
      final String name = row['name'] as String? ?? '';
      final String category = row['category'] as String? ?? '';
      final Map<String, dynamic> updates = {};
      if (_nameDeToEn.containsKey(name)) {
        updates['name'] = _nameDeToEn[name];
      }
      if (_categoryDeToEn.containsKey(category)) {
        updates['category'] = _categoryDeToEn[category];
      }
      if (updates.isNotEmpty) {
        changed = true;
        await _client
            .from('life_areas')
            .update({
              ...updates,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', row['id'])
            .eq('user_id', user.id);
      }
    }
    if (changed) {
      // no-op; caller can refetch
    }
  }

  // Alle Life Areas (auch unsichtbare) für einen User abrufen
  static Future<List<LifeArea>> getAllLifeAreas() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // Anonymous user - load from local storage
      return await _getLifeAreasAnonymous();
    }

    final response = await _client
        .from('life_areas')
        .select()
        .eq('user_id', user.id)
        .order('order_index');

    return (response as List).map((json) => LifeArea.fromJson(json)).toList();
  }

  // Unterbereiche zu einem Life Area laden
  static Future<List<LifeArea>> getChildAreas(String parentId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // Anonymous user - no child areas supported yet, return empty list
      return [];
    }

    final response = await _client
        .from('life_areas')
        .select()
        .eq('user_id', user.id)
        .eq('parent_id', parentId)
        .order('order_index');

    return (response as List).map((json) => LifeArea.fromJson(json)).toList();
  }

  // Einzelnen Bereich per ID laden
  static Future<LifeArea?> getAreaById(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // Anonymous user - try to find in local storage
      final areas = await _getLifeAreasAnonymous();
      try {
        return areas.firstWhere((area) => area.id == id);
      } catch (e) {
        return null;
      }
    }

    try {
      final response = await _client
          .from('life_areas')
          .select()
          .eq('user_id', user.id)
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return LifeArea.fromJson(response as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // Life Area erstellen
  static Future<LifeArea> createLifeArea({
    required String name,
    required String category,
    String? parentId,
    String color = '#2196F3',
    String icon = 'circle',
    int orderIndex = 0,
    // bool isVisible = true,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User nicht angemeldet');

    final newArea = {
      'user_id': user.id,
      'name': name,
      'category': category,
      'parent_id': parentId,
      'color': color,
      'icon': icon,
      'order_index': orderIndex,
      // Temporarily remove is_visible until migration is applied
      // 'is_visible': isVisible,
    };

    final response = await _client
        .from('life_areas')
        .insert(newArea)
        .select()
        .single();

    return LifeArea.fromJson(response);
  }

  // Life Area aktualisieren
  static Future<void> updateLifeArea(String id, Map<String, dynamic> updates) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User nicht angemeldet');

    await _client
        .from('life_areas')
        .update({
          ...updates,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', user.id);
  }

  // Sichtbarkeit einer Life Area umschalten
  static Future<void> toggleLifeAreaVisibility(String id) async {
    // Temporarily disabled until migration is applied
    throw Exception('Visibility toggle is temporarily disabled. Please apply the database migration.');
  }

  // Life Area löschen
  static Future<void> deleteLifeArea(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User nicht angemeldet');

    await _client
        .from('life_areas')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
  }

  // Hierarchische Struktur erstellen
  static List<LifeArea> buildHierarchy(List<LifeArea> areas) {
    final Map<String, List<LifeArea>> childrenMap = {};
    final List<LifeArea> roots = [];

    // Kinder gruppieren
    for (final area in areas) {
      if (area.parentId == null) {
        roots.add(area);
      } else {
        childrenMap.putIfAbsent(area.parentId!, () => []).add(area);
      }
    }

    return roots;
  }

  // Standard Life Areas erstellen
  static Future<void> createDefaultLifeAreas() async {
    final user = _client.auth.currentUser;
    
    // Prüfen ob bereits Life Areas existieren
    final existingAreas = await getLifeAreas();
    if (existingAreas.isNotEmpty) return;

    if (user == null) {
      // Anonymous user - save to local storage
      await _createDefaultLifeAreasAnonymous();
      return;
    }

    final defaultAreas = [
      {
        'name': 'Fitness',
        'category': 'Health',
        'color': '#FF5722',
        'icon': 'fitness_center',
        'order_index': 0,
      },
      {
        'name': 'Nutrition',
        'category': 'Health',
        'color': '#4CAF50',
        'icon': 'restaurant',
        'order_index': 1,
      },
      {
        'name': 'Learning',
        'category': 'Development',
        'color': '#2196F3',
        'icon': 'school',
        'order_index': 2,
      },
      {
        'name': 'Finance',
        'category': 'Finance',
        'color': '#FFC107',
        'icon': 'account_balance',
        'order_index': 3,
      },
      {
        'name': 'Art',
        'category': 'Creativity',
        'color': '#9C27B0',
        'icon': 'palette',
        'order_index': 4,
      },
      {
        'name': 'Relationships',
        'category': 'Social',
        'color': '#E91E63',
        'icon': 'people',
        'order_index': 5,
      },
      {
        'name': 'Spirituality',
        'category': 'Inner',
        'color': '#607D8B',
        'icon': 'self_improvement',
        'order_index': 6,
      },
      {
        'name': 'Career',
        'category': 'Work',
        'color': '#795548',
        'icon': 'work',
        'order_index': 7,
      },
    ];

    // Bulk-Insert statt sequenziell, um race conditions zu vermeiden
    final rows = defaultAreas.map((area) => {
          'user_id': user.id,
          'name': area['name'],
          'category': area['category'],
          'parent_id': null,
          'color': area['color'],
          'icon': area['icon'],
          'order_index': area['order_index'],
        }).toList();

    await _client.from('life_areas').insert(rows);
  }

  /// Ensure default life areas exist for anonymous users
  static Future<void> ensureDefaultLifeAreasForAnonymous() async {
    final user = _client.auth.currentUser;
    if (user != null) return; // Not for authenticated users

    final existingAreas = await _getLifeAreasAnonymous();
    if (existingAreas.isNotEmpty) return; // Already exist

    await _createDefaultLifeAreasAnonymous();
  }

  /// Create default life areas for anonymous users in local storage
  static Future<void> _createDefaultLifeAreasAnonymous() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await AnonymousUserService.getOrCreateAnonymousUserId();
      final key = 'life_areas_$userId';
      
      final defaultAreas = [
        {
          'name': 'Fitness',
          'category': 'Health',
          'color': '#FF5722',
          'icon': 'fitness_center',
          'order_index': 0,
        },
        {
          'name': 'Nutrition',
          'category': 'Health',
          'color': '#4CAF50',
          'icon': 'restaurant',
          'order_index': 1,
        },
        {
          'name': 'Learning',
          'category': 'Development',
          'color': '#2196F3',
          'icon': 'school',
          'order_index': 2,
        },
        {
          'name': 'Finance',
          'category': 'Finance',
          'color': '#FFC107',
          'icon': 'account_balance',
          'order_index': 3,
        },
        {
          'name': 'Art',
          'category': 'Creativity',
          'color': '#9C27B0',
          'icon': 'palette',
          'order_index': 4,
        },
        {
          'name': 'Relationships',
          'category': 'Social',
          'color': '#E91E63',
          'icon': 'people',
          'order_index': 5,
        },
        {
          'name': 'Spirituality',
          'category': 'Inner',
          'color': '#607D8B',
          'icon': 'self_improvement',
          'order_index': 6,
        },
        {
          'name': 'Career',
          'category': 'Work',
          'color': '#795548',
          'icon': 'work',
          'order_index': 7,
        },
      ];

      // Convert to LifeArea objects for consistent structure
      final lifeAreas = defaultAreas.map((area) {
        final now = DateTime.now();
        return LifeArea(
          id: 'anonymous_${area['name']?.toString().toLowerCase()}_$userId',
          userId: userId,
          name: area['name'] as String,
          category: area['category'] as String,
          color: area['color'] as String,
          icon: area['icon'] as String,
          orderIndex: area['order_index'] as int,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();

      // Save to local storage
      final jsonString = jsonEncode(lifeAreas.map((area) => area.toJson()).toList());
      await prefs.setString(key, jsonString);
      
    } catch (e) {
      // Fail silently for now, will be retried next time
    }
  }
} 