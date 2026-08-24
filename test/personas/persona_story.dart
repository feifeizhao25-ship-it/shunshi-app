// 5 用户 × 7 天故事驱动核心 — 加载 persona JSON、逐日模拟首页编排
//
// 19 项要求第 19 项前置。语义约定（与真实客户端一致）：
// - Day N 的首页渲染发生在 renderAt（当天首次打开 App），只受 Day 1..N-1
//   的行为影响；当天的事件发生在渲染之后（「Day 2 按首日行为重排」的因果方向）。
// - 每渲染一张卡自动记一条 seen（按天去重），与 _HomePageState._recordSeen +
//   HomeProfileStorage.recordBehavior 的去重规则一致。
// - muteDuringDay 当天操作、次日起生效，对应「不再推荐此类」。
// - 候选卡构建镜像 _HomePageState._buildCandidates 的默认本地状态
//   （breath/food/exercise 三张内置建议卡、无服务端下发、渲染时刻完成数为 0）。
//
// 输出既供纯 Dart 驱动测试断言，也供 golden 测试导出 manifest/dump。

import 'dart:convert';
import 'dart:io';

import 'package:shunshi/domain/services/home_orchestrator.dart';
import 'package:shunshi/presentation/pages/solar_term_page.dart';

/// 数据包目录（flutter test 的 cwd 为包根）
const String kPersonaFixtureDir = 'test/fixtures/personas';

/// 五个 persona 的 fixture 文件名（顺序即 A→E）
const List<String> kPersonaFixtureFiles = [
  'persona_a_newcomer_sleep.json',
  'persona_b_coach_energy.json',
  'persona_c_family_organizer.json',
  'persona_d_habit_tracker.json',
  'persona_e_privacy_sensitive.json',
];

/// 一个 persona 的一天
class PersonaDay {
  final int day;
  final DateTime date;
  final DateTime renderAt;
  final String narrative;
  final List<HomeBehaviorEvent> events;
  final Set<HomeCardCategory> muteDuringDay;

  const PersonaDay({
    required this.day,
    required this.date,
    required this.renderAt,
    required this.narrative,
    required this.events,
    required this.muteDuringDay,
  });
}

/// 一个 persona 的一周故事
class PersonaStory {
  final String id;
  final String archetype;
  final String matrixRole;
  final String description;
  final HomeGoal goal;
  final int goalChosenOnDay;
  final List<PersonaDay> days;

  const PersonaStory({
    required this.id,
    required this.archetype,
    required this.matrixRole,
    required this.description,
    required this.goal,
    required this.goalChosenOnDay,
    required this.days,
  });

  /// Day N 渲染时生效的目标（未到选目标日则为 null → 首页显示目标引导）
  HomeGoal? goalForRender(int day) => day >= goalChosenOnDay ? goal : null;

  static PersonaStory fromJson(Map<String, dynamic> json) {
    final persona = json['persona'] as Map<String, dynamic>;
    final goal = HomeGoal.fromId(json['goal'] as String?);
    if (goal == null) {
      throw FormatException('未知目标: ${json['goal']}');
    }
    final days = (json['days'] as List).map((d) {
      final m = d as Map<String, dynamic>;
      return PersonaDay(
        day: m['day'] as int,
        date: DateTime.parse(m['date'] as String),
        renderAt: DateTime.parse(m['renderAt'] as String),
        narrative: m['narrative'] as String? ?? '',
        events: (m['events'] as List? ?? const [])
            .map((e) => _eventFromJson(e as Map<String, dynamic>))
            .toList(),
        muteDuringDay: (m['muteDuringDay'] as List? ?? const [])
            .map((name) => HomeCardCategory.values
                .where((c) => c.name == name)
                .firstOrNull)
            .whereType<HomeCardCategory>()
            .toSet(),
      );
    }).toList();
    return PersonaStory(
      id: persona['id'] as String,
      archetype: persona['archetype'] as String,
      matrixRole: persona['matrixRole'] as String,
      description: persona['description'] as String? ?? '',
      goal: goal,
      goalChosenOnDay: json['goalChosenOnDay'] as int,
      days: days,
    );
  }

  static HomeBehaviorEvent _eventFromJson(Map<String, dynamic> m) {
    final type = HomeBehaviorType.values
        .where((t) => t.name == m['type'])
        .firstOrNull;
    if (type == null) throw FormatException('未知行为类型: ${m['type']}');
    return HomeBehaviorEvent(
      cardId: m['cardId'] as String,
      type: type,
      at: DateTime.parse(m['at'] as String),
    );
  }
}

/// 一天的渲染结果
class PersonaDayRender {
  final int day;
  final DateTime renderAt;
  final HomeGoal? goal;
  final Set<HomeCardCategory> mutedCategories;
  final OrchestratedHome home;
  final String narrative;

