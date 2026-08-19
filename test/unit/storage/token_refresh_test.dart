// test/unit/storage/token_refresh_test.dart
//
// 令牌自动续期的回归测试。
//
// 2026-08-18 复核发现这条链上有三个独立缺陷，叠加后的效果是
// **自动续期从来没有成功过**，且失败时 UI 完全无感知：
//
//   1. `newTokens['access']` —— 后端返回的字段名是 `access_token`
//      （login_page.dart 里读的就是后者）。取不到时 `?? ''` 会把
//      **空字符串当成有效令牌存进去**，刷新"成功"了，
//      但之后每个请求都带着 `Authorization: Bearer ` 继续 401。
//
//   2. `response.data as Map<String, String>` —— JSON 解出来是
//      `Map<String, dynamic>`，这个转换**必然抛 TypeError**，
//      被 catch 吞掉后一律当刷新失败。
//
//   3. 刷新失败只 `clearTokens()`，没有任何登出广播 ——
//      用户停在一个看似已登录、实则每个请求都 401 的界面上。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shunshi/core/storage/token_storage.dart';

void main() {
  // FlutterSecureStorage 在测试里走内存实现
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('TokenStorage.refreshToken', () {
    test('接受后端的 access_token / refresh_token 字段名', () async {
      final storage = TokenStorage();
      await storage.saveTokens(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );

      final ok = await storage.refreshToken((rt) async {
        expect(rt, 'old-refresh');
        return {
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
        };
      });

      expect(ok, isTrue);
      expect(await storage.getAccessToken(), 'new-access');
      expect(await storage.getRefreshToken(), 'new-refresh');
    });

    test('兼容旧的 access / refresh 字段名', () async {
      final storage = TokenStorage();
      await storage.saveTokens(accessToken: 'a', refreshToken: 'r');

      final ok = await storage.refreshToken(
        (_) async => {'access': 'new-a', 'refresh': 'new-r'},
      );

      expect(ok, isTrue);
      expect(await storage.getAccessToken(), 'new-a');
    });

    test('响应缺 access token 时判定为失败，不存空串', () async {
      final storage = TokenStorage();
      await storage.saveTokens(accessToken: 'old', refreshToken: 'r');

      // 这正是字段名写错时的实际情形：取不到 → 原来存 ''
      final ok = await storage.refreshToken((_) async => {'foo': 'bar'});

      expect(ok, isFalse, reason: '拿不到令牌就该失败，而不是"成功"存个空串');
      expect(await storage.getAccessToken(), isNull, reason: '应已清空令牌');
    });

    test('access token 为空字符串同样判定为失败', () async {
      final storage = TokenStorage();
      await storage.saveTokens(accessToken: 'old', refreshToken: 'r');

      final ok = await storage.refreshToken(
        (_) async => {'access_token': ''},
      );

      expect(ok, isFalse);
      expect(await storage.getAccessToken(), isNull);
    });

    test('响应未带新 refresh token 时沿用旧的', () async {
      final storage = TokenStorage();
      await storage.saveTokens(accessToken: 'a', refreshToken: 'keep-me');

      final ok = await storage.refreshToken(
        (_) async => {'access_token': 'new-a'},
      );

      expect(ok, isTrue);
      expect(await storage.getRefreshToken(), 'keep-me');
    });

    test('没有 refresh token 时直接返回 false，不发请求', () async {
      final storage = TokenStorage();
      var called = false;

      final ok = await storage.refreshToken((_) async {
        called = true;
        return {'access_token': 'x'};
      });

      expect(ok, isFalse);
      expect(called, isFalse);
    });

    test('刷新过程抛异常时清空令牌', () async {
      final storage = TokenStorage();
      await storage.saveTokens(accessToken: 'a', refreshToken: 'r');

      final ok = await storage.refreshToken(
        (_) async => throw Exception('network down'),
      );

      expect(ok, isFalse);
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test('回调签名接受 Map<String, dynamic>', () async {
      // 签名若是 Map<String, String>，调用方对 JSON 结果做
      // `as Map<String, String>` 必然抛 TypeError。
      // 这里传入含非字符串值的 map 来钉住类型。
      final storage = TokenStorage();
      await storage.saveTokens(accessToken: 'a', refreshToken: 'r');

      final ok = await storage.refreshToken(
        (_) async => <String, dynamic>{
          'access_token': 'new-a',
          'expires_in': 3600, // int，不是 String
        },
      );

      expect(ok, isTrue);
      expect(await storage.getAccessToken(), 'new-a');
    });
  });
}
