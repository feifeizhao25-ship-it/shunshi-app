import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/theme.dart';
import '../../../data/network/api_client.dart';
import '../../widgets/components/components.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  }

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _acceptedLegal = false;

  // 用户选择
  String? _selectedFeeling;
  String? _selectedGoal;
  String? _selectedStage;
  int? _selectedHour;
  String? _selectedStyle;

  final _feelings = [
    ('平静', '😊'),
    ('压力大', '😰'),
    ('疲惫', '😴'),
    ('焦虑', '🥴'),
    ('好奇', '🤔'),
  ];

  final _goals = [
    '😴 改善睡眠',
    '🧘 减压放松',
    '🍵 饮食调理',
    '🏃 增强体质',
    '🌿 中医养生',
    '❤️ 情绪管理',
  ];

  final _stages = [
    ('20-30岁', '活力期'),
    ('30-40岁', '平衡期'),
    ('40-50岁', '调理期'),
    ('50-60岁', '保养期'),
    ('60岁以上', '颐养期'),
  ];

  final _hours = [
    '6:00',
    '7:00',
    '8:00',
    '9:00',
    '12:00',
    '15:00',
    '18:00',
    '20:00',
    '21:00',
  ];

  final _styles = [('简约清新', '简约'), ('温暖柔和', 'gentle'), ('活力满满', 'energetic')];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 0:
        return true;
      case 1:
        return _selectedFeeling != null;
      case 2:
        return _selectedGoal != null;
      case 3:
        return _selectedStage != null;
      case 4:
        return _selectedHour != null;
      case 5:
        return _selectedStyle != null;
      case 6:
        return true;
      default:
        return true;
    }
  }

  void _nextPage() {
    if (_currentPage == 0 && !_ensureLegalConsent()) return;
    if (_currentPage < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  // Maps Chinese feeling to API value
  String _feelingToApi(String? feeling) {
    switch (feeling) {
      case '平静':
        return 'calm';
      case '压力大':
        return 'stressed';
      case '疲惫':
        return 'tired';
      case '焦虑':
        return 'anxious';
      case '好奇':
        return 'curious';
      default:
        return 'calm';
    }
  }

  // Maps Chinese goal to API value
  String _goalToApi(String? goal) {
    if (goal == null) return 'relax';
    if (goal.contains('睡眠')) return 'sleep';
    if (goal.contains('放松')) return 'relax';
    if (goal.contains('饮食')) return 'diet';
    if (goal.contains('体质')) return 'health';
    if (goal.contains('中医')) return 'tcm';
    if (goal.contains('情绪')) return 'emotion';
    return 'relax';
  }

  // Maps Chinese stage to API value
  String _stageToApi(String? stage) {
    if (stage == null) return 'professional';
    if (stage == '20-30岁') return 'student';
    if (stage == '30-40岁') return 'professional';
    if (stage == '40-50岁') return 'mid_career';
    if (stage == '50-60岁') return 'pre_retirement';
    if (stage == '60岁以上') return 'retired';
    return 'professional';
  }

  // Maps selected hour index to API time
  String _hourToApi(int? hourIndex) {
    if (hourIndex == null) return 'morning';
    final hour = [6, 7, 8, 9, 12, 15, 18, 20, 21][hourIndex];
    if (hour < 12) return 'morning';
    if (hour < 18) return 'afternoon';
    return 'evening';
  }

  Future<void> _finishOnboarding() async {
    if (!_ensureLegalConsent()) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    if (_selectedFeeling != null) {
      await prefs.setString('user_feeling', _selectedFeeling!);
    }
    if (_selectedGoal != null) {
      await prefs.setString('user_goal', _selectedGoal!);
    }
    if (_selectedStage != null) {
      await prefs.setString('user_stage', _selectedStage!);
    }
    if (_selectedHour != null) {
      await prefs.setInt('preferred_hour', _selectedHour!);
    }
    if (_selectedStyle != null) {
      await prefs.setString('style_preference', _selectedStyle!);
    }
    await prefs.setString('hemisphere', 'north'); // Default hemisphere

    // Call onboarding complete API
    try {
      final apiClient = ApiClient();
      await apiClient.post(
        '/api/v1/seasons/onboarding/complete',
        data: {
          'feeling': _feelingToApi(_selectedFeeling),
          'help_goal': _goalToApi(_selectedGoal),
          'life_stage': _stageToApi(_selectedStage),
          'support_time': _hourToApi(_selectedHour),
          'style_preference': _selectedStyle,
        },
      );
    } catch (e) {
      // API call failed, fallback to local storage - don't block user
      debugPrint('Onboarding API call failed: $e');
    }

    await OnboardingPage.markCompleted();

    if (mounted) {
      setState(() => _isLoading = false);
      context.go('/home');
    }
  }

  bool _ensureLegalConsent() {
    if (_acceptedLegal) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请先阅读并同意用户协议和隐私政策')));
    return false;
  }

  // ── 主题感知辅助 ──

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _bg(BuildContext context) => _isDark(context)
      ? ShunshiDarkColors.background
      : ShunshiColors.background;
  Color _primary(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.primary : ShunshiColors.primary;
  Color _primaryLight(BuildContext context) => _isDark(context)
      ? ShunshiDarkColors.primaryLight
      : ShunshiColors.primaryLight;
  Color _textPrimary(BuildContext context) => _isDark(context)
      ? ShunshiDarkColors.textPrimary
      : ShunshiColors.textPrimary;
  Color _textSecondary(BuildContext context) => _isDark(context)
      ? ShunshiDarkColors.textSecondary
      : ShunshiColors.textSecondary;
  Color _textHint(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.textHint : ShunshiColors.textHint;
  Color _border(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.border : ShunshiColors.border;
  Color _surfaceDim(BuildContext context) => _isDark(context)
      ? ShunshiDarkColors.surfaceDim
      : ShunshiColors.surfaceDim;
  Color _surface(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.surface : ShunshiColors.surface;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 900 && _currentPage == 0) {
      return _buildDesktopWelcome(context);
    }
    return Scaffold(
      backgroundColor: _bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(ShunshiSpacing.md),
                child: TextButton(
                  onPressed: _isLoading ? null : _finishOnboarding,
                  child: Text(
                    '跳过',
                    style: ShunshiTextStyles.caption.copyWith(
                      color: _textHint(context),
                    ),
                  ),
                ),
              ),
            ),

            // 页面内容
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: 7,
                physics: _isLoading
                    ? const NeverScrollableScrollPhysics()
                    : null,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _buildStep(context, index),
              ),
            ),

            if (_currentPage == 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ShunshiSpacing.pagePadding,
                ),
                child: _buildLegalConsent(context),
              ),

            // 进度指示器
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ShunshiSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? _primary(context)
                          : _surfaceDim(context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // 底部按钮
            Padding(
              padding: EdgeInsets.fromLTRB(
                ShunshiSpacing.pagePadding,
                ShunshiSpacing.md,
                ShunshiSpacing.pagePadding,
                ShunshiSpacing.xl,
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : GentleButton(
                      text: _currentPage == 6 ? '准备好了' : '下一步',
                      isPrimary: true,
                      onPressed: _canProceed ? _nextPage : null,
                      horizontalPadding: ShunshiSpacing.xl * 2,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalConsent(BuildContext context, {bool centered = false}) {
    return Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _acceptedLegal,
            activeColor: _primary(context),
            onChanged: _isLoading
                ? null
                : (value) => setState(() => _acceptedLegal = value ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('我已阅读并同意', style: ShunshiTextStyles.caption),
              TextButton(
                onPressed: () => context.push('/terms'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('《用户协议》'),
              ),
              Text('和', style: ShunshiTextStyles.caption),
              TextButton(
                onPressed: () => context.push('/privacy'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('《隐私政策》'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopWelcome(BuildContext context) {
    final primary = _primary(context);
    final textPrimary = _textPrimary(context);
    final textSecondary = _textSecondary(context);
    final features = <(IconData, String, String)>[
      (
        Icons.calendar_month_outlined,
        '节气与作息',
        '结合日期、地区与用户选择展示可执行提醒，不把传统知识写成医疗结论。',
      ),
      (Icons.favorite_border, '每日自我照顾', '从睡眠、压力、饮食与活动中选择今天最需要的一件事。'),
      (Icons.fact_check_outlined, '来源与边界', '内容展示来源、适用人群、更新时间与禁忌；高风险情况提示就医。'),
      (Icons.auto_graph_outlined, '一周成长记录', '只根据用户真实记录生成回顾，没有数据时如实显示空状态。'),
    ];

    return Scaffold(
      backgroundColor: _bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 56,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, _primaryLight(context)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.eco, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '顺时',
                      style: ShunshiTextStyles.heading.copyWith(
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _isLoading ? null : _finishOnboarding,
                      child: const Text('直接进入体验'),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(56, 56, 56, 64),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary.withValues(alpha: 0.12), _bg(context)],
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '面向中国用户的节气与日常自我照顾工具',
                                  style: ShunshiTextStyles.caption.copyWith(
                                    color: primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '顺着时间照顾自己，\n今天先做一件小事。',
                                style: ShunshiTextStyles.greeting.copyWith(
                                  color: textPrimary,
                                  fontSize: 48,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                '顺时把节气知识、个人记录和温和提醒整理成普通人看得懂的行动建议。重要健康问题始终交给有资质的专业人员。',
                                style: ShunshiTextStyles.body.copyWith(
                                  color: textSecondary,
                                  height: 1.8,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  GentleButton(
                                    text: '开始个性化设置',
                                    isPrimary: true,
                                    onPressed: _nextPage,
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : _finishOnboarding,
                                    icon: const Icon(Icons.arrow_forward),
                                    label: const Text('先看看首页'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '仅用于日常自我照顾与信息整理，不替代医疗诊断、治疗或紧急服务。',
                                style: ShunshiTextStyles.caption.copyWith(
                                  color: _textHint(context),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildLegalConsent(context),
                            ],
                          ),
                        ),
                        const SizedBox(width: 56),
                        Expanded(
                          flex: 4,
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: _surface(context),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: _border(context)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 36,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '今天的建议如何产生',
                                  style: ShunshiTextStyles.heading.copyWith(
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                for (final item in [
                                  '读取你主动选择的目标',
                                  '核对节气、地区与内容更新时间',
                                  '显示来源、适用范围和禁忌',
                                  '由你决定是否采用并记录反馈',
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            item,
                                            style: ShunshiTextStyles.body
                                                .copyWith(color: textSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 56,
                  vertical: 56,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '你会得到什么',
                        style: ShunshiTextStyles.insight.copyWith(
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GridView.count(
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.15,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final feature in features)
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: _surface(context),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _border(context)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(feature.$1, color: primary),
                                  const SizedBox(height: 16),
                                  Text(
                                    feature.$2,
                                    style: ShunshiTextStyles.heading.copyWith(
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Text(
                                      feature.$3,
                                      style: ShunshiTextStyles.caption.copyWith(
                                        color: textSecondary,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.workspace_premium_outlined,
                              color: primary,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                '免费版可完成基础记录与节气浏览；会员权益、额度、续费和报告导出以下单确认页及服务端校验为准。',
                                style: ShunshiTextStyles.body.copyWith(
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(56, 18, 56, 32),
                child: Text(
                  '© ${DateTime.now().year} 顺时 · 健康内容上线前需完成专业复核与主体合规信息补齐',
                  style: ShunshiTextStyles.caption.copyWith(
                    color: _textHint(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, int step) {
    switch (step) {
      case 0:
        return _buildWelcomeStep(context);
      case 1:
        return _buildFeelingStep(context);
      case 2:
        return _buildGoalStep(context);
      case 3:
        return _buildStageStep(context);
      case 4:
        return _buildTimeStep(context);
      case 5:
        return _buildStyleStep(context);
      case 6:
        return _buildCompleteStep(context);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==================== Step 0: 欢迎 ====================
  // "Hi, I'm 顺时" + 大留白 + 品牌色渐变背景

  Widget _buildWelcomeStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShunshiSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 品牌色渐变背景logo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primary(context), _primaryLight(context)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.eco, size: 48, color: Colors.white),
          ),
          const SizedBox(height: ShunshiSpacing.xxl),

          // 大留白 + 标题
          Text(
            'Hi，我是顺时',
            style: ShunshiTextStyles.greeting.copyWith(
              color: _textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ShunshiSpacing.md),
          Text(
            '你的专属养生伙伴\n让健康融入每一天',
            textAlign: TextAlign.center,
            style: ShunshiTextStyles.bodySecondary.copyWith(
              color: _textSecondary(context),
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Step 1: 情绪选择 (NEW) ====================

  Widget _buildFeelingStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShunshiSpacing.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: ShunshiSpacing.xl),
          Text(
            '你最近感觉如何？',
            style: ShunshiTextStyles.greeting.copyWith(
              color: _textPrimary(context),
              fontSize: 24,
            ),
          ),
          const SizedBox(height: ShunshiSpacing.sm),
          Text(
            '选择最符合你当前状态的一项',
            style: ShunshiTextStyles.bodySecondary.copyWith(
              color: _textSecondary(context),
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xl),

          // 情绪选项
          ...List.generate(_feelings.length, (index) {
            final (label, emoji) = _feelings[index];
            final isSelected = _selectedFeeling == label;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _feelings.length - 1 ? ShunshiSpacing.sm : 0,
              ),
              child: SoftCard(
                borderRadius: ShunshiSpacing.radiusLarge,
                borderColor: isSelected ? _primary(context) : null,
                borderWidth: isSelected ? 1.5 : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: ShunshiSpacing.lg,
                  vertical: ShunshiSpacing.md + 4,
                ),
                onTap: () => setState(() => _selectedFeeling = label),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: ShunshiSpacing.md),
                    Expanded(
                      child: Text(
                        label,
                        style: ShunshiTextStyles.body.copyWith(
                          color: isSelected
                              ? _primary(context)
                              : _textPrimary(context),
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: _primary(context),
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== Step 2: 目标 ====================
  // 卡片式选择养生目标

  Widget _buildGoalStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShunshiSpacing.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: ShunshiSpacing.xl),
          Text(
            '你最想改善什么？',
            style: ShunshiTextStyles.greeting.copyWith(
              color: _textPrimary(context),
              fontSize: 24,
            ),
          ),
          const SizedBox(height: ShunshiSpacing.sm),
          Text(
            '选择一个你最关心的养生目标',
            style: ShunshiTextStyles.bodySecondary.copyWith(
              color: _textSecondary(context),
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xl),

          // 卡片式选择
          ...List.generate(_goals.length, (index) {
            final goal = _goals[index];
            final isSelected = _selectedGoal == goal;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _goals.length - 1 ? ShunshiSpacing.sm : 0,
              ),
              child: SoftCard(
                borderRadius: ShunshiSpacing.radiusLarge,
                borderColor: isSelected ? _primary(context) : null,
                borderWidth: isSelected ? 1.5 : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: ShunshiSpacing.lg,
                  vertical: ShunshiSpacing.md + 4,
                ),
                onTap: () => setState(() => _selectedGoal = goal),
                child: Row(
                  children: [
                    Text(goal, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: ShunshiSpacing.md),
                    Expanded(
                      child: Text(
                        goal,
                        style: ShunshiTextStyles.body.copyWith(
                          color: isSelected
                              ? _primary(context)
                              : _textPrimary(context),
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: _primary(context),
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== Step 3: 阶段 ====================
  // 4个选项

  Widget _buildStageStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShunshiSpacing.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: ShunshiSpacing.xl),
          Text(
            '你现在处于哪个阶段？',
            style: ShunshiTextStyles.greeting.copyWith(
              color: _textPrimary(context),
              fontSize: 24,
            ),
          ),
          const SizedBox(height: ShunshiSpacing.sm),
          Text(
            '帮助我们为你定制方案',
            style: ShunshiTextStyles.bodySecondary.copyWith(
              color: _textSecondary(context),
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xl),
          ...List.generate(_stages.length, (index) {
            final (age, label) = _stages[index];
            final isSelected = _selectedStage == age;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _stages.length - 1 ? ShunshiSpacing.sm : 0,
              ),
              child: SoftCard(
                borderRadius: ShunshiSpacing.radiusLarge,
                borderColor: isSelected ? _primary(context) : null,
                borderWidth: isSelected ? 1.5 : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: ShunshiSpacing.lg,
                  vertical: ShunshiSpacing.md + 4,
                ),
                onTap: () => setState(() => _selectedStage = age),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        age,
                        style: ShunshiTextStyles.body.copyWith(
                          color: isSelected
                              ? _primary(context)
                              : _textPrimary(context),
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(
                      label,
                      style: ShunshiTextStyles.caption.copyWith(
                        color: isSelected
                            ? _primary(context)
                            : _textHint(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== Step 4: 时间偏好 ====================

  Widget _buildTimeStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShunshiSpacing.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: ShunshiSpacing.xl),
          Text(
            '你通常什么时候使用？',
            style: ShunshiTextStyles.greeting.copyWith(
              color: _textPrimary(context),
              fontSize: 24,
            ),
          ),
          const SizedBox(height: ShunshiSpacing.sm),
          Text(
            '我们会在合适的时间提醒你',
            style: ShunshiTextStyles.bodySecondary.copyWith(
              color: _textSecondary(context),
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xl),
          Wrap(
            spacing: ShunshiSpacing.sm,
            runSpacing: ShunshiSpacing.sm,
            children: _hours.map((hour) {
              final isSelected = _selectedHour == _hours.indexOf(hour);
              return InkWell(
                onTap: () =>
                    setState(() => _selectedHour = _hours.indexOf(hour)),
                borderRadius: BorderRadius.circular(ShunshiSpacing.radiusFull),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: ShunshiSpacing.lg,
                    vertical: ShunshiSpacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? _primary(context) : _surface(context),
                    borderRadius: BorderRadius.circular(
                      ShunshiSpacing.radiusFull,
                    ),
                    border: Border.all(
                      color: isSelected ? _primary(context) : _border(context),
                    ),
                  ),
                  child: Text(
                    hour,
                    style: ShunshiTextStyles.bodySecondary.copyWith(
                      color: isSelected ? Colors.white : _textPrimary(context),
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==================== Step 5: 风格选择 (NEW) ====================

  Widget _buildStyleStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShunshiSpacing.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: ShunshiSpacing.xl),
          Text(
            '顺时应该是什么风格？',
            style: ShunshiTextStyles.greeting.copyWith(
              color: _textPrimary(context),
              fontSize: 24,
            ),
          ),
          const SizedBox(height: ShunshiSpacing.sm),
          Text(
            '选择你喜欢的界面风格',
            style: ShunshiTextStyles.bodySecondary.copyWith(
              color: _textSecondary(context),
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xl),

          // 风格选项
          ...List.generate(_styles.length, (index) {
            final (label, apiValue) = _styles[index];
            final isSelected = _selectedStyle == label;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _styles.length - 1 ? ShunshiSpacing.sm : 0,
              ),
              child: SoftCard(
                borderRadius: ShunshiSpacing.radiusLarge,
                borderColor: isSelected ? _primary(context) : null,
                borderWidth: isSelected ? 1.5 : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: ShunshiSpacing.lg,
                  vertical: ShunshiSpacing.md + 4,
                ),
                onTap: () => setState(() => _selectedStyle = label),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: ShunshiTextStyles.body.copyWith(
                          color: isSelected
                              ? _primary(context)
                              : _textPrimary(context),
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: _primary(context),
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== Step 6: 完成 ====================
  // "准备好了" + 进入首页

  Widget _buildCompleteStep(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShunshiSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _primary(context).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 40,
              color: _primary(context),
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xxl),
          Text(
            '准备好了',
            style: ShunshiTextStyles.greeting.copyWith(
              color: _textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ShunshiSpacing.md),
          Text(
            '开始你的养生之旅吧',
            textAlign: TextAlign.center,
            style: ShunshiTextStyles.bodySecondary.copyWith(
              color: _textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
