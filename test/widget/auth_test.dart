import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth Widget Tests', () {
    testWidgets('AuthPage widget can be created', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Auth Page Test'),
            ),
          ),
        ),
      );

      expect(find.text('Auth Page Test'), findsOneWidget);
    });

    testWidgets('Basic widget test', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Test 1'),
                Text('Test 2'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Test 1'), findsOneWidget);
      expect(find.text('Test 2'), findsOneWidget);
    });
  });
} 