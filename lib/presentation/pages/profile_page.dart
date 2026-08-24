import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/theme.dart';
import '../../../data/services/store_service.dart';
import '../../../core/network/network_service.dart';
import '../../../core/storage/local_storage.dart';
import '../widgets/components/components.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userInfo;
  String? _loadError;

  // 设置状态
  bool _memoryEnabled = true;
  bool _dndEnabled = false;
  String _dndStart = '22:00';
  String _dndEnd = '08:00';
  bool _notificationsEnabled = true;
  String _hemisphere = 'north';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadSettings();
  }

  /// 读取本地持久化的开关状态（通知/静默时段/AI记忆）。
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hemisphere = prefs.getString('hemisphere') ?? 'north';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _memoryEnabled = prefs.getBool('memory_enabled') ?? true;
      _dndEnabled = prefs.getBool('dnd_enabled') ?? false;
      _dndStart = prefs.getString('dnd_start') ?? '22:00';
      _dndEnd = prefs.getString('dnd_end') ?? '08:00';
    });
  }

  Future<void> _persistSwitch(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _setHemisphere(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hemisphere', value);
    if (mounted) {
      setState(() => _hemisphere = value);
      context.go('/home');
    }
  }

  void _showHemisphereSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _textHint(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '选择半球',
              style: ShunshiTextStyles.heading.copyWith(
                color: _textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '影响首页显示的季节内容',
              style: ShunshiTextStyles.caption.copyWith(
                color: _textHint(context),
              ),
            ),
            const SizedBox(height: 20),
            _buildHemisphereOption(
              context,
              label: '北半球',
              desc: '北美、欧洲、亚洲（北部）',
              isSelected: _hemisphere == 'north',
              onTap: () {
                Navigator.pop(ctx);
                _setHemisphere('north');
              },
            ),
            const SizedBox(height: 12),
            _buildHemisphereOption(
              context,
              label: '南半球',
              desc: '南美、澳大利亚、非洲（南部）',
              isSelected: _hemisphere == 'south',
              onTap: () {
                Navigator.pop(ctx);
                _setHemisphere('south');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHemisphereOption(
    BuildContext context, {
    required String label,
    required String desc,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primary = ShunshiColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? primary : _textSecondary(context),
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: ShunshiTextStyles.body.copyWith(
                      color: _textPrimary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: ShunshiTextStyles.caption.copyWith(
                      color: _textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadUserInfo() async {
    try {
      final responses = await Future.wait([
        NetworkService().client.get('/users/me'),
        NetworkService().client.get('/subscription/current'),
      ]);
      Map<String, dynamic> unwrap(dynamic value) {
        final map = Map<String, dynamic>.from(value as Map);
        final data = map['data'];
        return data is Map ? Map<String, dynamic>.from(data) : map;
      }

      final user = unwrap(responses[0].data);
      final subscription = unwrap(responses[1].data);
      final createdAt = DateTime.tryParse('${user['created_at'] ?? ''}');
      final daysTogether = createdAt == null
          ? 0
          : DateTime.now()
                .difference(createdAt.toLocal())
                .inDays
                .clamp(0, 99999);
      final plan =
          '${subscription['plan'] ?? (user['is_premium'] == true ? 'premium' : 'free')}';
      if (!mounted) return;
      setState(() {
        _loadError = null;
        _userInfo = {
          'name': user['nickname'] ?? '顺时用户',
          'avatar': '😊',
          'subscription_type': plan,
          'subscription_label': plan == 'free' ? '免费用户' : '会员',
          'days_together': daysTogether,
          // 统计接口未提供时显示0，绝不伪造活跃数据。
          'total_conversations': user['total_conversations'] ?? 0,
          'total_records': user['total_records'] ?? 0,
          'total_reflections': user['total_reflections'] ?? 0,
          'streak_days': user['streak_days'] ?? 0,
          'member_since': user['created_at'] ?? '',
        };
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = '无法加载账户和会员权益，请检查网络后重试');
    }
  }

  // ── 主题感知辅助 ──

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ── 颜色获取 ──

  Color _bg(BuildContext context) => _isDark(context)
      ? ShunshiDarkColors.background
      : ShunshiColors.background;
  Color _surface(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.surface : ShunshiColors.surface;
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
  Color _divider(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.divider : ShunshiColors.divider;
  Color _primary(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.primary : ShunshiColors.primary;
  Color _primaryLight(BuildContext context) => _isDark(context)
      ? ShunshiDarkColors.primaryLight
      : ShunshiColors.primaryLight;
  Color _error(BuildContext context) =>
      _isDark(context) ? ShunshiDarkColors.error : ShunshiColors.error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg(context),
      body: _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadUserInfo,
                    child: const Text('重新加载'),
                  ),
                ],
              ),
            )
          : _userInfo == null
          ? Center(
              child: CircularProgressIndicator(
                color: _primary(context),
                strokeWidth: 2,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: ShunshiSpacing.pagePadding,
                  vertical: ShunshiSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 标题：greeting样式(28sp w300) ──
                    Text(
                      '我的',
                      style: ShunshiTextStyles.greeting.copyWith(
                        color: _textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: ShunshiSpacing.lg),

                    // ── 用户卡片：渐变背景，20dp圆角 ──
                    _buildUserCard(context),
                    const SizedBox(height: ShunshiSpacing.xl),

                    // ── 使用统计 ──
                    Padding(
                      padding: const EdgeInsets.only(
                        left:
                            ShunshiSpacing.cardPadding -
                            ShunshiSpacing.pagePadding +
                            4,
                      ),
                      child: Text(
                        '使用统计',
                        style: ShunshiTextStyles.caption.copyWith(
                          color: _textSecondary(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: ShunshiSpacing.sm),
                    _buildStatsGrid(context),
                    const SizedBox(height: ShunshiSpacing.xl),

                    // ── 功能入口列表 ──
                    _buildFeatureList(context),
                    const SizedBox(height: ShunshiSpacing.xl),

                    // ── 危险操作 ──
                    _buildDangerZone(context),
                    const SizedBox(height: ShunshiSpacing.xxl),
                  ],
                ),
              ),
            ),
    );
  }

  // ==================== 用户卡片 ====================

  Widget _buildUserCard(BuildContext context) {
    final isPremium = _userInfo!['subscription_type'] != 'free';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ShunshiSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary(context), _primaryLight(context)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // 头像
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _userInfo!['avatar'] ?? '😊',
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: ShunshiSpacing.md),
          // 名字
          Text(
            _userInfo!['name'],
            style: ShunshiTextStyles.heading.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: ShunshiSpacing.xs),
          // 陪伴天数
          Text(
            '已陪伴你 ${_userInfo!['days_together']} 天',
            style: ShunshiTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: ShunshiSpacing.md),
          // 订阅标签
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ShunshiSpacing.md,
              vertical: ShunshiSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isPremium
                  ? ShunshiColors.warm.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(ShunshiSpacing.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPremium ? Icons.spa : Icons.eco_outlined,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 4),
                Text(
                  isPremium
                      ? '🌿 养心会员'
                      : '🌿 ${_userInfo!['subscription_label']}',
                  style: ShunshiTextStyles.overline.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 2x2 统计网格 ====================

  Widget _buildStatsGrid(BuildContext context) {
    final stats = [
      ('对话', _userInfo!['total_conversations'] as int, ShunshiColors.primary),
      ('记录', _userInfo!['total_records'] as int, ShunshiColors.calm),
      ('反思', _userInfo!['total_reflections'] as int, ShunshiColors.warm),
      ('连续', _userInfo!['streak_days'] as int, ShunshiColors.warning),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: ShunshiSpacing.sm,
      crossAxisSpacing: ShunshiSpacing.sm,
      childAspectRatio: 1.5,
      children: stats.map((s) {
        final (label, value, color) = s;
        return SoftCard(
          borderRadius: ShunshiSpacing.radiusLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$value',
                style: ShunshiTextStyles.heading.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: ShunshiTextStyles.caption.copyWith(
                  color: _textSecondary(context),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==================== 功能入口列表 ====================

  Widget _buildFeatureList(BuildContext context) {
    final items = [
      _MenuItemData(
        emoji: '📋',
        label: '健康记录',
        onTap: () => context.push('/records'),
      ),
      _MenuItemData(
        emoji: '🔔',
        label: '通知设置',
        isSwitch: true,
        switchValue: _notificationsEnabled,
        onSwitchChanged: (v) {
          setState(() => _notificationsEnabled = v);
          _persistSwitch('notifications_enabled', v);
        },
      ),
      _MenuItemData(
        emoji: '🌙',
        label: '静默时段',
        isSwitch: true,
        switchValue: _dndEnabled,
        switchSubtitle: _dndEnabled ? '$_dndStart - $_dndEnd' : null,
        onSwitchChanged: (v) {
          if (v) {
            _showDndTimePicker(context);
          } else {
            setState(() => _dndEnabled = v);
            _persistSwitch('dnd_enabled', v);
          }
        },
      ),
      _MenuItemData(
        emoji: '🧠',
        label: 'AI记忆',
        isSwitch: true,
        switchValue: _memoryEnabled,
        onSwitchChanged: _setMemoryEnabled,
      ),
      _MenuItemData(
        emoji: '🌍',
        label: '所在半球',
        value: _hemisphere == 'north' ? '北半球' : '南半球',
        onTap: () => _showHemisphereSheet(context),
      ),
      _MenuItemData(
        emoji: '📱',
        label: '恢复购买',
        onTap: () => _handleRestorePurchase(context),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border(context), width: 1),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          return _buildFeatureItem(
            context,
            items[index],
            isLast: index == items.length - 1,
          );
        }),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    _MenuItemData item, {
    required bool isLast,
  }) {
    return InkWell(
      onTap: item.onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ShunshiSpacing.cardPadding,
          vertical: ShunshiSpacing.listItemPadding,
        ),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: _divider(context), width: 1)),
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(20))
              : null,
        ),
        child: Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: ShunshiSpacing.md),
            Expanded(
              child: Text(
                item.label,
                style: ShunshiTextStyles.body.copyWith(
                  color: _textPrimary(context),
                ),
              ),
            ),
            if (item.isSwitch)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.switchSubtitle != null)
                    Text(
                      item.switchSubtitle!,
                      style: ShunshiTextStyles.overline.copyWith(
                        color: _textHint(context),
                        fontSize: 11,
                      ),
                    ),
                  Switch(
                    value: item.switchValue ?? false,
                    activeThumbColor: _primary(context),
                    onChanged: item.onSwitchChanged,
                  ),
                ],
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.value != null)
                    Text(
                      item.value!,
                      style: ShunshiTextStyles.body.copyWith(
                        color: _primary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (item.value != null) const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: _textHint(context),
                    size: 20,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ==================== 危险操作区域 ====================

  Widget _buildDangerZone(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border(context), width: 1),
      ),
      child: Column(
        children: [
          // 清空记忆
          InkWell(
            onTap: () => _showClearMemoryDialog(context),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ShunshiSpacing.cardPadding,
                vertical: ShunshiSpacing.listItemPadding,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _divider(context), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Text('🗑', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: ShunshiSpacing.md),
                  Expanded(
                    child: Text(
                      '清空记忆',
                      style: ShunshiTextStyles.body.copyWith(
                        color: _error(context),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: _textHint(context),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // 关于顺时
          InkWell(
            onTap: () => showAboutDialog(
              context: context,
              applicationName: '顺时',
              applicationVersion: '1.0.0',
              applicationLegalese: '顺应时节，养生有道',
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ShunshiSpacing.cardPadding,
                vertical: ShunshiSpacing.listItemPadding,
              ),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Text('📄', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: ShunshiSpacing.md),
                  Expanded(
                    child: Text(
                      '关于顺时',
                      style: ShunshiTextStyles.body.copyWith(
                        color: _textPrimary(context),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: _textHint(context),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Dialogs ====================

  /// 切换 AI 记忆。
  ///
  /// 此前只翻转本地 switch，后端记忆照常写入 —— 开关是假的。
  /// 现在调用记忆开关接口，失败时回退并明确提示。
  Future<void> _setMemoryEnabled(bool value) async {
    final previous = _memoryEnabled;
    setState(() => _memoryEnabled = value);
    try {
      final response = await NetworkService().client.put(
        '/memory/toggle',
        data: {'enabled': value},
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw StateError('unexpected status $code');
      }
      await _persistSwitch('memory_enabled', value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _memoryEnabled = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置失败，请检查网络后重试')));
    }
  }

  /// 清空记忆：真实调用后端删除接口并清掉本地缓存。
  ///
  /// 此前只 `setState(_memoryEnabled = false)` 就提示"记忆已清空"，
  /// 实际什么都没删 —— 典型的假成功。现在失败时明确报错，不谎报。
  Future<void> _clearMemory() async {
    try {
      final response = await NetworkService().client.delete('/memory');
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw StateError('unexpected status $code');
      }
      await localStorage.clearUserData();
      if (!mounted) return;
      setState(() => _memoryEnabled = false);
      await _persistSwitch('memory_enabled', false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('记忆已清空，我会重新认识你'),
          backgroundColor: _primary(context),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('清空失败，请检查网络后重试'),
          backgroundColor: _error(context),
        ),
      );
    }
  }

  void _showClearMemoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('清空记忆', style: ShunshiTextStyles.heading),
        content: Text(
          '确定要清空所有记忆吗？此操作不可恢复',
          style: ShunshiTextStyles.bodySecondary.copyWith(
            color: _textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '再想想',
              style: ShunshiTextStyles.button.copyWith(
                color: _textSecondary(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearMemory();
            },
            child: Text(
              '清空',
              style: ShunshiTextStyles.button.copyWith(color: _error(context)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDndTimePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: ShunshiSpacing.xl,
          right: ShunshiSpacing.xl,
          top: ShunshiSpacing.lg,
          bottom: ShunshiSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('静默时段', style: ShunshiTextStyles.heading),
            const SizedBox(height: ShunshiSpacing.lg),
            ListTile(
              leading: Icon(Icons.bedtime, color: _primary(context)),
              title: Text('开始时间', style: ShunshiTextStyles.body),
              trailing: Text(
                _dndStart,
                style: ShunshiTextStyles.body.copyWith(
                  color: _primary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: 22, minute: 0),
                );
                if (time != null) {
                  setState(() => _dndStart = time.format(context));
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.wb_sunny, color: ShunshiColors.warm),
              title: Text('结束时间', style: ShunshiTextStyles.body),
              trailing: Text(
                _dndEnd,
                style: ShunshiTextStyles.body.copyWith(
                  color: ShunshiColors.warm,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: 8, minute: 0),
                );
                if (time != null) {
                  setState(() => _dndEnd = time.format(context));
                }
              },
            ),
            const SizedBox(height: ShunshiSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  setState(() => _dndEnabled = true);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('dnd_enabled', true);
                  await prefs.setString('dnd_start', _dndStart);
                  await prefs.setString('dnd_end', _dndEnd);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('静默时段: $_dndStart - $_dndEnd'),
                      backgroundColor: _primary(context),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: ShunshiSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ShunshiSpacing.radiusLarge,
                    ),
                  ),
                ),
                child: Text('确认', style: ShunshiTextStyles.button),
              ),
            ),
            const SizedBox(height: ShunshiSpacing.sm),
          ],
        ),
      ),
    );
  }

  // ==================== 恢复购买 ====================

  Future<void> _handleRestorePurchase(BuildContext context) async {
    final store = StoreService();
    if (!await store.initialize()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('当前设备不支持应用内购'),
            backgroundColor: _textSecondary(context),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          color: _primary(context),
          strokeWidth: 2,
        ),
      ),
    );

    try {
      await store.restorePurchases();
      if (context.mounted) {
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
      if (context.mounted) {
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

// ==================== Helper ====================

class _MenuItemData {
  final String emoji;
  final String label;
  final VoidCallback? onTap;
  final bool isSwitch;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final String? switchSubtitle;
  final String? value; // For displaying a value label (e.g., hemisphere)

  _MenuItemData({
    required this.emoji,
    required this.label,
    this.onTap,
    this.isSwitch = false,
    this.switchValue,
    this.onSwitchChanged,
    this.switchSubtitle,
    this.value,
  });
}
