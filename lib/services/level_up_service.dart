import 'package:flutter/material.dart';

/// Simple global notifier to broadcast level-up events across the app
class LevelUpService {
  static final ValueNotifier<int?> _levelUpNotifier = ValueNotifier<int?>(null);

  static void setOnLevelUp(void Function(int level) listener) {
    _levelUpNotifier.addListener(() {
      final lvl = _levelUpNotifier.value;
      if (lvl != null) listener(lvl);
    });
  }

  static void notifyLevelUp(int level) {
    _levelUpNotifier.value = level;
  }
}

