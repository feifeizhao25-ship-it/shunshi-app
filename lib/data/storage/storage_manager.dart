import '../../core/storage/token_storage.dart';

class StorageManager {
  StorageManager._();

  static final user = _UserStorage();

  static Future<void> init() async {
    // flutter_secure_storage initializes lazily on the native platform.
  }
}

class _UserStorage {
  Future<void> saveToken(
    String accessToken, {
    String refreshToken = '',
    DateTime? expiresAt,
  }) => tokenStorage.saveTokens(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: expiresAt,
  );

  Future<void> clear() => tokenStorage.clearTokens();
}
