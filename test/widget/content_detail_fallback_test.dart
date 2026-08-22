// test/widget/content_detail_fallback_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shunshi/core/config/app_config.dart';
import 'package:shunshi/data/network/api_client.dart';
import 'package:shunshi/presentation/pages/content_detail_page.dart';

/// 所有请求都返回 404 的适配器，模拟后端未部署/内容不存在。
class _NotFoundAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'message': 'not found'}),
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AppConfig.apiBaseUrlOverride = 'https://test.shunshi.invalid';
    ApiClient.adapterOverride = () => _NotFoundAdapter();
  });

  tearDown(() {
    AppConfig.apiBaseUrlOverride = null;
    ApiClient.adapterOverride = null;
  });

  testWidgets('API 不可用时展示调用方提供的本地内容而非错误页', (tester) async {
    const fallback = ContentDetail(
      id: '山药粥',
      title: '山药粥',
      tags: ['补气', '健脾'],
      ingredients: ['山药 200g', '粳米 100g'],
      steps: ['山药去皮切块', '慢炖30分钟至粥稠'],
      tip: '可加入红枣增加甜味',
      type: ContentDetailType.food,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ContentDetailPage(contentId: '山药粥', fallbackContent: fallback),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('山药粥'), findsWidgets);
    expect(find.text('山药去皮切块'), findsOneWidget);
    expect(find.text('加载失败，请稍后重试'), findsNothing);
    expect(find.text('未找到内容'), findsNothing);
  });

  testWidgets('没有本地内容兜底时仍然如实报错并提供重试', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ContentDetailPage(contentId: '不存在的条目')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('加载失败，请稍后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
