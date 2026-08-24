// 首页编排引擎单测
//
// 覆盖 19 项要求第 13/15 项的可解释个性化约束：
// - 不同目标产生不同排序
// - 不同日期产生不同排序（新颖性轮换）
// - 推荐理由可解释（目标匹配/紧迫性/新颖性透出）
// - 关闭某类推荐生效
// - 权重与分层数量约束（Hero 1 / 重点 ≤3 / 进展 ≤2）

import 'package:flutter_test/flutter_test.dart';
import 'package:shunshi/domain/services/home_orchestrator.dart';

void main() {
  const orchestrator = HomeOrchestrator();

  /// 与首页一致的候选卡骨架（文案简化，结构相同）
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
          id: 'family',
          category: HomeCardCategory.family,
          conclusion: '给家人也泡一杯罗汉果茶',
          why: '照顾自己，也照顾身边人。',
          goalTags: {HomeGoal.family},
          actionability: 0.6,
          confidence: 0.8,
          actionLabel: '记下了',
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
        HomeCardCandidate(
          id: 'anomaly_inactive',
          category: HomeCardCategory.anomaly,
          layer: HomeCardLayer.progress,
          conclusion: '今天还没行动，从 1 分钟呼吸开始',
          why: '呼吸是最轻的开始。',
          actionability: 0.9,
          confidence: 1.0,
          actionLabel: '呼吸 1 分钟',
        ),
      ];

  group('分层结构', () {
    test('Hero 恰 1 张、今日重点 ≤3、进展与异常 ≤2，且互不重叠', () {
      final result = orchestrator.orchestrate(
        OrchestrationInput(
          now: DateTime(2026, 8, 23, 9),
          goal: HomeGoal.sleep,
          candidates: candidates(),
        ),
      );

      expect(result.hero, isNotNull);
      expect(result.focus.length, lessThanOrEqualTo(3));
      expect(result.progress.length, lessThanOrEqualTo(2));

      final ids = [
        result.hero!.card.id,
        ...result.focus.map((r) => r.card.id),
        ...result.progress.map((r) => r.card.id),
      ];
      expect(ids.toSet().length, ids.length, reason: '卡片不应跨层重复');
      // 进展层卡片只来自 progress 层候选
      for (final r in result.progress) {
        expect(r.card.layer, HomeCardLayer.progress);
      }
    });

    test('候选按分数降序排列', () {
      final result = orchestrator.orchestrate(
        OrchestrationInput(
          now: DateTime(2026, 8, 23, 9),
          goal: HomeGoal.calm,
          candidates: candidates(),
        ),
      );
      final scores = [
        result.hero!.score,
        ...result.focus.map((r) => r.score),
      ];
      for (var i = 0; i + 1 < scores.length; i++) {
        expect(scores[i], greaterThanOrEqualTo(scores[i + 1]));
      }
    });
  });

  group('个性化：不同目标产生不同排序', () {
    test('家庭目标把家庭关怀卡排进前列，饮食目标则不会', () {
      final now = DateTime(2026, 8, 23, 9);
      final familyResult = orchestrator.orchestrate(
        OrchestrationInput(
          now: now,
          goal: HomeGoal.family,
          candidates: candidates(),
        ),
      );
      final dietResult = orchestrator.orchestrate(
        OrchestrationInput(
          now: now,
          goal: HomeGoal.diet,
          candidates: candidates(),
        ),
      );

      double scoreOf(OrchestratedHome r, String id) {
        final all = [if (r.hero != null) r.hero!, ...r.focus, ...r.progress];
        return all.firstWhere((x) => x.card.id == id).score;
      }

      // 同一张家庭卡：family 目标下相关性拉满，diet 目标下相关性垫底
      expect(
        scoreOf(familyResult, 'family'),
        greaterThan(scoreOf(dietResult, 'family')),
      );
      // 饮食目标下食疗卡得分高于其在家庭目标下的得分
      expect(
        scoreOf(dietResult, 'food'),
        greaterThan(scoreOf(familyResult, 'food')),
      );
    });

    test('未选目标时所有卡相关性一致（0.5），不产生目标偏向', () {
      final result = orchestrator.orchestrate(
        OrchestrationInput(
          now: DateTime(2026, 8, 23, 9),
          candidates: candidates(),
        ),
      );
      final all = [result.hero!, ...result.focus];
      // 无目标时不应出现「贴合目标」类理由
      for (final r in all) {
        expect(
          r.reasons.where((reason) => reason.contains('贴合你的目标')),
          isEmpty,
        );
      }
    });
  });

  group('个性化：不同日期产生不同排序', () {
    test('相邻两天的新颖性轮换改变卡序', () {
      List<String> orderFor(DateTime now) {
        final result = orchestrator.orchestrate(
          OrchestrationInput(
            now: now,
            goal: HomeGoal.calm,
            candidates: candidates(),
          ),
        );
        return [result.hero!.card.id, ...result.focus.map((r) => r.card.id)];
      }

      final day1 = orderFor(DateTime(2026, 8, 23, 9));
      final day2 = orderFor(DateTime(2026, 8, 24, 9));
      final day3 = orderFor(DateTime(2026, 8, 25, 9));

      // 三天里至少有一天顺序不同（新颖性哈希按日轮换）
      final allSame = day1.toString() == day2.toString() &&
          day2.toString() == day3.toString();
      expect(allSame, isFalse, reason: '不同日期应产生可解释的卡序差异');
    });

    test('同一天内排序稳定（可复现）', () {
      final now = DateTime(2026, 8, 23, 9);
      List<String> order() => [
            orchestrator
                .orchestrate(
                  OrchestrationInput(
                      now: now, goal: HomeGoal.sleep, candidates: candidates()),
                )
                .hero!
                .card
                .id,
            ...orchestrator
                .orchestrate(
                  OrchestrationInput(
                      now: now, goal: HomeGoal.sleep, candidates: candidates()),
                )
                .focus
                .map((r) => r.card.id),
          ];
      expect(order(), order());
    });

    test('节气临近换日时紧迫性上升', () {
      // 14 日（次日换节气）vs 1 日（刚换完）
      final nearChange = orchestrator.orchestrate(
        OrchestrationInput(
          now: DateTime(2026, 8, 14, 9),
          goal: HomeGoal.sleep,
          candidates: candidates(),
        ),
      );
      final justChanged = orchestrator.orchestrate(
        OrchestrationInput(
          now: DateTime(2026, 8, 1, 9),
          goal: HomeGoal.sleep,
          candidates: candidates(),
        ),
      );

      double solarScore(OrchestratedHome r) => [
            if (r.hero != null) r.hero!,
            ...r.focus,
            ...r.progress,
          ].firstWhere((x) => x.card.id == 'solar_term').score;

      expect(solarScore(nearChange), greaterThan(solarScore(justChanged)));
    });
  });

  group('推荐理由可解释', () {
    test('目标匹配的卡给出「贴合你的目标」理由', () {
      final result = orchestrator.orchestrate(
        OrchestrationInput(
          now: DateTime(2026, 8, 23, 9),
          goal: HomeGoal.family,
          candidates: candidates(),
        ),
      );
      final all = [result.hero!, ...result.focus, ...result.progress];
      final family = all.firstWhere((r) => r.card.id == 'family');
      expect(
        family.reasons.any((r) => r.contains('贴合你的目标「照顾好家人」')),
        isTrue,
      );
      expect(family.reasonSummary, isNotEmpty);
    });

    test('无任何突出因子时回退到通用理由，reasonSummary 不为空', () {
      const card = HomeCardCandidate(
        id: 'plain',
        category: HomeCardCategory.chat,
        conclusion: '有心事，和顺时聊聊',
        why: '顺时一直在。',
        // 无目标标签、晚间时段、无行动按钮 → 各因子都不突出
      );
      final result = orchestrator.orchestrate(
        OrchestrationInput(
          now: DateTime(2026, 8, 2, 22),
          candidates: [card],
        ),
      );
      expect(result.hero!.reasons, isEmpty);
      expect(result.hero!.reasonSummary, '综合你今天的节气与时间安排推荐');
    });
  });

  group('类别屏蔽', () {
    test('关闭某类推荐后该类别卡片完全消失', () {
      final result = orchestrator.orchestrate(
        OrchestrationInput(
          now: DateTime(2026, 8, 23, 9),
          goal: HomeGoal.family,
          candidates: candidates(),
          mutedCategories: const {HomeCardCategory.family},
        ),
      );
      final ids = [
        result.hero!.card.id,
        ...result.focus.map((r) => r.card.id),
        ...result.progress.map((r) => r.card.id),
      ];
      expect(ids.contains('family'), isFalse);
    });

    test('屏蔽全部 focus 类别时 Hero 为空但进展层仍正常', () {
      final result = orchestrator.orchestrate(
        OrchestrationInput(
          now: DateTime(2026, 8, 23, 9),
          candidates: candidates(),
          mutedCategories: const {
            HomeCardCategory.solarTerm,
            HomeCardCategory.rhythm,
            HomeCardCategory.family,
            HomeCardCategory.breath,
            HomeCardCategory.food,
          },
        ),
      );
      expect(result.hero, isNull);
      expect(result.focus, isEmpty);
      expect(result.progress, isNotEmpty);
    });
  });

  group('权重口径', () {
    test('权重合计为 1，与 35/25/15/15/10 设计一致', () {
      const sum = HomeOrchestrator.weightRelevance +
          HomeOrchestrator.weightUrgency +
          HomeOrchestrator.weightNovelty +
          HomeOrchestrator.weightActionability +
          HomeOrchestrator.weightConfidence;
      expect(sum, closeTo(1.0, 1e-9));
      expect(HomeOrchestrator.weightRelevance, 0.35);
      expect(HomeOrchestrator.weightUrgency, 0.25);
      expect(HomeOrchestrator.weightNovelty, 0.15);
      expect(HomeOrchestrator.weightActionability, 0.15);
      expect(HomeOrchestrator.weightConfidence, 0.10);
    });
  });
}
