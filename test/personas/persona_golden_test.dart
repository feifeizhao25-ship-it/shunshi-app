// 5 用户 × 7 天首页 golden 截图（19 项要求第 19 项前置）
//
// 用真实 HomePage 渲染每个 persona 每天的首页：
// - SharedPreferences 注入模拟器生成的存储种子（键与 HomeProfileStorage 一致）
// - HomePage.nowOverride 固定当天日期锚点（测试专用钩子）
// - 手机视口 430×2400 一屏截全四层结构
//
// 生成基线：flutter test --update-goldens test/personas/persona_golden_test.dart
// 常规校验：flutter test test/personas/persona_golden_test.dart
// 基线在 test/personas/goldens/（版本控制内，差异审查后才允许 --update-goldens）；
// 每次运行同时导出 manifest.json + story_dump.json 到 验收证据/顺时/personas/。
//
// 中文渲染依赖 macOS 系统字体 Arial Unicode.ttf（setUpAll 加载）；
// 换机器/换字体后基线会变化，需审查差异再更新。

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shunshi/core/config/app_config.dart';
import 'package:shunshi/data/network/api_client.dart';
import 'package:shunshi/presentation/pages/home/home_page.dart';

import 'persona_story.dart';

/// 证据输出目录（相对包根）
const String kEvidenceDir = '../../验收证据/顺时/personas';

void main() {
  final stories = loadPersonaStories();
  final sims = {for (final s in stories) s.id: simulatePersonaWeek(s)};

  setUpAll(() async {
    // golden 环境无系统中文字体，加载 Arial Unicode 让截图可读
    const fontPath = '/System/Library/Fonts/Supplemental/Arial Unicode.ttf';
    final fontFile = File(fontPath);
    if (fontFile.existsSync()) {
      final bytes = fontFile.readAsBytesSync();
      final loader = FontLoader('TestCJK')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    // Material 图标字体（golden 环境不自动加载，缺了会渲染成豆腐块）
    const iconPath = '/Users/feifei00/flutter/bin/cache/artifacts/'
        'material_fonts/MaterialIcons-Regular.otf';
    final iconFile = File(iconPath);
    if (iconFile.existsSync()) {
      final bytes = iconFile.readAsBytesSync();
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    // emoji 字体尽力加载（彩色位图字体在部分 Skia 版本不可用，失败则留豆腐块）
    const emojiPath = '/System/Library/Fonts/Apple Color Emoji.ttc';
    final emojiFile = File(emojiPath);
    if (emojiFile.existsSync()) {
      try {
        final bytes = emojiFile.readAsBytesSync();
        final loader = FontLoader('TestEmoji')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      } catch (_) {
        // 忽略：emoji 缺失不影响卡序与文字验收
      }
    }
  });

  setUp(() {
    AppConfig.apiBaseUrlOverride = 'https://test.shunshi.invalid';
    ApiClient.adapterOverride = () => _TestAdapter();
    FlutterSecureStorage.setMockInitialValues({'access_token': 'test-token'});
  });

  tearDown(() {
    AppConfig.apiBaseUrlOverride = null;
    ApiClient.adapterOverride = null;
  });

  // 导出 manifest + 全量 dump（每次运行刷新，内容与基线截图一一对应）
  test('导出 manifest.json 与 story_dump.json 到验收证据目录', () {
    Directory(kEvidenceDir).createSync(recursive: true);
    final records = <Map<String, dynamic>>[];
    for (final story in stories) {
      final sim = sims[story.id]!;
      for (final r in sim.renders) {
        records.add({
          'persona': story.id,
          'personaRole': story.matrixRole,
          'day': r.day,
          'date': r.renderAt.toIso8601String().substring(0, 10),
          'renderAt': r.renderAt.toIso8601String(),
          'goal': r.goal?.name,
          'mutedCategories': r.mutedCategories.map((c) => c.name).toList(),
          'hero': r.hero?.card.id,
          'focusOrder': r.focusOrder,
          'progressOrder': r.progressOrder,
          'heroReasonSummary': r.hero?.reasonSummary ?? '',
          'narrative': r.narrative,
          'screenshot':
              'persona_${story.id.toLowerCase()}_day${r.day}.png',
        });
      }
    }
    File('$kEvidenceDir/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'product': '顺时（国内版 Flutter 客户端）',
        'pipeline': 'flutter test test/personas/persona_golden_test.dart'
            '（19 项要求第 19 项前置；golden 基线在 手机端-Flutter/test/personas/goldens/）',
        'weekStart': '2026-08-24',
        'viewport': {'width': 430, 'height': 1600, 'devicePixelRatio': 1.0},
        'font': 'Arial Unicode.ttf（golden 测试环境注入，供中文可读）',
        'recordCount': records.length,
        'records': records,
      }),
    );

    // 全量 dump：每张卡的分数与理由，供报告与复核
    final dump = <String, dynamic>{};
    for (final story in stories) {
      final sim = sims[story.id]!;
      dump[story.id] = {
        'matrixRole': story.matrixRole,
        'goal': story.goal.name,
        'goalChosenOnDay': story.goalChosenOnDay,
        'totalCompletions': sim.totalCompletions,
        'days': [
          for (final r in sim.renders)
            {
              'day': r.day,
              'renderAt': r.renderAt.toIso8601String(),
              'goal': r.goal?.name,
              'muted': r.mutedCategories.map((c) => c.name).toList(),
              'focusOrder': r.focusOrder,
              'progressOrder': r.progressOrder,
              'cards': {
                for (final id in r.allRendered)
                  id: {
                    'score':
                        double.parse(r.cardOf(id).score.toStringAsFixed(4)),
                    'reasons': r.cardOf(id).reasons,
                  },
              },
            },
        ],
      };
    }
    File('$kEvidenceDir/story_dump.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(dump),
    );
  });

  for (final story in stories) {
    group('persona ${story.id} ${story.matrixRole}', () {
      final sim = sims[story.id]!;
      for (final render in sim.renders) {
        testWidgets('day${render.day} 首页 golden', (tester) async {
          SharedPreferences.setMockInitialValues({
            'onboarding_completed': true,
            'has_seen_guide_cards_v2': true,
            ...sim.storageSeedForRender(render.day),
          });
          tester.view.physicalSize = const Size(430, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: ThemeData(fontFamily: 'TestCJK'),
                home: HomePage(nowOverride: render.renderAt),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(HomePage),
            matchesGoldenFile(
                'goldens/persona_${story.id.toLowerCase()}_day${render.day}.png'),
          );
        });
      }
    });
  }
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
