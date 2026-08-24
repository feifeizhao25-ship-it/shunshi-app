// 首页编排引擎 — 纯 Dart，与 UI 解耦
//
// 输入：用户目标 / 当前日期时间 / 候选卡数据 / 已关闭的推荐类别 / 行为画像
// 输出：Hero 卡 + 今日重点(≤3) + 进展与异常(≤2)，每张卡带可解释的推荐理由
//
// 编排分数 = 相关性35% + 紧迫性25% + 新颖性15% + 可行动性15% + 信心10%
// （见《四项目-19项要求》第 13/15 项个性化设计）
//
// 个性化 v2（行为反馈入分）：
// - 看过（历史天数）→ 新颖性 ×0.3，且不再给「换个新内容」理由
// - 点开过（历史天数）→ 相关性 +0.15，理由透出「你之前点开过」
// - 今日已完成 → 退出前排（不进 Hero/今日重点）
// - 昨天完成 → 新颖性 ×0.2 让位；若昨日有完成记录，给 Hero 透出
//   「昨天你完成了 X，今天推荐 Y」的可解释理由
// 全部按日期确定性计算：同一天同一画像结果可复现。

/// 用户首次进入选择的养身目标（本地持久化，可重置）
enum HomeGoal {
  sleep('睡个好觉'),
  energy('白天更有精神'),
  calm('放松减压'),
  diet('吃得顺应节气'),
  family('照顾好家人');

  final String label;
  const HomeGoal(this.label);

  static HomeGoal? fromId(String? id) {
    if (id == null) return null;
    for (final goal in HomeGoal.values) {
      if (goal.name == id) return goal;
    }
    return null;
  }
}

/// 推荐卡类别 — 用户可以按类别关闭推荐
enum HomeCardCategory {
  rhythm('今日节律'),
  solarTerm('节气建议'),
  family('家庭关怀'),
  breath('呼吸放松'),
  food('食疗饮食'),
  exercise('轻运动'),
  chat('AI 陪伴'),
  progress('进展'),
  anomaly('提醒');

  final String label;
  const HomeCardCategory(this.label);
}

/// 卡片所处的信息层级
enum HomeCardLayer { focus, progress }

/// 行为类型（个性化 v2）
enum HomeBehaviorType {
  /// 卡片在首页展示过
  seen,

  /// 用户点开了卡片（详情/行动 BottomSheet）
  opened,

  /// 用户完成了卡片主行动
  completed,
}

/// 一条行为记录
class HomeBehaviorEvent {
  final String cardId;
  final HomeBehaviorType type;
  final DateTime at;

  const HomeBehaviorEvent({
    required this.cardId,
    required this.type,
    required this.at,
  });
}

/// 行为画像 — 一组行为记录的聚合查询
///
/// 所有查询都以「天」为粒度、相对传入的 [now] 计算，保证同一天结果稳定。
class HomeBehaviorProfile {
  final List<HomeBehaviorEvent> events;

  const HomeBehaviorProfile([this.events = const []]);

  static DateTime _dayStart(DateTime t) => DateTime(t.year, t.month, t.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 今天是否已完成该卡
  bool completedToday(String cardId, DateTime now) => events.any((e) =>
      e.cardId == cardId &&
      e.type == HomeBehaviorType.completed &&
      _sameDay(e.at, now));

  /// 昨天是否完成过该卡
  bool completedYesterday(String cardId, DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    return events.any((e) =>
        e.cardId == cardId &&
        e.type == HomeBehaviorType.completed &&
        _sameDay(e.at, yesterday));
  }

  /// 今天之前是否看过该卡（不含今天 —— 今天刚展示不算「看过旧内容」）
  bool seenBeforeToday(String cardId, DateTime now) {
    final todayStart = _dayStart(now);
    return events.any((e) =>
        e.cardId == cardId &&
        e.type == HomeBehaviorType.seen &&
        e.at.isBefore(todayStart));
  }

  /// 今天之前是否点开过该卡
  bool openedBeforeToday(String cardId, DateTime now) {
    final todayStart = _dayStart(now);
    return events.any((e) =>
        e.cardId == cardId &&
        e.type == HomeBehaviorType.opened &&
        e.at.isBefore(todayStart));
  }
}

/// 候选卡数据 — 由 UI 层从节气/建议/本地状态构建
class HomeCardCandidate {
  final String id;
  final HomeCardCategory category;
  final HomeCardLayer layer;

