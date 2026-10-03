import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/product_view_mode.dart';

/// Persists non-session app preferences (survives logout).
class AppSettingsStorage {
  AppSettingsStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tag = 'AppSettingsStorage';
  static const _kAllowScreenshots = 'allow_screenshots';
  static const _kProductViewMode = 'product_view_mode';
  static const _kSearchRecents = 'search_recents_json';
  static const _kPreviewAll = 'product_details_preview_all';
  static const _kPreviewDetails = 'product_details_preview_details';

  final FlutterSecureStorage _storage;

  /// Defaults to `false` (screenshots / screen recording blocked).
  Future<bool> readAllowScreenshots() async {
    final raw = await _storage.read(key: _kAllowScreenshots);
    if (raw == null || raw.isEmpty) return false;
    return raw == 'true';
  }

  Future<void> writeAllowScreenshots(bool value) async {
    await _storage.write(
      key: _kAllowScreenshots,
      value: value ? 'true' : 'false',
    );
    AppLog.d(_tag, 'allowScreenshots=$value');
  }

  /// Defaults to [ProductViewMode.group].
  Future<ProductViewMode> readProductViewMode() async {
    final raw = await _storage.read(key: _kProductViewMode);
    return ProductViewModeX.fromStorage(raw);
  }

  Future<void> writeProductViewMode(ProductViewMode mode) async {
    await _storage.write(key: _kProductViewMode, value: mode.storageValue);
    AppLog.d(_tag, 'productViewMode=${mode.storageValue}');
  }

  /// Defaults to `false` (thumbnail strip hidden until user enables it).
  Future<bool> readPreviewAll() async {
    final raw = await _storage.read(key: _kPreviewAll);
    if (raw == null || raw.isEmpty) return false;
    return raw == 'true';
  }

  Future<void> writePreviewAll(bool value) async {
    await _storage.write(
      key: _kPreviewAll,
      value: value ? 'true' : 'false',
    );
    AppLog.d(_tag, 'previewAll=$value');
  }

  /// Defaults to `true` (weight chrome shown until the user hides it).
  Future<bool> readPreviewDetails() async {
    final raw = await _storage.read(key: _kPreviewDetails);
    if (raw == null || raw.isEmpty) return true;
    return raw == 'true';
  }

  Future<void> writePreviewDetails(bool value) async {
    await _storage.write(
      key: _kPreviewDetails,
      value: value ? 'true' : 'false',
    );
    AppLog.d(_tag, 'previewDetails=$value');
  }

  Future<String?> readSearchRecentsJson() => _storage.read(key: _kSearchRecents);

  Future<void> writeSearchRecentsJson(String json) async {
    await _storage.write(key: _kSearchRecents, value: json);
  }
}
