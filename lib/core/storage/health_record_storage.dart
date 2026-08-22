import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted-at-rest storage for the user's local wellness journal.
class HealthRecordStorage {
  HealthRecordStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> clear() async {
    for (final key in keys) {
      await _storage.delete(key: key);
    }
  }

  static const moodKey = 'health_mood_records';
  static const sleepKey = 'health_sleep_records';
  static const exerciseKey = 'health_exercise_records';
  static const dietKey = 'health_diet_records';
  static const keys = [moodKey, sleepKey, exerciseKey, dietKey];
}

final healthRecordStorage = HealthRecordStorage();