  /// 一句人话结论（组件层会做 25 字约束）
  final String conclusion;

  /// 「为什么」展开层文案
  final String why;

  /// 匹配的用户目标；空集合表示与目标无关的通用卡
  final Set<HomeGoal> goalTags;

  /// 可行动性 0~1：是否能一键完成主行动
  final double actionability;

  /// 信心 0~1：内容来源可靠度（本地节气推算 > 服务端内容）
  final double confidence;

  /// 主行动按钮文案；为空则卡片无主行动
  final String actionLabel;

  const HomeCardCandidate({
    required this.id,
    required this.category,
    required this.conclusion,
    required this.why,
    this.layer = HomeCardLayer.focus,
    this.goalTags = const {},
    this.actionability = 0.5,
    this.confidence = 0.5,
    this.actionLabel = '',
  });
}

/// 编排输入
class OrchestrationInput {
  final HomeGoal? goal;
  final DateTime now;
  final List<HomeCardCandidate> candidates;

  /// 用户已关闭的推荐类别
  final Set<HomeCardCategory> mutedCategories;

  /// 行为画像（个性化 v2）：空画像时行为因子全部不生效，与 v1 一致
  final HomeBehaviorProfile behavior;

  const OrchestrationInput({
    required this.now,
    required this.candidates,
    this.goal,
    this.mutedCategories = const {},
    this.behavior = const HomeBehaviorProfile(),
  });
}

/// 排序后的卡片：分数 + 可解释理由
class RankedHomeCard {
  final HomeCardCandidate card;
  final double score;
  final List<String> reasons;

  const RankedHomeCard({
    required this.card,
    required this.score,
    required this.reasons,
  });

  /// 「为什么推荐」的一句话总结
  String get reasonSummary =>
      reasons.isEmpty ? '综合你今天的节气与时间安排推荐' : reasons.join('；');
}

/// 编排输出 — 四层结构中的前三层（探索区不参与编排）
class OrchestratedHome {
  /// Hero 决策卡：今日一件事
  final RankedHomeCard? hero;

  /// 今日重点（≤3，不含 Hero）
  final List<RankedHomeCard> focus;

  /// 进展与异常（≤2）
  final List<RankedHomeCard> progress;

  const OrchestratedHome({
    required this.hero,
    required this.focus,
    required this.progress,
  });
}

/// 首页编排引擎
class HomeOrchestrator {
  const HomeOrchestrator();

  static const double weightRelevance = 0.35;
  static const double weightUrgency = 0.25;
  static const double weightNovelty = 0.15;
  static const double weightActionability = 0.15;
  static const double weightConfidence = 0.10;

  OrchestratedHome orchestrate(OrchestrationInput input) {
    final visible = input.candidates
        .where((c) => !input.mutedCategories.contains(c.category))
        .toList();

    final ranked = visible
        .map((c) => _rank(c, input))
        .toList()
      // 分数降序；同分时按 id 字典序保证结果稳定可测
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return a.card.id.compareTo(b.card.id);
      });

    final focusPool = ranked
        .where((r) =>
            r.card.layer == HomeCardLayer.focus &&
            // 今日已完成的卡退出前排，进入进展层统计
            !input.behavior.completedToday(r.card.id, input.now))
        .toList();
    final progressPool =
        ranked.where((r) => r.card.layer == HomeCardLayer.progress).toList();

    final hero = focusPool.isEmpty ? null : focusPool.first;
    final focus = focusPool.skip(hero == null ? 0 : 1).take(3).toList();
    final progress = progressPool.take(2).toList();

