// Token Storage Service
// Securely stores authentication tokens

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tokenExpiryKey = 'token_expiry';
  
  final FlutterSecureStorage _storage;
  
  TokenStorage() : _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  // Save tokens
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? expiresAt,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    if (expiresAt != null) {
      await _storage.write(
        key: _tokenExpiryKey,
        value: expiresAt.toIso8601String(),
      );
    }
  }
  
  // Get access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }
  
  // Get refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }
  
  // Check if token is expired
  Future<bool> isTokenExpired() async {
    final expiryStr = await _storage.read(key: _tokenExpiryKey);
    if (expiryStr == null) return true;
    
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return true;
    
    return DateTime.now().isAfter(expiry);
  }
  
  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    if (token == null) return false;
    
    final expired = await isTokenExpired();
    return !expired;
  }
  
  // Clear all tokens (logout)
  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _tokenExpiryKey);
  }
  
  // Refresh token
  /// 用 refresh token 换一对新令牌。
  ///
  /// 修复两处：
  ///
  /// 1. **字段名对不上。** 原来读 `newTokens['access']` / `['refresh']`，
  ///    而后端返回的是 `access_token` / `refresh_token`
  ///    （login_page.dart 里读的就是后者）。取不到时 `?? ''` 会把
  ///    **空字符串当成有效令牌存进去** —— 刷新"成功"了，
  ///    但之后每个请求都带着 `Authorization: Bearer ` 继续 401。
  ///    两种命名都兼容，并对空值显式失败。
  ///
  /// 2. **返回类型。** 签名要求 `Map<String, String>`，但 JSON 解出来是
  ///    `Map<String, dynamic>`，调用方那边的 `as Map<String, String>`
  ///    是必然抛 `TypeError` 的。改为 `Map<String, dynamic>`。
  Future<bool> refreshToken(
    Future<Map<String, dynamic>> Function(String) refreshFn,
  ) async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final newTokens = await refreshFn(refreshToken);

      final access =
          (newTokens['access_token'] ?? newTokens['access']) as String?;
      final refresh =
          (newTokens['refresh_token'] ?? newTokens['refresh']) as String?;

      // 空令牌等于没刷新成功 —— 存进去只会让后续请求继续 401，
      // 且因为 refreshed==true 而不会触发登出。
      if (access == null || access.isEmpty) {
        await clearTokens();
        return false;
      }

      await saveTokens(
        accessToken: access,
        refreshToken: (refresh != null && refresh.isNotEmpty)
            ? refresh
            : refreshToken,
      );
      return true;
    } catch (e) {
      await clearTokens();
      return false;
    }
  }
}

// Global instance
final tokenStorage = TokenStorage();
