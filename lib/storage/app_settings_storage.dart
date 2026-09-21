import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:project_c/helper/app_log.dart';

/// Persists non-session app preferences (survives logout).
class AppSettingsStorage {
  AppSettingsStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tag = 'AppSettingsStorage';
  static const _kAllowScreenshots = 'allow_screenshots';

  final FlutterSecureStorage _storage;

  /// Defaults to `false` (screenshots / screen recording blocked).
  Future<bool> readAllowScreenshots() async {
    final raw = await _storage.read(key: _kAllowScreenshots);
    if (raw == null || raw.isEmpty) return false;
    return raw == 'true';
  }

  Future<void> writeAllowScreenshots(bool value) async {
    await _storage.write(key: _kAllowScreenshots, value: value ? 'true' : 'false');
    AppLog.d(_tag, 'allowScreenshots=$value');
  }
}
