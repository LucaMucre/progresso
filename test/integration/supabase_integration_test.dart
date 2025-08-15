import 'package:flutter_test/flutter_test.dart';
import 'package:progresso/services/db_service.dart';

void main() {
  group('Supabase Integration Tests', () {
    test('badgeLevel function works correctly', () {
      expect(badgeLevel(0), 0); // Keine Badge
      expect(badgeLevel(2), 0); // Keine Badge
      expect(badgeLevel(3), 1); // Bronze
      expect(badgeLevel(5), 1); // Bronze
      expect(badgeLevel(7), 2); // Silber
      expect(badgeLevel(15), 2); // Silber
      expect(badgeLevel(30), 3); // Gold
      expect(badgeLevel(100), 3); // Gold
    });

    test('xpForLevel function works correctly', () {
      expect(xpForLevel(1), 100);  // 1 * 100
      expect(xpForLevel(2), 200);  // 2 * 100
      expect(xpForLevel(3), 300);  // 3 * 100
      expect(xpForLevel(4), 400);  // 4 * 100
    });

    test('level calculation works correctly', () {
      expect(calculateLevel(25), 1);   // 0-99 XP = Level 1
      expect(calculateLevel(99), 1);   // 0-99 XP = Level 1
      expect(calculateLevel(100), 2);  // 100-199 XP = Level 2
      expect(calculateLevel(175), 2);  // 100-199 XP = Level 2
      expect(calculateLevel(200), 3);  // 200-299 XP = Level 3
    });
  });
} 