    // Day 2 可解释重排序：昨天有完成记录时，给今日 Hero 透出承接连贯的理由
    if (hero != null) {
      final doneYesterday = visible
          .where((c) => input.behavior.completedYesterday(c.id, input.now))
          .toList();
      if (doneYesterday.isNotEmpty &&
          !input.behavior.completedYesterday(hero.card.id, input.now)) {
        hero.reasons.add(
          '昨天你完成了${doneYesterday.first.category.label}'
          '，今天推荐${hero.card.category.label}',
        );
      }
    }

    return OrchestratedHome(hero: hero, focus: focus, progress: progress);
  }

  RankedHomeCard _rank(HomeCardCandidate card, OrchestrationInput input) {
    final behavior = input.behavior;
    var relevance = _relevance(card, input.goal);
    final urgency = _urgency(card, input.now);
    var novelty = _novelty(card.id, input.now);

    // ── 个性化 v2：行为反馈入分 ──
    // 点开过（历史）且今天没完成 → 用户表现出兴趣，相关性上调
    final openedBefore = behavior.openedBeforeToday(card.id, input.now);
    final completedNow = behavior.completedToday(card.id, input.now);
    if (openedBefore && !completedNow) {
      relevance = (relevance + 0.15).clamp(0.0, 1.0);
    }
    // 看过的旧内容降新颖性；昨天刚完成的今天让位
    if (behavior.seenBeforeToday(card.id, input.now)) {
      novelty *= 0.3;
    }
    if (behavior.completedYesterday(card.id, input.now)) {
      novelty *= 0.2;
    }

    final score = relevance * weightRelevance +
        urgency * weightUrgency +
        novelty * weightNovelty +
        card.actionability.clamp(0.0, 1.0) * weightActionability +
        card.confidence.clamp(0.0, 1.0) * weightConfidence;

    return RankedHomeCard(
      card: card,
      score: score,
      reasons:
          _reasons(card, input, relevance, urgency, novelty, openedBefore),
    );
  }

  /// 相关性：目标匹配 1.0；通用卡 0.5；不匹配 0.2；未选目标一律 0.5
  double _relevance(HomeCardCandidate card, HomeGoal? goal) {
    if (goal == null) return 0.5;
    if (card.goalTags.isEmpty) return 0.5;
    return card.goalTags.contains(goal) ? 1.0 : 0.2;
  }

  /// 紧迫性：节气卡特异性由「距节气换日」决定；节律卡按时段；其余取基线
  double _urgency(HomeCardCandidate card, DateTime now) {
    switch (card.category) {
      case HomeCardCategory.solarTerm:
        // 节气表按 day ~/ 15 切换：1~14 日→15 日换，15 日后→次月换
        final daysUntilChange = now.day < 15
            ? 15 - now.day
            : DateTime(now.year, now.month + 1, 0).day - now.day;
        return (1 - daysUntilChange / 15).clamp(0.0, 1.0);
      case HomeCardCategory.rhythm:
        final hour = now.hour;
        if (hour >= 5 && hour < 11) return 0.9;
        if (hour >= 11 && hour < 17) return 0.6;
        return 0.3;
      default:
        return 0.4;
    }
  }

  /// 新颖性：按「日期 + 卡片 id」确定性哈希，同一天稳定、换天轮换
  double _novelty(String cardId, DateTime now) {
    final key = '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}:$cardId';
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return (hash % 1000) / 1000;
  }

  List<String> _reasons(
    HomeCardCandidate card,
    OrchestrationInput input,
    double relevance,
    double urgency,
    double novelty,
    bool openedBefore,
  ) {
    final reasons = <String>[];
    final goal = input.goal;
    if (goal != null && card.goalTags.contains(goal)) {
      reasons.add('贴合你的目标「${goal.label}」');
    }
    if (openedBefore) {
      reasons.add('你之前点开过，可能正需要');
    }
    if (urgency >= 0.7) {
      if (card.category == HomeCardCategory.solarTerm) {
        reasons.add('节气将换，提前调整正当时');
      } else if (card.category == HomeCardCategory.rhythm) {
        reasons.add('现在正是顺应节律的好时段');
      }
    }
    if (novelty >= 0.7) {
      reasons.add('最近没看过，今天换个新内容');
    }
    return reasons;
  }
}
