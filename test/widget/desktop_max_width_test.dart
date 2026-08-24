// 桌面宽屏 max-width 约束 widget 测试
//
// 覆盖截图实测问题：桌面视口（1440×900）下登录/订阅/首页
// 不再把移动布局拉满全宽，而是限宽居中（与 onboarding 桌面风格一致）。

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shunshi/core/config/app_config.dart';
import 'package:shunshi/data/network/api_client.dart';
import 'package:shunshi/presentation/pages/home/home_page.dart';
import 'package:shunshi/presentation/pages/login/login_page.dart';
import 'package:shunshi/presentation/pages/subscription/subscription_page.dart';
import 'package:shunshi/presentation/widgets/responsive_content.dart';

void main() {
  void useDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// 内容实际渲染宽度（MaxWidthContent 注入的限宽约束盒）
  Finder constrainedBoxOf(double maxWidth) => find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == maxWidth,
      );

  double constrainedWidth(WidgetTester tester, double maxWidth) {
    final box = constrainedBoxOf(maxWidth);
    expect(box, findsOneWidget);
    return tester.getSize(box).width;
  }

  double constrainedLeft(WidgetTester tester, double maxWidth) {
    return tester.getTopLeft(constrainedBoxOf(maxWidth)).dx;
  }

  testWidgets('登录页：桌面视口下内容限宽 520 且水平居中', (tester) async {
    useDesktopViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();

    expect(constrainedWidth(tester, kFormContentMaxWidth), kFormContentMaxWidth);
    expect(constrainedLeft(tester, kFormContentMaxWidth),
        (1440 - kFormContentMaxWidth) / 2);
  });

  testWidgets('订阅页：桌面视口下内容限宽 520 且水平居中', (tester) async {
    useDesktopViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: SubscriptionPage()));
    await tester.pumpAndSettle();

    expect(constrainedWidth(tester, kFormContentMaxWidth), kFormContentMaxWidth);
    expect(constrainedLeft(tester, kFormContentMaxWidth),
        (1440 - kFormContentMaxWidth) / 2);
  });

  testWidgets('首页四层结构：桌面视口下内容限宽 720 且水平居中', (tester) async {
    useDesktopViewport(tester);
    SharedPreferences.setMockInitialValues({'home_profile_goal': 'sleep'});
    FlutterSecureStorage.setMockInitialValues({'access_token': 'test-token'});
    AppConfig.apiBaseUrlOverride = 'https://test.shunshi.invalid';
    ApiClient.adapterOverride = () => _TestAdapter();
    addTearDown(() {
      AppConfig.apiBaseUrlOverride = null;
      ApiClient.adapterOverride = null;
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomePage())),
    );
    await tester.pumpAndSettle();

    expect(constrainedWidth(tester, kFeedContentMaxWidth), kFeedContentMaxWidth);
    // 首页有 24px 水平内边距，内容区相对页面左边距 = padding + 居中偏移
    expect(constrainedLeft(tester, kFeedContentMaxWidth),
        24 + (1440 - 48 - kFeedContentMaxWidth) / 2);
  });

  testWidgets('移动视口（390 宽）下内容正常铺满，不受桌面约束影响',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();

    // 登录页有水平 pagePadding，内容宽 = 屏宽 - 2*padding，远小于 520
    expect(constrainedWidth(tester, kFormContentMaxWidth), lessThan(390));
  });
}

class _TestAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'greeting': '今天也要好好照顾自己',
        'daily_insight': {'text': '顺应节气，从一件轻松的小事开始。'},
        'suggestions': <Map<String, dynamic>>[],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
