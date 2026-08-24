// 个性化 v2 单测 — 行为反馈入分 / 完成退出前排 / 连续两天可解释差异
//
// 覆盖 19 项要求第 13/15 项深化：
// - 看过 → 降新颖性（分数下降，且不再给「换个新内容」理由）
// - 点开过 → 相关性上调（理由透出「你之前点开过」）
// - 今日完成 → 退出前排（不进 Hero/今日重点）
// - 昨天完成 → 今日让位 + Hero 理由「昨天你完成了 X，今天推荐 Y」
// - 同一天同一画像可复现；不同行为产生可解释差异

import 'package:flutter_test/flutter_test.dart';
import 'package:shunshi/domain/services/home_orchestrator.dart';

void main() {
  const orchestrator = HomeOrchestrator();

  List<HomeCardCandidate> candidates() => const [
        HomeCardCandidate(
          id: 'solar_term',
          category: HomeCardCategory.solarTerm,
          conclusion: '处暑：润燥养阴',
          why: '处暑出暑，秋意渐浓。',
          goalTags: {HomeGoal.diet, HomeGoal.energy, HomeGoal.sleep},
          actionability: 0.8,
          confidence: 0.9,
          actionLabel: '今天照做',
        ),
        HomeCardCandidate(
          id: 'rhythm',
          category: HomeCardCategory.rhythm,
          conclusion: '今日作息：早睡早起',
          why: '顺应天时，身体最省力。',
          goalTags: {HomeGoal.sleep, HomeGoal.energy, HomeGoal.calm},
          actionability: 0.7,
          confidence: 0.9,
          actionLabel: '今天照做',
        ),
        HomeCardCandidate(
          id: 'breath',
          category: HomeCardCategory.breath,
          conclusion: '花 5 分钟，做一次深呼吸',
          why: '吸气4秒 · 停顿4秒 · 呼气6秒',
          goalTags: {HomeGoal.calm, HomeGoal.sleep},
          actionability: 0.9,
          confidence: 0.7,
          actionLabel: '去做',
        ),
        HomeCardCandidate(
          id: 'food',
          category: HomeCardCategory.food,
          conclusion: '喝点温热的，暖暖胃',
          why: '暖胃养血，适合这个时节',
          goalTags: {HomeGoal.diet},
          actionability: 0.9,
          confidence: 0.7,
          actionLabel: '去做',
        ),
        HomeCardCandidate(
          id: 'progress_today',
          category: HomeCardCategory.progress,
          layer: HomeCardLayer.progress,
          conclusion: '今日已完成 0 件小行动',
          why: '从最简单的一件开始就好。',
          confidence: 1.0,
        ),
      ];

  List<RankedHomeCard> allCards(OrchestratedHome r) => [
        if (r.hero != null) r.hero!,
        ...r.focus,
        ...r.progress,
      ];

  RankedHomeCard cardOf(OrchestratedHome r, String id) =>
      allCards(r).firstWhere((x) => x.card.id == id);

  List<String> focusOrder(OrchestratedHome r) => [
        if (r.hero != null) r.hero!.card.id,
        ...r.focus.map((x) => x.card.id),
      ];

  group('行为入分：看过降新颖性', () {
    test('历史看过的卡分数下降，且不再给「换个新内容」理由', () {
      final now = DateTime(2026, 8, 23, 9);
      final fresh = orchestrator.orchestrate(
        OrchestrationInput(
            now: now, goal: HomeGoal.calm, candidates: candidates()),
      );
      final seenProfile = HomeBehaviorProfile([
        HomeBehaviorEvent(
          cardId: 'breath',
          type: HomeBehaviorType.seen,
          at: DateTime(2026, 8, 22, 9),
        ),
      ]);
      final seen = orchestrator.orchestrate(
        OrchestrationInput(
          now: now,
          goal: HomeGoal.calm,
          candidates: candidates(),
          behavior: seenProfile,
        ),
      );

      expect(
        cardOf(seen, 'breath').score,
        lessThan(cardOf(fresh, 'breath').score),
        reason: '看过的卡新颖性 ×0.3，总分应下降',
      );
      // 未看过的卡分数不受影响
      expect(
        cardOf(seen, 'food').score,
        cardOf(fresh, 'food').score,
      );
    });

    test('今天刚展示的 seen 不算「看过旧内容」，分数不变', () {
      final now = DateTime(2026, 8, 23, 9);
      final base = orchestrator.orchestrate(
        OrchestrationInput(
            now: now, goal: HomeGoal.calm, candidates: candidates()),
      );
      final sameDaySeen = orchestrator.orchestrate(
        OrchestrationInput(
          now: now,
          goal: HomeGoal.calm,
          candidates: candidates(),
          behavior: HomeBehaviorProfile([
            HomeBehaviorEvent(
              cardId: 'breath',
              type: HomeBehaviorType.seen,
              at: DateTime(2026, 8, 23, 8),
            ),
          ]),
        ),
      );
      expect(cardOf(sameDaySeen, 'breath').score, cardOf(base, 'breath').score);
    });
  });

  group('行为入分：点开过相关性上调', () {
    test('历史点开过的卡分数上升，理由透出「你之前点开过」', () {
      final now = DateTime(2026, 8, 23, 9);
      final base = orchestrator.orchestrate(
        OrchestrationInput(
            now: now, goal: HomeGoal.calm, candidates: candidates()),
      );
      final opened = orchestrator.orchestrate(
        OrchestrationInput(
          now: now,
          goal: HomeGoal.calm,
          candidates: candidates(),
          behavior: HomeBehaviorProfile([
            HomeBehaviorEvent(
              cardId: 'food',
              type: HomeBehaviorType.opened,
              at: DateTime(2026, 8, 21, 20),
            ),
          ]),
        ),
      );

      expect(
        cardOf(opened, 'food').score,
        greaterThan(cardOf(base, 'food').score),
      );
      expect(
        cardOf(opened, 'food').reasons.any((r) => r.contains('你之前点开过')),
        isTrue,
      );
      // 其他卡不受影响
      expect(cardOf(opened, 'breath').score, cardOf(base, 'breath').score);
    });
  });

  group('完成状态：今日完成退出前排', () {
    test('今日已完成的卡不进 Hero/今日重点', () {
      final now = DateTime(2026, 8, 23, 9);
      final base = orchestrator.orchestrate(
        OrchestrationInput(
            now: now, goal: HomeGoal.calm, candidates: candidates()),
      );
      // 先确认 hero 在无行为时存在且属于前排
      expect(base.hero, isNotNull);
      final heroId = base.hero!.card.id;

      final completed = orchestrator.orchestrate(
        OrchestrationInput(
          now: now,
          goal: HomeGoal.calm,
          candidates: candidates(),
          behavior: HomeBehaviorProfile([
            HomeBehaviorEvent(
              cardId: heroId,
              type: HomeBehaviorType.completed,
              at: DateTime(2026, 8, 23, 8),
            ),
          ]),
        ),
      );

      expect(focusOrder(completed).contains(heroId), isFalse,
          reason: '今日已完成的卡应退出前排');
      expect(completed.hero, isNotNull);
      expect(completed.hero!.card.id, isNot(heroId));
    });
  });

  group('Day 2 重排序：昨天行为影响今天', () {
    test('昨天完成的卡今天分数被压低，Hero 透出承接理由', () {
      final day2 = DateTime(2026, 8, 24, 9);
      final day1Behavior = HomeBehaviorProfile([
        HomeBehaviorEvent(
          cardId: 'solar_term',
          type: HomeBehaviorType.completed,
          at: DateTime(2026, 8, 23, 10),
        ),
      ]);

      final withoutHistory = orchestrator.orchestrate(
        OrchestrationInput(
            now: day2, goal: HomeGoal.calm, candidates: candidates()),
      );
      final withHistory = orchestrator.orchestrate(
        OrchestrationInput(
          now: day2,
          goal: HomeGoal.calm,
          candidates: candidates(),
          behavior: day1Behavior,
        ),
      );

      // 昨天完成的卡今天新颖性 ×0.2 → 分数下降
      expect(
        cardOf(withHistory, 'solar_term').score,
        lessThan(cardOf(withoutHistory, 'solar_term').score),
      );
      // Hero 给出可解释的承接理由「昨天你完成了 X，今天推荐 Y」
      final hero = withHistory.hero!;
      expect(
        hero.reasons.any((r) =>
            r.startsWith('昨天你完成了') && r.contains('，今天推荐')),
        isTrue,
        reason: 'Day 2 Hero 应解释与昨天行为的承接关系',
      );
    });

    test('第一天行为让第二天卡序产生可解释差异', () {
      final day2 = DateTime(2026, 8, 24, 9);

      // Day 1（8-23）行为：看过 breath、完成 solar_term、点开 food
      final day1Behavior = HomeBehaviorProfile([
        HomeBehaviorEvent(
          cardId: 'breath',
          type: HomeBehaviorType.seen,
          at: DateTime(2026, 8, 23, 12),
        ),
        HomeBehaviorEvent(
          cardId: 'solar_term',
          type: HomeBehaviorType.completed,
          at: DateTime(2026, 8, 23, 12),
        ),
        HomeBehaviorEvent(
          cardId: 'food',
          type: HomeBehaviorType.opened,
          at: DateTime(2026, 8, 23, 12),
        ),
      ]);

      // Day 2：同一批候选，分别用空画像与 Day 1 画像编排
      final d2Baseline = orchestrator.orchestrate(
        OrchestrationInput(
            now: day2, goal: HomeGoal.calm, candidates: candidates()),
      );
      final d2 = orchestrator.orchestrate(
        OrchestrationInput(
          now: day2,
          goal: HomeGoal.calm,
          candidates: candidates(),
          behavior: day1Behavior,
        ),
      );

      // 卡序应不同：昨天完成的 solar_term 让位、点开过的 food 前移
      expect(focusOrder(d2), isNot(focusOrder(d2Baseline)),
          reason: '第一天行为应让第二天卡序产生可解释变化');

      // 差异可解释：opened 的分数升高、seen / 昨天完成的分数降低
      expect(cardOf(d2, 'food').score,
          greaterThan(cardOf(d2Baseline, 'food').score));
      expect(cardOf(d2, 'breath').score,
          lessThan(cardOf(d2Baseline, 'breath').score));
      expect(cardOf(d2, 'solar_term').score,
          lessThan(cardOf(d2Baseline, 'solar_term').score));
      // 未受行为影响的 rhythm 分数不变
      expect(cardOf(d2, 'rhythm').score, cardOf(d2Baseline, 'rhythm').score);
    });

    test('同一天同一画像排序可复现', () {
      final now = DateTime(2026, 8, 24, 9);
      final profile = HomeBehaviorProfile([
        HomeBehaviorEvent(
          cardId: 'breath',
          type: HomeBehaviorType.opened,
          at: DateTime(2026, 8, 23, 12),
        ),
        HomeBehaviorEvent(
          cardId: 'food',
          type: HomeBehaviorType.completed,
          at: DateTime(2026, 8, 24, 8),
        ),
      ]);
      List<String> order() => focusOrder(orchestrator.orchestrate(
            OrchestrationInput(
              now: now,
              goal: HomeGoal.sleep,
              candidates: candidates(),
              behavior: profile,
            ),
          ));
      expect(order(), order());
    });

    test('昨天的完成记录不影响昨天的编排（时间方向正确）', () {
      final day1 = DateTime(2026, 8, 23, 9);
      final profile = HomeBehaviorProfile([
        HomeBehaviorEvent(
          cardId: 'breath',
          type: HomeBehaviorType.completed,
          at: DateTime(2026, 8, 23, 12), // 当天晚些时候才完成
        ),
      ]);
      final withFuture = orchestrator.orchestrate(
        OrchestrationInput(
          now: day1,
          goal: HomeGoal.calm,
          candidates: candidates(),
          behavior: profile,
        ),
      );
      // 同一天 completedToday 成立 → breath 退出前排
      expect(focusOrder(withFuture).contains('breath'), isFalse);
      // 但不会因为「昨天完成」被压分（它不在昨天）——与同日无行为基线比较
      final day0 = DateTime(2026, 8, 22, 9);
      final base0 = orchestrator.orchestrate(
        OrchestrationInput(
            now: day0, goal: HomeGoal.calm, candidates: candidates()),
      );
      final beforeIt = orchestrator.orchestrate(
        OrchestrationInput(
          now: day0,
          goal: HomeGoal.calm,
          candidates: candidates(),
          behavior: profile,
        ),
      );
      expect(cardOf(beforeIt, 'breath').score, cardOf(base0, 'breath').score,
          reason: '8-22 编排时 8-23 的完成尚未发生，分数应与无行为基线一致');
    });
  });

  group('画像查询边界', () {
    test('空画像时所有行为查询为 false（v1 行为兼容）', () {
      const profile = HomeBehaviorProfile();
      final now = DateTime(2026, 8, 23, 9);
      expect(profile.completedToday('breath', now), isFalse);
      expect(profile.completedYesterday('breath', now), isFalse);
      expect(profile.seenBeforeToday('breath', now), isFalse);
      expect(profile.openedBeforeToday('breath', now), isFalse);
    });
  });
}
