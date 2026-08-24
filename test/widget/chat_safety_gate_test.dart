// test/widget/chat_safety_gate_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shunshi/presentation/pages/chat_page.dart';
import 'package:shunshi/presentation/widgets/chat/crisis_resource_card.dart';

void main() {
  group('ChatPage 安全闸门', () {
    setUp(() {
      // 跳过首次引导卡，直接进入对话界面
      SharedPreferences.setMockInitialValues({'has_seen_guide_cards_v2': true});
    });

    testWidgets('用户输入命中危机词：阻断生成并展示求助资源卡', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChatPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '我最近真的不想活了');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // 展示安全兜底文案 + 求助资源卡
      expect(find.textContaining('我真的很担心你'), findsOneWidget);
      expect(find.byType(CrisisResourceCard), findsOneWidget);
      expect(find.text('12356'), findsOneWidget);
      // 未走生成接口，不出现网络错误兜底
      expect(find.textContaining('连接出了问题'), findsNothing);
    });

    testWidgets('用户输入命中医疗急症词：提示拨打 120 并展示资源卡', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChatPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '家里老人突然昏迷了');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.textContaining('120'), findsWidgets);
      expect(find.byType(CrisisResourceCard), findsOneWidget);
      expect(find.textContaining('连接出了问题'), findsNothing);
    });
  });
}
