// 本地全链路联调测试（live backend contract test）
//
// 直连本地起好的顺时后端（默认 http://127.0.0.1:8500，可用
// `--dart-define=SHUNSHI_API_BASE_URL=...` 覆盖），用客户端**既有**
// ApiService / ApiClient 真实走一遍契约：guest-login → chat/send →
// ai/chat → memory 开关 → home dashboard → 数据导出。
//
// 后端不可达时整组 skip（动态探测），因此混进 `flutter test` 全量跑
// 不会破坏无后端环境下的既有基线。

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shunshi/core/config/app_config.dart';
import 'package:shunshi/data/network/api_client.dart';
import 'package:shunshi/data/services/api_service.dart';

Future<bool> _backendReachable(String baseUrl) async {
  try {
    final resp = await Dio().get<Map<String, dynamic>>(
      '$baseUrl/healthz',
      options: Options(receiveTimeout: const Duration(seconds: 2)),
    );
    return resp.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  final baseUrl = AppConfig.apiBaseUrl;
  final up = await _backendReachable(baseUrl);
  const skipReason = '本地后端不可达（需先起 :8500，见联调记录），跳过 live 契约测试';

  group('live backend contract (顺时后端 + 网关 + mock LLM)', skip: up ? false : skipReason, () {
    late Dio anon;
    late String token;
    late ApiClient authedClient;

    setUpAll(() async {
      anon = Dio(BaseOptions(baseUrl: baseUrl));
      final login = await anon.post<Map<String, dynamic>>('/api/v1/auth/guest-login');
      expect(login.statusCode, 200);
      token = login.data!['access_token'] as String;
      expect(token, isNotEmpty);

      // ApiClient(dio:) 注入自定义 dio：真实走 ApiService 代码路径，
      // 但绕过 _AuthInterceptor（flutter_secure_storage 在 VM 测试里无插件）。
      authedClient = ApiClient(
        dio: Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60),
        )),
      );
    });

    test('ApiService.chat → /api/v1/chat/send 收到中文回复', () async {
      final api = ApiService(client: authedClient);
      final body = await api.chat(userId: 'live-it', message: '最近总是失眠，怎么办');

      // chat_page.dart 的解包路径：result['data'] ?? result，再读 message/text
      final data = body['data'] ?? body;
      final reply = data['message'] ?? data['text'];
      expect(reply, isA<String>());
      expect(reply as String, isNotEmpty);
      expect(reply, contains('顺时')); // mock 固定中文回复
      expect(body['content'], reply);
    });

    test('/api/v1/ai/chat（ShunShiRouter 契约）返回 content/message', () async {
      final resp = await authedClient.post<dynamic>(
        '/api/v1/ai/chat',
        data: {
          'user_input': '今天吃什么好',
          'intent': 'dietary_advice',
          'context': {'current_season': 'winter'},
          'prompt': '你是顺时健康陪伴助手，请给出今日饮食建议。',
          'model_tier': 'free',
        },
      );
      expect(resp.statusCode, 200);
      final body = resp.data as Map<String, dynamic>;
      final content = body['content'] ?? body['message'] ?? body['data'];
      expect(content, isA<String>());
      expect(content as String, contains('顺时'));
      expect(body['tone'], 'gentle');
    });

    test('memory 开关：默认关闭 → 打开 → 回读一致 → 关闭', () async {
      final before = await authedClient.get<dynamic>('/api/v1/settings/memory');
      expect((before.data as Map)['enabled'], isFalse);

      await authedClient.post<dynamic>(
        '/api/v1/settings/memory',
        data: {'enabled': true},
      );
      final after = await authedClient.get<dynamic>('/api/v1/settings/memory');
      expect((after.data as Map)['enabled'], isTrue);

      await authedClient.post<dynamic>(
        '/api/v1/settings/memory',
        data: {'enabled': false},
      );
    });

    test('home dashboard 契约：greeting/daily_insight/suggestions', () async {
      final resp = await authedClient.get<dynamic>(
        '/api/v1/seasons/home/dashboard',
        queryParameters: {'hemisphere': 'north'},
      );
      expect(resp.statusCode, 200);
      final data = resp.data as Map<String, dynamic>;
      // home_page.dart 解包：data['greeting'] / data['daily_insight']['text'] / data['suggestions']
      expect(data['greeting'], isA<String>());
      expect(data.containsKey('daily_insight'), isTrue);
      expect(data['suggestions'], isA<List>());
    });

    test('数据导出包含刚聊过的消息', () async {
      final resp = await authedClient.post<dynamic>('/api/v1/auth/data/export');
      expect(resp.statusCode, 200);
      final data = resp.data as Map<String, dynamic>;
      expect(data['product'], 'shunshi');
      expect((data['messages'] as List), isNotEmpty);
      expect(data['settings'], isA<Map>());
    });

    test('未认证请求被拒（401）', () async {
      try {
        await anon.post<dynamic>('/api/v1/chat/send', data: {'message': 'hi'});
        fail('应当抛 401');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 401);
      }
    });
  });
}
