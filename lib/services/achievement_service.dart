import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int target;
  final AchievementType type;
  
  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.target,
    required this.type,
  });
}

enum AchievementType {
  streak,
  totalActions,
  totalXP,
  lifeAreas,
  singleSession,
  level,
  weekly,
  special
}

class AchievementService {
  static final _supabase = Supabase.instance.client;
  static Set<String> _unlockedAchievements = {};
  static Function(Achievement)? _onAchievementUnlocked;
  
  static void setOnAchievementUnlocked(Function(Achievement) callback) {
    _onAchievementUnlocked = callback;
  }
  
  static final List<Achievement> _allAchievements = [
    // Erste Schritte
    Achievement(
      id: 'first_steps',
      title: 'First steps',
      description: 'Create your first life area',
      icon: Icons.add_circle,
      color: Colors.blue,
      target: 1,
      type: AchievementType.lifeAreas,
    ),
    
    // Streak Achievements
    Achievement(
      id: 'streak_3',
      title: 'Starter',
      description: 'Active 3 days in a row',
      icon: Icons.local_fire_department,
      color: Colors.orange.shade300,
      target: 3,
      type: AchievementType.streak,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Consistent',
      description: 'Active 7 days in a row',
      icon: Icons.local_fire_department,
      color: Colors.orange,
      target: 7,
      type: AchievementType.streak,
    ),
    Achievement(
      id: 'streak_30',
      title: 'Expert',
      description: 'Active 30 days in a row',
      icon: Icons.emoji_events,
      color: Colors.amber,
      target: 30,
      type: AchievementType.streak,
    ),
    Achievement(
      id: 'streak_100',
      title: 'Legend',
      description: 'Active 100 days in a row',
      icon: Icons.stars,
      color: Colors.purple,
      target: 100,
      type: AchievementType.streak,
    ),
    
    // Action Achievements
    Achievement(
      id: 'actions_10',
      title: 'Active',
      description: '10 activities completed',
      icon: Icons.check_circle,
      color: Colors.green.shade300,
      target: 10,
      type: AchievementType.totalActions,
    ),
    Achievement(
      id: 'actions_50',
      title: 'Diligent',
      description: '50 activities completed',
      icon: Icons.check_circle,
      color: Colors.green,
      target: 50,
      type: AchievementType.totalActions,
    ),
    Achievement(
      id: 'actions_100',
      title: 'Productive',
      description: '100 activities completed',
      icon: Icons.verified,
      color: Colors.green.shade700,
      target: 100,
      type: AchievementType.totalActions,
    ),
    Achievement(
      id: 'actions_500',
      title: 'Workaholic',
      description: '500 activities completed',
      icon: Icons.workspace_premium,
      color: Colors.indigo,
      target: 500,
      type: AchievementType.totalActions,
    ),
    
    // XP Achievements
    Achievement(
      id: 'xp_100',
      title: 'Collector',
      description: '100 XP collected',
      icon: Icons.star,
      color: Colors.yellow.shade600,
      target: 100,
      type: AchievementType.totalXP,
    ),
    Achievement(
      id: 'xp_500',
      title: 'Experienced',
      description: '500 XP collected',
      icon: Icons.star,
      color: Colors.yellow.shade700,
      target: 500,
      type: AchievementType.totalXP,
    ),
    Achievement(
      id: 'xp_1000',
      title: 'Master',
      description: '1000 XP collected',
      icon: Icons.auto_awesome,
      color: Colors.orange.shade600,
      target: 1000,
      type: AchievementType.totalXP,
    ),
    Achievement(
      id: 'xp_5000',
      title: 'Grandmaster',
      description: '5000 XP collected',
      icon: Icons.diamond,
      color: Colors.purple.shade600,
      target: 5000,
      type: AchievementType.totalXP,
    ),
    
    // Level Achievements
    Achievement(
      id: 'level_5',
      title: 'Climber',
      description: 'Reach level 5',
      icon: Icons.trending_up,
      color: Colors.cyan,
      target: 5,
      type: AchievementType.level,
    ),
    Achievement(
      id: 'level_10',
      title: 'Advanced',
      description: 'Reach level 10',
      icon: Icons.trending_up,
      color: Colors.cyan.shade700,
      target: 10,
      type: AchievementType.level,
    ),
    Achievement(
      id: 'level_25',
      title: 'Elite',
      description: 'Reach level 25',
      icon: Icons.military_tech,
      color: Colors.deepPurple,
      target: 25,
      type: AchievementType.level,
    ),
    
    // Life Area Achievements
    Achievement(
      id: 'areas_3',
      title: 'Organized',
      description: '3 different life areas',
      icon: Icons.category,
      color: Colors.teal.shade300,
      target: 3,
      type: AchievementType.lifeAreas,
    ),
    Achievement(
      id: 'areas_5',
      title: 'Versatile',
      description: '5 different life areas',
      icon: Icons.category,
      color: Colors.teal,
      target: 5,
      type: AchievementType.lifeAreas,
    ),
    Achievement(
      id: 'areas_8',
      title: 'Balanced',
      description: '8 different life areas',
      icon: Icons.balance,
      color: Colors.teal.shade700,
      target: 8,
      type: AchievementType.lifeAreas,
    ),
    
    // Session Achievements
    Achievement(
      id: 'session_5',
      title: 'Focused',
      description: '5 activities in one day',
      icon: Icons.flash_on,
      color: Colors.lightBlue,
      target: 5,
      type: AchievementType.singleSession,
    ),
    Achievement(
      id: 'session_10',
      title: 'Poweruser',
      description: '10 activities in one day',
      icon: Icons.bolt,
      color: Colors.blue.shade700,
      target: 10,
      type: AchievementType.singleSession,
    ),
    
    // Special Achievements
    Achievement(
      id: 'early_bird',
      title: 'Early bird',
      description: 'Activity before 8am',
      icon: Icons.wb_sunny,
      color: Colors.orange.shade400,
      target: 1,
      type: AchievementType.special,
    ),
    Achievement(
      id: 'night_owl',
      title: 'Night owl',
      description: 'Activity after 10pm',
      icon: Icons.nights_stay,
      color: Colors.indigo.shade400,
      target: 1,
      type: AchievementType.special,
    ),
    Achievement(
      id: 'weekend_warrior',
      title: 'Weekend warrior',
      description: 'Activity on the weekend',
      icon: Icons.weekend,
      color: Colors.deepOrange,
      target: 1,
      type: AchievementType.special,
    ),
  ];
  
