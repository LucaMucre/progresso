import 'package:flutter_test/flutter_test.dart';
import 'package:progresso/services/db_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Supabase Integration Tests', () {
    test('calculateEarnedXp should calculate correct XP with bonuses', () {
      // Test ohne Boni
      expect(calculateEarnedXp(25, null, 0), 25);
      
      // Test mit Duration Bonus
      expect(calculateEarnedXp(25, 30, 0), 28); // 25 + (30/10) = 28
      
      // Test mit Streak Bonus
      expect(calculateEarnedXp(25, null, 7), 27); // 25 + 2 = 27
      
      // Test mit beiden Boni
      expect(calculateEarnedXp(25, 60, 10), 33); // 25 + 6 + 2 = 33
    });

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
  });
} 