  const PersonaDayRender({
    required this.day,
    required this.renderAt,
    required this.goal,
    required this.mutedCategories,
    required this.home,
    required this.narrative,
  });

  RankedHomeCard? get hero => home.hero;

  /// Hero + 今日重点的卡 id 顺序（前排）
  List<String> get focusOrder => [
        if (home.hero != null) home.hero!.card.id,
        ...home.focus.map((r) => r.card.id),
      ];

  List<String> get progressOrder => home.progress.map((r) => r.card.id).toList();

  /// 当天首页出现的全部卡 id
  List<String> get allRendered => [...focusOrder, ...progressOrder];

  RankedHomeCard cardOf(String id) => [
        if (home.hero != null) home.hero!,
        ...home.focus,
        ...home.progress,
      ].firstWhere((r) => r.card.id == id);
}

/// 一个 persona 的整周模拟结果
class PersonaWeekSimulation {
  final PersonaStory story;
  final List<PersonaDayRender> renders;

  /// 全部行为事件 = JSON 显式事件 + 渲染时合成的 seen（按时间排序）
  final List<HomeBehaviorEvent> allEvents;

  const PersonaWeekSimulation({
    required this.story,
    required this.renders,
    required this.allEvents,
  });

  PersonaDayRender renderOf(int day) => renders[day - 1];

  /// 截至 Day N 渲染前生效的关闭类别（Day 1..N-1 的 muteDuringDay 并集）
  Set<HomeCardCategory> mutedForRender(int day) {
    final muted = <HomeCardCategory>{};
    for (final d in story.days) {
      if (d.day < day) muted.addAll(d.muteDuringDay);
    }
    return muted;
  }

  /// 按日期键的完成集合（与 home_completions 存储格式一致）
  Map<String, List<String>> completionsByDate({int? beforeDay}) {
    final map = <String, List<String>>{};
    for (final e in allEvents) {
      if (e.type != HomeBehaviorType.completed) continue;
      final dayOf = story.days
          .where((d) => _sameDay(d.date, e.at))
          .map((d) => d.day)
          .firstOrNull;
      if (dayOf == null) continue;
      if (beforeDay != null && dayOf >= beforeDay) continue;
      final key = _dateKey(e.at);
      map.putIfAbsent(key, () => []);
      if (!map[key]!.contains(e.cardId)) map[key]!.add(e.cardId);
    }
    return map;
  }

  /// 完成行动总数
  int get totalCompletions =>
      allEvents.where((e) => e.type == HomeBehaviorType.completed).length;

  /// Day N 渲染前的 SharedPreferences 种子（键与 HomeProfileStorage 完全一致）
  Map<String, Object> storageSeedForRender(int day) {
    final goal = story.goalForRender(day);
    final events = allEvents.where((e) {
      final dayOf = story.days
          .where((d) => _sameDay(d.date, e.at))
          .map((d) => d.day)
          .firstOrNull;
      return dayOf != null && dayOf < day;
    }).toList();
    return {
      if (goal != null) 'home_profile_goal': goal.name,
      'home_profile_muted_categories':
          mutedForRender(day).map((c) => c.name).toList(),
      'home_behavior_events': jsonEncode(events
          .map((e) => {
                'cardId': e.cardId,
                'type': e.type.name,
                'at': e.at.toIso8601String(),
              })
          .toList()),
      'home_completions': jsonEncode(completionsByDate(beforeDay: day)),
    };
  }

