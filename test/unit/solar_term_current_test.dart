// test/unit/solar_term_current_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shunshi/presentation/pages/solar_term_page.dart';

void main() {
  group('SolarTermData.current', () {
    test('节气表包含全部 24 个节气', () {
      final terms = SolarTermData.all();
      expect(terms.length, 24);
      expect(terms.map((t) => t.name).toSet().length, 24);
    });

    test('按日期返回对应节气，不再全年硬编码同一个', () {
      expect(SolarTermData.current(DateTime(2026, 3, 6)).name, '惊蛰');
      expect(SolarTermData.current(DateTime(2026, 3, 21)).name, '春分');
      expect(SolarTermData.current(DateTime(2026, 6, 10)).name, '芒种');
      expect(SolarTermData.current(DateTime(2026, 6, 21)).name, '夏至');
      expect(SolarTermData.current(DateTime(2026, 8, 8)).name, '立秋');
      expect(SolarTermData.current(DateTime(2026, 8, 21)).name, '处暑');
    });

    test('跨年边界日期也能落到合法节气', () {
      expect(SolarTermData.current(DateTime(2026, 1, 10)).name, '小寒');
      expect(SolarTermData.current(DateTime(2026, 1, 25)).name, '大寒');
      expect(SolarTermData.current(DateTime(2026, 12, 25)).name, '冬至');
    });
  });
}
