// lib/core/security/safety_filter.dart

/// 安全过滤器 - 负责内容安全过滤
///
/// 客户端体验层：提供即时反馈。真正的防线必须在服务端独立再检查一遍，
/// 规则集以服务端下发为准（见产品开发文档第二十二、三十二章）。
class SafetyFilter {
  /// 医疗意图类关键词：明确寻求诊断或用药，命中即拦截
  static const medicalIntentKeywords = ['吃什么药', '怎么治疗', '如何治愈', '处方', '手术'];

  /// 医疗主题类关键词：涉及健康主题但意图可能是了解养生，
  /// 命中不拦截，但必须标记并附加就医提示
  static const medicalTopicKeywords = [
    '血压',
    '血糖',
    '血脂',
    '尿酸',
    '指标',
    '数值',
    '体检',
    '诊断',
    '治疗',
    '治愈',
    '药',
    '检查',
    '肿瘤',
    '癌症',
    '新冠',
    '肺炎',
  ];

  /// 医疗相关关键词（意图类 + 主题类）
  static const medicalKeywords = [
    ...medicalIntentKeywords,
    ...medicalTopicKeywords,
  ];

  /// 敏感关键词
  static const sensitiveKeywords = ['自杀', '自残', '抑郁', '焦虑症', '死亡', '轻生'];

  /// 检查输入
  Future<SafetyResult> check(String input) async {
    final lowerInput = input.toLowerCase();

    // 1. 检查敏感词（危机层，命中即拦截并给出求助资源）
    for (final keyword in sensitiveKeywords) {
      if (lowerInput.contains(keyword)) {
        return SafetyResult(
          isSafe: false,
          response: _getSensitiveResponse(keyword),
          flag: 'sensitive',
        );
      }
    }

    // 2. 检查医疗意图词（命中即拦截，给出就医引导）
    for (final keyword in medicalIntentKeywords) {
      if (lowerInput.contains(keyword)) {
        return SafetyResult(
          isSafe: false,
          response: _medicalIntentResponse,
          flag: 'medical_blocked',
          needsDoctorConsult: true,
        );
      }
    }

    // 3. 检查医疗主题词（不拦截，标记并附加就医提示）
    for (final keyword in medicalTopicKeywords) {
      if (lowerInput.contains(keyword)) {
        return SafetyResult(
          isSafe: true,
          response: '',
          flag: 'caution',
          needsDoctorConsult: true,
        );
      }
    }

    return SafetyResult(isSafe: true, flag: 'none');
  }

  /// 医疗意图拦截文案：不诊断、不贴标签，引导至专业渠道
  static const _medicalIntentResponse =
      '这个问题涉及具体的诊断或用药，需要医生根据你的实际情况判断，我不能给出建议。'
      '请尽快咨询医生或药师，他们会给你更安全的指导。';

  String _getSensitiveResponse(String keyword) {
    final responses = {
      '自杀':
          '我感受到你可能正在经历困难时刻。你的生命很宝贵，如果感到难以承受，建议你寻求专业帮助。可以拨打心理援助热线：400-161-9995',
      '自残': '我听到你提到伤害自己的想法。我很关心你，建议你和信任的人聊聊，或者寻求专业心理帮助。',
      '抑郁': '听起来你最近情绪很低落。如果这种状态持续，建议你咨询专业心理医生。',
      '焦虑症': '焦虑是很多人都会有的感受。如果影响到了日常生活，可以考虑寻求专业帮助。',
    };
    return responses[keyword] ?? '我理解你的感受，建议你寻求专业帮助。';
  }
}

/// 安全检查结果
class SafetyResult {
  final bool isSafe;
  final String response;
  final String flag;
  final bool needsDoctorConsult;

  const SafetyResult({
    required this.isSafe,
    this.response = '',
    required this.flag,
    this.needsDoctorConsult = false,
  });
}
