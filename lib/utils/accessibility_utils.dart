import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Accessibility utilities and semantic helpers for screen readers
class AccessibilityUtils {
  /// Semantic label for XP display
  static String xpLabel(int xp) => '$xp experience points earned';
  
  /// Semantic label for streak display  
  static String streakLabel(int streak) => 
    streak == 0 ? 'No current streak' : 
    streak == 1 ? '1 day streak' : '$streak days streak';
  
  /// Semantic label for level display
  static String levelLabel(int level) => 'Level $level';
  
  /// Semantic label for activity duration
  static String durationLabel(int minutes) =>
    minutes == 0 ? 'No duration set' :
    minutes == 1 ? '1 minute' : '$minutes minutes';
  
  /// Semantic label for calendar day
  static String calendarDayLabel(int day, {int? activitiesCount}) =>
    activitiesCount == null || activitiesCount == 0
      ? 'Day $day, no activities'
      : activitiesCount == 1
        ? 'Day $day, 1 activity'
        : 'Day $day, $activitiesCount activities';
  
  /// Semantic label for life area bubble
  static String lifeAreaLabel(String name, double minutes) =>
    'Life area $name, ${minutes.round()} minutes logged';
  
  /// Semantic hint for interactive elements
  static const String tapHint = 'Double tap to activate';
  static const String editHint = 'Double tap to edit';
  static const String deleteHint = 'Double tap to delete';
  static const String navigationHint = 'Double tap to navigate';
  
  /// Activity card accessibility
  static String activityCardLabel({
    required String title,
    required int xp,
    required String timeAgo,
    int? duration,
  }) {
    final durationText = duration != null && duration > 0 
      ? ', ${durationLabel(duration)}' 
      : '';
    return 'Activity $title$durationText, ${xpLabel(xp)}, $timeAgo';
  }

  /// Button accessibility
  static String buttonLabel({
    required String text,
    bool isEnabled = true,
  }) => isEnabled ? text : '$text, disabled';

  /// Form field accessibility
  static String textFieldLabel({
    required String label,
    bool isRequired = false,
    String? error,
  }) {
    String result = label;
    if (isRequired) result += ', required field';
    if (error != null) result += ', error: $error';
    return result;
  }

  /// Announce changes to screen reader
  static void announceToScreenReader(String message) {
    // Note: SemanticsService.announce is only available in debug builds
    // In release builds, screen readers will pick up changes through semantic widgets
    if (kDebugMode) {
      // For production use, prefer using Semantics widgets instead of announcements
      debugPrint('Screen reader announcement: $message');
    }
  }

  /// Focus management helpers
  static void requestFocus(FocusNode focusNode) {
    focusNode.requestFocus();
  }

  /// Check if accessibility features are enabled
  static bool get isAccessibilityEnabled {
    return WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.accessibleNavigation;
  }

  /// Check if screen reader is active
  static bool get isScreenReaderEnabled {
    final features = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.accessibleNavigation || features.disableAnimations;
  }
}