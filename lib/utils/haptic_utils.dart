import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Haptic feedback utilities for better user experience
class HapticUtils {
  /// Light impact feedback for buttons and selections
  static void lightImpact() {
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }
  }

  /// Medium impact feedback for important actions
  static void mediumImpact() {
    if (!kIsWeb) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Heavy impact feedback for critical actions
  static void heavyImpact() {
    if (!kIsWeb) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Selection feedback for toggles and sliders
  static void selectionClick() {
    if (!kIsWeb) {
      HapticFeedback.selectionClick();
    }
  }

  /// Success feedback pattern
  static void success() {
    if (!kIsWeb) {
      // Double light tap for success feeling
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.lightImpact();
      });
    }
  }

  /// Error feedback pattern  
  static void error() {
    if (!kIsWeb) {
      // Heavy impact for error attention
      HapticFeedback.heavyImpact();
    }
  }

  /// Achievement unlock feedback pattern
  static void achievement() {
    if (!kIsWeb) {
      // Escalating pattern for celebration
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 50), () {
        HapticFeedback.mediumImpact();
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.heavyImpact();
      });
    }
  }

  /// Navigation feedback
  static void navigation() {
    lightImpact();
  }

  /// Form submit feedback
  static void submit() {
    mediumImpact();
  }

  /// Delete action feedback
  static void delete() {
    heavyImpact();
  }

  /// Calendar day tap feedback
  static void calendarTap() {
    selectionClick();
  }

  /// Level up feedback pattern
  static void levelUp() {
    if (!kIsWeb) {
      // Celebration pattern
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 200), () {
        HapticFeedback.lightImpact();
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        HapticFeedback.lightImpact();
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        HapticFeedback.heavyImpact();
      });
    }
  }
}