  static List<Achievement> get allAchievements => _allAchievements;
  
  static String _prefsKeyForUser() {
    final uid = _supabase.auth.currentUser?.id;
    return uid != null ? 'unlocked_achievements_$uid' : 'unlocked_achievements';
  }

  static Future<void> loadUnlockedAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Migrate from legacy global key if present and user-specific key missing
      final userKey = _prefsKeyForUser();
      String? unlockedJson = prefs.getString(userKey);
      if (unlockedJson == null) {
        final legacy = prefs.getString('unlocked_achievements');
        if (legacy != null) {
          unlockedJson = legacy;
          await prefs.setString(userKey, legacy);
          await prefs.remove('unlocked_achievements');
        }
      }
      if (unlockedJson != null) {
        final List<dynamic> unlocked = jsonDecode(unlockedJson);
        _unlockedAchievements = unlocked.cast<String>().toSet();
      }
    } catch (e) {
      print('Error loading achievements: $e');
    }
  }
  
  static Future<void> _saveUnlockedAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyForUser(), jsonEncode(_unlockedAchievements.toList()));
    } catch (e) {
      print('Error saving achievements: $e');
    }
  }
  
  static bool isUnlocked(String achievementId) {
    return _unlockedAchievements.contains(achievementId);
  }
  
  static Future<void> checkAndUnlockAchievements({
    required int currentStreak,
    required int totalActions,
    required int totalXP,
    required int level,
    required int lifeAreaCount,
    int? dailyActions,
    DateTime? lastActionTime,
  }) async {
    final newlyUnlocked = <Achievement>[];
    
    for (final achievement in _allAchievements) {
      if (_unlockedAchievements.contains(achievement.id)) continue;
      
      bool shouldUnlock = false;
      
      switch (achievement.type) {
        case AchievementType.streak:
          shouldUnlock = currentStreak >= achievement.target;
          break;
        case AchievementType.totalActions:
          shouldUnlock = totalActions >= achievement.target;
          break;
        case AchievementType.totalXP:
          shouldUnlock = totalXP >= achievement.target;
          break;
        case AchievementType.level:
          shouldUnlock = level >= achievement.target;
          break;
        case AchievementType.lifeAreas:
          // Erwartung: lifeAreaCount ist die Anzahl von Bereichen, in denen bereits mindestens
          // eine Aktivität erstellt wurde (Standardbereiche zählen erst dann).
          shouldUnlock = lifeAreaCount >= achievement.target;
          break;
        case AchievementType.singleSession:
          shouldUnlock = (dailyActions ?? 0) >= achievement.target;
          break;
        case AchievementType.special:
          shouldUnlock = _checkSpecialAchievement(achievement, lastActionTime);
          break;
        case AchievementType.weekly:
          // TODO: Implement weekly achievements
          break;
      }
      
      if (shouldUnlock) {
        _unlockedAchievements.add(achievement.id);
        newlyUnlocked.add(achievement);
        
        // Trigger animation callback
        _onAchievementUnlocked?.call(achievement);
      }
    }
    
    if (newlyUnlocked.isNotEmpty) {
      await _saveUnlockedAchievements();
    }
  }
  
  static bool _checkSpecialAchievement(Achievement achievement, DateTime? actionTime) {
    if (actionTime == null) return false;
    
    switch (achievement.id) {
      case 'early_bird':
        return actionTime.hour < 8;
      case 'night_owl':
        return actionTime.hour >= 22;
      case 'weekend_warrior':
        // Wochenende nur bei lokaler Zeit auswerten
        final local = actionTime.toLocal();
        return local.weekday == DateTime.saturday || local.weekday == DateTime.sunday;
      default:
        return false;
    }
  }
  
  static List<Achievement> getUnlockedAchievements() {
    return _allAchievements.where((a) => _unlockedAchievements.contains(a.id)).toList();
  }
  
  static List<Achievement> getLockedAchievements() {
    return _allAchievements.where((a) => !_unlockedAchievements.contains(a.id)).toList();
  }
  
  static double getProgressPercentage() {
    return _unlockedAchievements.length / _allAchievements.length;
  }
  
  static int getUnlockedCount() {
    return _unlockedAchievements.length;
  }
  
  static int getTotalCount() {
    return _allAchievements.length;
  }
}