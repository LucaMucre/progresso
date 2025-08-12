import 'package:flutter/material.dart';
import 'achievement_service.dart';
import '../widgets/achievement_unlock_widget.dart';
import '../widgets/level_up_dialog.dart';

/// Simple global notifier to broadcast level-up events across the app
class LevelUpService {
  static final ValueNotifier<int?> _levelUpNotifier = ValueNotifier<int?>(null);
  static bool _isShowing = false;
  static bool _levelUpPending = false;
  static final List<Achievement> _pendingAchievements = <Achievement>[];
  static bool _pendingDirty = false;

  static void setOnLevelUp(void Function(int level) listener) {
    _levelUpNotifier.addListener(() {
      final lvl = _levelUpNotifier.value;
      if (lvl != null) listener(lvl);
    });
  }

  static void notifyLevelUp(int level) {
    // Mark that a level-up is coming so achievements won't show prematurely
    _levelUpPending = true;
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
          builder: (_) => AchievementUnlockWidget(
            achievement: a,
            onDismissed: () => Navigator.of(context).pop(),
          ),
        );
      }
    }
    _isShowing = false;
  }

  /// Queue an achievement to be shown later (after any level-up)
  static void queueAchievement(Achievement achievement) {
    _pendingAchievements.add(achievement);
    _pendingDirty = true;
  }

  /// Helper used by listeners of level-up events to ensure the level-up dialog is
  /// shown first, followed by any queued achievements.
  static Future<void> showLevelThenPending({
    required BuildContext context,
    required int level,
  }) async {
    // Capture and clear pending achievements at the moment we begin showing
    final toShow = List<Achievement>.from(_pendingAchievements);
    _pendingAchievements.clear();
    _levelUpPending = false; // we are processing it now
    await showInOrder(context: context, level: level, achievements: toShow);
  }

  /// If there is no level-up pending, show any queued achievements now.
  static Future<void> showPendingAchievements({
    required BuildContext context,
  }) async {
    if (_isShowing) return;
    if (_levelUpPending) return; // a level-up will handle showing them
    if (_pendingAchievements.isEmpty) return;

    _isShowing = true;
    final toShow = List<Achievement>.from(_pendingAchievements);
    _pendingAchievements.clear();
    for (final a in toShow) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => AchievementUnlockWidget(
          achievement: a,
          onDismissed: () => Navigator.of(context).pop(),
        ),
      );
    }
    _isShowing = false;
  }

  /// Exposed for screens to know if something is awaiting display.
  static bool get hasPendingAchievements => _pendingAchievements.isNotEmpty || _pendingDirty;
}

