// 顺时 首页 — 国内版
// 设计理念：大留白，大字体，低信息密度，深呼吸感
//
// 信息架构（19 项要求第 10/13/3 项）：四层结构
//   1. Hero 决策卡「今日一件事」— 唯一首要行动
//   2. 今日重点（≤3）— 今日节律/节气建议/家庭关怀等，按编排分数排序
//   3. 进展与异常（≤2）
//   4. 可折叠「全部功能」探索区 — 不删任何既有功能入口
//
// 卡序由本地编排引擎（HomeOrchestrator）决定：相关性35% + 紧迫性25%
// + 新颖性15% + 可行动性15% + 信心10%；用户可选目标、看推荐理由、
// 关闭某类推荐、重置画像（全部本地持久化，无后端依赖）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../../data/network/api_client.dart';
import '../../../data/storage/home_profile_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../../../domain/services/home_orchestrator.dart';
import '../../widgets/home/three_level_card.dart';
import '../../widgets/responsive_content.dart';
import '../solar_term_page.dart';

/// 首页
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.nowOverride});

  /// 测试专用日期锚点：固定「今天」，用于 5 用户×7 天故事的 golden/集成测试。
  /// 生产代码不传，一律取 DateTime.now()。
  final DateTime? nowOverride;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _greeting = '';
  String _dailyInsight = '今天适合慢下来\n给自己泡一杯茶';
  bool _isLoading = true;
  // 加载失败时对用户可见，而不是静默展示预置内容
  String? _loadError;

  // 建议卡片数据
  final List<_SuggestionItem> _suggestions = [
    _SuggestionItem(icon: '🌬️', title: '呼吸', subtitle: '5min', id: 'breath'),
    _SuggestionItem(icon: '🍵', title: '食疗', subtitle: '试试', id: 'food'),
    _SuggestionItem(icon: '🧘', title: '运动', subtitle: '10m', id: 'exercise'),
  ];
  final Set<String> _completedSuggestions = {};

  // ── 个性化 v1：本地画像 ──
  HomeGoal? _goal;
  Set<HomeCardCategory> _mutedCategories = {};
  bool _exploreExpanded = false;

  // ── 个性化 v2：行为画像 + 完成状态持久化 ──
  HomeBehaviorProfile _behavior = const HomeBehaviorProfile();
  final Set<String> _seenRecorded = {};

  static const _orchestrator = HomeOrchestrator();

  /// 「今天」的取值入口：默认实时；测试可通过 [HomePage.nowOverride] 固定
  DateTime get _now => widget.nowOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDailyContent();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final goal = await homeProfileStorage.loadGoal();
    final muted = await homeProfileStorage.loadMutedCategories();
    final behavior = await homeProfileStorage.loadBehaviorProfile();
    // 完成状态按日期键持久化：跨启动恢复今日的完成集合
    final completed =
        await homeProfileStorage.loadCompletionsForDate(_now);
    if (mounted) {
      setState(() {
        _goal = goal;
        _mutedCategories = muted;
        _behavior = behavior;
        _completedSuggestions.addAll(completed);
      });
    }
  }

  /// 行为反馈入分：本地即时更新画像 + 落盘（seen 按天去重由存储层保证，
  /// 这里再用会话内集合避免 build 期间重复写）
  void _recordBehavior(String cardId, HomeBehaviorType type) {
    final now = DateTime.now();
    _behavior = HomeBehaviorProfile([
      ..._behavior.events,
      HomeBehaviorEvent(cardId: cardId, type: type, at: now),
    ]);
    unawaited(homeProfileStorage.recordBehavior(cardId, type, at: now));
  }

  void _recordSeen(String cardId) {
    if (!_seenRecorded.add(cardId)) return;
    _recordBehavior(cardId, HomeBehaviorType.seen);
  }

  /// 标记完成：更新状态、落盘（按日期键）、记 completed 行为
  void _markCompleted(String cardId) {
    final now = DateTime.now();
    setState(() => _completedSuggestions.add(cardId));
    _behavior = HomeBehaviorProfile([
      ..._behavior.events,
      HomeBehaviorEvent(cardId: cardId, type: HomeBehaviorType.completed, at: now),
    ]);
    unawaited(homeProfileStorage.markCompleted(cardId, at: now));
  }

  Future<void> _loadDailyContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hemisphere = prefs.getString('hemisphere') ?? 'north';
      final accessToken = await tokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        if (mounted) {
          setState(() {
            _loadError = '登录后才能获取你的个性化内容';
            _isLoading = false;
          });
        }
        return;
      }

      final apiClient = ApiClient();
      final response = await apiClient.get(
        '/api/v1/seasons/home/dashboard',
        queryParameters: {
          'hemisphere': hemisphere,
        },
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        setState(() {
          _greeting = data['greeting'] ?? _getGreeting();
          _dailyInsight = data['daily_insight']?['text'] ?? _dailyInsight;
          // Parse suggestions if available
          final suggestions = data['suggestions'] as List?;
          if (suggestions != null && suggestions.isNotEmpty) {
            _suggestions.clear();
            for (final s in suggestions) {
              _suggestions.add(_SuggestionItem(
                icon: _getIconForCategory(s['category'] ?? ''),
                title: s['text'] ?? '',
                subtitle: '',
                id: s['id'] ?? '',
              ));
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      // 接口失败时不再静默回落到预置内容——那会让用户以为看到的是真实数据。
      debugPrint('Home dashboard API call failed: $e');
      if (mounted) {
        setState(() {
          _loadError = '内容加载失败，请检查网络后重试';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _greeting = _greeting.isEmpty ? _getGreeting() : _greeting;
        _loadError = null;
        _isLoading = false;
      });
    }
  }

  /// 供 UI 层读取的加载错误，非空时应展示错误态与重试入口。
  String? get loadError => _loadError;

  /// 重新拉取每日内容（错误态重试按钮调用）。
  Future<void> retryLoadDailyContent() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    await _loadDailyContent();
  }

  String _getIconForCategory(String category) {
    switch (category) {
      case 'movement': return '🧘';
      case 'food': return '🍵';
      case 'rest': return '😴';
      case 'mental': return '🧠';
      default: return '💡';
    }
  }

  /// 根据当前时间返回问候语
  String _getGreeting() {
    final hour = _now.hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早安';
    if (hour < 18) return '午安';
    return '晚安';
  }

  /// 问候语：优先用后端返回的个性化文案，否则按时段生成。
  /// 此前这里硬编码了 `，feifei` 作为用户名 —— 每个用户都会看到别人的名字。
  String _getGreetingText() {
    return _greeting.isEmpty ? _getGreeting() : _greeting;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _loadError != null
            ? _buildErrorState()
            : _buildHome(),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 四层信息架构
  // ──────────────────────────────────────────────

  Widget _buildHome() {
    final now = _now;
    final orchestrated = _orchestrator.orchestrate(
      OrchestrationInput(
        now: now,
        goal: _goal,
        mutedCategories: _mutedCategories,
        behavior: _behavior,
        candidates: _buildCandidates(now),
      ),
    );

    // 记录「看过」行为（入分用；会话内 + 存储层双重去重）
    for (final r in [
      if (orchestrated.hero != null) orchestrated.hero!,
      ...orchestrated.focus,
      ...orchestrated.progress,
    ]) {
      _recordSeen(r.card.id);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      // 桌面宽屏下限宽居中，四层结构不拉满全宽
      child: MaxWidthContent(
        maxWidth: kFeedContentMaxWidth,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          // ── Greeting ──
          _buildGreeting(),
          const SizedBox(height: 24),

          // ── 首次进入：选一个目标（30 秒上手引导）──
          if (_goal == null) ...[
            _buildGoalPicker(),
            const SizedBox(height: 24),
          ],

          // ── 第 1 层：Hero 决策卡「今日一件事」──
          if (orchestrated.hero != null) ...[
            _buildSectionHeader('今日一件事'),
            const SizedBox(height: 12),
            _buildRankedCard(orchestrated.hero!, isHero: true),
            const SizedBox(height: 32),
          ],

          // ── 第 2 层：今日重点（≤3）──
          if (orchestrated.focus.isNotEmpty) ...[
            _buildSectionHeader('今日重点'),
            const SizedBox(height: 12),
            ...orchestrated.focus.map(
              (ranked) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildRankedCard(ranked),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── 第 3 层：进展与异常（≤2）──
          if (orchestrated.progress.isNotEmpty) ...[
            _buildSectionHeader('进展与异常'),
            const SizedBox(height: 12),
            ...orchestrated.progress.map(
              (ranked) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildRankedCard(ranked),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── 第 4 层：可折叠探索区（不删任何既有功能入口）──
          _buildExploreSection(),
          const SizedBox(height: 32),
        ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF9B9B9B),
        letterSpacing: 1,
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 候选卡构建：节气/节律/家庭关怀 + 既有建议 + 进展
  // ──────────────────────────────────────────────

  List<HomeCardCandidate> _buildCandidates(DateTime now) {
    final term = SolarTermData.current(now);
    // 完成计数从本地持久化（按日期键）恢复，跨启动保留
    final done = _completedSuggestions.length;
    final candidates = <HomeCardCandidate>[
      // 节气建议 — 本地推算，信心最高
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
      // 今日节律
      HomeCardCandidate(
        id: 'rhythm',
        category: HomeCardCategory.rhythm,
        conclusion: '今日作息：${term.sleepAdvice.first}',
        why: '${term.name}时节，${term.sleepAdvice.join('，')}。'
            '顺应天时，身体最省力。',
        goalTags: const {HomeGoal.sleep, HomeGoal.energy, HomeGoal.calm},
        actionability: 0.7,
        confidence: 0.9,
        actionLabel: '今天照做',
      ),
      // 家庭关怀
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
      // AI 陪伴（既有入口）
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
      // 既有建议卡（呼吸/食疗/运动，或服务端下发）
      for (final item in _suggestions)
        HomeCardCandidate(
          id: item.id,
          category: _categoryForSuggestion(item.id),
          conclusion: _conclusionForSuggestion(item),
          why: _getSuggestionDetail(item.id),
          goalTags: _goalsForSuggestion(item.id),
          actionability: 0.9,
          confidence: 0.7,
          actionLabel: '去做',
        ),
      // 进展（第 3 层）
      HomeCardCandidate(
        id: 'progress_today',
        category: HomeCardCategory.progress,
        layer: HomeCardLayer.progress,
        conclusion: '今日已完成 $done 件小行动',
        why: done == 0
            ? '还没有完成的行动。从最简单的一件开始就好。'
            : '每完成一件，身体就松一分。继续保持。',
        confidence: 1.0,
      ),
      // 异常提醒（第 3 层）：傍晚后仍无行动
      if (done == 0 && now.hour >= 18)
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

    // 已完成的卡退出前排，进入进展层统计
    return candidates
        .where((c) => !_completedSuggestions.contains(c.id))
        .toList();
  }

  HomeCardCategory _categoryForSuggestion(String id) {
    switch (id) {
      case 'breath': return HomeCardCategory.breath;
      case 'food': return HomeCardCategory.food;
      case 'exercise': return HomeCardCategory.exercise;
      default: return HomeCardCategory.rhythm;
    }
  }

  Set<HomeGoal> _goalsForSuggestion(String id) {
    switch (id) {
      case 'breath': return const {HomeGoal.calm, HomeGoal.sleep};
      case 'food': return const {HomeGoal.diet};
      case 'exercise': return const {HomeGoal.energy, HomeGoal.calm};
      default: return const {};
    }
  }

  /// 主结论文案保持口语短句；组件层另有 25 字约束兜底
  String _conclusionForSuggestion(_SuggestionItem item) {
    switch (item.id) {
      case 'breath': return '花 5 分钟，做一次深呼吸';
      case 'food': return '喝点温热的，暖暖胃';
      case 'exercise': return '舒展身体，只要 10 分钟';
      default: return item.title;
    }
  }

  String _emojiForCard(String id) {
    switch (id) {
      case 'solar_term': return SolarTermData.current().emoji;
      case 'rhythm': return '🌅';
      case 'family': return '🏠';
      case 'chat': return '💬';
      case 'progress_today': return '📈';
      case 'anomaly_inactive': return '⏰';
      default:
        for (final item in _suggestions) {
          if (item.id == id) return item.icon;
        }
        return '💡';
    }
  }

  // ──────────────────────────────────────────────
  // 卡片渲染：三级阅读 + 主行动 + 为什么推荐
  // ──────────────────────────────────────────────

  Widget _buildRankedCard(RankedHomeCard ranked, {bool isHero = false}) {
    final card = ranked.card;
    return ThreeLevelCard(
      emoji: _emojiForCard(card.id),
      conclusion: card.conclusion,
      why: card.why,
      actionLabel: card.actionLabel,
      onAction: card.actionLabel.isEmpty ? null : () => _onCardAction(card),
      detailLabel: '专业详情',
      onDetail: _detailRouteFor(card.id) == null
          ? null
          : () {
              _recordBehavior(card.id, HomeBehaviorType.opened);
              context.go(_detailRouteFor(card.id)!);
            },
      onWhyRecommended: () => _showWhyRecommended(ranked),
    );
  }

  String? _detailRouteFor(String id) {
    switch (id) {
      case 'solar_term':
      case 'rhythm':
        return '/seasons';
      case 'family':
        return '/library';
      case 'chat':
        return '/chat';
      default:
        return null;
    }
  }

  void _onCardAction(HomeCardCandidate card) {
    switch (card.id) {
      case 'breath':
      case 'food':
      case 'exercise':
      case 'anomaly_inactive':
        // 既有行为：展开 BottomSheet 详情，可标记完成
        final item = _suggestions.firstWhere(
          (s) => s.id == (card.id == 'anomaly_inactive' ? 'breath' : card.id),
          orElse: () => _suggestions.first,
        );
        _onSuggestionTap(item);
        break;
      case 'chat':
        _recordBehavior(card.id, HomeBehaviorType.opened);
        context.go('/chat');
        break;
      default:
        // 「今天照做」「记下了」— 本地标记完成（按日期键持久化），进入进展统计
        _markCompleted(card.id);
    }
  }

  // ──────────────────────────────────────────────
  // 「为什么推荐」说明 + 关闭类别 + 重置画像
  // ──────────────────────────────────────────────

  void _showWhyRecommended(RankedHomeCard ranked) {
    final category = ranked.card.category;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFFAF8F5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E5E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '为什么推荐这张卡',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C2C2C),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ranked.reasonSummary,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF6B6660),
                height: 1.7,
              ),
            ),
            const SizedBox(height: 24),
            // 关闭某类推荐
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await homeProfileStorage.muteCategory(category);
                  await _loadProfile();
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2C2C2C),
                  side: const BorderSide(color: Color(0xFFD9D4CC)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('不再推荐「${category.label}」'),
              ),
            ),
            const SizedBox(height: 8),
            // 重置画像
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  await homeProfileStorage.resetProfile();
                  await _loadProfile();
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text(
                  '重置画像，重新选择目标',
                  style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 首次进入：30 秒目标选择引导
  // ──────────────────────────────────────────────

  Widget _buildGoalPicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选一个目标，首页为你而排',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C2C2C),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '30 秒就好，之后随时能改',
            style: TextStyle(fontSize: 13, color: Color(0xFF9B9B9B)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HomeGoal.values.map((goal) {
              return ChoiceChip(
                label: Text(goal.label),
                selected: false,
                onSelected: (_) async {
                  await homeProfileStorage.saveGoal(goal);
                  await _loadProfile();
                },
                labelStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2C2C2C),
                ),
                backgroundColor: const Color(0xFFF5F3EF),
                selectedColor: const Color(0xFF4A7C6F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFE8E5E0)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 第 4 层：可折叠「全部功能」探索区
  //
  // 原首页入口（AI 对话/节气/建议）全部保留在新结构中；
  // 这里收纳的是 app 全部既有功能入口，一个都不删。
  // ──────────────────────────────────────────────

  Widget _buildExploreSection() {
    const entries = [
      (emoji: '💬', label: '和顺时聊聊', route: '/chat'),
      (emoji: '🌿', label: '节气养生', route: '/seasons'),
      (emoji: '📖', label: '养生内容', route: '/library'),
      (emoji: '📝', label: '健康记录', route: '/records'),
      (emoji: '🪞', label: '情绪复盘', route: '/reflection'),
      (emoji: '👤', label: '我的', route: '/profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _exploreExpanded = !_exploreExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '全部功能',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                  ),
                  Icon(
                    _exploreExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF9B9B9B),
                  ),
                ],
              ),
            ),
          ),
          if (_exploreExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.2,
                children: entries.map((entry) {
                  return InkWell(
                    onTap: () => context.go(entry.route),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(entry.emoji, style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 6),
                        Text(
                          entry.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B6660),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 加载失败态
  //
  // 此前接口失败时会静默展示预置内容，用户完全看不出数据是假的。
  // 现在明确告知并提供重试。
  // ──────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Color(0xFFBDB8B0),
            ),
            const SizedBox(height: 20),
            Text(
              _loadError ?? '内容加载失败',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w300,
                color: Color(0xFF6B6660),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: retryLoadDailyContent,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2C2C2C),
                side: const BorderSide(color: Color(0xFFD9D4CC)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                '重试',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Greeting + 每日一句
  // ──────────────────────────────────────────────

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreetingText(),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w300, // 细体
            color: Color(0xFF2C2C2C),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        // 淡分隔
        Container(
          width: 32,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFF4A7C6F).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 16),
        // 每日一句：优先服务端个性化文案
        Text(
          _dailyInsight,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Color(0xFF9B9B9B),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  void _onSuggestionTap(_SuggestionItem item) {
    if (_completedSuggestions.contains(item.id)) {
      // 已完成，展示详情或跳过
      return;
    }
    _recordBehavior(item.id, HomeBehaviorType.opened);
    // 展开BottomSheet详情
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _SuggestionDetailSheet(
        item: item,
        onComplete: () {
          _markCompleted(item.id);
          Navigator.pop(context);
        },
        onSkip: () => Navigator.pop(context),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Suggestion BottomSheet
// ═══════════════════════════════════════════════

class _SuggestionDetailSheet extends StatelessWidget {
  final _SuggestionItem item;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const _SuggestionDetailSheet({
    required this.item,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E5E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          Text(item.icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C2C2C),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getSuggestionDetail(item.id),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF6B6B6B),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          // 完成按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A7C6F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('完成了', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          // 跳过
          TextButton(
            onPressed: onSkip,
            child: const Text(
              '下次再说',
              style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

String _getSuggestionDetail(String id) {
  switch (id) {
    case 'breath':
      return '闭上眼睛，慢慢地深呼吸\n吸气4秒 · 停顿4秒 · 呼气6秒\n让身体慢慢放松下来';
    case 'food':
      return '今日推荐：温热的红枣桂圆茶\n暖胃养血，适合这个时节\n简单易做，几分钟就好';
    case 'exercise':
      return '试试简单的拉伸运动\n活动肩颈、转动腰部\n10分钟就能让身体舒展';
    default:
      return '试试看吧';
  }
}

// ═══════════════════════════════════════════════
// Data Model
// ═══════════════════════════════════════════════

class _SuggestionItem {
  final String icon;
  final String title;
  final String subtitle;
  final String id;

  const _SuggestionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.id,
  });
}
