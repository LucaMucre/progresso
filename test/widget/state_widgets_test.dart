import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progresso/widgets/state_widgets.dart';

void main() {
  group('StateWidget Tests', () {
    testWidgets('should render loading state correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StateWidget.loading(message: 'Loading data...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading data...'), findsOneWidget);
    });

    testWidgets('should render error state with retry button', (tester) async {
      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StateWidget.error(
              message: 'Something went wrong',
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(retryPressed, isTrue);
    });

    testWidgets('should render empty state correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StateWidget.empty(message: 'No data found'),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('No data found'), findsOneWidget);
    });
  });
}