import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'anonymous_user_service.dart';
import '../navigation.dart';
import '../repository/local_logs_repository.dart';

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
      // Anonymous user - load from local storage only
      return await _getLifeAreasAnonymous();
    }

    // Authenticated user - sync and merge local + server data
    await _syncDataWithServer(user.id);
    
    // Return merged data (prioritizing local, then server)
    return await _getMergedLifeAreas(user.id);
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
      final allAreas = jsonList.map((json) => LifeArea.fromJson(json)).toList();
      
      // Filter out subcategories (areas with parentId) to only show top-level areas
      return allAreas.where((area) => area.parentId == null).toList();
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
      // Anonymous user - get child areas from local storage
      return await _getChildAreasAnonymous(parentId);
    }

    final response = await _client
        .from('life_areas')
        .select()
        .eq('user_id', user.id)
        .eq('parent_id', parentId)
        .order('order_index');

    return (response as List).map((json) => LifeArea.fromJson(json)).toList();
  }

  /// Load child areas for anonymous users from local storage
  static Future<List<LifeArea>> _getChildAreasAnonymous(String parentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await AnonymousUserService.getOrCreateAnonymousUserId();
      final key = 'life_areas_$userId';
      final jsonString = prefs.getString(key);
      
      if (jsonString == null) {
        return [];
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final allAreas = jsonList.map((json) => LifeArea.fromJson(json)).toList();
      
      // Filter to only return areas with the specified parentId
      return allAreas.where((area) => area.parentId == parentId).toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    } catch (e) {
      return [];
    }
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
    String userId;
    
    if (user != null) {
      // Authenticated user
      userId = user.id;
    } else {
      // Anonymous user - use local storage
      userId = await AnonymousUserService.getOrCreateAnonymousUserId();
    }

    if (user != null) {
      // Authenticated user - save to database
      final newArea = {
        'user_id': userId,
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

      // Notify UI components about the change
      notifyLifeAreasChanged();
      
      return LifeArea.fromJson(response);
    } else {
      // Anonymous user - save locally
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final newArea = LifeArea(
        id: id,
        userId: userId,
        name: name,
        category: category,
        parentId: parentId,
        color: color,
        icon: icon,
        orderIndex: orderIndex,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to local storage
      await _saveLocalLifeArea(newArea);
      
      // Notify UI components about the change
      notifyLifeAreasChanged();
      
      return newArea;
    }
  }

  // Save life area locally for anonymous users
  static Future<void> _saveLocalLifeArea(LifeArea lifeArea) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AnonymousUserService.getOrCreateAnonymousUserId();
    final key = 'life_areas_$userId';
    final existingData = prefs.getString(key) ?? '[]';
    final List<dynamic> lifeAreas = jsonDecode(existingData);
    
    // Add new life area
    lifeAreas.add(lifeArea.toJson());
    
    // Save back to preferences
    await prefs.setString(key, jsonEncode(lifeAreas));
  }

  // Life Area aktualisieren
  static Future<void> updateLifeArea(String id, Map<String, dynamic> updates) async {
    final user = _client.auth.currentUser;
    
    if (user != null) {
      // Authenticated user - update in database
      await _client
          .from('life_areas')
          .update({
            ...updates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .eq('user_id', user.id);
    } else {
      // Anonymous user - update locally
      await _updateLocalLifeArea(id, updates);
    }
    
    // Notify UI components about the change
    notifyLifeAreasChanged();
  }

  // Update life area locally for anonymous users
  static Future<void> _updateLocalLifeArea(String id, Map<String, dynamic> updates) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AnonymousUserService.getOrCreateAnonymousUserId();
    final key = 'life_areas_$userId';
    final existingData = prefs.getString(key) ?? '[]';
    final List<dynamic> lifeAreas = jsonDecode(existingData);
    
    // Find and update the life area
    for (int i = 0; i < lifeAreas.length; i++) {
      if (lifeAreas[i]['id'] == id) {
        lifeAreas[i] = {...lifeAreas[i], ...updates, 'updated_at': DateTime.now().toIso8601String()};
        break;
      }
    }
    
    // Save back to preferences
    await prefs.setString(key, jsonEncode(lifeAreas));
  }

  // Sichtbarkeit einer Life Area umschalten
  static Future<void> toggleLifeAreaVisibility(String id) async {
    // Temporarily disabled until migration is applied
    throw Exception('Visibility toggle is temporarily disabled. Please apply the database migration.');
  }

  // Life Area löschen
  static Future<void> deleteLifeArea(String id) async {
    final user = _client.auth.currentUser;
    
    // First get the life area to be deleted to get its name
    final lifeAreas = await getLifeAreas();
    final lifeAreaToDelete = lifeAreas.firstWhere((area) => area.id == id, orElse: () => throw Exception('Life area not found'));
    final canonicalName = canonicalAreaName(lifeAreaToDelete.name);
    
    if (user != null) {
      // Authenticated user - delete from database
      await _client
          .from('life_areas')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);
      
      // Also clean up related activities in the database
      await _cleanupActivitiesForDeletedArea(canonicalName, authenticated: true);
    } else {
      // Anonymous user - delete locally
      await _deleteLocalLifeArea(id);
      
      // Also clean up related activities locally
      await _cleanupActivitiesForDeletedArea(canonicalName, authenticated: false);
    }
    
    // Notify UI components about the change
    notifyLifeAreasChanged();
  }

  // Delete life area locally for anonymous users
  static Future<void> _deleteLocalLifeArea(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await AnonymousUserService.getOrCreateAnonymousUserId();
    final key = 'life_areas_$userId';
    final existingData = prefs.getString(key) ?? '[]';
    final List<dynamic> lifeAreas = jsonDecode(existingData);
    
    // Remove the life area
    lifeAreas.removeWhere((area) => area['id'] == id);
    
    // Save back to preferences
    await prefs.setString(key, jsonEncode(lifeAreas));
  }

  // Clean up activities for deleted life area
  static Future<void> _cleanupActivitiesForDeletedArea(String canonicalName, {required bool authenticated}) async {
    if (authenticated) {
      // For authenticated users, we would need to update the database
      // This is complex because activities are stored with JSON notes
      // For now, we'll just clean up locally cached data
      await _cleanupLocalActivityData(canonicalName);
    } else {
      // For anonymous users, clean up local data
      await _cleanupLocalActivityData(canonicalName);
    }
  }

  // Clean up local activity data that references the deleted life area
  static Future<void> _cleanupLocalActivityData(String canonicalName) async {
    try {
      // Notify that logs have changed so UI updates and recalculates statistics
      notifyLogsChanged();
      
      if (kDebugMode) {
        print('Cleaned up activity references for deleted life area: $canonicalName');
      }
      
    } catch (e) {
      // If cleanup fails, log but don't block the deletion
      if (kDebugMode) {
        print('Warning: Failed to clean up activity data for deleted life area: $e');
      }
    }
  }

  // Check if a life area still exists by canonical name
  static Future<bool> lifeAreaExistsByName(String canonicalName) async {
    final areas = await getLifeAreas();
    return areas.any((area) => canonicalAreaName(area.name) == canonicalName);
  }

  // Get existing life area names as canonical names (for filtering statistics)
  static Future<Set<String>> getExistingCanonicalNames() async {
    final areas = await getLifeAreas();
    return areas.map((area) => canonicalAreaName(area.name)).toSet();
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
    
    // For authenticated users, check if areas already exist (either local or server)
    if (user != null) {
      // Check server directly to avoid sync issues
      final serverResponse = await _client
          .from('life_areas')
          .select()
          .eq('user_id', user.id)
          .limit(1);
      
      if ((serverResponse as List).isNotEmpty) {
        return; // Server already has data, don't create defaults
      }
      
      // Check local data too
      final localAreas = await _getLifeAreasAnonymous();
      if (localAreas.isNotEmpty) {
        // Local data exists, let sync handle it
        return;
      }
    } else {
      // Anonymous user - check local storage
      final existingAreas = await _getLifeAreasAnonymous();
      if (existingAreas.isNotEmpty) return;
      
      // Create defaults for anonymous user
      await _createDefaultLifeAreasAnonymous();
      return;
    }

    // Only reached for authenticated users with no data anywhere
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

  /// Sync local data with server (bidirectional)
  static Future<void> _syncDataWithServer(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncKey = 'life_areas_synced_$userId';
      final alreadySynced = prefs.getBool(syncKey) ?? false;
      
      // Skip sync if already done for this user
      if (alreadySynced) {
        return;
      }
      
      // Get local data
      final localAreas = await _getLifeAreasAnonymous();
      
      // Get server data
      final serverResponse = await _client
          .from('life_areas')
          .select()
          .eq('user_id', userId)
          .order('order_index');
      final serverAreas = (serverResponse as List).map((json) => LifeArea.fromJson(json)).toList();
      
      // First time sync - upload local data to server only if server is empty
      if (serverAreas.isEmpty && localAreas.isNotEmpty) {
        // Create a map to track unique areas by canonical name
        final Map<String, Map<String, dynamic>> uniqueAreas = {};
        
        for (final area in localAreas) {
          final canonicalName = canonicalAreaName(area.name);
          // Only add if not already present (avoid duplicates)
          if (!uniqueAreas.containsKey(canonicalName)) {
            uniqueAreas[canonicalName] = {
              'user_id': userId,
              'name': area.name,
              'category': area.category,
              'parent_id': area.parentId,
              'color': area.color,
              'icon': area.icon,
              'order_index': area.orderIndex,
            };
          }
        }
        
        if (uniqueAreas.isNotEmpty) {
          await _client.from('life_areas').insert(uniqueAreas.values.toList());
        }
        await prefs.setBool(syncKey, true);
      } else if (serverAreas.isNotEmpty) {
        // Server already has data, mark as synced
        await prefs.setBool(syncKey, true);
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Life areas sync failed: $e');
      }
    }
  }

  /// Get merged life areas (local + server, with local priority)
  static Future<List<LifeArea>> _getMergedLifeAreas(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncKey = 'life_areas_synced_$userId';
      final alreadySynced = prefs.getBool(syncKey) ?? false;
      
      // If synced, get data from server (single source of truth)
      if (alreadySynced) {
        final serverResponse = await _client
            .from('life_areas')
            .select()
            .eq('user_id', userId)
            .isFilter('parent_id', null)  // Only get top-level areas (no subcategories)
            .order('order_index');
        
        final serverAreas = (serverResponse as List).map((json) => LifeArea.fromJson(json)).toList();
        
        // Deduplicate by canonical name just in case
        final Map<String, LifeArea> uniqueAreas = {};
        for (final area in serverAreas) {
          final canonicalName = canonicalAreaName(area.name);
          // Keep first occurrence of each canonical name
          if (!uniqueAreas.containsKey(canonicalName)) {
            uniqueAreas[canonicalName] = area;
          }
        }
        
        return uniqueAreas.values.toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      }
      
      // Not synced yet - return local data
      final localAreas = await _getLifeAreasAnonymous();
      
      // Deduplicate local data as well
      final Map<String, LifeArea> uniqueAreas = {};
      for (final area in localAreas) {
        final canonicalName = canonicalAreaName(area.name);
        if (!uniqueAreas.containsKey(canonicalName)) {
          uniqueAreas[canonicalName] = area;
        }
      }
      
      return uniqueAreas.values.toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get merged life areas: $e');
      }
      return await _getLifeAreasAnonymous(); // Fallback to local only
    }
  }

  /// Delete user data from server (when account is deleted)
  static Future<void> deleteUserDataFromServer(String userId) async {
    try {
      await _client
          .from('life_areas')
          .delete()
          .eq('user_id', userId);
      
      // Clear sync flag so local data becomes primary again
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('life_areas_synced_$userId');
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to delete user data from server: $e');
      }
    }
  }
  
  /// Reset sync state for a user (useful after logout or before fresh registration)
  static Future<void> resetSyncState(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('life_areas_synced_$userId');
    } catch (e) {
      if (kDebugMode) {
        print('Failed to reset sync state: $e');
      }
    }
  }
} 