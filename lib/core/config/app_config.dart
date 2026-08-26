import 'package:flutter/foundation.dart';

/// Build-time configuration for the domestic ShunShi client.
///
/// Production builds must provide `SHUNSHI_API_BASE_URL` with `--dart-define`.
/// Keeping the provider credentials on the server prevents them from being
/// extracted from a mobile or web bundle.
class AppConfig {
  AppConfig._();

  @visibleForTesting
  static String? apiBaseUrlOverride;

  static const _configuredApiBaseUrl = String.fromEnvironment(
    'SHUNSHI_API_BASE_URL',
  );

  /// Fail immediately during startup when a release artifact has no API URL.
  static void validate() {
    apiBaseUrl;
  }

  static String get apiBaseUrl {
    final override = apiBaseUrlOverride?.trim();
    if (override != null && override.isNotEmpty) return _normalize(override);
    final configured = _configuredApiBaseUrl.trim();
    if (configured.isNotEmpty) return _normalize(configured);
    if (kReleaseMode) {
      throw StateError('SHUNSHI_API_BASE_URL is required for a release build.');
    }
    return 'http://localhost:4000';
  }

  static String _normalize(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
