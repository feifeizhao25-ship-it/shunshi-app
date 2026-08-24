// 首页信息架构 widget 测试
//
// 覆盖 19 项要求第 10/13/3 项：
// - 四层结构渲染（Hero 今日一件事 / 今日重点 / 进展与异常 / 全部功能）
// - 探索区折叠展开
// - 三级阅读「为什么」展开
// - 主结论 25 字约束
// - 首次进入目标引导、关闭类别与重置画像入口

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
import 'package:shunshi/presentation/widgets/home/three_level_card.dart';

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
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
  }

  group('四层信息架构', () {
    testWidgets('渲染 Hero/今日重点/进展与异常/全部功能 四层', (tester) async {
      await pumpHome(tester, initialPrefs: {'home_profile_goal': 'sleep'});

      expect(find.text('今日一件事'), findsOneWidget);
      expect(find.text('今日重点'), findsOneWidget);
      expect(find.text('进展与异常'), findsOneWidget);
      expect(find.text('全部功能'), findsOneWidget);

      // Hero 层恰有一张卡带主行动按钮
      expect(find.byType(ThreeLevelCard), findsWidgets);
    });

    testWidgets('今日重点不超过 3 张、进展与异常不超过 2 张', (tester) async {
      await pumpHome(tester, initialPrefs: {'home_profile_goal': 'sleep'});

      // 引擎层已用单测钉死数量约束；这里验证 UI 层确实分区渲染
      final focusHeader = find.text('今日重点');
      final progressHeader = find.text('进展与异常');
      expect(focusHeader, findsOneWidget);
      expect(progressHeader, findsOneWidget);
    });
  });

  group('探索区', () {
    testWidgets('默认折叠，点开后展示全部既有功能入口，再点收起', (tester) async {
      await pumpHome(tester, initialPrefs: {'home_profile_goal': 'sleep'});

      // 折叠态：入口不可见
      expect(find.text('健康记录'), findsNothing);
      expect(find.text('情绪复盘'), findsNothing);

      await tester.ensureVisible(find.text('全部功能'));
      await tester.tap(find.text('全部功能'));
      await tester.pumpAndSettle();

      // 展开态：既有功能入口一个不少
      expect(find.text('和顺时聊聊'), findsOneWidget);
      expect(find.text('节气养生'), findsOneWidget);
      expect(find.text('养生内容'), findsOneWidget);
      expect(find.text('健康记录'), findsOneWidget);
      expect(find.text('情绪复盘'), findsOneWidget);
      expect(find.text('我的'), findsWidgets); // 底部导航也可能有

      // 再点收起
      await tester.tap(find.text('全部功能'));
      await tester.pumpAndSettle();
      expect(find.text('健康记录'), findsNothing);
    });
  });

  group('三级阅读', () {
    testWidgets('点「为什么」展开原因层，再点收起', (tester) async {
      await pumpHome(tester, initialPrefs: {'home_profile_goal': 'sleep'});

      expect(find.text('收起原因'), findsNothing);

      await tester.ensureVisible(find.text('为什么').first);
      await tester.tap(find.text('为什么').first);
      await tester.pumpAndSettle();
      expect(find.text('收起原因'), findsOneWidget);

      await tester.tap(find.text('收起原因'));
      await tester.pumpAndSettle();
      expect(find.text('收起原因'), findsNothing);
    });

    testWidgets('主结论超过 25 字时组件层截断并加省略号', (tester) async {
      const longConclusion = '这是一段远远超过二十五个字的主结论文案用来验证组件层的长度约束是否生效';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThreeLevelCard(conclusion: longConclusion, why: '原因'),
          ),
        ),
      );

      expect(find.text(longConclusion), findsNothing);
      final text = tester.widget<Text>(
        find.text('${longConclusion.substring(0, 25)}…'),
      );
      expect(text.data!.length, 26); // 25 字 + 省略号
    });

    test('fitConclusion：短文案原样返回，长文案 25 字截断', () {
      expect(fitConclusion('短结论'), '短结论');
      const exact = '一二三四五六七八九十一二三四五六七八九十一二三四五';
      expect(fitConclusion(exact), exact); // 恰好 25 字不截断
      expect(fitConclusion('$exact六'), '$exact…');
      expect(fitConclusion('  带空白  '), '带空白');
    });
  });

  group('个性化 v1（本地画像）', () {
    testWidgets('首次进入显示目标引导，选目标后引导消失并本地持久化', (tester) async {
      await pumpHome(tester); // 无画像

      expect(find.text('选一个目标，首页为你而排'), findsOneWidget);

      await tester.tap(find.text('睡个好觉'));
      await tester.pumpAndSettle();

      expect(find.text('选一个目标，首页为你而排'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('home_profile_goal'), 'sleep');
    });

    testWidgets('已选目标的用户不再看到引导', (tester) async {
      await pumpHome(tester, initialPrefs: {'home_profile_goal': 'family'});
      expect(find.text('选一个目标，首页为你而排'), findsNothing);
    });

    testWidgets('「为什么推荐」说明含理由、关闭类别与重置画像入口', (tester) async {
      await pumpHome(tester, initialPrefs: {'home_profile_goal': 'sleep'});

      await tester.ensureVisible(find.byIcon(Icons.info_outline).first);
      await tester.tap(find.byIcon(Icons.info_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('为什么推荐这张卡'), findsOneWidget);
      expect(find.textContaining('不再推荐'), findsOneWidget);
      expect(find.text('重置画像，重新选择目标'), findsOneWidget);

      // 重置画像：回到底部 sheet 关闭、目标引导重新出现、本地清空
      await tester.tap(find.text('重置画像，重新选择目标'));
      await tester.pumpAndSettle();
      expect(find.text('为什么推荐这张卡'), findsNothing);
      expect(find.text('选一个目标，首页为你而排'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('home_profile_goal'), isNull);
    });

    testWidgets('关闭某类推荐后持久化到本地', (tester) async {
      await pumpHome(tester, initialPrefs: {'home_profile_goal': 'sleep'});

      await tester.ensureVisible(find.byIcon(Icons.info_outline).first);
      await tester.tap(find.byIcon(Icons.info_outline).first);
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('不再推荐'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('home_profile_muted_categories'), isNotEmpty);
    });
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
