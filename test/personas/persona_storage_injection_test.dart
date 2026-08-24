// fake storage 注入测试 — persona JSON 通过 SharedPreferences 键直注真实首页
//
// 验证故事数据包的事件格式与 HomeProfileStorage 存储键完全对齐：
// 不改任何生产代码路径，把模拟器生成的种子写进 mock SharedPreferences，
// 真实 HomePage 渲染出的就是该 persona 当天的首页状态。

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

import 'persona_story.dart';

void main() {
  final stories = {for (final s in loadPersonaStories()) s.id: s};
  final sims = stories.map((id, s) => MapEntry(id, simulatePersonaWeek(s)));

  void setUpEnv(Map<String, Object> seed) {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'has_seen_guide_cards_v2': true,
      ...seed,
    });
    FlutterSecureStorage.setMockInitialValues({'access_token': 'test-token'});
    AppConfig.apiBaseUrlOverride = 'https://test.shunshi.invalid';
    ApiClient.adapterOverride = () => _TestAdapter();
    addTearDown(() {
      AppConfig.apiBaseUrlOverride = null;
      ApiClient.adapterOverride = null;
    });
  }

  Future<void> pumpHome(WidgetTester tester, DateTime now) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: HomePage(nowOverride: now)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('A Day2：注入首日后首页按行为重排，Hero 透出承接与点开过理由',
      (tester) async {
    final sim = sims['A']!;
    final day2 = sim.renderOf(2);
    setUpEnv(sim.storageSeedForRender(2));
    await pumpHome(tester, day2.renderAt);

    // 已选目标 → 目标引导消失；四层结构在
    expect(find.text('选一个目标，首页为你而排'), findsNothing);
    expect(find.text('今日一件事'), findsOneWidget);
    expect(find.text('今日重点'), findsOneWidget);

    // Hero 是模拟器算出的 rhythm；打开「为什么推荐」核对理由透出
    expect(find.textContaining('今日作息'), findsWidgets);
    await tester.ensureVisible(find.byIcon(Icons.info_outline).first);
    await tester.tap(find.byIcon(Icons.info_outline).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('你之前点开过'), findsOneWidget);

    // 与模拟器一致：食疗在 Day1 未点开，Day2 不进前排第 2 位之前的断言由驱动测试覆盖
  });

  testWidgets('E Day2：未选目标 → 首页显示目标引导', (tester) async {
    final simE = sims['E']!;
    // goal 未选 → 种子不含 home_profile_goal → 首页显示目标引导
    setUpEnv(simE.storageSeedForRender(2));
    await pumpHome(tester, simE.renderOf(2).renderAt);
    expect(find.text('选一个目标，首页为你而排'), findsOneWidget);
  });

  testWidgets('E Day4：已选 calm + 已关闭 chat → AI 陪伴卡不再出现',
      (tester) async {
    final simE = sims['E']!;
    setUpEnv(simE.storageSeedForRender(4));
    await pumpHome(tester, simE.renderOf(4).renderAt);
    expect(find.text('选一个目标，首页为你而排'), findsNothing);
    expect(find.text('有心事，和顺时聊聊'), findsNothing);
    expect(find.text('今日一件事'), findsOneWidget);
  });

  testWidgets('C Day4 傍晚：进展层透出「今天还没行动」异常提醒', (tester) async {
    final sim = sims['C']!;
    setUpEnv(sim.storageSeedForRender(4));
    await pumpHome(tester, sim.renderOf(4).renderAt);
    expect(find.text('今天还没行动，从 1 分钟呼吸开始'), findsOneWidget);
    expect(find.text('进展与异常'), findsOneWidget);
  });

  test('种子键与 HomeProfileStorage 存储键逐一对应', () {
    // 键名是存储契约的一部分，硬编码对照，改键名会让本测试失败
    final seed = sims['A']!.storageSeedForRender(3);
    expect(seed.keys, containsAll([
      'home_profile_goal',
      'home_profile_muted_categories',
      'home_behavior_events',
      'home_completions',
    ]));
    // 事件编码格式与 _encodeEvents 一致：cardId/type/at
    final events =
        jsonDecode(seed['home_behavior_events']! as String) as List;
    expect(events, isNotEmpty);
    for (final e in events) {
      expect((e as Map).keys, containsAll(['cardId', 'type', 'at']));
      expect(['seen', 'opened', 'completed'], contains(e['type']));
      expect(DateTime.tryParse('${e['at']}'), isNotNull);
    }
    // 完成记录按 yyyy-MM-dd 键控
    final completions =
        jsonDecode(seed['home_completions']! as String) as Map;
    expect(completions.keys, everyElement(matches(r'^\d{4}-\d{2}-\d{2}$')));
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
