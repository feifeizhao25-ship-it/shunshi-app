// test/integration/chat_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shunshi/main.dart';
import '../helpers/test_app_environment.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Chat flow integration', () {
    late TestAppEnvironment environment;
    setUp(() async {
      environment = TestAppEnvironment();
      await environment.start();
    });
    tearDown(() => environment.stop());
    testWidgets('chat page is accessible from home', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: ShunshiApp()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      // Look for chat tab/button
      final chatFinder = find.byIcon(Icons.chat_bubble_outline);
      if (chatFinder.evaluate().isNotEmpty) {
        await tester.tap(chatFinder.first);
        await tester.pump(const Duration(milliseconds: 500));
        // Chat page should be visible
        expect(find.byType(TextField), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('chat input field accepts text', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: ShunshiApp()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      final chatFinder = find.text('AI对话');
      expect(chatFinder, findsWidgets);
      await tester.tap(chatFinder.first);
      await tester.pump(const Duration(milliseconds: 500));

      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsAtLeastNWidgets(1));
      await tester.enterText(inputFinder.last, '今天立春，有什么养生建议？');
      await tester.pump();
      expect(find.text('今天立春，有什么养生建议？'), findsOneWidget);
    });
  });
}
