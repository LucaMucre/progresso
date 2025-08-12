import 'package:flutter/material.dart';
import 'achievement_service.dart';
import '../widgets/achievement_unlock_widget.dart';
import '../widgets/level_up_dialog.dart';

/// Simple global notifier to broadcast level-up events across the app
class LevelUpService {
  static final ValueNotifier<int?> _levelUpNotifier = ValueNotifier<int?>(null);
  static bool _isShowing = false;

  static void setOnLevelUp(void Function(int level) listener) {
    _levelUpNotifier.addListener(() {
      final lvl = _levelUpNotifier.value;
      if (lvl != null) listener(lvl);
    });
  }

  static void notifyLevelUp(int level) {
    _levelUpNotifier.value = level;
  }

  /// Utility to show dialogs in order: first LevelUp, then Achievement(s)
  static Future<void> showInOrder({
    required BuildContext context,
    required int level,
    List<Achievement>? achievements,
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    // Show level-up first
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => LevelUpDialog(level: level),
    );
    // Then show achievements sequentially
    if (achievements != null) {
      for (final a in achievements) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => AchievementUnlockWidget(achievement: a),
        );
      }
    }
    _isShowing = false;
  }
}

