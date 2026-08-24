// 个性化 v2 本地存储单测 — 行为事件 / 按日期键完成记录
//
// 覆盖：
// - 行为事件写入与读取（含 seen 按天去重）
// - 超保留窗口（30 天）事件自动清理
// - 完成记录按日期键持久化、幂等、跨「启动」可读
// - markCompleted 同时落 completed 行为事件
// - resetProfile 清画像但保留完成历史

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shunshi/data/storage/home_profile_storage.dart';
import 'package:shunshi/domain/services/home_orchestrator.dart';

void main() {
  late HomeProfileStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = HomeProfileStorage();
  });

  group('行为事件', () {
    test('写入后可读回，类型与时间保留', () async {
      final at = DateTime(2026, 8, 22, 20, 30);
      await storage.recordBehavior('breath', HomeBehaviorType.opened, at: at);
      await storage.recordBehavior('food', HomeBehaviorType.seen, at: at);

      final profile =
          await storage.loadBehaviorProfile(now: DateTime(2026, 8, 23, 9));
      expect(profile.events.length, 2);
      expect(profile.openedBeforeToday('breath', DateTime(2026, 8, 23, 9)),
          isTrue);
      expect(
          profile.seenBeforeToday('food', DateTime(2026, 8, 23, 9)), isTrue);
    });

    test('seen 按「卡 + 天」去重，其它类型不去重', () async {
      final day = DateTime(2026, 8, 22, 9);
      await storage.recordBehavior('breath', HomeBehaviorType.seen, at: day);
      await storage.recordBehavior('breath', HomeBehaviorType.seen,
          at: day.add(const Duration(hours: 3)));
      await storage.recordBehavior('breath', HomeBehaviorType.opened, at: day);
      await storage.recordBehavior('breath', HomeBehaviorType.opened,
          at: day.add(const Duration(hours: 1)));

      final profile =
          await storage.loadBehaviorProfile(now: DateTime(2026, 8, 23, 9));
      final seenCount = profile.events
          .where((e) => e.type == HomeBehaviorType.seen)
          .length;
      final openedCount = profile.events
          .where((e) => e.type == HomeBehaviorType.opened)
          .length;
      expect(seenCount, 1);
      expect(openedCount, 2);
    });

    test('超出保留窗口的事件读取时自动清理', () async {
      final old = DateTime(2026, 7, 1, 9); // 远超 30 天窗口
      final recent = DateTime(2026, 8, 22, 9);
      await storage.recordBehavior('old_card', HomeBehaviorType.seen,
          at: DateTime(2026, 8, 20, 9));
      // 手工塞入一条过期事件（recordBehavior 会以写入时间裁剪，绕不开窗口）
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('home_behavior_events')!;
      await prefs.setString(
        'home_behavior_events',
        raw.replaceAll('2026-08-20', '2026-07-01'),
      );

      final profile = await storage.loadBehaviorProfile(now: recent);
      expect(profile.events, isEmpty, reason: '过期事件应被清理');
      // 清理结果已回写
      expect(prefs.getString('home_behavior_events'), '[]');
      expect(old.isBefore(recent), isTrue); // 语义哨兵
    });
  });

  group('完成记录（按日期键）', () {
    test('markCompleted 后按日期可读回，跨启动保留', () async {
      final today = DateTime(2026, 8, 23, 9);
      await storage.markCompleted('solar_term', at: today);
      await storage.markCompleted('rhythm', at: today);

      // 模拟跨启动：换一个新的 storage 实例读同一份 prefs
      final fresh = HomeProfileStorage();
      final done = await fresh.loadCompletionsForDate(today);
      expect(done, containsAll(['solar_term', 'rhythm']));
      // 别的日期读不到
      expect(
        await fresh.loadCompletionsForDate(DateTime(2026, 8, 24, 9)),
        isEmpty,
      );
    });

    test('markCompleted 幂等，且落一条 completed 行为事件', () async {
      final today = DateTime(2026, 8, 23, 9);
      await storage.markCompleted('breath', at: today);
      await storage.markCompleted('breath', at: today);

      expect(await storage.loadCompletionsForDate(today), {'breath'});
      final profile = await storage.loadBehaviorProfile(now: today);
      expect(
        profile.events
            .where((e) => e.type == HomeBehaviorType.completed)
            .length,
        1,
        reason: '重复 markCompleted 不应重复落行为事件',
      );
      expect(profile.completedToday('breath', today), isTrue);
      expect(profile.completedYesterday('breath', today), isFalse);
      expect(
        profile.completedYesterday('breath', today.add(const Duration(days: 1))),
        isTrue,
      );
    });

    test('resetProfile 清画像与行为，但保留完成历史', () async {
      final today = DateTime(2026, 8, 23, 9);
      await storage.saveGoal(HomeGoal.sleep);
      await storage.muteCategory(HomeCardCategory.family);
      await storage.recordBehavior('breath', HomeBehaviorType.seen, at: today);
      await storage.markCompleted('breath', at: today);

      await storage.resetProfile();

      expect(await storage.loadGoal(), isNull);
      expect(await storage.loadMutedCategories(), isEmpty);
      expect(
        (await storage.loadBehaviorProfile(now: today)).events,
        isEmpty,
      );
      expect(await storage.loadCompletionsForDate(today), {'breath'});
    });
  });
}
