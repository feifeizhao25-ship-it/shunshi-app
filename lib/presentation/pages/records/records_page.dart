import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/shunshi_colors.dart';
import '../../../core/theme/shunshi_spacing.dart';
import '../../../core/theme/shunshi_text_styles.dart';
import '../../../core/theme/shunshi_animations.dart';
import '../../widgets/components/components.dart';

/// 健康记录 — 像写日记，不严肃不复杂
///
/// 沉浸、简洁、无干扰的日记式健康记录
/// 4个Tab：情绪 / 睡眠 / 运动 / 饮食
/// 每个Tab：本周趋势图 + 今日摘要 + 底部输入区
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;

  // ── 模拟7天情绪数据 ──
  final List<_MoodRecord> _moodRecords = [
    _MoodRecord(date: '周一', emoji: '😊', label: '开心', value: 7.0, note: '工作顺利', time: '下午3:20'),
    _MoodRecord(date: '周二', emoji: '😄', label: '很棒', value: 9.0, note: '和朋友聚餐', time: '晚上8:10'),
    _MoodRecord(date: '周三', emoji: '😐', label: '一般', value: 5.0, note: '有点累', time: '中午12:30'),
    _MoodRecord(date: '周四', emoji: '🙂', label: '还行', value: 6.0, note: '', time: '上午10:00'),
    _MoodRecord(date: '周五', emoji: '😊', label: '开心', value: 8.0, note: '完成了项目', time: '下午5:45'),
    _MoodRecord(date: '周六', emoji: '😔', label: '低落', value: 3.0, note: '下雨了', time: '下午2:15'),
    _MoodRecord(date: '今天', emoji: '😊', label: '开心', value: 7.0, note: '', time: null),
  ];

  // ── 模拟7天睡眠数据 ──
  final List<_SleepRecord> _sleepRecords = [
    _SleepRecord(date: '周一', hours: 7.5, quality: _SleepQuality.good, bedtime: '22:30', wakeup: '06:00'),
    _SleepRecord(date: '周二', hours: 6.0, quality: _SleepQuality.poor, bedtime: '01:00', wakeup: '07:00'),
    _SleepRecord(date: '周三', hours: 8.0, quality: _SleepQuality.excellent, bedtime: '22:00', wakeup: '06:00'),
    _SleepRecord(date: '周四', hours: 7.0, quality: _SleepQuality.good, bedtime: '23:00', wakeup: '06:00'),
    _SleepRecord(date: '周五', hours: 7.5, quality: _SleepQuality.good, bedtime: '22:30', wakeup: '06:00'),
    _SleepRecord(date: '周六', hours: 5.5, quality: _SleepQuality.fair, bedtime: '00:30', wakeup: '06:00'),
    _SleepRecord(date: '今天', hours: 8.5, quality: _SleepQuality.excellent, bedtime: '22:00', wakeup: '06:30'),
  ];

  // ── 模拟7天运动数据 ──
  final List<_ExerciseRecord> _exerciseRecords = [
    _ExerciseRecord(date: '周一', minutes: 30, type: '散步', intensity: '轻'),
    _ExerciseRecord(date: '周二', minutes: 0, type: '', intensity: ''),
    _ExerciseRecord(date: '周三', minutes: 45, type: '瑜伽', intensity: '中'),
    _ExerciseRecord(date: '周四', minutes: 20, type: '拉伸', intensity: '轻'),
    _ExerciseRecord(date: '周五', minutes: 60, type: '跑步', intensity: '高'),
    _ExerciseRecord(date: '周六', minutes: 15, type: '散步', intensity: '轻'),
    _ExerciseRecord(date: '今天', minutes: 40, type: '游泳', intensity: '中'),
  ];

  // ── 模拟7天饮食数据 ──
  final List<_DietRecord> _dietRecords = [
    _DietRecord(date: '周一', score: 8, meals: '三餐规律，少油少盐', emoji: '🥗'),
    _DietRecord(date: '周二', score: 6, meals: '外卖较多', emoji: '🍔'),
    _DietRecord(date: '周三', score: 9, meals: '自己做饭，营养均衡', emoji: '🍲'),
    _DietRecord(date: '周四', score: 5, meals: '忘了吃早餐', emoji: '☕'),
    _DietRecord(date: '周五', score: 8, meals: '水果蔬菜吃得多', emoji: '🍎'),
    _DietRecord(date: '周六', score: 7, meals: '和朋友聚餐', emoji: '🥘'),
    _DietRecord(date: '今天', score: 9, meals: '清淡饮食', emoji: '🥬'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShunshiColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _MoodTab(records: _moodRecords),
                  _SleepTab(records: _sleepRecords),
                  _ExerciseTab(records: _exerciseRecords),
                  _DietTab(records: _dietRecords),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ShunshiSpacing.md,
        ShunshiSpacing.md,
        ShunshiSpacing.md,
        ShunshiSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            color: ShunshiColors.textPrimary,
          ),
          const SizedBox(width: ShunshiSpacing.xs),
          Text('健康记录', style: ShunshiTextStyles.heading),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const tabs = ['情绪', '睡眠', '运动', '饮食'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShunshiSpacing.pagePadding),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = _currentTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _tabController.animateTo(i),
              child: Column(
                children: [
                  Text(
                    tabs[i],
                    style: ShunshiTextStyles.caption.copyWith(
                      color: isActive
                          ? ShunshiColors.primary
                          : ShunshiColors.textHint,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      fontSize: isActive ? 15 : 14,
                    ),
                  ),
                  const SizedBox(height: ShunshiSpacing.sm),
                  AnimatedContainer(
                    duration: ShunshiAnimations.stateChange,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: isActive
                          ? ShunshiColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 情绪 Tab
// ═══════════════════════════════════════════

class _MoodTab extends StatefulWidget {
  final List<_MoodRecord> records;
  const _MoodTab({required this.records});

  @override
  State<_MoodTab> createState() => _MoodTabState();
}

class _MoodTabState extends State<_MoodTab> {
  int _selectedEmojiIndex = -1;
  final TextEditingController _noteController = TextEditingController();

  static const List<_EmojiChoice> _emojis = [
    _EmojiChoice(emoji: '😊', label: '开心', value: 7.0),
    _EmojiChoice(emoji: '😌', label: '平静', value: 6.0),
    _EmojiChoice(emoji: '😢', label: '难过', value: 3.0),
    _EmojiChoice(emoji: '😰', label: '焦虑', value: 4.0),
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _record() {
    if (_selectedEmojiIndex < 0) return;
    final choice = _emojis[_selectedEmojiIndex];
    setState(() {
      widget.records.last = _MoodRecord(
        date: '今天',
        emoji: choice.emoji,
        label: choice.label,
        value: choice.value,
        note: _noteController.text.trim(),
        time: _nowLabel(),
      );
      _selectedEmojiIndex = -1;
      _noteController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已记录：${choice.label}',
            style: ShunshiTextStyles.caption.copyWith(color: Colors.white)),
        backgroundColor: ShunshiColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShunshiSpacing.radiusMedium)),
      ),
    );
  }

  String _nowLabel() {
    final h = DateTime.now().hour;
    if (h < 6) return '凌晨${h}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    if (h < 12) return '上午${h}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    if (h < 18) return '下午${h - 12}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    return '晚上${h - 12}:${DateTime.now().minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.records.map((r) => r.value).toList();
    final labels = widget.records.map((r) => r.date).toList();
    final today = widget.records.last;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ShunshiSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 本周趋势标题
          Text('本周情绪趋势', style: ShunshiTextStyles.caption),
          const SizedBox(height: ShunshiSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(ShunshiSpacing.md),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: _MoodLineChart(
                data: values,
                labels: labels,
                lineColor: ShunshiColors.warm,
              ),
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xl),

          // 今日记录
          Text('今日', style: ShunshiTextStyles.caption),
          const SizedBox(height: ShunshiSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(ShunshiSpacing.md),
            child: Row(
              children: [
                Text(today.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: ShunshiSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(today.label, style: ShunshiTextStyles.body),
                      if (today.note.isNotEmpty)
                        Text(today.note, style: ShunshiTextStyles.caption),
                    ],
                  ),
                ),
                if (today.time != null)
                  Text(today.time!, style: ShunshiTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xl),

          // 记录此刻 — 底部输入区
          Text('记录此刻', style: ShunshiTextStyles.caption),
          const SizedBox(height: ShunshiSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(ShunshiSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('你现在感觉如何？', style: ShunshiTextStyles.body),
                const SizedBox(height: ShunshiSpacing.md),
                // 情绪选择 — 4个emoji，单选
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_emojis.length, (i) {
                    final e = _emojis[i];
                    final selected = _selectedEmojiIndex == i;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedEmojiIndex = i),
                      child: AnimatedContainer(
                        duration: ShunshiAnimations.stateChange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: ShunshiSpacing.sm,
                          vertical: ShunshiSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? ShunshiColors.warm.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                              ShunshiSpacing.radiusMedium),
                          border: Border.all(
                            color: selected
                                ? ShunshiColors.warm.withValues(alpha: 0.5)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(e.emoji,
                                style: TextStyle(
                                    fontSize: selected ? 28 : 24)),
                            const SizedBox(height: 2),
                            Text(e.label,
                                style: ShunshiTextStyles.caption
                                    .copyWith(fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: ShunshiSpacing.md),
                // 可选文字输入
                TextField(
                  controller: _noteController,
                  style: ShunshiTextStyles.hint,
                  decoration: InputDecoration(
                    hintText: '写点什么（可选）...',
                    hintStyle: ShunshiTextStyles.hint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          ShunshiSpacing.radiusMedium),
                      borderSide: BorderSide(color: ShunshiColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          ShunshiSpacing.radiusMedium),
                      borderSide: BorderSide(color: ShunshiColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          ShunshiSpacing.radiusMedium),
                      borderSide: BorderSide(
                          color: ShunshiColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: ShunshiSpacing.md,
                      vertical: ShunshiSpacing.sm + 4,
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: ShunshiSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: GentleButton(
                    text: '记录',
                    isPrimary: true,
                    onPressed: _selectedEmojiIndex >= 0 ? _record : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xxl),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 睡眠 Tab
// ═══════════════════════════════════════════

class _SleepTab extends StatefulWidget {
  final List<_SleepRecord> records;
  const _SleepTab({required this.records});

  @override
  State<_SleepTab> createState() => _SleepTabState();
}

class _SleepTabState extends State<_SleepTab> {
  TimeOfDay _bedtime = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay _wakeup = const TimeOfDay(hour: 6, minute: 50);
  int _qualityIndex = 2; // 默认"良好"

  void _pickBedtime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _bedtime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => _bedtime = t);
  }

  void _pickWakeup() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _wakeup,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => _wakeup = t);
  }

  String _fmt(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _record() {
    final bedMin = _bedtime.hour * 60 + _bedtime.minute;
    var wakeMin = _wakeup.hour * 60 + _wakeup.minute;
    if (wakeMin <= bedMin) wakeMin += 24 * 60; // 跨夜
    final hours = (wakeMin - bedMin) / 60;
    final quality = _SleepQuality.values[_qualityIndex];
    setState(() {
      widget.records.last = _SleepRecord(
        date: '今天',
        hours: hours,
        quality: quality,
        bedtime: _fmt(_bedtime),
        wakeup: _fmt(_wakeup),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已记录睡眠 ${hours.toStringAsFixed(1)}小时',
            style: ShunshiTextStyles.caption.copyWith(color: Colors.white)),
        backgroundColor: ShunshiColors.calm,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShunshiSpacing.radiusMedium)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.records.map((r) => r.hours).toList();
    final labels = widget.records.map((r) => r.date).toList();
    final last = widget.records.last;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ShunshiSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本周睡眠趋势', style: ShunshiTextStyles.caption),
          const SizedBox(height: ShunshiSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(ShunshiSpacing.md),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: _BarChart(
                data: values,
                labels: labels,
                barColor: ShunshiColors.calm,
                suffix: 'h',
              ),
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xl),

          // 昨晚大号展示
          Text('昨晚睡了', style: ShunshiTextStyles.caption),
          const SizedBox(height: ShunshiSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${last.hours.toInt()}',
                style: ShunshiTextStyles.greeting.copyWith(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: ShunshiColors.primary,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '小时${(last.hours % 1 * 60).toInt()}分',
                  style: ShunshiTextStyles.body.copyWith(
                    color: ShunshiColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ShunshiSpacing.xs),
          Row(
            children: [
              Text('质量：', style: ShunshiTextStyles.caption),
              Text(
                last.quality.label,
                style: ShunshiTextStyles.body.copyWith(
                  color: last.quality.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: ShunshiSpacing.xl),

          // 记录睡眠
          Text('记录睡眠', style: ShunshiTextStyles.caption),
          const SizedBox(height: ShunshiSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(ShunshiSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('入睡时间', style: ShunshiTextStyles.caption),
                const SizedBox(height: ShunshiSpacing.xs),
                GestureDetector(
                  onTap: _pickBedtime,
                  child: SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ShunshiSpacing.md,
                      vertical: ShunshiSpacing.sm + 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(_bedtime), style: ShunshiTextStyles.body),
                        Icon(Icons.access_time,
                            size: 18, color: ShunshiColors.textHint),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: ShunshiSpacing.md),
                Text('起床时间', style: ShunshiTextStyles.caption),
                const SizedBox(height: ShunshiSpacing.xs),
                GestureDetector(
                  onTap: _pickWakeup,
                  child: SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ShunshiSpacing.md,
                      vertical: ShunshiSpacing.sm + 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(_wakeup), style: ShunshiTextStyles.body),
                        Icon(Icons.access_time,
                            size: 18, color: ShunshiColors.textHint),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: ShunshiSpacing.md),
                Text('质量选择', style: ShunshiTextStyles.caption),
                const SizedBox(height: ShunshiSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_SleepQuality.values.length, (i) {
                    final q = _SleepQuality.values[i];
                    final selected = _qualityIndex == i;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _qualityIndex = i),
                      child: AnimatedContainer(
                        duration: ShunshiAnimations.stateChange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: ShunshiSpacing.sm + 4,
                          vertical: ShunshiSpacing.xs + 2,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? q.color.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                              ShunshiSpacing.radiusMedium),
                          border: Border.all(
                            color: selected
                                ? q.color.withValues(alpha: 0.5)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(q.emoji,
                                style: TextStyle(
                                    fontSize: selected ? 28 : 24)),
                            const SizedBox(height: 2),
                            Text(q.label,
                                style: ShunshiTextStyles.caption
                                    .copyWith(fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: ShunshiSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: GentleButton(
                    text: '记录',
                    isPrimary: true,
                    onPressed: _record,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xxl),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 运动 Tab
// ═══════════════════════════════════════════

class _ExerciseTab extends StatefulWidget {
  final List<_ExerciseRecord> records;
  const _ExerciseTab({required this.records});

  @override
  State<_ExerciseTab> createState() => _ExerciseTabState();
}

class _ExerciseTabState extends State<_ExerciseTab> {
  static const List<String> _types = ['散步', '跑步', '瑜伽', '游泳', '骑行', '拉伸'];
  int _typeIndex = 0;
  double _duration = 30.0;
  int _intensityIndex = 0;

  static const List<String> _intensities = ['轻', '中', '高'];

  void _record() {
    setState(() {
      widget.records.last = _ExerciseRecord(
        date: '今天',
        minutes: _duration.round(),
        type: _types[_typeIndex],
        intensity: _intensities[_intensityIndex],
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_types[_typeIndex]} ${_duration.round()}分钟',
            style: ShunshiTextStyles.caption.copyWith(color: Colors.white)),
        backgroundColor: ShunshiColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShunshiSpacing.radiusMedium)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.records.map((r) => r.minutes.toDouble()).toList();
    final labels = widget.records.map((r) => r.date).toList();
    final last = widget.records.last;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ShunshiSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本周运动趋势', style: ShunshiTextStyles.caption),
          const SizedBox(height: ShunshiSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(ShunshiSpacing.md),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: _BarChart(
                data: values,
                labels: labels,
                barColor: ShunshiColors.primary,
                suffix: 'm',
              ),
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xl),

          // 今日运动统计
          Text('今日', style: ShunshiTextStyles.caption),
          const SizedBox(height: ShunshiSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(ShunshiSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${last.minutes} 分钟',
                        style: ShunshiTextStyles.heading.copyWith(
                          color: ShunshiColors.primary,
                        ),
                      ),
                      if (last.type.isNotEmpty)
                        Text(last.type,
                            style: ShunshiTextStyles.bodySecondary),
                    ],
                  ),
                ),
                if (last.intensity.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ShunshiSpacing.sm,
                      vertical: ShunshiSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: ShunshiColors.primaryLight.withValues(alpha: 0.3),
                      borderRadius:
                          BorderRadius.circular(ShunshiSpacing.radiusFull),
                    ),
                    child: Text(
                      last.intensity,
                      style: ShunshiTextStyles.caption.copyWith(
                        color: ShunshiColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xl),

          // 记录运动
          Text('记录运动', style: ShunshiTextStyles.caption),
          const SizedBox(height: ShunshiSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(ShunshiSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('运动类型', style: ShunshiTextStyles.caption),
                const SizedBox(height: ShunshiSpacing.sm),
                // 可滚动的运动类型选择
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _types.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: ShunshiSpacing.sm),
                    itemBuilder: (context, i) {
                      final selected = _typeIndex == i;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _typeIndex = i),
                        child: AnimatedContainer(
                          duration: ShunshiAnimations.stateChange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: ShunshiSpacing.md,
                            vertical: ShunshiSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? ShunshiColors.primary.withValues(alpha: 0.15)
                                : ShunshiColors.surfaceDim,
                            borderRadius: BorderRadius.circular(
                                ShunshiSpacing.radiusFull),
                            border: Border.all(
                              color: selected
                                  ? ShunshiColors.primary.withValues(alpha: 0.5)
                                  : ShunshiColors.divider,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(_types[i],
                                style: ShunshiTextStyles.caption.copyWith(
                                  color: selected
                                      ? ShunshiColors.primary
                                      : ShunshiColors.textSecondary,
                                )),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: ShunshiSpacing.lg),

                Text('运动时长', style: ShunshiTextStyles.caption),
                const SizedBox(height: ShunshiSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: ShunshiColors.primary,
                          inactiveTrackColor:
                              ShunshiColors.primary.withValues(alpha: 0.2),
                          thumbColor: ShunshiColors.primary,
                          overlayColor:
                              ShunshiColors.primary.withValues(alpha: 0.1),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8),
                        ),
                        child: Slider(
                          value: _duration,
                          min: 5,
                          max: 120,
                          onChanged: (v) =>
                              setState(() => _duration = v),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${_duration.round()} min',
                        style: ShunshiTextStyles.body.copyWith(
                          color: ShunshiColors.primary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ShunshiSpacing.md),

                Text('强度', style: ShunshiTextStyles.caption),
                const SizedBox(height: ShunshiSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                      _intensities.length, (i) {
                    final selected = _intensityIndex == i;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _intensityIndex = i),
                      child: AnimatedContainer(
                        duration: ShunshiAnimations.stateChange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: ShunshiSpacing.md + 4,
                          vertical: ShunshiSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? ShunshiColors.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                              ShunshiSpacing.radiusMedium),
                          border: Border.all(
                            color: selected
                                ? ShunshiColors.primary.withValues(alpha: 0.5)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _intensities[i],
                          style: ShunshiTextStyles.body.copyWith(
                            color: selected
                                ? ShunshiColors.primary
                                : ShunshiColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: ShunshiSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: GentleButton(
                    text: '记录',
                    isPrimary: true,
                    onPressed: _record,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xxl),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 饮食 Tab
// ═══════════════════════════════════════════

class _DietTab extends StatefulWidget {
  final List<_DietRecord> records;
  const _DietTab({required this.records});

  @override
  State<_DietTab> createState() => _DietTabState();
}

class _DietTabState extends State<_DietTab> {
  int _score = 7;
  final TextEditingController _noteController = TextEditingController();

  void _record() {
    setState(() {
      widget.records.last = _DietRecord(
        date: '今天',
        score: _score,
        meals: _noteController.text.trim().isEmpty
            ? '未填写'
            : _noteController.text.trim(),
        emoji: _score >= 8 ? '🥗' : _score >= 6 ? '🍔' : '☕',
      );
      _noteController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('饮食健康度 ${_score}/10',
            style: ShunshiTextStyles.caption.copyWith(color: Colors.white)),
        backgroundColor: ShunshiColors.earth,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShunshiSpacing.radiusMedium)),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.records.map((r) => r.score.toDouble()).toList();
    final labels = widget.records.map((r) => r.date).toList();
    final last = widget.records.last;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ShunshiSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本周饮食趋势', style: ShunshiTextStyles.caption),
          const SizedBox(height: ShunshiSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(ShunshiSpacing.md),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: _MoodLineChart(
                data: values,
                labels: labels,
                lineColor: ShunshiColors.earth,
              ),
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xl),

          // 今日
          Text('今日', style: ShunshiTextStyles.caption),
          const SizedBox(height: ShunshiSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(ShunshiSpacing.md),
            child: Row(
              children: [
                Text(last.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: ShunshiSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(last.meals, style: ShunshiTextStyles.body),
                      Text('健康度 ${last.score}/10',
                          style: ShunshiTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xl),

          // 记录饮食
          Text('记录饮食', style: ShunshiTextStyles.caption),
          const SizedBox(height: ShunshiSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.all(ShunshiSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今天吃了什么？', style: ShunshiTextStyles.body),
                const SizedBox(height: ShunshiSpacing.sm),
                TextField(
                  controller: _noteController,
                  style: ShunshiTextStyles.body,
                  decoration: InputDecoration(
                    hintText: '写点什么...',
                    hintStyle: ShunshiTextStyles.hint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          ShunshiSpacing.radiusMedium),
                      borderSide: BorderSide(color: ShunshiColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          ShunshiSpacing.radiusMedium),
                      borderSide: BorderSide(color: ShunshiColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          ShunshiSpacing.radiusMedium),
                      borderSide: BorderSide(
                          color: ShunshiColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: ShunshiSpacing.md,
                      vertical: ShunshiSpacing.sm + 4,
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: ShunshiSpacing.md),

                // 评分slider
                Text('健康度', style: ShunshiTextStyles.caption),
                const SizedBox(height: ShunshiSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: ShunshiColors.earth,
                          inactiveTrackColor:
                              ShunshiColors.earth.withValues(alpha: 0.2),
                          thumbColor: ShunshiColors.earth,
                          overlayColor:
                              ShunshiColors.earth.withValues(alpha: 0.1),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8),
                        ),
                        child: Slider(
                          value: _score.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          onChanged: (v) =>
                              setState(() => _score = v.round()),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '$_score/10',
                        style: ShunshiTextStyles.body.copyWith(
                          color: ShunshiColors.earth,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ShunshiSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: GentleButton(
                    text: '记录',
                    isPrimary: true,
                    onPressed: _record,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xxl),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 图表 — CustomPainter
// ═══════════════════════════════════════════

/// 柔和折线图 — 用于情绪/饮食趋势
class _MoodLineChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final Color lineColor;

  const _MoodLineChart({
    required this.data,
    required this.labels,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('暂无数据', style: ShunshiTextStyles.hint));
    }
    return CustomPaint(
      painter: _SoftLinePainter(
        data: data,
        labels: labels,
        lineColor: lineColor,
        dotColor: lineColor,
      ),
      size: Size.infinite,
    );
  }
}

class _SoftLinePainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final Color lineColor;
  final Color dotColor;

  _SoftLinePainter({
    required this.data,
    required this.labels,
    required this.lineColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const padL = 8.0, padR = 8.0, padT = 16.0, padB = 24.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;

    final minV = data.reduce(min);
    final maxV = data.reduce(max);
    final range = (maxV - minV == 0) ? 1.0 : maxV - minV;
    final aMin = minV - range * 0.15;
    final aMax = maxV + range * 0.15;
    final aRange = aMax - aMin;

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = padL +
          (data.length > 1 ? i / (data.length - 1) * w : w / 2);
      final y = padT + h - ((data[i] - aMin) / aRange) * h;
      points.add(Offset(x, y));
    }

    // 渐变填充
    final fillPath = Path()
      ..moveTo(points.first.dx, padT + h)
      ..lineTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final c1 =
          Offset((points[i].dx + points[i - 1].dx) / 2, points[i - 1].dy);
      final c2 =
          Offset((points[i].dx + points[i - 1].dx) / 2, points[i].dy);
      fillPath.cubicTo(
          c1.dx, c1.dy, c2.dx, c2.dy, points[i].dx, points[i].dy);
    }
    fillPath.lineTo(points.last.dx, padT + h);
    fillPath.close();

    final rect = Rect.fromLTRB(padL, padT, size.width - padR, padT + h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withValues(alpha: 0.15), lineColor.withValues(alpha: 0.02)],
        ).createShader(rect),
    );
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withValues(alpha: 0.2), lineColor.withValues(alpha: 0.03)],
        ).createShader(rect),
    );

    // 线条
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final c1 =
          Offset((points[i].dx + points[i - 1].dx) / 2, points[i - 1].dy);
      final c2 =
          Offset((points[i].dx + points[i - 1].dx) / 2, points[i].dy);
      linePath.cubicTo(
          c1.dx, c1.dy, c2.dx, c2.dy, points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // 数据点
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4, Paint()..color = Colors.white);
      canvas.drawCircle(points[i], 3, Paint()..color = dotColor);
    }

    // X轴标签
    for (int i = 0; i < labels.length; i++) {
      final x = padL +
          (labels.length > 1 ? i / (labels.length - 1) * w : w / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(fontSize: 10, color: Color(0xFFBFBFBF)),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, padT + h + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _SoftLinePainter old) =>
      old.data != data || old.lineColor != lineColor;
}

/// 柱状图 — 用于睡眠/运动趋势
class _BarChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final Color barColor;
  final String suffix;

  const _BarChart({
    required this.data,
    required this.labels,
    required this.barColor,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text('暂无数据', style: ShunshiTextStyles.hint));
    }
    return CustomPaint(
      painter: _SoftBarPainter(
        data: data,
        labels: labels,
        barColor: barColor,
        suffix: suffix,
      ),
      size: Size.infinite,
    );
  }
}

class _SoftBarPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final Color barColor;
  final String suffix;

  _SoftBarPainter({
    required this.data,
    required this.labels,
    required this.barColor,
    required this.suffix,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const padL = 4.0, padR = 4.0, padT = 16.0, padB = 24.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;

    final maxV = data.reduce(max).toDouble();
    final aMax = maxV * 1.15;

    final barWidth = w / data.length * 0.5;
    final gap = w / data.length;

    for (int i = 0; i < data.length; i++) {
      final barH = (data[i] / aMax) * h;
      final x = padL + gap * i + (gap - barWidth) / 2;
      final y = padT + h - barH;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        const Radius.circular(4),
      );

      canvas.drawRRect(rrect, Paint()..color = barColor.withValues(alpha: 0.6));

      // 数值标签
      final valText = suffix.isEmpty
          ? data[i].toStringAsFixed(0)
          : '${data[i].toStringAsFixed(0)}$suffix';
      final tp = TextPainter(
        text: TextSpan(
          text: valText,
          style: TextStyle(fontSize: 9, color: barColor.withValues(alpha: 0.8)),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
          canvas, Offset(x + barWidth / 2 - tp.width / 2, y - 14));

      // X轴标签
      final lp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(fontSize: 10, color: Color(0xFFBFBFBF)),
        ),
        textDirection: TextDirection.ltr,
      );
      lp.layout();
      lp.paint(
        canvas,
        Offset(padL + gap * i + gap / 2 - lp.width / 2, padT + h + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SoftBarPainter old) =>
      old.data != data || old.barColor != barColor;
}

// ═══════════════════════════════════════════
// 数据模型
// ═══════════════════════════════════════════

class _EmojiChoice {
  final String emoji;
  final String label;
  final double value;
  const _EmojiChoice(
      {required this.emoji, required this.label, required this.value});
}

class _MoodRecord {
  String date;
  String emoji;
  String label;
  double value;
  String note;
  String? time;
  _MoodRecord({
    required this.date,
    required this.emoji,
    required this.label,
    required this.value,
    required this.note,
    this.time,
  });
}

enum _SleepQuality {
  poor(emoji: '😫', label: '很差', color: ShunshiColors.blush),
  fair(emoji: '🥱', label: '一般', color: ShunshiColors.warning),
  good(emoji: '😌', label: '良好', color: ShunshiColors.calm),
  excellent(emoji: '😴', label: '优秀', color: ShunshiColors.primary);

  const _SleepQuality({
    required this.emoji,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String label;
  final Color color;
}

class _SleepRecord {
  String date;
  double hours;
  _SleepQuality quality;
  String bedtime;
  String wakeup;
  _SleepRecord({
    required this.date,
    required this.hours,
    required this.quality,
    required this.bedtime,
    required this.wakeup,
  });
}

class _ExerciseRecord {
  String date;
  int minutes;
  String type;
  String intensity;
  _ExerciseRecord({
    required this.date,
    required this.minutes,
    required this.type,
    required this.intensity,
  });
}

class _DietRecord {
  String date;
  int score;
  String meals;
  String emoji;
  _DietRecord({
    required this.date,
    required this.score,
    required this.meals,
    required this.emoji,
  });
}
