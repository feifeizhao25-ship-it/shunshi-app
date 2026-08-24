// 5 用户 × 7 天首页状态递进驱动测试（19 项要求第 19 项前置）
//
// 断言对象是「状态递进」而非文案变化：
// - Day 1：选定目标后 Hero 即贴合目标（E 未选目标 → 目标引导态）
// - Day 2：按首日行为重排 —— 点开过的卡透出「你之前点开过」，
//   昨天完成过且未蝉联 Hero 时透出「昨天你完成了 X，今天推荐 Y」
// - Day 3-5：个人基线 —— 前排稳定到各自目标相关卡，理由可解释
// - Day 4：C 傍晚无行动 → 进展层出现「今天还没行动」异常提醒
// - Day 6：E 第二次关闭类别生效（纠错画像）
// - Day 7：每人前排与 Day 1 显著不同且各自稳定，差异可解释
// - 跨 persona 同日：5 人卡序互不相同，差异可归因到目标/行为/关闭类别
//
// 吸引力代理指标（首要任务完成、推荐采纳、纠错/关闭）在本测试中计算并锚定，
// 同一批数字导出到 验收证据/顺时/personas/story_dump.json 供报告引用。

import 'package:flutter_test/flutter_test.dart';
import 'package:shunshi/domain/services/home_orchestrator.dart';

import 'persona_story.dart';

