import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Alle Life Areas für einen User abrufen
  static Future<List<LifeArea>> getLifeAreas() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User nicht angemeldet');

    final response = await _client
        .from('life_areas')
        .select()
        .eq('user_id', user.id)
        .order('order_index');

    return (response as List).map((json) => LifeArea.fromJson(json)).toList();
  }

  // Alle Life Areas (auch unsichtbare) für einen User abrufen
  static Future<List<LifeArea>> getAllLifeAreas() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User nicht angemeldet');

    final response = await _client
        .from('life_areas')
        .select()
        .eq('user_id', user.id)
        .order('order_index');

    return (response as List).map((json) => LifeArea.fromJson(json)).toList();
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
    throw Exception('Sichtbarkeit-Umschaltung ist temporär deaktiviert. Bitte wenden Sie die Datenbank-Migration an.');
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
    if (user == null) throw Exception('User nicht angemeldet');

    // Prüfen ob bereits Life Areas existieren
    final existingAreas = await getLifeAreas();
    if (existingAreas.isNotEmpty) return;

    final defaultAreas = [
      {
        'name': 'Fitness',
        'category': 'Gesundheit',
        'color': '#FF5722',
        'icon': 'fitness_center',
        'order_index': 0,
      },
      {
        'name': 'Ernährung',
        'category': 'Gesundheit',
        'color': '#4CAF50',
        'icon': 'restaurant',
        'order_index': 1,
      },
      {
        'name': 'Bildung',
        'category': 'Entwicklung',
        'color': '#2196F3',
        'icon': 'school',
        'order_index': 2,
      },
      {
        'name': 'Finanzen',
        'category': 'Wirtschaft',
        'color': '#FFC107',
        'icon': 'account_balance',
        'order_index': 3,
      },
      {
        'name': 'Kunst',
        'category': 'Kreativität',
        'color': '#9C27B0',
        'icon': 'palette',
        'order_index': 4,
      },
      {
        'name': 'Beziehungen',
        'category': 'Sozial',
        'color': '#E91E63',
        'icon': 'people',
        'order_index': 5,
      },
      {
        'name': 'Spiritualität',
        'category': 'Inneres',
        'color': '#607D8B',
        'icon': 'self_improvement',
        'order_index': 6,
      },
      {
        'name': 'Karriere',
        'category': 'Beruf',
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
} 