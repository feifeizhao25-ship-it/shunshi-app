// lib/presentation/pages/solar_term_page.dart
//
// 节气养生页面 — 沉浸、自然、柔和
// 顶部大视觉区域(40%) + 养生说明 + 生活建议SoftCard + 横滑推荐
// SingleChildScrollView滚动

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/shunshi_colors.dart';
import '../../core/theme/shunshi_spacing.dart';
import '../../core/theme/shunshi_text_styles.dart';
import '../widgets/components/soft_card.dart';

// ── 数据模型 ──────────────────────────────────────────

class SolarTermData {
  final String name;
  final String date;
  final String description;
  final String season; // spring / summer / autumn / winter
  final String emoji;
  final List<String> healthTips;
  final List<String> dietaryAdvice;
  final List<String> teaRecommendations;
  final List<String> exerciseAdvice;
  final List<String> sleepAdvice;
  final List<String> recommendations; // 推荐内容标题

  const SolarTermData({
    required this.name,
    required this.date,
    required this.description,
    required this.season,
    required this.emoji,
    required this.healthTips,
    required this.dietaryAdvice,
    required this.teaRecommendations,
    required this.exerciseAdvice,
    required this.sleepAdvice,
    this.recommendations = const [],
  });

  static List<SolarTermData> all() => [
        const SolarTermData(
          name: '立春',
          date: '二月四日',
          season: 'spring',
          emoji: '🌱',
          description: '春季开始，万物复苏。阳气生发，宜疏肝理气，调畅情志。',
          healthTips: ['宜早睡早起', '多食辛甘发散之物'],
          dietaryAdvice: ['葱姜蒜', '韭菜', '豆芽'],
          teaRecommendations: ['茉莉花茶', '玫瑰花茶'],
          exerciseAdvice: ['散步', '太极拳'],
          sleepAdvice: ['22点前入睡', '早起晒太阳'],
          recommendations: ['春日养肝食疗', '疏肝理气瑜伽', '茉莉花茶冲泡'],
        ),
        const SolarTermData(
          name: '雨水',
          date: '二月十九日',
          season: 'spring',
          emoji: '🌧️',
          description: '降雨增多，湿气渐重。脾胃当令，宜健脾祛湿。',
          healthTips: ['健脾祛湿', '适当运动'],
          dietaryAdvice: ['山药', '薏米', '红豆'],
          teaRecommendations: ['陈皮普洱', '茯苓茶'],
          exerciseAdvice: ['室内运动', '八段锦'],
          sleepAdvice: ['保持干燥', '早睡'],
          recommendations: ['健脾祛湿粥', '八段锦跟练', '春季茶饮推荐'],
        ),
        const SolarTermData(
          name: '惊蛰',
          date: '三月五日',
          season: 'spring',
          emoji: '🐛',
          description: '惊蛰万物生，宜舒展身体，调畅肝气。春雷始鸣，蛰虫苏醒。',
          healthTips: ['舒展筋骨', '养肝护肝'],
          dietaryAdvice: ['菠菜', '春笋', '枸杞'],
          teaRecommendations: ['菊花茶', '枸杞茶'],
          exerciseAdvice: ['户外散步', '拉伸运动'],
          sleepAdvice: ['23点前入睡', '早起锻炼'],
          recommendations: ['春季养肝食谱', '晨起拉伸15分钟', '菊花枸杞茶'],
        ),
        const SolarTermData(
          name: '清明',
          date: '四月四日',
          season: 'spring',
          emoji: '🌿',
          description: '清明时节，草木繁茂。宜踏青运动，疏泄肝气。',
          healthTips: ['踏青散步', '清淡饮食'],
          dietaryAdvice: ['荠菜', '春韭', '香椿'],
          teaRecommendations: ['龙井茶', '白茶'],
          exerciseAdvice: ['踏青', '放风筝'],
          sleepAdvice: ['顺应天时', '午间小憩'],
          recommendations: ['清明养生指南', '春日踏青路线', '明目茶饮推荐'],
        ),
        const SolarTermData(
          name: '谷雨',
          date: '四月二十日',
          season: 'spring',
          emoji: '🌾',
          description: '雨生百谷，春将尽。宜养肝健脾，祛湿防过敏。',
          healthTips: ['养肝健脾', '防过敏'],
          dietaryAdvice: ['香椿', '菠菜', '山药'],
          teaRecommendations: ['谷雨茶', '陈皮茶'],
          exerciseAdvice: ['慢跑', '太极拳'],
          sleepAdvice: ['早睡早起', '勿过度劳累'],
          recommendations: ['春季过敏预防', '健脾祛湿食疗', '谷雨茶养生'],
        ),
        const SolarTermData(
          name: '立夏',
          date: '五月六日',
          season: 'summer',
          emoji: '☀️',
          description: '夏季开始，心气渐旺。宜养心安神，清淡饮食。',
          healthTips: ['养心安神', '清淡饮食'],
          dietaryAdvice: ['苦瓜', '绿豆', '西瓜'],
          teaRecommendations: ['酸梅汤', '薄荷茶'],
          exerciseAdvice: ['晨练', '游泳'],
          sleepAdvice: ['晚睡早起', '午睡30分钟'],
          recommendations: ['夏季养心食谱', '消暑茶饮推荐', '晨间养生运动'],
        ),
        const SolarTermData(
          name: '小满',
          date: '五月二十一日',
          season: 'summer',
          emoji: '🌻',
          description: '小满者，物至于此小得盈满。宜清热利湿，健脾和胃。',
          healthTips: ['清热利湿', '健脾和胃'],
          dietaryAdvice: ['冬瓜', '薏米', '莲子'],
          teaRecommendations: ['冬瓜茶', '薏米水'],
          exerciseAdvice: ['散步', '瑜伽'],
          sleepAdvice: ['夜卧早起', '适当午睡'],
          recommendations: ['清热利湿汤饮', '小满养生指南', '夏日瑜伽推荐'],
        ),
        const SolarTermData(
          name: '芒种',
          date: '六月六日',
          season: 'summer',
          emoji: '🌾',
          description: '芒种忙种，天气渐热。宜清热化湿，益气生津。',
          healthTips: ['清热化湿', '益气生津'],
          dietaryAdvice: ['绿豆', '酸梅', '西瓜'],
          teaRecommendations: ['酸梅汤', '菊花茶'],
          exerciseAdvice: ['游泳', '太极'],
          sleepAdvice: ['晚睡早起', '补充午休'],
          recommendations: ['消暑养生食谱', '夏季护肤茶饮', '芒种运动推荐'],
        ),
        const SolarTermData(
          name: '小暑',
          date: '七月七日',
          season: 'summer',
          emoji: '🌡️',
          description: '小暑温风至，炎热将至。宜养心防暑，静心度夏。',
          healthTips: ['养心防暑', '静心度夏'],
          dietaryAdvice: ['莲藕', '绿豆', '冬瓜'],
          teaRecommendations: ['金银花茶', '荷叶茶'],
          exerciseAdvice: ['晨练', '傍晚散步'],
          sleepAdvice: ['夜卧早起', '午休30分钟'],
          recommendations: ['消暑降温食谱', '心静自然凉茶饮', '小暑运动指南'],
        ),
        const SolarTermData(
          name: '大暑',
          date: '七月二十二日',
          season: 'summer',
          emoji: '🔥',
          description: '大暑节气，一年最热。宜清热解暑，补气养阴。',
          healthTips: ['清热解暑', '补气养阴'],
          dietaryAdvice: ['西瓜', '苦瓜', '绿豆'],
          teaRecommendations: ['酸梅汤', '菊花茶'],
          exerciseAdvice: ['晨间运动', '游泳'],
          sleepAdvice: ['避暑就凉', '充足睡眠'],
          recommendations: ['大暑养生食谱', '清凉消暑茶饮', '夏日晚间散步'],
        ),
        const SolarTermData(
          name: '立秋',
          date: '八月七日',
          season: 'autumn',
          emoji: '🍂',
          description: '秋季开始，暑去凉来。宜滋阴润肺，收敛精神。',
          healthTips: ['滋阴润肺', '收敛精神'],
          dietaryAdvice: ['梨', '百合', '银耳'],
          teaRecommendations: ['蜂蜜柚子茶', '银耳羹'],
          exerciseAdvice: ['慢跑', '登山'],
          sleepAdvice: ['早卧早起', '与鸡俱兴'],
          recommendations: ['秋季润肺食谱', '滋阴养生茶饮', '秋日登山指南'],
        ),
        const SolarTermData(
          name: '处暑',
          date: '八月二十三日',
          season: 'autumn',
          emoji: '🌤️',
          description: '处暑出暑，秋意渐浓。宜润燥养阴，调理脾胃。',
          healthTips: ['润燥养阴', '调理脾胃'],
          dietaryAdvice: ['百合', '银耳', '蜂蜜'],
          teaRecommendations: ['罗汉果茶', '蜂蜜水'],
          exerciseAdvice: ['太极拳', '慢跑'],
          sleepAdvice: ['早睡早起', '适度午休'],
          recommendations: ['处暑润燥食谱', '秋季养生茶饮', '处暑运动推荐'],
        ),
        const SolarTermData(
          name: '白露',
          date: '九月七日',
          season: 'autumn',
          emoji: '💧',
          description: '白露秋分夜，一夜凉一夜。宜温润防燥，养阴润肺。',
          healthTips: ['温润防燥', '养阴润肺'],
          dietaryAdvice: ['梨', '银耳', '百合'],
          teaRecommendations: ['桂花茶', '百合茶'],
          exerciseAdvice: ['晨跑', '太极'],
          sleepAdvice: ['早睡', '注意保暖'],
          recommendations: ['白露养生食谱', '秋季茶饮推荐', '晨间养生运动'],
        ),
        const SolarTermData(
          name: '秋分',
          date: '九月二十三日',
          season: 'autumn',
          emoji: '🌙',
          description: '秋分者，阴阳相半。宜平衡阴阳，调和情志。',
          healthTips: ['平衡阴阳', '调和情志'],
          dietaryAdvice: ['山药', '百合', '莲子'],
          teaRecommendations: ['菊花茶', '枸杞茶'],
          exerciseAdvice: ['散步', '瑜伽'],
          sleepAdvice: ['早睡早起', '适度运动'],
          recommendations: ['秋分养生食谱', '平衡阴阳茶饮', '秋季瑜伽推荐'],
        ),
        const SolarTermData(
          name: '寒露',
          date: '十月八日',
          season: 'autumn',
          emoji: '🍁',
          description: '寒露时节，露气寒冷。宜温润防寒，养阴润燥。',
          healthTips: ['温润防寒', '养阴润燥'],
          dietaryAdvice: ['芝麻', '核桃', '梨'],
          teaRecommendations: ['红枣茶', '桂圆茶'],
          exerciseAdvice: ['慢跑', '登山'],
          sleepAdvice: ['早睡', '注意保暖'],
          recommendations: ['寒露养生食谱', '温润茶饮推荐', '秋日登山指南'],
        ),
        const SolarTermData(
          name: '霜降',
          date: '十月二十三日',
          season: 'autumn',
          emoji: '❄️',
          description: '霜降时节，气肃而凝。宜温补气血，养胃润燥。',
          healthTips: ['温补气血', '养胃润燥'],
          dietaryAdvice: ['柿子', '栗子', '牛肉'],
          teaRecommendations: ['红茶', '姜茶'],
          exerciseAdvice: ['太极', '慢跑'],
          sleepAdvice: ['早睡', '保暖防寒'],
          recommendations: ['霜降养生食谱', '暖身茶饮推荐', '秋季养生运动'],
        ),
        const SolarTermData(
          name: '立冬',
          date: '十一月七日',
          season: 'winter',
          emoji: '🌡️',
          description: '冬季开始，万物收藏。宜温补养藏，补肾固本。',
          healthTips: ['温补养藏', '补肾固本'],
          dietaryAdvice: ['羊肉', '核桃', '黑豆'],
          teaRecommendations: ['红茶', '红枣枸杞茶'],
          exerciseAdvice: ['室内运动', '八段锦'],
          sleepAdvice: ['早卧晚起', '避寒就温'],
          recommendations: ['冬季温补食谱', '暖身茶饮推荐', '室内养生运动'],
        ),
        const SolarTermData(
          name: '小雪',
          date: '十一月二十二日',
          season: 'winter',
          emoji: '🌨️',
          description: '小雪时节，天气渐冷。宜温阳散寒，补肾助阳。',
          healthTips: ['温阳散寒', '补肾助阳'],
          dietaryAdvice: ['牛肉', '羊肉', '红枣'],
          teaRecommendations: ['姜枣茶', '桂圆红枣茶'],
          exerciseAdvice: ['室内瑜伽', '八段锦'],
          sleepAdvice: ['早卧晚起', '注意保暖'],
          recommendations: ['小雪温补食谱', '冬日暖身茶饮', '室内养生瑜伽'],
        ),
        const SolarTermData(
          name: '大雪',
          date: '十二月七日',
          season: 'winter',
          emoji: '⛄',
          description: '大雪纷飞，天地闭塞。宜温补助阳，养藏精气。',
          healthTips: ['温补助阳', '养藏精气'],
          dietaryAdvice: ['羊肉汤', '当归鸡', '核桃'],
          teaRecommendations: ['当归茶', '红枣姜茶'],
          exerciseAdvice: ['室内运动', '太极'],
          sleepAdvice: ['早卧晚起', '避寒保暖'],
          recommendations: ['大雪养生食谱', '冬日滋补汤品', '冬季养生指南'],
        ),
        const SolarTermData(
          name: '冬至',
          date: '十二月二十二日',
          season: 'winter',
          emoji: '❄️',
          description: '冬至一阳生，阴极阳生。宜温阳益气，补肾固本。',
          healthTips: ['温阳益气', '补肾固本'],
          dietaryAdvice: ['饺子', '羊肉汤', '八宝粥'],
          teaRecommendations: ['红茶', '枸杞红枣茶'],
          exerciseAdvice: ['散步', '八段锦'],
          sleepAdvice: ['早卧晚起', '养藏精气'],
          recommendations: ['冬至养生食谱', '冬季进补指南', '冬至茶饮推荐'],
        ),
        const SolarTermData(
          name: '小寒',
          date: '一月五日',
          season: 'winter',
          emoji: '🧊',
          description: '小寒时节，冷气积久。宜温阳散寒，益气补血。',
          healthTips: ['温阳散寒', '益气补血'],
          dietaryAdvice: ['羊肉', '桂圆', '红枣'],
          teaRecommendations: ['姜茶', '当归红茶'],
          exerciseAdvice: ['室内运动', '太极'],
          sleepAdvice: ['早睡', '注意保暖'],
          recommendations: ['小寒养生食谱', '暖身滋补汤饮', '冬季养生运动'],
        ),
        const SolarTermData(
          name: '大寒',
          date: '一月二十日',
          season: 'winter',
          emoji: '🧣',
          description: '大寒到顶点，日后天渐暖。宜温补固本，为春做准备。',
          healthTips: ['温补固本', '迎接春天'],
          dietaryAdvice: ['八宝饭', '腊八粥', '羊肉'],
          teaRecommendations: ['红茶', '枸杞茶'],
          exerciseAdvice: ['室内太极', '八段锦'],
          sleepAdvice: ['早睡', '保暖防寒'],
          recommendations: ['大寒养生食谱', '腊八粥做法', '冬季进补指南'],
        ),
      ];
}

