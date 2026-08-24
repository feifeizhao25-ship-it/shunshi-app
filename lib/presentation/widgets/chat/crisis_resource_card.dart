import 'package:flutter/material.dart';

/// 求助资源卡 - 输入或 AI 输出命中自伤/危机/医疗急症关键词时展示
///
/// 纯客户端兜底：不依赖后端。号码用 SelectableText 展示，方便长按复制拨打
/// （项目未引入 url_launcher，暂不做得活 tel: 跳转）。
class CrisisResourceCard extends StatelessWidget {
  const CrisisResourceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4A7C6F).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4A7C6F).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('❤️', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '你并不孤单，帮助随时都在',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _resourceRow('全国心理援助热线（24小时）', '12356'),
          _resourceRow('北京心理危机研究与干预中心', '010-82951332'),
          _resourceRow('紧急情况请拨打', '120（急救）/ 110'),
          const SizedBox(height: 8),
          const Text(
            '顺时不是医疗服务，以上内容来自公开公益渠道，如有不适请及时就医。',
            style: TextStyle(fontSize: 11, color: Color(0xFF9B9B9B), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _resourceRow(String label, String number) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
            ),
          ),
          const SizedBox(width: 8),
          SelectableText(
            number,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4A7C6F),
            ),
          ),
        ],
      ),
    );
  }
}
