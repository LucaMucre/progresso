import 'package:flutter/material.dart';

/// Internal data models for dashboard components

/// Represents a day entry in the calendar view
class DayEntry {
  final String title;
  final Color? color;
  final String? areaKey; // canonical key to identify life area (name|category)
  final int? durationMin; // duration in minutes for tie-breaking

  const DayEntry({
    required this.title,
    this.color,
    this.areaKey,
    this.durationMin,
  });
}

/// Represents an area tag for activities
class AreaTag {
  final String name;
  final String category;
  final Color color;

  const AreaTag({
    required this.name,
    required this.category,
    required this.color,
  });
}

/// Represents a slice in a stacked bar chart
class StackSlice {
  final Color color;
  final int minutes;

  const StackSlice({
    required this.color,
    required this.minutes,
  });
}

/// Statistics data for dashboard display
class DashboardStatistics {
  final int totalActions;
  final int totalXP;
  final int totalMinutes;
  final double avgXpPerDay;
  final int currentStreak;
  final List<AreaTag> lifeAreasData;
  final Map<DateTime, List<DayEntry>> dailyData;
  final List<int> weeklyPattern;

  const DashboardStatistics({
    required this.totalActions,
    required this.totalXP,
    required this.totalMinutes,
    required this.avgXpPerDay,
    required this.currentStreak,
    required this.lifeAreasData,
    required this.dailyData,
    required this.weeklyPattern,
  });
}