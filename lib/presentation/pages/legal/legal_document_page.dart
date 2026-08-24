import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

enum LegalDocumentType { terms, privacy }

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({required this.type, super.key});

  final LegalDocumentType type;

  bool get _isPrivacy => type == LegalDocumentType.privacy;

  @override
  Widget build(BuildContext context) {
    final sections = _isPrivacy ? _privacySections : _termsSections;
    return Scaffold(
      backgroundColor: ShunshiColors.background,
      appBar: AppBar(
        title: Text(_isPrivacy ? '隐私政策' : '用户协议'),
        backgroundColor: ShunshiColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
          children: [
            Text(
              '更新日期：2026年8月22日',
              style: ShunshiTextStyles.caption.copyWith(
                color: ShunshiColors.textHint,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '正式生效日期以上线前法务确认版本为准',
              style: ShunshiTextStyles.caption.copyWith(
                color: ShunshiColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            for (final section in sections) ...[
              Text(section.$1, style: ShunshiTextStyles.heading),
              const SizedBox(height: 8),
              Text(section.$2, style: ShunshiTextStyles.bodySecondary),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

const _termsSections = <(String, String)>[
  (
    '1. 服务性质',
    '顺时提供节气知识、日常记录和辅助建议，不构成医疗诊断、处方、治疗、急救、心理咨询、法律或财务意见。涉及症状、用药、孕产、儿童、老年人或慢性病时，应咨询有资质的专业人员。',
  ),
  (
    '2. 账号与内容',
    '用户应妥善保管账号，仅提交本人有权处理的信息。不得利用服务实施违法、侵权、歧视、欺诈或危害他人的行为。游客模式不等于匿名，必要的安全日志仍可能依法处理。',
  ),
  (
    '3. AI 输出与人工判断',
    'AI 输出是候选信息，可能不完整或存在错误。产品应显示来源、时间、适用范围和不确定性；用户不得仅凭 AI 输出作出就医、用药或其他高风险决定。',
  ),
  (
    '4. 会员、续费与退款',
    '会员价格、期限、额度、自动续费和退款规则以下单确认页、应用商店规则及适用法律为准。权益仅在支付渠道验证成功后生效，取消续费不影响已支付周期内依法享有的权益。',
  ),
  (
    '5. 上线前必须补齐',
    '正式运营主体、注册地址、客服、争议解决方式和适用法律需由运营方及律师在上线前补齐。本页面是产品代码中的合规模板，不替代正式法律意见。',
  ),
];

const _privacySections = <(String, String)>[
  (
    '1. 我们处理的信息',
    '为提供账号、个性化、日常记录、会员、通知和安全功能，我们可能处理手机号、用户主动选择的目标与偏好、健康相关记录、聊天内容、订单状态以及必要的设备和安全日志。未获得授权时不会读取通讯录、照片、麦克风或位置。',
  ),
  (
    '2. 敏感个人信息与单独同意',
    '健康记录、语音、精确位置等可能属于敏感个人信息。启用相应功能前应说明具体目的、方式、范围和保存期限，并另行取得明确同意；拒绝非必要权限不影响其他基础功能。',
  ),
  (
    '3. AI 与第三方处理',
    '使用 AI 功能时，仅向经审核的模型服务发送完成任务所需的最少内容，并按配置的数据区域、保留期限和禁止训练要求处理。第三方处理者、数据类型和用途应在正式版本的第三方清单中逐项披露。',
  ),
  (
    '4. 保存、导出、删除与撤回',
    '数据仅在实现服务和履行法定义务所需期限内保存。用户可在设置中申请访问、更正、导出、删除、撤回同意或注销账号；法定留存期届满后，相关记录应删除或匿名化。',
  ),
  (
    '5. 未成年人和紧急情况',
    '未成年人使用需监护人同意。产品不提供紧急医疗或危机干预；出现严重不适、自伤或人身安全风险时，应立即联系当地紧急服务和有资质的专业人员。',
  ),
  ('6. 联系方式', '正式运营主体、个人信息保护负责人、联系地址和联系方式必须在上线前补齐。未补齐前不得以生产版本对外收集真实用户信息。'),
];
