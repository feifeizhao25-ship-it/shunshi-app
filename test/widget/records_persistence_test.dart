import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shunshi/presentation/pages/records/records_page.dart';

void main() {
  testWidgets('健康记录首次打开不展示虚构数据，并可保存第一条真实记录', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: RecordsPage()));
    await tester.pumpAndSettle();

    expect(find.text('工作顺利'), findsNothing);
    expect(find.text('和朋友聚餐'), findsNothing);
    expect(find.text('记录“平静”'), findsOneWidget);

    await tester.tap(find.text('记录“平静”'));
    await tester.pumpAndSettle();

    const storage = FlutterSecureStorage();
    final stored = await storage.read(key: 'health_mood_records');
    expect(stored, isNotNull);
    expect(stored, contains('平静'));
    expect(find.text('本周情绪趋势'), findsOneWidget);
  });
}
