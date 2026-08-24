import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shunshi/presentation/pages/legal/legal_document_page.dart';
import 'package:shunshi/presentation/pages/login/login_page.dart';

void main() {
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/terms',
        builder: (_, __) =>
            const LegalDocumentPage(type: LegalDocumentType.terms),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, __) =>
            const LegalDocumentPage(type: LegalDocumentType.privacy),
      ),
    ],
  );

  testWidgets('未同意协议时禁止发送验证码', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('获取验证码'));
    await tester.pump();

    expect(find.text('请先阅读并同意用户协议和隐私政策'), findsOneWidget);
  });

  testWidgets('登录页可以打开用户协议和隐私政策', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('《用户协议》'));
    await tester.pumpAndSettle();
    expect(find.text('1. 服务性质'), findsOneWidget);

    final router = GoRouter.of(tester.element(find.byType(LegalDocumentPage)));
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('《隐私政策》'));
    await tester.pumpAndSettle();
    expect(find.text('1. 我们处理的信息'), findsOneWidget);
  });
}
