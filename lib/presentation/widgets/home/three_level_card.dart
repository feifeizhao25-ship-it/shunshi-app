// 三级阅读卡片 — 「一句人话结论 → 为什么(可展开) → 专业详情入口」
//
// 首页核心卡统一使用本组件（19 项要求第 3 项：普通人看得懂）。
// 主结论文案在组件层做 25 字约束，超出省略处理。

import 'package:flutter/material.dart';

import '../../../core/theme/shunshi_colors.dart';
import '../../../core/theme/shunshi_text_styles.dart';
import '../components/soft_card.dart';

/// 卡面主结论最大长度（字），超出截断加省略号
const int kConclusionMaxChars = 25;

/// 主结论文案长度约束：超过 25 字截断并加省略号
String fitConclusion(String text, {int maxChars = kConclusionMaxChars}) {
  final trimmed = text.trim();
  if (trimmed.length <= maxChars) return trimmed;
  return '${trimmed.substring(0, maxChars)}…';
}

/// 三级阅读卡片
///
/// - 一级：一句人话结论（≤25 字）
/// - 二级：「为什么」可展开
/// - 三级：专业详情入口
class ThreeLevelCard extends StatefulWidget {
  final String emoji;

  /// 一句人话结论 — 组件层自动做 25 字约束
  final String conclusion;

  /// 「为什么」展开层内容
  final String why;

  /// 主行动按钮文案；为空则不渲染按钮
  final String actionLabel;
  final VoidCallback? onAction;

  /// 专业详情入口
  final String detailLabel;
  final VoidCallback? onDetail;

  /// 「为什么推荐」说明入口
  final VoidCallback? onWhyRecommended;

  const ThreeLevelCard({
    super.key,
    required this.conclusion,
    required this.why,
    this.emoji = '',
    this.actionLabel = '',
    this.onAction,
    this.detailLabel = '专业详情',
    this.onDetail,
    this.onWhyRecommended,
  });

  @override
  State<ThreeLevelCard> createState() => _ThreeLevelCardState();
}

class _ThreeLevelCardState extends State<ThreeLevelCard> {
  bool _whyExpanded = false;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: ShunshiColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 一级：一句人话结论（≤25 字）──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.emoji.isNotEmpty) ...[
                Text(widget.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  fitConclusion(widget.conclusion),
                  style: ShunshiTextStyles.heading.copyWith(
                    fontSize: 17,
                    height: 1.5,
                  ),
                ),
              ),
              if (widget.onWhyRecommended != null)
                InkWell(
                  onTap: widget.onWhyRecommended,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: ShunshiColors.textHint,
                    ),
                  ),
                ),
            ],
          ),

          // ── 二级：为什么（可展开）──
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _whyExpanded = !_whyExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _whyExpanded ? '收起原因' : '为什么',
                    style: ShunshiTextStyles.caption.copyWith(
                      color: ShunshiColors.primaryDark,
                    ),
                  ),
                  Icon(
                    _whyExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: ShunshiColors.primaryDark,
                  ),
                ],
              ),
            ),
          ),
          if (_whyExpanded) ...[
            const SizedBox(height: 4),
            Text(
              widget.why,
              style: ShunshiTextStyles.bodySecondary.copyWith(height: 1.7),
            ),
          ],

          // ── 主行动 + 三级：专业详情入口 ──
          if (widget.actionLabel.isNotEmpty || widget.onDetail != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.actionLabel.isNotEmpty)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ShunshiColors.primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        widget.actionLabel,
                        style: ShunshiTextStyles.buttonSmall,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (widget.onDetail != null) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: widget.onDetail,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Text(
                        '${widget.detailLabel} →',
                        style: ShunshiTextStyles.caption.copyWith(
                          color: ShunshiColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
