// 顺时 首页 — 国内版
// 设计理念：大留白，大字体，低信息密度，深呼吸感

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/network/api_client.dart';

/// 首页
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _greeting = '';
  String _dailyInsight = '今天适合慢下来\n给自己泡一杯茶';
  bool _isLoading = true;

  // 建议卡片数据
  final List<_SuggestionItem> _suggestions = [
    _SuggestionItem(icon: '🌬️', title: '呼吸', subtitle: '5min', id: 'breath'),
    _SuggestionItem(icon: '🍵', title: '食疗', subtitle: '试试', id: 'food'),
    _SuggestionItem(icon: '🧘', title: '运动', subtitle: '10m', id: 'exercise'),
  ];
  final Set<String> _completedSuggestions = {};

  @override
  void initState() {
    super.initState();
    _loadDailyContent();
  }

  Future<void> _loadDailyContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'demo_user';
      final hemisphere = prefs.getString('hemisphere') ?? 'north';

      final apiClient = ApiClient();
      final response = await apiClient.get(
        '/api/v1/seasons/home/dashboard',
        queryParameters: {
          'user_id': userId,
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
      // API call failed, use hardcoded data
      debugPrint('Home dashboard API call failed: $e');
    }

    if (mounted) {
      setState(() {
        _greeting = _greeting.isEmpty ? _getGreeting() : _greeting;
        _isLoading = false;
      });
    }
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
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早安';
    if (hour < 18) return '午安';
    return '晚安';
  }

  String _getGreetingWithName() {
    return '${_greeting.isEmpty ? _getGreeting() : _greeting}，feifei';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // ── Greeting ──
                    _buildGreeting(),
                    const SizedBox(height: 32),

                    // ── 淡分隔 ──
                    _buildDivider(),
                    const SizedBox(height: 40),

                    // ── Daily Insight ──
                    _buildDailyInsight(),
                    const SizedBox(height: 48),

                    // ── Suggestion Cards ──
                    _buildSuggestions(),
                    const SizedBox(height: 40),

                    // ── AI 入口 ──
                    _buildAIEntry(),
                    const SizedBox(height: 32),

                    // ── 节气卡片 ──
                    _buildSolarTermCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Greeting
  // ──────────────────────────────────────────────

  Widget _buildGreeting() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        _getGreetingWithName(),
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w300, // 细体
          color: Color(0xFF2C2C2C),
          height: 1.3,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 淡分隔线
  // ──────────────────────────────────────────────

  Widget _buildDivider() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 32,
        height: 2,
        decoration: BoxDecoration(
          color: const Color(0xFF4A7C6F).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Daily Insight — 居中，大留白
  // ──────────────────────────────────────────────

  Widget _buildDailyInsight() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), // 至少40dp两侧留白
      child: Text(
        _dailyInsight,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w400,
          color: Color(0xFF6B6B6B),
          height: 1.6,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Suggestion Cards — 水平3个SoftCard
  // ──────────────────────────────────────────────

  Widget _buildSuggestions() {
    return Row(
      children: _suggestions.map((item) {
        final isCompleted = _completedSuggestions.contains(item.id);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: _suggestions.indexOf(item) == 0 ? 0 : 8,
              right: _suggestions.indexOf(item) == _suggestions.length - 1 ? 0 : 8,
            ),
            child: _SoftCard(
              onTap: () => _onSuggestionTap(item),
              borderRadius: 16,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    item.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isCompleted
                          ? const Color(0xFF9B9B9B)
                          : const Color(0xFF2C2C2C),
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isCompleted
                          ? const Color(0xFFCCCCCC)
                          : const Color(0xFF9B9B9B),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _onSuggestionTap(_SuggestionItem item) {
    if (_completedSuggestions.contains(item.id)) {
      // 已完成，展示详情或跳过
      return;
    }
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
          setState(() => _completedSuggestions.add(item.id));
          Navigator.pop(context);
        },
        onSkip: () => Navigator.pop(context),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // AI 入口卡片
  // ──────────────────────────────────────────────

  Widget _buildAIEntry() {
    return _SoftCard(
      onTap: () => context.go('/chat'),
      child: Row(
        children: [
          Text(
            '💬',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              '和顺时聊聊',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF2C2C2C),
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: const Color(0xFF9B9B9B),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 节气卡片 — 轻量
  // ──────────────────────────────────────────────

  Widget _buildSolarTermCard() {
    return _SoftCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🍃',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                '惊蛰 · 春始',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2C2C2C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '宜：舒展、养肝',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9B9B9B),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// SoftCard — 柔和卡片组件
// ═══════════════════════════════════════════════

class _SoftCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsets padding;

  const _SoftCard({
    required this.child,
    this.onTap,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
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
