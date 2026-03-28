// lib/presentation/pages/content_detail_page.dart
//
// 养生内容详情页 — 从API获取内容，支持多类型展示
// 食疗 / 穴位 / 运动 / 茶饮 / 睡眠

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/shunshi_colors.dart';
import '../../core/theme/shunshi_spacing.dart';
import '../../core/theme/shunshi_text_styles.dart';
import '../../data/network/api_client.dart';
import '../widgets/components/soft_card.dart';

/// 内容类型枚举
enum ContentDetailType {
  food,        // 食疗
  acupressure, // 穴位
  exercise,    // 运动
  tea,         // 茶饮
  sleep,       // 睡眠
}

/// 内容详情数据模型
class ContentDetail {
  final String id;
  final String title;
  final String? category;
  final List<String> tags;
  final String? body;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> benefits;
  final String? tip;
  final String? imageUrl;
  final String? duration;
  final String? difficulty;
  final String? emoji;
  final bool isLiked;
  final ContentDetailType type;

  const ContentDetail({
    required this.id,
    required this.title,
    this.category,
    this.tags = const [],
    this.body,
    this.ingredients = const [],
    this.steps = const [],
    this.benefits = const [],
    this.tip,
    this.imageUrl,
    this.duration,
    this.difficulty,
    this.emoji,
    this.isLiked = false,
    this.type = ContentDetailType.food,
  });

  factory ContentDetail.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] ?? json['category'] ?? 'food';
    ContentDetailType type = ContentDetailType.food;
    for (final t in ContentDetailType.values) {
      if (t.name == typeStr) {
        type = t;
        break;
      }
    }

    return ContentDetail(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      category: json['category'],
      tags: List<String>.from(json['tags'] ?? []),
      body: json['body'],
      ingredients: List<String>.from(json['ingredients'] ?? []),
      steps: List<String>.from(json['steps'] ?? []),
      benefits: List<String>.from(json['benefits'] ?? json['effects'] ?? []),
      tip: json['tip'],
      imageUrl: json['image_url'],
      duration: json['duration'],
      difficulty: json['difficulty'],
      emoji: json['emoji'],
      isLiked: json['is_liked'] ?? false,
      type: type,
    );
  }
}

/// 养生内容详情页
class ContentDetailPage extends StatefulWidget {
  final String contentId;

  const ContentDetailPage({super.key, required this.contentId});

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  ContentDetail? _content;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isLiked = false;
  bool _isLiking = false;

  /// 类型对应的 emoji
  static const Map<ContentDetailType, String> _typeEmojis = {
    ContentDetailType.food: '🥣',
    ContentDetailType.acupressure: '✋',
    ContentDetailType.exercise: '🧘',
    ContentDetailType.tea: '🍵',
    ContentDetailType.sleep: '😴',
  };

  /// 类型对应的中文标签
  static const Map<ContentDetailType, String> _typeLabels = {
    ContentDetailType.food: '食疗',
    ContentDetailType.acupressure: '穴位',
    ContentDetailType.exercise: '运动',
    ContentDetailType.tea: '茶饮',
    ContentDetailType.sleep: '睡眠',
  };

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ApiClient();

      // 优先尝试 contents API
      Map<String, dynamic>? data;
      try {
        final response = await client.get('/api/v1/contents/${widget.contentId}');
        data = response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : null;
      } catch (_) {
        // 忽略，尝试 CMS API
      }

      // 回退到 CMS API
      data ??= await (() async {
        final response = await client.get('/api/v1/cms/content/${widget.contentId}');
        return response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : null;
      })();

      if (data != null) {
        final contentData = data;
        setState(() {
          _content = ContentDetail.fromJson(contentData);
          _isLiked = _content!.isLiked;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '未找到内容';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败，请稍后重试';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking || _content == null) return;
    setState(() => _isLiking = true);

    try {
      final client = ApiClient();
      await client.post('/api/v1/contents/${widget.contentId}/like');
      setState(() {
        _isLiked = !_isLiked;
        _isLiking = false;
      });
    } catch (_) {
      setState(() => _isLiking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败，请稍后重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShunshiColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ShunshiColors.primary))
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_errorMessage!, style: ShunshiTextStyles.bodySecondary),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadContent,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final c = _content!;
    final emoji = _typeEmojis[c.type] ?? '📋';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ShunshiSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 返回按钮
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: GestureDetector(
                onTap: () => context.go('/library'),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: ShunshiColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text('返回', style: ShunshiTextStyles.caption),
                  ],
                ),
              ),
            ),
          ),

          // emoji + 标题
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(c.title, style: ShunshiTextStyles.insight.copyWith(fontSize: 22)),
          const SizedBox(height: 6),

          // 分类 + 时长 + 难度
          Row(
            children: [
              if (c.category != null || c.type != ContentDetailType.food)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ShunshiColors.primaryLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(ShunshiSpacing.radiusFull),
                  ),
                  child: Text(
                    c.category ?? _typeLabels[c.type]!,
                    style: ShunshiTextStyles.caption.copyWith(
                      color: ShunshiColors.primaryDark,
                    ),
                  ),
                ),
              if (c.duration != null) ...[
                const SizedBox(width: 8),
                Text(c.duration!, style: ShunshiTextStyles.caption),
              ],
              if (c.difficulty != null) ...[
                const SizedBox(width: 4),
                Text(' · ${c.difficulty!}', style: ShunshiTextStyles.caption),
              ],
              const Spacer(),
              // 喜欢按钮
              GestureDetector(
                onTap: _toggleLike,
                child: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? ShunshiColors.blush : ShunshiColors.textHint,
                  size: 24,
                ),
              ),
            ],
          ),

          // 大图区域
          const SizedBox(height: 24),
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ShunshiColors.surfaceDim,
              borderRadius: BorderRadius.circular(ShunshiSpacing.radiusLarge),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 64)),
            ),
          ),

          // 正文 (body)
          if (c.body != null && c.body!.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(c.body!, style: ShunshiTextStyles.body.copyWith(height: 1.8)),
          ],

          // 功效 / 标签
          if (c.tags.isNotEmpty || c.benefits.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('功效', style: ShunshiTextStyles.heading),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [...c.benefits, ...c.tags].map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: ShunshiColors.primaryLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(ShunshiSpacing.radiusFull),
                  ),
                  child: Text(
                    tag,
                    style: ShunshiTextStyles.caption.copyWith(
                      color: ShunshiColors.primaryDark,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // 材料列表
          if (c.ingredients.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('材料', style: ShunshiTextStyles.heading),
            const SizedBox(height: 12),
            Text(c.ingredients.join(' · '), style: ShunshiTextStyles.body),
          ],

          // 步骤列表
          if (c.steps.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('步骤', style: ShunshiTextStyles.heading),
            const SizedBox(height: 12),
            ...c.steps.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: ShunshiColors.primaryLight.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: ShunshiTextStyles.buttonSmall.copyWith(
                            color: ShunshiColors.primaryDark,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: ShunshiTextStyles.body.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // 小贴士
          if (c.tip != null) ...[
            const SizedBox(height: 28),
            SoftCard(
              borderRadius: ShunshiSpacing.radiusMedium,
              color: ShunshiColors.warm.withValues(alpha: 0.15),
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '小贴士',
                          style: ShunshiTextStyles.heading.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(c.tip!, style: ShunshiTextStyles.bodySecondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
