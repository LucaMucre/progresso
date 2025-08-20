import 'package:flutter/material.dart';
import '../../utils/accessibility_utils.dart';
import '../../utils/haptic_utils.dart';

class CalendarDayEntry {
  final String title;
  final Color? color;
  const CalendarDayEntry({required this.title, this.color});
}

class CalendarGrid extends StatefulWidget {
  final DateTime month;
  final Map<DateTime, List<CalendarDayEntry>> dayEntries;
  final void Function(DateTime) onOpenDay;
  final Map<DateTime, Color>? dayDominantColors; // optional server-aggregated dominant colors

  const CalendarGrid({
    super.key,
    required this.month,
    required this.dayEntries,
    required this.onOpenDay,
    this.dayDominantColors,
  });

  @override
  State<CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<CalendarGrid> {
  // Memoization cache for dominant color per day
  final Map<DateTime, Color?> _dominantColorCache = {};

  @override
  void didUpdateWidget(covariant CalendarGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month || !identical(oldWidget.dayEntries, widget.dayEntries)) {
      _dominantColorCache.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 900; // responsive grid
    // Smaller window => lower aspect ratio => taller cells to keep previews visible
    double childAspectRatio;
    if (screenWidth < 520) {
      childAspectRatio = 0.70;
    } else if (screenWidth < 720) {
      childAspectRatio = 0.80;
    } else if (screenWidth < 900) {
      childAspectRatio = 0.95;
    } else {
      childAspectRatio = 1.10;
    }
    // Removed unused maxEntriesPerCell variable

    final first = DateTime(widget.month.year, widget.month.month);
    // Monday is 1, Sunday is 7 in Dart. We want Monday to be first day of week
    final firstWeekday = first.weekday; 
    final daysInMonth = DateTime(widget.month.year, widget.month.month + 1, 0).day;
    final cells = <Widget>[];

    // Add empty cells for days before the first day of month
    // If month starts on Tuesday (2), add 1 empty cell for Monday
    // If month starts on Sunday (7), add 6 empty cells
    final emptyCells = firstWeekday == 7 ? 6 : firstWeekday - 1;
    for (int i = 0; i < emptyCells; i++) {
      cells.add(const SizedBox.shrink());
    }
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(widget.month.year, widget.month.month, d);
      final key = DateTime(date.year, date.month, date.day);
      final entries = widget.dayEntries[key] ?? const <CalendarDayEntry>[];
      // Prefer server-provided dominant color
      Color? dominantColor = widget.dayDominantColors != null
          ? widget.dayDominantColors![key]
          : _dominantColorCache[key];
      // If not provided, compute locally (memoized) - fallback logic
      if (dominantColor == null && entries.isNotEmpty) {
        // Note: CalendarDayEntry doesn't have duration info, so fallback to count-based logic
        // The main logic should use dayDominantColors from dashboard_page.dart
        final Map<int, int> colorCounts = {};
        for (final e in entries) {
          final color = (e.color ?? Theme.of(context).colorScheme.primary).value;
          colorCounts[color] = (colorCounts[color] ?? 0) + 1;
        }
        int maxCount = 0;
        int? maxColorValue;
        colorCounts.forEach((colorValue, count) {
          if (count > maxCount) {
            maxCount = count;
            maxColorValue = colorValue;
          }
        });
        if (maxColorValue != null) {
          dominantColor = Color(maxColorValue!);
          _dominantColorCache[key] = dominantColor;
        }
      }

      cells.add(Semantics(
        label: AccessibilityUtils.calendarDayLabel(d, activitiesCount: entries.length),
        hint: AccessibilityUtils.navigationHint,
        button: true,
        child: GestureDetector(
          onTap: () {
            HapticUtils.calendarTap();
            widget.onOpenDay(date);
          },
        child: RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.all(4),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: key == todayKey
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.20)
                  : dominantColor?.withValues(alpha: 0.25),
              border: Border.all(
                color: key == todayKey
                    ? Theme.of(context).colorScheme.primary
                    : (dominantColor ?? Theme.of(context).dividerColor)
                        .withValues(alpha: 0.6),
                width: key == todayKey ? 2.0 : 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$d',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: key == todayKey ? FontWeight.w700 : FontWeight.w500,
                      color: key == todayKey
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : dominantColor != null
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
          ),
        ),
        ),
      ));
    }

    return RepaintBoundary(
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 7,
        childAspectRatio: childAspectRatio,
        children: cells,
      ),
    );
  }
}

