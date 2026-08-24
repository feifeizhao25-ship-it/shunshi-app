// 首页推荐画像本地存储 — 个性化 v2（纯客户端，无后端依赖）
//
// 存四类东西：用户目标、已关闭的推荐类别、行为事件（看过/点开/完成）、
// 按日期键的完成记录。行为事件保留 30 天并封顶 200 条；
// 完成记录按 yyyy-MM-dd 键控，跨启动保留，超 30 天的旧键自动清理。
// 「重置画像」清目标 + 类别屏蔽 + 行为事件；完成记录属于用户的行动历史，保留。

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/services/home_orchestrator.dart';

class HomeProfileStorage {
  static const _goalKey = 'home_profile_goal';
  static const _mutedKey = 'home_profile_muted_categories';
  static const _behaviorKey = 'home_behavior_events';
  static const _completionsKey = 'home_completions';

  /// 行为事件与完成记录的保留窗口
  static const retentionDays = 30;

  /// 行为事件条数上限（防无限增长）
  static const maxBehaviorEvents = 200;

  Future<HomeGoal?> loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return HomeGoal.fromId(prefs.getString(_goalKey));
  }

  Future<void> saveGoal(HomeGoal goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goalKey, goal.name);
  }

  Future<Set<HomeCardCategory>> loadMutedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_mutedKey) ?? const [];
    return raw
        .map((name) => HomeCardCategory.values
            .where((c) => c.name == name)
            .firstOrNull)
        .whereType<HomeCardCategory>()
        .toSet();
  }

  Future<void> muteCategory(HomeCardCategory category) async {
    final muted = await loadMutedCategories();
    muted.add(category);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _mutedKey,
      muted.map((c) => c.name).toList(),
    );
  }

  // ── 个性化 v2：行为事件 ──

  static String _dateKey(DateTime t) => '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  /// 读取行为画像（自动清理超出保留窗口的事件）
  Future<HomeBehaviorProfile> loadBehaviorProfile({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final events = _decodeEvents(prefs.getString(_behaviorKey));
    final pruned = _pruneEvents(events, now ?? DateTime.now());
    if (pruned.length != events.length) {
      await prefs.setString(_behaviorKey, _encodeEvents(pruned));
    }
    return HomeBehaviorProfile(pruned);
  }

  /// 记录一条行为。seen 按「卡 + 天」去重，避免每次重建首页都写一条。
  Future<void> recordBehavior(
    String cardId,
    HomeBehaviorType type, {
    DateTime? at,
  }) async {
    final time = at ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final events = _pruneEvents(
      _decodeEvents(prefs.getString(_behaviorKey)),
      time,
    );
    if (type == HomeBehaviorType.seen) {
      final alreadySeenToday = events.any((e) =>
          e.cardId == cardId &&
          e.type == HomeBehaviorType.seen &&
          _dateKey(e.at) == _dateKey(time));
      if (alreadySeenToday) return;
    }
    events.add(HomeBehaviorEvent(cardId: cardId, type: type, at: time));
    final capped = events.length > maxBehaviorEvents
        ? events.sublist(events.length - maxBehaviorEvents)
        : events;
    await prefs.setString(_behaviorKey, _encodeEvents(capped));
  }

  List<HomeBehaviorEvent> _pruneEvents(
    List<HomeBehaviorEvent> events,
    DateTime now,
  ) {
    final cutoff = now.subtract(const Duration(days: retentionDays));
    return events.where((e) => e.at.isAfter(cutoff)).toList();
  }

  List<HomeBehaviorEvent> _decodeEvents(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((m) {
            final type = HomeBehaviorType.values
                .where((t) => t.name == m['type'])
                .firstOrNull;
            final at = DateTime.tryParse('${m['at']}');
            final cardId = m['cardId'];
            if (type == null || at == null || cardId is! String) return null;
            return HomeBehaviorEvent(cardId: cardId, type: type, at: at);
          })
          .whereType<HomeBehaviorEvent>()
          .toList();
    } on FormatException {
      return [];
    }
  }

  String _encodeEvents(List<HomeBehaviorEvent> events) => jsonEncode(
        events
            .map((e) => {
                  'cardId': e.cardId,
                  'type': e.type.name,
                  'at': e.at.toIso8601String(),
                })
            .toList(),
      );

  // ── 个性化 v2：按日期键的完成记录 ──

  /// 读取某天的完成卡 id 集合（跨启动保留）
  Future<Set<String>> loadCompletionsForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _decodeCompletions(prefs.getString(_completionsKey));
    return (map[_dateKey(date)] ?? const []).toSet();
  }

  /// 标记某卡在某天完成（幂等），同时落一条 completed 行为事件
  Future<void> markCompleted(String cardId, {DateTime? at}) async {
    final time = at ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final map = _decodeCompletions(prefs.getString(_completionsKey));
    final key = _dateKey(time);
    final ids = map[key] ?? <String>[];
    if (!ids.contains(cardId)) {
      ids.add(cardId);
      map[key] = ids;
      _pruneCompletions(map, time);
      await prefs.setString(_completionsKey, jsonEncode(map));
      // 仅首次完成落行为事件，重复调用保持幂等
      await recordBehavior(cardId, HomeBehaviorType.completed, at: time);
    }
  }

  Map<String, List<String>> _decodeCompletions(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map;
      return map.map((k, v) => MapEntry(
            '$k',
            (v as List).whereType<String>().toList(),
          ));
    } on FormatException {
      return {};
    }
  }

  void _pruneCompletions(Map<String, List<String>> map, DateTime now) {
    final cutoff = _dateKey(now.subtract(const Duration(days: retentionDays)));
    map.removeWhere((key, _) => key.compareTo(cutoff) < 0);
  }

  /// 重置画像：清掉目标、类别屏蔽与行为事件；完成记录是用户的行动历史，保留
  Future<void> resetProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_goalKey);
    await prefs.remove(_mutedKey);
    await prefs.remove(_behaviorKey);
  }
}

final homeProfileStorage = HomeProfileStorage();