// ── 季节颜色映射 ──────────────────────────────────────

Color _seasonGradientStart(String season) {
  switch (season) {
    case 'spring':
      return const Color(0xFFB5C7A8); // sage green
    case 'summer':
      return const Color(0xFFD4A574); // warm amber
    case 'autumn':
      return const Color(0xFFC4B5A0); // earth
    case 'winter':
      return const Color(0xFF9BB8C9); // calm blue
    default:
      return ShunshiColors.primary;
  }
}

Color _seasonGradientEnd(String season) {
  switch (season) {
    case 'spring':
      return const Color(0xFFD8E5D0);
    case 'summer':
      return const Color(0xFFE8D0B8);
    case 'autumn':
      return const Color(0xFFE0D8CC);
    case 'winter':
      return const Color(0xFFC8D8E2);
    default:
      return ShunshiColors.background;
  }
}

String _seasonLabel(String season) {
  switch (season) {
    case 'spring':
      return '春';
    case 'summer':
      return '夏';
    case 'autumn':
      return '秋';
    case 'winter':
      return '冬';
    default:
      return '';
  }
}

// ── 主页面 ────────────────────────────────────────────

class SolarTermPage extends ConsumerStatefulWidget {
  const SolarTermPage({super.key});

  @override
  ConsumerState<SolarTermPage> createState() => _SolarTermPageState();
}

