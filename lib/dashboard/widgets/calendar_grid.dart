import 'package:flutter/material.dart';

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
    final maxEntriesPerCell = isCompact ? 2 : 3; // baseline, further refined per-cell below

    final first = DateTime(widget.month.year, widget.month.month, 1);
    final firstWeekday = first.weekday == 7 ? 0 : first.weekday; // Mon=1..Sun=7 => 0..6 with Sun at 0
    final daysInMonth = DateTime(widget.month.year, widget.month.month + 1, 0).day;
    final cells = <Widget>[];

    for (int i = 0; i < firstWeekday - 1; i++) {
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
      // If not provided, compute locally (memoized)
      if (dominantColor == null && entries.isNotEmpty) {
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

      cells.add(GestureDetector(
        onTap: () => widget.onOpenDay(date),
        child: RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.all(4),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: key == todayKey
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.14)
                  : dominantColor?.withOpacity(0.10),
              border: Border.all(
                color: key == todayKey
                    ? Theme.of(context).colorScheme.primary
                    : (dominantColor ?? Theme.of(context).dividerColor)
                        .withOpacity(0.25),
                width: key == todayKey ? 1.4 : 1.0,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: LayoutBuilder(
            builder: (ctx, cons) {
              final h = cons.maxHeight;
              final pad = h <= 56 ? 3.0 : 8.0;
              int maxEntries = maxEntriesPerCell;
              if (h <= 56) {
                maxEntries = 1;
              } else if (h <= 88) {
                maxEntries = 2;
              }
              return Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      '$d',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: key == todayKey ? FontWeight.w700 : null,
                            color: key == todayKey
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : null,
                          ),
                    ),
                    if (entries.isNotEmpty && maxEntries > 0)
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          physics: const ClampingScrollPhysics(),
                          itemCount: entries.length,
                          itemBuilder: (context, idx) {
                            final e = entries[idx];
                            final Color dot = e.color ??
                                dominantColor ??
                                Theme.of(context).colorScheme.outline;
                            return Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: dot,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      e.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.labelSmall,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
            ),
          ),
        ),
      ));
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: childAspectRatio,
      children: cells,
    );
  }
}

