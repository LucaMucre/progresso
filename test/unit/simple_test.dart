import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simple Tests', () {
    test('Basic math test', () {
      expect(1 + 1, equals(2));
      expect(2 * 3, equals(6));
      expect(10 - 5, equals(5));
    });

    test('String test', () {
      expect('Hello', isA<String>());
      expect('World'.length, equals(5));
    });

    test('List test', () {
      final list = [1, 2, 3];
      expect(list.length, equals(3));
      expect(list.first, equals(1));
      expect(list.last, equals(3));
    });
  });
} 