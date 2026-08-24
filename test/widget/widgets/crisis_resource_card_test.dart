// test/widget/widgets/crisis_resource_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shunshi/presentation/widgets/chat/crisis_resource_card.dart';

void main() {
  group('CrisisResourceCard widget', () {
    testWidgets('展示心理援助热线与急救提示', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CrisisResourceCard()),
        ),
      );

      expect(find.text('你并不孤单，帮助随时都在'), findsOneWidget);
      expect(find.text('12356'), findsOneWidget);
      expect(find.text('010-82951332'), findsOneWidget);
      expect(find.text('120（急救）/ 110'), findsOneWidget);
      expect(find.textContaining('请及时就医'), findsOneWidget);
    });

    testWidgets('热线号码可复制（SelectableText）', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CrisisResourceCard()),
        ),
      );

      expect(find.byType(SelectableText), findsNWidgets(3));
    });
  });
}
