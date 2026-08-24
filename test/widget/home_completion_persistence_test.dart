// 完成状态跨会话持久化 widget 测试
//
// 覆盖个性化 v2 第 5 项：今日一件事的完成状态按日期键存本地，
// 跨启动保留；「进展与异常」层的完成计数从持久化读取。

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
import 'package:shunshi/data/storage/home_profile_storage.dart';
import 'package:shunshi/presentation/pages/home/home_page.dart';

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomePage())),
    );
    await tester.pumpAndSettle();
  }

  void setUpEnv() {
    SharedPreferences.setMockInitialValues({'home_profile_goal': 'sleep'});
    FlutterSecureStorage.setMockInitialValues({'access_token': 'test-token'});
    AppConfig.apiBaseUrlOverride = 'https://test.shunshi.invalid';
    ApiClient.adapterOverride = () => _TestAdapter();
    addTearDown(() {
      AppConfig.apiBaseUrlOverride = null;
      ApiClient.adapterOverride = null;
    });
  }

  testWidgets('点「今天照做」后完成状态落盘；重新启动首页完成计数保留',
      (tester) async {
    setUpEnv();
    await pumpHome(tester);

    // 会话 1：完成一张卡（默认 action 分支 → 本地标记 + 持久化）
    expect(find.text('今日已完成 0 件小行动'), findsOneWidget);
    await tester.ensureVisible(find.text('今天照做').first);
    await tester.tap(find.text('今天照做').first);
    await tester.pumpAndSettle();

    // 完成的卡退出前排，进展层计数 +1
    expect(find.text('今日已完成 1 件小行动'), findsOneWidget);

    // 落盘验证：按日期键的完成记录 + completed 行为事件
    final done =
        await homeProfileStorage.loadCompletionsForDate(DateTime.now());
    expect(done.length, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('home_behavior_events'), contains('completed'));

    // 会话 2：销毁页面树，重新 pump 一个全新首页（同一 prefs = 同一台设备）
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await pumpHome(tester);

    // 完成计数从持久化恢复，完成的卡仍退出前排
    expect(find.text('今日已完成 1 件小行动'), findsOneWidget);
    expect(find.text('今日已完成 0 件小行动'), findsNothing);
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
