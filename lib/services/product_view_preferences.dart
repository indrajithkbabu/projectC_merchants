import 'package:flutter/foundation.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/storage/app_settings_storage.dart';

/// Reactive preference for store-profile product layout.
///
/// Survives logout (same as screenshot preference). Store profile listens via
/// [ListenableBuilder]; Settings writes through [setMode].
class ProductViewPreferences extends ChangeNotifier {
  ProductViewPreferences({required AppSettingsStorage storage})
    : _storage = storage;

  static const _tag = 'ProductViewPreferences';

  final AppSettingsStorage _storage;

  ProductViewMode _mode = ProductViewMode.group;
  bool _loaded = false;

  ProductViewMode get mode => _mode;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _mode = await _storage.readProductViewMode();
    _loaded = true;
    AppLog.d(_tag, 'loaded mode=${_mode.storageValue}');
    notifyListeners();
  }

  Future<void> setMode(ProductViewMode mode) async {
    if (_mode == mode && _loaded) return;
    _mode = mode;
    _loaded = true;
    notifyListeners();
    await _storage.writeProductViewMode(mode);
    AppLog.d(_tag, 'setMode=${mode.storageValue}');
  }
}
