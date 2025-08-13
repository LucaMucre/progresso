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
  static final List<VoidCallback> _onDialogsClosed = <VoidCallback>[];

  // Expose minimal read-only flags for UI guards
  static bool get isShowingDialogs => _isShowing;
  static bool get isLevelUpPending => _levelUpPending;

  static void setOnLevelUp(void Function(int level) listener) {
    _levelUpNotifier.addListener(() {
      final lvl = _levelUpNotifier.value;
      if (lvl != null) listener(lvl);
    });
    // If a level-up already occurred before this listener was registered,
    // trigger it immediately so the dialog is not missed.
    final pending = _levelUpNotifier.value;
    if (_levelUpPending && pending != null) {
      listener(pending);
    }
  }

  static void notifyLevelUp(int level) {
    print('DEBUG LevelUpService: notifyLevelUp($level) called');
    // Mark that a level-up is coming so achievements won't show prematurely
    _levelUpPending = true;
    _levelUpNotifier.value = level;
    // When a level-up is announced, prevent any already scheduled achievement dialogs
    // from showing before the level-up.
    // (They will be shown by showLevelThenPending after level-up finishes.)
    _pendingDirty = true;
    print('DEBUG LevelUpService: _levelUpPending=$_levelUpPending, achievements queued=${_pendingAchievements.length}');
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
    _emitDialogsClosed();
  }

  /// Queue an achievement to be shown later (after any level-up)
  static void queueAchievement(Achievement achievement) {
    print('DEBUG queueAchievement: Adding ${achievement.title}, _levelUpPending=$_levelUpPending');
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
    // Defer to next frame to avoid Navigator lock if called during a route pop
    await Future<void>.delayed(Duration.zero);
    await showInOrder(context: context, level: level, achievements: toShow);
  }

  /// If there is no level-up pending, show any queued achievements now.
  /// If there IS a level-up pending, trigger it so it shows level-up + achievements together.
  static Future<void> showPendingAchievements({
    required BuildContext context,
  }) async {
    print('DEBUG showPendingAchievements: _isShowing=$_isShowing, _levelUpPending=$_levelUpPending, achievements=${_pendingAchievements.length}');
    if (_isShowing) return;
    
    // If level-up is pending, trigger it now so level-up + achievements show in order
    if (_levelUpPending && _levelUpNotifier.value != null) {
      print('DEBUG showPendingAchievements: Level-up pending, calling showLevelThenPending');
      await showLevelThenPending(context: context, level: _levelUpNotifier.value!);
      return;
    }
    
    // Otherwise, just show achievements
    if (_pendingAchievements.isEmpty) return;

    print('DEBUG showPendingAchievements: Showing ${_pendingAchievements.length} achievements only');
    _isShowing = true;
    final toShow = List<Achievement>.from(_pendingAchievements);
    _pendingAchievements.clear();
    _pendingDirty = false;
    for (final a in toShow) {
      print('DEBUG showPendingAchievements: Showing achievement ${a.title}');
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
    _emitDialogsClosed();
  }

  /// Exposed for screens to know if something is awaiting display.
  static bool get hasPendingAchievements => _pendingAchievements.isNotEmpty || _pendingDirty;

  static void addOnDialogsClosed(VoidCallback cb) {
    _onDialogsClosed.add(cb);
  }

  static void removeOnDialogsClosed(VoidCallback cb) {
    _onDialogsClosed.remove(cb);
  }

  static void _emitDialogsClosed() {
    for (final cb in List<VoidCallback>.from(_onDialogsClosed)) {
      try { cb(); } catch (_) {}
    }
  }
}

