import 'dart:convert';

/// Cached parsed activity data to avoid repeated JSON parsing in UI
class ParsedActivityData {
  final String? title;
  final String? area;
  final String? lifeArea;  
  final String? category;
  final String? plainText;
  final bool isValid;

  const ParsedActivityData({
    this.title,
    this.area,
    this.lifeArea,
    this.category,
    this.plainText,
    this.isValid = false,
  });

  /// Create from raw notes string, parsing JSON if needed
  factory ParsedActivityData.fromNotes(String? notes) {
    if (notes == null || notes.trim().isEmpty) {
      return const ParsedActivityData();
    }

    try {
      final obj = jsonDecode(notes);
      if (obj is Map<String, dynamic>) {
        return ParsedActivityData(
          title: obj['title'] as String?,
          area: obj['area'] as String?,
          lifeArea: obj['life_area'] as String?,
          category: obj['category'] as String?,
          plainText: _extractPlainText(obj),
          isValid: true,
        );
      }
    } catch (_) {
      // If JSON parsing fails, treat as plain text
      return ParsedActivityData(
        plainText: notes.split('\n').first.trim(),
        isValid: false,
      );
    }
    
    return ParsedActivityData(plainText: notes, isValid: false);
  }

  /// Extract plain text from Quill Delta format if available
  static String? _extractPlainText(Map<String, dynamic> obj) {
    try {
      final delta = obj['delta'];
      if (delta is List) {
        final buffer = StringBuffer();
        for (final op in delta) {
          if (op is Map<String, dynamic>) {
            final insert = op['insert'];
            if (insert is String) {
              buffer.write(insert);
            }
          }
        }
        final result = buffer.toString().trim();
        return result.isEmpty ? null : result;
      }
    } catch (_) {
      // Ignore errors in Delta parsing
    }
    return null;
  }

  /// Get effective area name (prefer area over lifeArea)
  String get effectiveAreaName {
    if (area != null && area!.trim().isNotEmpty) return area!.trim();
    if (lifeArea != null && lifeArea!.trim().isNotEmpty) return lifeArea!.trim();
    return '';
  }

  /// Get display title (prefer title over plainText)
  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) return title!.trim();
    if (plainText != null && plainText!.trim().isNotEmpty) return plainText!.trim();
    return 'Activity';
  }
}

/// Extension to add parsed data caching to ActionLog
extension ActionLogParsed on dynamic {
  ParsedActivityData get parsedNotes {
    // This would ideally be cached in the object, but for now we parse on demand
    // In a real implementation, you'd want to cache this
    final notes = this.notes as String?;
    return ParsedActivityData.fromNotes(notes);
  }
}