  static String _dateKey(DateTime t) => '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 加载全部 persona 故事
List<PersonaStory> loadPersonaStories() {
  return kPersonaFixtureFiles.map((file) {
    final raw = File('$kPersonaFixtureDir/$file').readAsStringSync();
    return PersonaStory.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }).toList();
}

/// 候选卡构建 — 镜像 _HomePageState._buildCandidates 的默认本地状态。
/// （无服务端下发建议；渲染在当天事件之前，当日完成数为 0。）
List<HomeCardCandidate> buildStoryCandidates(DateTime now) {
  final term = SolarTermData.current(now);
  return [
    HomeCardCandidate(
      id: 'solar_term',
      category: HomeCardCategory.solarTerm,
      conclusion: '${term.name}：${term.healthTips.first}',
      why: '${term.description}\n宜：${term.healthTips.join('、')}。',
      goalTags: const {HomeGoal.diet, HomeGoal.energy, HomeGoal.sleep},
      actionability: 0.8,
      confidence: 0.9,
      actionLabel: '今天照做',
    ),
    HomeCardCandidate(
      id: 'rhythm',
      category: HomeCardCategory.rhythm,
      conclusion: '今日作息：${term.sleepAdvice.first}',
      why: '${term.name}时节，${term.sleepAdvice.join('，')}。顺应天时，身体最省力。',
      goalTags: const {HomeGoal.sleep, HomeGoal.energy, HomeGoal.calm},
      actionability: 0.7,
      confidence: 0.9,
      actionLabel: '今天照做',
    ),
    HomeCardCandidate(
      id: 'family',
      category: HomeCardCategory.family,
      conclusion: '给家人也泡一杯${term.teaRecommendations.first}',
      why: '${term.name}宜饮${term.teaRecommendations.join('、')}。'
          '照顾自己，也照顾身边人。',
      goalTags: const {HomeGoal.family},
      actionability: 0.6,
      confidence: 0.8,
      actionLabel: '记下了',
    ),
    const HomeCardCandidate(
      id: 'chat',
      category: HomeCardCategory.chat,
      conclusion: '有心事，和顺时聊聊',
      why: '说出来会轻松一些。顺时一直在。',
      goalTags: {HomeGoal.calm},
      actionability: 0.9,
      confidence: 0.7,
      actionLabel: '开始聊聊',
    ),
    const HomeCardCandidate(
      id: 'breath',
      category: HomeCardCategory.breath,
      conclusion: '花 5 分钟，做一次深呼吸',
      why: '吸气4秒 · 停顿4秒 · 呼气6秒',
      goalTags: {HomeGoal.calm, HomeGoal.sleep},
      actionability: 0.9,
      confidence: 0.7,
      actionLabel: '去做',
    ),
    const HomeCardCandidate(
      id: 'food',
      category: HomeCardCategory.food,
      conclusion: '喝点温热的，暖暖胃',
      why: '暖胃养血，适合这个时节',
      goalTags: {HomeGoal.diet},
      actionability: 0.9,
      confidence: 0.7,
      actionLabel: '去做',
    ),
    const HomeCardCandidate(
      id: 'exercise',
      category: HomeCardCategory.exercise,
      conclusion: '舒展身体，只要 10 分钟',
      why: '试试简单的拉伸运动，活动肩颈、转动腰部',
      goalTags: {HomeGoal.energy, HomeGoal.calm},
      actionability: 0.9,
      confidence: 0.7,
      actionLabel: '去做',
    ),
    const HomeCardCandidate(
      id: 'progress_today',
      category: HomeCardCategory.progress,
      layer: HomeCardLayer.progress,
      conclusion: '今日已完成 0 件小行动',
      why: '还没有完成的行动。从最简单的一件开始就好。',
      confidence: 1.0,
    ),
    // 异常提醒：傍晚后仍无行动（镜像 _buildCandidates 的 done==0 && hour>=18）
    if (now.hour >= 18)
      const HomeCardCandidate(
        id: 'anomaly_inactive',
        category: HomeCardCategory.anomaly,
        layer: HomeCardLayer.progress,
        conclusion: '今天还没行动，从 1 分钟呼吸开始',
        why: '不需要多做，一件就够。呼吸是最轻的开始。',
        actionability: 0.9,
        confidence: 1.0,
        actionLabel: '呼吸 1 分钟',
      ),
  ];
}

/// 逐日模拟一个 persona 的一周首页
PersonaWeekSimulation simulatePersonaWeek(PersonaStory story) {
  const orchestrator = HomeOrchestrator();
  final events = <HomeBehaviorEvent>[];
  final renders = <PersonaDayRender>[];

  for (final day in story.days) {
    // Day N 渲染：只注入 Day 1..N-1 的行为与关闭类别
    final muted = <HomeCardCategory>{};
    for (final d in story.days) {
      if (d.day < day.day) muted.addAll(d.muteDuringDay);
    }
    final home = orchestrator.orchestrate(
      OrchestrationInput(
        now: day.renderAt,
        goal: story.goalForRender(day.day),
        mutedCategories: muted,
        behavior: HomeBehaviorProfile(List.unmodifiable(events)),
        candidates: buildStoryCandidates(day.renderAt),
      ),
    );
    final render = PersonaDayRender(
      day: day.day,
      renderAt: day.renderAt,
      goal: story.goalForRender(day.day),
      mutedCategories: muted,
      home: home,
      narrative: day.narrative,
    );
    renders.add(render);

    // 渲染后：App 自动为每张展示卡记 seen（按天去重），再落当天显式事件
    final seenAt = day.renderAt.add(const Duration(minutes: 5));
    final seenToday = <String>{};
    for (final id in render.allRendered) {
      if (seenToday.add(id)) {
        events.add(HomeBehaviorEvent(
          cardId: id,
          type: HomeBehaviorType.seen,
          at: seenAt,
        ));
      }
    }
    events.addAll(day.events);
    events.sort((a, b) => a.at.compareTo(b.at));
  }

  return PersonaWeekSimulation(
    story: story,
    renders: renders,
    allEvents: events,
  );
}
