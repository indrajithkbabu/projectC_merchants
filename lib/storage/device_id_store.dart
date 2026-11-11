import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/profile_switching_log.dart';

/// Stable installation id for OTP verify + `X-Catalog-Device-Id`.
///
/// Survives logout/login on the same install; a fresh install gets a new id.
class DeviceIdStore {
  DeviceIdStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tag = 'DeviceIdStore';
  static const _kDeviceId = 'catalog_device_id';

  final FlutterSecureStorage _storage;
  String? _cached;

  /// Returns a 16–128 char `[A-Za-z0-9_-]` id, creating one if missing.
  Future<String> getOrCreate() async {
    final cached = _cached?.trim() ?? '';
    if (_isValid(cached)) return cached;

    final existing = (await _storage.read(key: _kDeviceId))?.trim() ?? '';
    if (_isValid(existing)) {
      _cached = existing;
      AppLog.d(_tag, 'Loaded installation device id len=${existing.length}');
      ProfileSwitchingLog.d(
        'PS-01/02',
        'deviceId reused (secure storage) id=$existing',
      );
      return existing;
    }

    final next = _generate();
    await _storage.write(key: _kDeviceId, value: next);
    _cached = next;
    AppLog.d(_tag, 'Created installation device id len=${next.length}');
    ProfileSwitchingLog.d(
      'PS-01/03',
      'deviceId created (fresh install) id=$next',
    );
    return next;
  }

  bool _isValid(String value) {
    if (value.length < 16 || value.length > 128) return false;
    return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
  }

  String _generate() {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
    final rng = Random.secure();
    final chars = List<String>.generate(
      32,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    );
    return 'flutter_${chars.join()}';
  }
}
