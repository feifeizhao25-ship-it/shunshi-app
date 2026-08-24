// test/unit/safety_filter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shunshi/core/security/safety_filter.dart';

void main() {
  late SafetyFilter filter;

  setUp(() {
    filter = SafetyFilter();
  });

  group('SafetyFilter 危机/急症闸门', () {
    test('自伤危机词命中即拦截，flag 为 crisis，文案含求助热线', () async {
      final result = await filter.check('我最近真的不想活了');
      expect(result.isSafe, isFalse);
      expect(result.flag, 'crisis');
      expect(SafetyFilter.needsCrisisCard(result.flag), isTrue);
    });

    test('敏感词自杀优先走 crisis 分支', () async {
      final result = await filter.check('活着好累，想过自杀');
      expect(result.isSafe, isFalse);
      expect(result.flag, 'crisis');
    });

    test('医疗急症词命中即拦截，flag 为 medical_emergency，提示拨打 120', () async {
      final result = await filter.check('突然胸痛得厉害怎么办');
      expect(result.isSafe, isFalse);
      expect(result.flag, 'medical_emergency');
      expect(result.needsDoctorConsult, isTrue);
      expect(result.response, contains('120'));
      expect(SafetyFilter.needsCrisisCard(result.flag), isTrue);
    });

    test('危机优先级高于急症', () async {
      final result = await filter.check('我胸痛，不想活了');
      expect(result.flag, 'crisis');
    });

    test('情绪敏感词（抑郁）拦截且需要资源卡', () async {
      final result = await filter.check('最近抑郁得厉害');
      expect(result.isSafe, isFalse);
      expect(result.flag, 'sensitive');
      expect(SafetyFilter.needsCrisisCard(result.flag), isTrue);
    });

    test('医疗意图词拦截但不需要资源卡', () async {
      final result = await filter.check('高血压吃什么药');
      expect(result.isSafe, isFalse);
      expect(result.flag, 'medical_blocked');
      expect(SafetyFilter.needsCrisisCard(result.flag), isFalse);
    });

    test('医疗主题词放行但标记就医提示', () async {
      final result = await filter.check('体检血压偏高要注意什么');
      expect(result.isSafe, isTrue);
      expect(result.flag, 'caution');
      expect(result.needsDoctorConsult, isTrue);
    });

    test('普通养生问题安全通过', () async {
      final result = await filter.check('今天立春吃什么好');
      expect(result.isSafe, isTrue);
      expect(result.flag, 'none');
      expect(result.needsDoctorConsult, isFalse);
    });
  });
}