void main() {
  final stories = loadPersonaStories();
  final sims = {for (final s in stories) s.id: simulatePersonaWeek(s)};

  PersonaWeekSimulation sim(String id) => sims[id]!;

  bool hasReason(RankedHomeCard? card, String needle) =>
      card != null && card.reasons.any((r) => r.contains(needle));

  /// 昨天完成过、且今天 Hero 不是昨天完成的那张 → Hero 必须透出承接理由
  void expectContinuationReason(PersonaDayRender render, List<String> doneYesterday) {
    if (doneYesterday.isEmpty) return;
    final hero = render.hero!;
    if (doneYesterday.contains(hero.card.id)) return; // 蝉联不加承接理由（引擎语义）
    expect(
      hero.reasons.any(
          (r) => r.startsWith('昨天你完成了') && r.contains('，今天推荐')),
      isTrue,
      reason: 'Day ${render.day} Hero 应解释与昨天行为的承接关系',
    );
  }

  group('数据包完整性', () {
    test('5 个 persona × 7 天，日期连续，事件格式与存储层对齐', () {
      expect(stories.length, 5);
      const knownCardIds = {
        'solar_term', 'rhythm', 'family', 'chat',
        'breath', 'food', 'exercise', 'anomaly_inactive',
      };
      for (final story in stories) {
        expect(story.days.length, 7, reason: '${story.id} 应有 7 天');
        for (var i = 0; i < 7; i++) {
          final day = story.days[i];
          expect(day.day, i + 1);
          if (i > 0) {
            expect(
              day.date.difference(story.days[i - 1].date).inDays,
              1,
              reason: '${story.id} 日期应连续',
            );
          }
          for (final e in day.events) {
            expect(knownCardIds, contains(e.cardId),
                reason: '${story.id} Day${day.day} 事件引用了未知卡 ${e.cardId}');
            // 事件必须发生在当天渲染之后（Day N 渲染只受 1..N-1 行为影响）
            expect(e.at.isAfter(day.renderAt), isTrue,
                reason: '${story.id} Day${day.day} 事件应发生在渲染之后');
          }
        }
      }
    });

    test('同一天同一画像结果可复现（模拟两次卡序一致）', () {
      for (final story in stories) {
        final again = simulatePersonaWeek(story);
        for (var d = 1; d <= 7; d++) {
          expect(again.renderOf(d).focusOrder, sim(story.id).renderOf(d).focusOrder);
        }
      }
    });
  });

  group('通用状态递进规则', () {
    test('Day 2 起：点开过的卡透出「你之前点开过」，承接理由按规则出现', () {
      for (final story in stories) {
        final s = sim(story.id);
        for (var d = 2; d <= 7; d++) {
          final render = s.renderOf(d);
          // 历史点开过且当天仍展示的卡，理由必须透出（未被关闭）
          final openedBefore = s.allEvents
              .where((e) =>
                  e.type == HomeBehaviorType.opened &&
                  e.at.isBefore(render.renderAt))
              .map((e) => e.cardId)
              .toSet();
          for (final id in openedBefore) {
            if (render.allRendered.contains(id)) {
              expect(hasReason(render.cardOf(id), '你之前点开过'), isTrue,
                  reason: '${story.id} Day$d 的 $id 应透出点开过理由');
            }
          }
          // 承接理由
          final doneYesterday = s.allEvents
              .where((e) =>
                  e.type == HomeBehaviorType.completed &&
                  e.at.isAfter(render.renderAt
                      .subtract(const Duration(days: 1))
                      .copyWith(hour: 0, minute: 0)) &&
                  e.at.isBefore(render.renderAt))
              .map((e) => e.cardId)
              .toList();
          expectContinuationReason(render, doneYesterday);
        }
      }
    });

    test('Day 7 前排与 Day 1 不同：一周行为让首页产生递进，不是原地踏步', () {
      for (final story in stories) {
        final s = sim(story.id);
        expect(s.renderOf(7).focusOrder, isNot(s.renderOf(1).focusOrder),
            reason: '${story.id} 一周后前排应与首日不同');
      }
    });

    test('选了目标的 persona，Hero 始终贴合其目标（或通用卡）', () {
      for (final story in stories) {
        final s = sim(story.id);
        for (var d = story.goalChosenOnDay; d <= 7; d++) {
          final hero = s.renderOf(d).hero!;
          expect(
            hero.card.goalTags.isEmpty ||
                hero.card.goalTags.contains(story.goal),
            isTrue,
            reason: '${story.id} Day$d Hero=${hero.card.id} 应贴合目标',
          );
        }
      }
    });
  });

  group('A 想改善作息的新手（sleep）', () {
    test('Day1 节律为 Hero → Day4 透出承接 → Day5 作息让位节气 → Day7 点开过的食疗进前排', () {
      final s = sim('A');
      expect(s.renderOf(1).hero!.card.id, 'rhythm');
      expect(hasReason(s.renderOf(2).hero, '你之前点开过'), isTrue);
      expect(hasReason(s.renderOf(4).hero, '昨天你完成了呼吸放松'), isTrue);
      // Day4 完成了作息 → Day5 作息让位，节气成为 Hero 并透出承接
      expect(s.renderOf(5).hero!.card.id, 'solar_term');
      expect(hasReason(s.renderOf(5).hero, '昨天你完成了今日节律'), isTrue);
      // Day6 点开过食疗 → Day7 食疗被相关性上调进前排
      expect(s.renderOf(6).focusOrder, isNot(contains('food')));
      expect(s.renderOf(7).focusOrder, contains('food'));
      expect(hasReason(s.renderOf(7).cardOf('food'), '你之前点开过'), isTrue);
      expect(s.totalCompletions, 9);
    });
  });

  group('B 健康/成长教练（energy）', () {
    test('首日深查 7 张卡 → 运动常驻前排 → 承接理由连续透出', () {
      final s = sim('B');
      final opened = s.allEvents
          .where((e) => e.type == HomeBehaviorType.opened)
          .map((e) => e.cardId)
          .toSet();
      expect(opened.length, greaterThanOrEqualTo(6),
          reason: '专业者首日应点开评估大部分卡片');
      for (var d = 2; d <= 7; d++) {
        expect(s.renderOf(d).focusOrder, contains('exercise'),
            reason: 'B Day$d 运动应在前排');
        expect(hasReason(s.renderOf(d).cardOf('exercise'), '你之前点开过'), isTrue);
      }
      expect(hasReason(s.renderOf(2).hero, '昨天你完成了轻运动'), isTrue);
      expect(s.renderOf(5).hero!.card.id, 'solar_term');
      expect(s.totalCompletions, 13);
    });
  });

  group('C 家庭组织者（family）', () {
    test('家庭关怀 7 天蝉联 Hero；Day4 傍晚无行动触发异常提醒并被采纳', () {
      final s = sim('C');
      for (var d = 1; d <= 7; d++) {
        expect(s.renderOf(d).hero!.card.id, 'family',
            reason: 'C Day$d Hero 应为家庭关怀');
      }
      // Day1 点开食疗 → Day2 食疗升至第 2 位
      expect(s.renderOf(2).focusOrder[1], 'food');
      // Day4 傍晚渲染：进展层出现「今天还没行动」异常卡
      expect(s.renderOf(4).renderAt.hour, greaterThanOrEqualTo(18));
      expect(s.renderOf(4).progressOrder, contains('anomaly_inactive'));
      // 异常建议被采纳：当晚完成了呼吸 → Day5 Hero 透出承接
      expect(hasReason(s.renderOf(5).hero, '昨天你完成了呼吸放松'), isTrue);
      expect(s.totalCompletions, 10);
    });
  });

  group('D 习惯打卡用户（energy）', () {
    test('7 天 21 件全勤；Hero 在 Day5 从节律切换为节气，前排第 4 位轮换新内容', () {
      final s = sim('D');
      expect(s.totalCompletions, 21);
      final byDate = s.completionsByDate();
      expect(byDate.length, 7);
      for (final ids in byDate.values) {
        expect(ids.length, 3, reason: 'D 每天打卡 3 件');
      }
      for (var d = 1; d <= 4; d++) {
        expect(s.renderOf(d).hero!.card.id, 'rhythm');
      }
      for (var d = 5; d <= 7; d++) {
        expect(s.renderOf(d).hero!.card.id, 'solar_term');
        expect(hasReason(s.renderOf(d).hero, '昨天你完成了今日节律'), isTrue);
      }
      // 前排第 4 位在没见过的新卡之间轮换（新颖性驱动）
      final fourth = [2, 3, 4].map((d) => s.renderOf(d).focusOrder[3]).toSet();
      expect(fourth.length, 3, reason: 'D Day2-4 前排第 4 位应每天不同');
    });
  });

  group('E 隐私敏感用户（calm，Day3 才选目标）', () {
    test('前两天目标引导态 → Day3 选目标 → 关闭 AI 陪伴/家庭关怀后永久消失', () {
      final s = sim('E');
      // Day1-2 未选目标：首页应处于目标引导态（goal == null）
      expect(s.renderOf(1).goal, isNull);
      expect(s.renderOf(2).goal, isNull);
      expect(s.renderOf(3).goal, HomeGoal.calm);
      // Day3 关闭 chat → Day4 起 AI 陪伴卡不再出现
      expect(s.renderOf(3).allRendered, contains('chat'));
      for (var d = 4; d <= 7; d++) {
        expect(s.renderOf(d).allRendered, isNot(contains('chat')),
            reason: 'E Day$d 不应再出现已关闭的 AI 陪伴');
      }
      // Day6 关闭 family → Day7 家庭关怀不再出现（Day2 未选目标时它曾进过前排）
      expect(s.renderOf(2).allRendered, contains('family'));
      expect(s.renderOf(7).allRendered, isNot(contains('family')));
      expect(s.renderOf(7).mutedCategories,
          {HomeCardCategory.chat, HomeCardCategory.family});
      // 选目标后 Hero 透出对呼吸打卡的承接
      expect(hasReason(s.renderOf(3).hero, '昨天你完成了呼吸放松'), isTrue);
      expect(s.totalCompletions, 7);
    });
  });

  group('跨 persona 同日差异（可解释）', () {
    test('Day3 五人的前排卡序互不相同', () {
      final orders =
          stories.map((s) => sim(s.id).renderOf(3).focusOrder.join(',')).toSet();
      expect(orders.length, 5, reason: 'Day3 五个 persona 的前排卡序应全部不同');
    });

    test('Day3：C 的 Hero 是家庭关怀，其余四人都不是（目标不同）', () {
      expect(sim('C').renderOf(3).hero!.card.id, 'family');
      for (final id in ['A', 'B', 'D', 'E']) {
        expect(sim(id).renderOf(3).hero!.card.id, isNot('family'));
      }
    });

    test('Day3：B 点开过家庭关怀 → 进前排并透出理由；D 没点开过 → 不进前排（同目标异行为）', () {
      final b = sim('B').renderOf(3);
      final d = sim('D').renderOf(3);
      expect(b.focusOrder, contains('family'));
      expect(hasReason(b.cardOf('family'), '你之前点开过'), isTrue,
          reason: '差异来源是 B Day2 点开了家庭关怀（相关性 +0.15）');
      expect(d.focusOrder, isNot(contains('family')));
    });

    test('Day7：E 的首页没有 AI 陪伴与家庭关怀，其余四人的候选未被裁剪', () {
      final e = sim('E').renderOf(7);
      expect(e.allRendered, isNot(contains('chat')));
      expect(e.allRendered, isNot(contains('family')));
      // A/B/C/D 未关闭任何类别：焦点候选 7 张卡全在编排池中
      for (final id in ['A', 'B', 'C', 'D']) {
        expect(sim(id).renderOf(7).mutedCategories, isEmpty);
      }
      // 同日对比：C 的 Hero 是家庭关怀，E 连这张卡都看不到 —— 最直观的差异
      expect(sim('C').renderOf(7).hero!.card.id, 'family');
    });
  });

  group('吸引力代理指标（可观测，不含留存数字）', () {
    // 首日 Hero 是否被当天完成（首要任务完成率的客户端代理）
    int heroAdoptionDays(PersonaWeekSimulation s) {
      var count = 0;
      for (var d = 1; d <= 7; d++) {
        final heroId = s.renderOf(d).hero!.card.id;
        final adopted = s.story.days[d - 1].events.any(
            (e) => e.cardId == heroId && e.type == HomeBehaviorType.completed);
        if (adopted) count++;
      }
      return count;
    }

    // 当天完成过任意一张前排卡（推荐采纳率的客户端代理）
    int focusAdoptionDays(PersonaWeekSimulation s) {
      var count = 0;
      for (var d = 1; d <= 7; d++) {
        final focus = s.renderOf(d).focusOrder.toSet();
        final adopted = s.story.days[d - 1].events.any(
            (e) => focus.contains(e.cardId) && e.type == HomeBehaviorType.completed);
        if (adopted) count++;
      }
      return count;
    }

    test('五个 persona 的 Hero/前排采纳与纠错行为被确定性地观测到', () {
      // Hero 采纳天数：A 3/7（Day1/2/4 完成当天的节律 Hero），C 6/7（仅 Day4 漏），
      // D 4/7（Day5 起 Hero 换成节气后他只打卡不点 Hero），E 1/7（Day7 完成当晚 Hero），
      // B 0/7 —— B/E 完成的是前排非 Hero 卡，差异本身就是报告素材
      expect(heroAdoptionDays(sim('A')), 3);
      expect(heroAdoptionDays(sim('B')), 0);
      expect(heroAdoptionDays(sim('C')), 6);
      expect(heroAdoptionDays(sim('D')), 4);
      expect(heroAdoptionDays(sim('E')), 1);
      // 前排采纳天数：A/B/C/D 每天完成前排卡；E Day1 纯观察、
      // Day2 完成呼吸时呼吸卡尚未进前排（未选目标），共 5 天
      expect(focusAdoptionDays(sim('A')), 7);
      expect(focusAdoptionDays(sim('B')), 7);
      expect(focusAdoptionDays(sim('C')), 7);
      expect(focusAdoptionDays(sim('D')), 7);
      expect(focusAdoptionDays(sim('E')), 5);
      // 纠错/关闭行为：只有 E 使用了「不再推荐此类」（2 次）
      expect(sim('E').renderOf(7).mutedCategories.length, 2);
      for (final id in ['A', 'B', 'C', 'D']) {
        expect(sim(id).renderOf(7).mutedCategories, isEmpty);
      }
    });
  });
}
