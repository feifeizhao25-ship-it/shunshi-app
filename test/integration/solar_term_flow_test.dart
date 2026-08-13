// test/integration/solar_term_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shunshi/main.dart';
import '../helpers/test_app_environment.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Solar term flow integration', () {
    late TestAppEnvironment environment;
    setUp(() async {
      environment = TestAppEnvironment();
      await environment.start();
    });
    tearDown(() => environment.stop());
    testWidgets('home shows solar term section', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: ShunshiApp()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      // Solar term card should be visible on home
      // Look for season-related text
      final solarTermTexts = ['节气', '立春', '雨水', '惊蛰', '春分'];
      bool found = false;
      for (final text in solarTermTexts) {
        if (find.textContaining(text).evaluate().isNotEmpty) {
          found = true;
          break;
        }
      }
      expect(found, isTrue);
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
