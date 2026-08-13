import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shunshi/core/config/app_config.dart';
import 'package:shunshi/data/network/api_client.dart';

class TestAppEnvironment {
  Future<void> start({bool onboardingCompleted = true}) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': onboardingCompleted,
      'has_seen_guide_cards_v2': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    AppConfig.apiBaseUrlOverride = 'https://test.shunshi.invalid';
    ApiClient.adapterOverride = () => _TestAdapter(_responseFor);
  }

  Map<String, dynamic> _responseFor(String path) {
    if (path.endsWith('/home/dashboard')) {
      return {
        'greeting': '今天也要好好照顾自己',
        'daily_insight': {'text': '顺应节气，从一件轻松的小事开始。'},
        'solar_term': {'name': '立春', 'description': '春日初始'},
        'suggestions': <Map<String, dynamic>>[],
      };
    }
    return {'data': <String, dynamic>{}, 'message': '测试响应'};
  }

  Future<void> stop() async {
    AppConfig.apiBaseUrlOverride = null;
    ApiClient.adapterOverride = null;
  }
}

class _TestAdapter implements HttpClientAdapter {
  _TestAdapter(this._responseFor);

  final Map<String, dynamic> Function(String) _responseFor;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(_responseFor(options.uri.path)),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
