import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_tokens.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';

/// Persists catalog session tokens and a cached profile snapshot.
class SessionStorage {
  SessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tag = 'SessionStorage';
  static const _kAccess = 'catalog_access_token';
  static const _kRefresh = 'catalog_refresh_token';
  static const _kAccessExp = 'catalog_access_expires_at';
  static const _kRefreshExp = 'catalog_refresh_expires_at';
  static const _kProfile = 'catalog_profile_json';

  final FlutterSecureStorage _storage;

  Future<void> saveTokens(CatalogTokens tokens) async {
    await Future.wait([
      _storage.write(key: _kAccess, value: tokens.accessToken),
      _storage.write(key: _kRefresh, value: tokens.refreshToken),
      _storage.write(key: _kAccessExp, value: tokens.accessExpiresAt),
      _storage.write(key: _kRefreshExp, value: tokens.refreshExpiresAt),
    ]);
    AppLog.d(_tag, 'Tokens saved');
  }

  Future<CatalogTokens?> readTokens() async {
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    final accessExp = await _storage.read(key: _kAccessExp);
    final refreshExp = await _storage.read(key: _kRefreshExp);
    if (access == null ||
        refresh == null ||
        accessExp == null ||
        refreshExp == null ||
        access.isEmpty ||
        refresh.isEmpty) {
      return null;
    }
    return CatalogTokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: accessExp,
      refreshExpiresAt: refreshExp,
    );
  }

  Future<void> saveProfile(CatalogProfile profile) async {
    await _storage.write(
      key: _kProfile,
      value: jsonEncode(profile.toJson()),
    );
  }

  Future<CatalogProfile?> readProfile() async {
    final raw = await _storage.read(key: _kProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CatalogProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      AppLog.e(_tag, 'Failed to parse cached profile', e);
      return null;
    }
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccess),
      _storage.delete(key: _kRefresh),
      _storage.delete(key: _kAccessExp),
      _storage.delete(key: _kRefreshExp),
      _storage.delete(key: _kProfile),
    ]);
    AppLog.d(_tag, 'Session cleared');
  }
}
