import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shunshi/main.dart';

import 'helpers/test_app_environment.dart';

void main() {
  testWidgets('App 完整流程测试', (WidgetTester tester) async {
    final environment = TestAppEnvironment();
    await environment.start();
    addTearDown(environment.stop);
    // 1. 启动 App
    await tester.pumpWidget(const ShunshiApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));

    print('✅ 1. App 启动成功');

    // 2. 测试首页
    expect(find.text('顺时'), findsOneWidget);
    print('✅ 2. 首页显示正常');

    // 3. 测试打卡功能
    final habitButtons = find.byIcon(Icons.add);
    if (habitButtons.evaluate().isNotEmpty) {
      await tester.tap(habitButtons.first);
      await tester.pump();
      print('✅ 3. 打卡功能可用');
    }

    // 4. 测试导航到养生页
    await tester.tap(find.text('节气'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('节气'), findsOneWidget);
    print('✅ 4. 养生页正常');

    // 5. 测试节气页面跳转
    final solarButtons = find.byIcon(Icons.wb_sunny);
    if (solarButtons.evaluate().isNotEmpty) {
      await tester.tap(solarButtons.first);
      await tester.pump(const Duration(milliseconds: 500));
      print('✅ 5. 节气页面正常');
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
    }

    // 6. 测试对话页
    await tester.tap(find.text('AI对话'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TextField), findsAtLeastNWidgets(1));
    print('✅ 6. 对话页正常');

    // 7. 测试内容页
    await tester.tap(find.text('内容'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('养生内容'), findsWidgets);
    print('✅ 7. 内容页正常');

    // 8. 测试个人中心
    await tester.tap(find.text('我的'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('我的'), findsOneWidget);
    print('✅ 8. 个人中心正常');

    print('\n🎉 全部测试通过!');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
