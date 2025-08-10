import 'package:flutter_test/flutter_test.dart';
import 'package:progresso/services/db_service.dart';

void main() {
  group('DB Service Tests', () {
    test('badgeLevel should return correct badge levels', () {
      expect(badgeLevel(0), 0); // Keine Badge
      expect(badgeLevel(2), 0); // Keine Badge
      expect(badgeLevel(3), 1); // Bronze
      expect(badgeLevel(5), 1); // Bronze
      expect(badgeLevel(7), 2); // Silber
      expect(badgeLevel(15), 2); // Silber
      expect(badgeLevel(30), 3); // Gold
      expect(badgeLevel(100), 3); // Gold
    });

    test('xpForLevel should calculate correct XP requirements (linear scale)', () {
      expect(xpForLevel(1), 50);   // 1 * 50
      expect(xpForLevel(2), 100);  // 2 * 50
      expect(xpForLevel(3), 150);  // 3 * 50
      expect(xpForLevel(4), 200);  // 4 * 50
    });
  });
} 