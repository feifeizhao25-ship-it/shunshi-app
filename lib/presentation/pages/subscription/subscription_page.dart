import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/store_service.dart';
import '../../widgets/components/components.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  int _selectedIndex = 0;
  bool _isPurchasing = false;

  final _plans = [
    _PlanData(
      name: '养心计划',
      price: '¥29.9',
      period: '月',
      icon: Icons.spa_outlined,
      features: ['无限AI对话', '个性化养生建议', '专属节气提醒'],
      color: ShunshiColors.primary,
    ),
    _PlanData(
      name: '疗愈计划',
      price: '¥49.9',
      period: '月',
      icon: Icons.favorite_outline,
      features: ['包含养心全部', '家庭关怀', '深度健康分析'],
      color: ShunshiColors.warm,
    ),
    _PlanData(
      name: '家庭计划',
      price: '¥79.9',
      period: '月',
      icon: Icons.family_restroom_outlined,
      features: ['包含疗愈全部', '最多5位家人'],
      color: ShunshiColors.calm,
    ),
  ];

  // ── 主题感知辅助 ──

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _bg(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.background : ShunshiColors.background;
  Color _textPrimary(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.textPrimary : ShunshiColors.textPrimary;
  Color _textSecondary(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.textSecondary : ShunshiColors.textSecondary;
  Color _textHint(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.textHint : ShunshiColors.textHint;
  Color _border(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.border : ShunshiColors.border;
  Color _surfaceDim(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.surfaceDim : ShunshiColors.surfaceDim;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: ShunshiSpacing.pagePadding,
            vertical: ShunshiSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 顶部导航 ──
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new,
                        color: _textPrimary(context), size: 20),
                  ),
                  Expanded(
                    child: Text(
                      '订阅',
                      style: ShunshiTextStyles.heading.copyWith(
                        color: _textPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ShunshiSpacing.lg),

              // ── 标题：insight样式 ──
              Text(
                '解锁更多可能',
                style: ShunshiTextStyles.insight.copyWith(
                  color: _textPrimary(context),
                ),
              ),
              const SizedBox(height: ShunshiSpacing.xs),
              Text(
                '选择适合你的养生方案',
                style: ShunshiTextStyles.bodySecondary.copyWith(
                  color: _textSecondary(context),
                ),
              ),

              const SizedBox(height: ShunshiSpacing.xl),

              // ── 计划卡片 ──
              ...List.generate(_plans.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        index < _plans.length - 1 ? ShunshiSpacing.md : 0,
                  ),
                  child: _buildPlanCard(context, _plans[index], index),
                );
              }),

              const SizedBox(height: ShunshiSpacing.xl),

              // ── GentleButton 立即订阅 ──
              Center(
                child: GentleButton(
                  text: '立即订阅',
                  isPrimary: true,
                  isLoading: _isPurchasing,
                  horizontalPadding: ShunshiSpacing.xl * 2,
                  onPressed: _isPurchasing ? null : _handleSubscribe,
                ),
              ),

              const SizedBox(height: ShunshiSpacing.lg),

              // ── 恢复购买：文字链接 ──
              Center(
                child: TextButton(
                  onPressed: _handleRestorePurchase,
                  child: Text(
                    '恢复购买',
                    style: ShunshiTextStyles.caption.copyWith(
                      color: _textHint(context),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: ShunshiSpacing.md),

              // ── 条款 ──
              Center(
                child: Text(
                  '订阅自动续费，可随时取消。购买即表示同意服务条款。',
                  textAlign: TextAlign.center,
                  style: ShunshiTextStyles.overline.copyWith(
                    color: _textHint(context),
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: ShunshiSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, _PlanData plan, int index) {
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.all(ShunshiSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? plan.color.withValues(alpha: 0.08)
              : _surfaceDim(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? plan.color : _border(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? plan.color.withValues(alpha: 0.15)
                        : _surfaceDim(context),
                    borderRadius:
                        BorderRadius.circular(ShunshiSpacing.radiusMedium),
                  ),
                  child: Icon(plan.icon, color: plan.color, size: 22),
                ),
                const SizedBox(width: ShunshiSpacing.md),
                Expanded(
                  child: Text(
                    plan.name,
                    style: ShunshiTextStyles.heading.copyWith(
                      color: _textPrimary(context),
                    ),
                  ),
                ),
                // 选中指示器
                if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: plan.color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _textHint(context), width: 1.5),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: ShunshiSpacing.sm),

            // 价格
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  plan.price,
                  style: ShunshiTextStyles.insight.copyWith(
                    color: plan.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(width: ShunshiSpacing.xs),
                Text(
                  '/${plan.period}',
                  style: ShunshiTextStyles.bodySecondary.copyWith(
                    color: _textSecondary(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: ShunshiSpacing.md),

            // 功能列表
            ...plan.features.map((feature) => Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        feature != plan.features.last ? ShunshiSpacing.xs : 0,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: plan.color, size: 16),
                      const SizedBox(width: ShunshiSpacing.sm),
                      Text(
                        feature,
                        style: ShunshiTextStyles.bodySecondary.copyWith(
                          color: _textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _handleSubscribe() {
    setState(() => _isPurchasing = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isPurchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_plans[_selectedIndex].name} 即将开放订阅'),
            backgroundColor: ShunshiColors.primary,
          ),
        );
      }
    });
  }

  Future<void> _handleRestorePurchase() async {
    final store = StoreService();
    if (!store.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('当前设备不支持应用内购'),
            backgroundColor: ShunshiColors.textSecondary,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
            child: CircularProgressIndicator(
              color: ShunshiColors.primary,
              strokeWidth: 2,
            ),
          ),
    );

    try {
      await store.restorePurchases();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在恢复购买，请稍候...'),
            duration: Duration(seconds: 3),
            backgroundColor: ShunshiColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('恢复购买失败: $e'),
            backgroundColor: ShunshiColors.error,
          ),
        );
      }
    }
  }
}

class _PlanData {
  final String name;
  final String price;
  final String period;
  final IconData icon;
  final List<String> features;
  final Color color;

  const _PlanData({
    required this.name,
    required this.price,
    required this.period,
    required this.icon,
    required this.features,
    required this.color,
  });
}
