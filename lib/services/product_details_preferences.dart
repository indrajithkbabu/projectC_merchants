import 'package:project_c/helper/app_log.dart';
import 'package:project_c/storage/app_settings_storage.dart';

/// Persists product-details chrome prefs across route entries.
///
/// Survives logout (same as [ProductViewPreferences] / screenshot preference).
class ProductDetailsPreferences {
  ProductDetailsPreferences({required AppSettingsStorage storage})
    : _storage = storage;

  static const _tag = 'ProductDetailsPreferences';

  final AppSettingsStorage _storage;

  bool _previewAll = false;
  bool _previewDetails = true;
  bool _loaded = false;

  bool get previewAll => _previewAll;
  bool get previewDetails => _previewDetails;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _previewAll = await _storage.readPreviewAll();
    _previewDetails = await _storage.readPreviewDetails();
    _loaded = true;
    AppLog.d(
      _tag,
      'loaded previewAll=$_previewAll previewDetails=$_previewDetails',
    );
  }

  Future<void> setPreviewAll(bool value) async {
    if (_previewAll == value && _loaded) return;
    _previewAll = value;
    _loaded = true;
    await _storage.writePreviewAll(value);
    AppLog.d(_tag, 'setPreviewAll=$value');
  }

  Future<void> setPreviewDetails(bool value) async {
    if (_previewDetails == value && _loaded) return;
    _previewDetails = value;
    _loaded = true;
    await _storage.writePreviewDetails(value);
    AppLog.d(_tag, 'setPreviewDetails=$value');
  }
}
