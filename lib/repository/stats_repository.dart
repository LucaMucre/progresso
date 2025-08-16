import 'package:supabase_flutter/supabase_flutter.dart';

class StatsRepository {
  final SupabaseClient db;
  StatsRepository(this.db);

  Future<Map<DateTime, Map<String, int>>> fetchDailyAreaTotals({
    required DateTime month,
  }) async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return {};
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final res = await db.rpc('daily_activity_totals', params: {
      'uid': uid,
      'start_date': '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
      'end_date': '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
      'tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
    });
    final out = <DateTime, Map<String, int>>{};
    if (res is List) {
      for (final row in res) {
        final String? dayStr = row['day'] as String?;
        if (dayStr == null) continue;
        final String area = (row['area_key'] as String?) ?? 'unknown';
        final int total = (row['total'] as num?)?.toInt() ?? 0;
        final day = DateTime.parse(dayStr);
        final key = DateTime(day.year, day.month, day.day);
        final bucket = out.putIfAbsent(key, () => <String, int>{});
        bucket[area] = total;
      }
    }
    return out;
  }

  Future<Map<DateTime, List<Map<String, dynamic>>>> fetchDailyAreaTotalsDetailed({
    required DateTime month,
  }) async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return {};
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final res = await db.rpc('daily_activity_totals', params: {
      'uid': uid,
      'start_date': '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
      'end_date': '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
      'tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
    });
    final out = <DateTime, List<Map<String, dynamic>>>{};
    if (res is List) {
      for (final row in res) {
        final String? dayStr = row['day'] as String?;
        if (dayStr == null) continue;
        final day = DateTime.parse(dayStr);
        final key = DateTime(day.year, day.month, day.day);
        final item = {
          'area_key': (row['area_key'] as String?) ?? 'unknown',
          'total': (row['total'] as num?)?.toInt() ?? 0,
          'sum_duration': (row['sum_duration'] as num?)?.toInt() ?? 0,
          'sum_xp': (row['sum_xp'] as num?)?.toInt() ?? 0,
        };
        (out[key] ??= <Map<String, dynamic>>[]).add(item);
      }
    }
    return out;
  }
}

