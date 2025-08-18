import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Service for XP calculations and level logic
class XpService {
  /// XP threshold for level n (linear system: 100 XP per level)
  static int xpForLevel(int level) => level * 100;

  /// Calculate level from total XP (linear system: 100 XP per level)
  static int calculateLevel(int totalXp) {
    if (totalXp <= 0) return 1;
    return (totalXp / 100).floor() + 1;
  }

  /// Detailed level progress info: current level, XP since level start, XP until next level
  static Map<String, int> calculateLevelDetailed(int totalXp) {
    final level = calculateLevel(totalXp);
    // 100 XP per level
    final xpInto = totalXp % 100; // XP in current level (remainder of division)
    const xpNeeded = 100; // Each level needs 100 XP
    
    return {
      'level': level,
      'xpInto': xpInto,
      'xpNext': xpNeeded,
    };
  }

  /// Estimate plain text length from notes field (robust against JSON/Delta)
  static int _estimatePlainTextLength(String? notes) {
    if (notes == null || notes.trim().isEmpty) return 0;
    try {
      final obj = jsonDecode(notes);
      if (obj is Map<String, dynamic>) {
        int len = 0;
        final title = obj['title'];
        if (title is String) len += title.trim().length;
        final content = obj['content'];
        if (content is String) len += content.trim().length;
        // Quill Delta possibly as 'ops'
        final ops = obj['ops'];
        if (ops is List) {
          for (final o in ops) {
            if (o is Map && o['insert'] is String) {
              len += (o['insert'] as String).length;
            }
          }
        }
        if (len > 0) return len;
        // Fallback: stringify and filter
        return obj.toString().replaceAll(RegExp(r'[{}\[\]",:]+'), ' ').trim().length;
      }
      if (obj is List) {
        // Possible Quill Delta
        int len = 0;
        for (final e in obj) {
          if (e is Map && e['insert'] is String) {
            len += (e['insert'] as String).length;
          }
        }
        if (len > 0) return len;
      }
    } catch (_) {
      // ignore and fall back
    }
    return notes.replaceAll(RegExp(r"\s+"), ' ').trim().length;
  }

  /// Client-side fallback XP calculation if edge function fails
  static int calculateEarnedXpFallback({int? durationMin, String? notes, String? imageUrl}) {
    final int timeMinutes = durationMin ?? 0;
    int xp = timeMinutes ~/ 5; // 1 XP per 5 minutes
    final int textLen = _estimatePlainTextLength(notes);
    xp += textLen ~/ 100; // 1 XP per 100 characters
    final bool hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    if (hasImage) {
      xp += 2; // static image bonus
    }
    if (xp <= 0 && (timeMinutes > 0 || textLen > 0 || hasImage)) xp = 1;
    return xp;
  }

  /// Try to extract a 'title' from notes JSON wrapper
  static String? extractTitleFromNotes(dynamic notesValue) {
    try {
      if (notesValue is String && notesValue.trim().isNotEmpty) {
        final obj = jsonDecode(notesValue);
        if (obj is Map<String, dynamic>) {
          final t = obj['title'];
          if (t is String && t.trim().isNotEmpty) return t.trim();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error extracting title from notes: $e');
    }
    return null;
  }
}