class _SolarTermPageState extends ConsumerState<SolarTermPage> {
  SolarTermData _getCurrentSolarTerm() {
    final now = DateTime.now();
    final terms = SolarTermData.all();
    final monthIndex = now.month;
    final termIndex = ((monthIndex - 2) * 2 + now.day ~/ 15) % 24;
    return terms[termIndex.clamp(0, terms.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final currentTerm = _getCurrentSolarTerm();

    return Scaffold(
      backgroundColor: ShunshiColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 顶部大视觉区域 (40%) ──
            _HeroSection(term: currentTerm),

            // ── 节气养生说明 ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ShunshiSpacing.pagePadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),
                  Text(
                    '节气养生',
                    style: ShunshiTextStyles.heading,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentTerm.description,
                    style: ShunshiTextStyles.body.copyWith(height: 1.8),
                  ),
                ],
              ),
            ),

            // ── 生活建议卡片 ──
            _AdviceSection(term: currentTerm),

            // ── 推荐内容 ──
            _RecommendSection(term: currentTerm),

            // 底部留白
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── 顶部大视觉区域 — 占屏幕40%，渐变背景(primary→background) ──

class _HeroSection extends StatelessWidget {
  final SolarTermData term;

  const _HeroSection({required this.term});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.40;

    return Container(
      height: heroHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ShunshiColors.primary,
            ShunshiColors.background,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(ShunshiSpacing.radiusXL),
          bottomRight: Radius.circular(ShunshiSpacing.radiusXL),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 节气emoji
            Text(
              term.emoji,
              style: const TextStyle(fontSize: 36),
            ),
            const SizedBox(height: 10),
            // 节气名称 — 28sp w300 居中
            Text(
              term.name,
              style: ShunshiTextStyles.greeting.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w300,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            // 季节+日期
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ShunshiColors.textPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(
                      ShunshiSpacing.radiusFull,
                    ),
                  ),
                  child: Text(
                    _seasonLabel(term.season),
                    style: ShunshiTextStyles.overline.copyWith(
                      color: ShunshiColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  term.date,
                  style: ShunshiTextStyles.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 生活建议卡片 — SoftCard: 图标 + 标题 + 一句话 ──

class _AdviceSection extends StatelessWidget {
  final SolarTermData term;

  const _AdviceSection({required this.term});

  @override
  Widget build(BuildContext context) {
    final tips = <_AdviceItem>[
      if (term.exerciseAdvice.isNotEmpty)
        _AdviceItem(
          emoji: '🧘',
          title: '运动养生',
          subtitle: term.exerciseAdvice.first,
        ),
      if (term.teaRecommendations.isNotEmpty)
        _AdviceItem(
          emoji: '🍵',
          title: '茶饮推荐',
          subtitle: term.teaRecommendations.first,
        ),
      if (term.dietaryAdvice.isNotEmpty)
        _AdviceItem(
          emoji: '🍽️',
          title: '饮食建议',
          subtitle: '多食 ${term.dietaryAdvice.take(2).join("、")}',
        ),
      if (term.sleepAdvice.isNotEmpty)
        _AdviceItem(
          emoji: '😴',
          title: '作息建议',
          subtitle: term.sleepAdvice.first,
        ),
    ].take(3).toList(); // 2-3个

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShunshiSpacing.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          Text(
            '生活建议',
            style: ShunshiTextStyles.heading,
          ),
          const SizedBox(height: 16),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SoftCard(
                  borderRadius: ShunshiSpacing.radiusMedium,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Text(
                        tip.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tip.title,
                              style: ShunshiTextStyles.heading.copyWith(
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tip.subtitle,
                              style: ShunshiTextStyles.bodySecondary.copyWith(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _AdviceItem {
  final String emoji;
  final String title;
  final String subtitle;

  const _AdviceItem({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

// ── 推荐内容横滑卡片 — PageView ──

class _RecommendSection extends StatelessWidget {
  final SolarTermData term;

  const _RecommendSection({required this.term});

  @override
  Widget build(BuildContext context) {
    if (term.recommendations.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShunshiSpacing.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          Text(
            '推荐内容',
            style: ShunshiTextStyles.heading,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.75),
              padEnds: false,
              itemCount: term.recommendations.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SoftCard(
                    borderRadius: ShunshiSpacing.radiusLarge,
                    padding: const EdgeInsets.all(20),
                    onTap: () {
                      // TODO: 导航到详情页
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          term.recommendations[index],
                          style: ShunshiTextStyles.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '查看详情 →',
                          style: ShunshiTextStyles.caption.copyWith(
                            color: ShunshiColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
