import 'package:flutter/material.dart';

/// Utility functions for calendar operations

class CalendarUtils {
  /// Get the first day of the week for a given date
  static DateTime startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  /// Get the last day of the week for a given date
  static DateTime endOfWeek(DateTime date) {
    final weekday = date.weekday;
    return date.add(Duration(days: 7 - weekday));
  }

  /// Get the first day of the month
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Get the last day of the month
  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// Get all days in a month
  static List<DateTime> getDaysInMonth(DateTime month) {
    final firstDay = startOfMonth(month);
    final lastDay = endOfMonth(month);
    final days = <DateTime>[];
    
    for (int i = 0; i <= lastDay.day - 1; i++) {
      days.add(firstDay.add(Duration(days: i)));
    }
    
    return days;
  }

  /// Get calendar grid including leading/trailing days from other months
  static List<DateTime> getCalendarGrid(DateTime month) {
    final firstDayOfMonth = startOfMonth(month);
    final lastDayOfMonth = endOfMonth(month);
    
    // Start from Monday of the week containing the first day
    final startDate = startOfWeek(firstDayOfMonth);
    
    // End on Sunday of the week containing the last day
    final endDate = endOfWeek(lastDayOfMonth);
    
    final days = <DateTime>[];
    DateTime current = startDate;
    
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    
    return days;
  }

  /// Check if two dates are on the same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Check if a date is today
  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  /// Check if a date is in the current month
  static bool isInMonth(DateTime date, DateTime month) {
    return date.year == month.year && date.month == month.month;
  }

  /// Get weekday name (short)
  static String getWeekdayName(int weekday, {bool short = true}) {
    const longNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 
      'Friday', 'Saturday', 'Sunday'
    ];
    const shortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    final names = short ? shortNames : longNames;
    return names[weekday - 1];
  }

  /// Get month name
  static String getMonthName(int month, {bool short = false}) {
    const longNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const shortNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final names = short ? shortNames : longNames;
    return names[month - 1];
  }

  /// Get the number of weeks in a month
  static int getWeeksInMonth(DateTime month) {
    final grid = getCalendarGrid(month);
    return (grid.length / 7).ceil();
  }

  /// Navigate to previous month
  static DateTime previousMonth(DateTime current) {
    if (current.month == 1) {
      return DateTime(current.year - 1, 12, 1);
    } else {
      return DateTime(current.year, current.month - 1, 1);
    }
  }

  /// Navigate to next month
  static DateTime nextMonth(DateTime current) {
    if (current.month == 12) {
      return DateTime(current.year + 1, 1, 1);
    } else {
      return DateTime(current.year, current.month + 1, 1);
    }
  }

  /// Format date for display
  static String formatDate(DateTime date, {bool includeYear = false}) {
    if (includeYear) {
      return '${getMonthName(date.month)} ${date.day}, ${date.year}';
    } else {
      return '${getMonthName(date.month)} ${date.day}';
    }
  }
}