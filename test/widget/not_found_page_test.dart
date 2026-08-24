// 404 页 widget 测试
//
// 覆盖：GoRouter 未匹配路由时展示中文友好页，
// 不暴露 GoException 等框架异常文本，「返回首页」可导航。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shunshi/presentation/pages/not_found/not_found_page.dart';

void main() {
  Future<void> pumpRouter(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/no-such-route',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                const Scaffold(body: Text('首页占位')),
          ),
        ],
        errorBuilder: (context, state) => const NotFoundPage(),
      );

  testWidgets('未匹配路由展示中文 404 页，不含框架异常文本', (tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    await pumpRouter(tester, router);

    expect(find.text('页面不存在'), findsOneWidget);
    expect(find.text('返回首页'), findsOneWidget);
    // 不暴露 GoException / 路由路径等异常细节
    expect(find.textContaining('GoException'), findsNothing);
    expect(find.textContaining('no routes for location'), findsNothing);
    expect(find.textContaining('/no-such-route'), findsNothing);
    expect(find.textContaining('Page Not Found'), findsNothing);
  });

  testWidgets('点「返回首页」导航到 /home', (tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    await pumpRouter(tester, router);

    await tester.tap(find.text('返回首页'));
    await tester.pumpAndSettle();

    expect(find.text('首页占位'), findsOneWidget);
    expect(find.text('页面不存在'), findsNothing);
  });
}
