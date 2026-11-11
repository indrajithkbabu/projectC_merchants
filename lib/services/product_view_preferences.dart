import 'package:flutter/foundation.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/collage_grid_arrangement.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/storage/app_settings_storage.dart';

/// Reactive preference for store-profile product layout (+ collage grid prefs).
///
/// Survives logout (same as screenshot preference). Store profile listens via
/// [ListenableBuilder]; Settings writes through [setMode].
///
/// Collage N×N arrangement APIs are kept for rollback but unused while
/// `kEnableCollageImageArrangement` is false.
class ProductViewPreferences extends ChangeNotifier {
  ProductViewPreferences({required AppSettingsStorage storage})
    : _storage = storage;

  static const _tag = 'ProductViewPreferences';

  final AppSettingsStorage _storage;

  ProductViewMode _mode = ProductViewMode.group;
  CollageGridArrangement _collageGrid =
      CollageGridArrangementX.defaultArrangement;
  bool _loaded = false;

  ProductViewMode get mode => _mode;

  /// Inside-card N×N arrangement for Group / Single collages.
  CollageGridArrangement get collageGridArrangement => _collageGrid;

  int get collageGridSide => _collageGrid.side;

  int get collagePageSize => _collageGrid.pageSize;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    _mode = await _storage.readProductViewMode();
    _collageGrid = await _storage.readCollageGridArrangement();
    _loaded = true;
    AppLog.d(
      _tag,
      'loaded mode=${_mode.storageValue} collage=${_collageGrid.label}',
    );
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

  Future<void> setCollageGridArrangement(
    CollageGridArrangement arrangement,
  ) async {
    if (_collageGrid == arrangement && _loaded) return;
    _collageGrid = arrangement;
    _loaded = true;
    notifyListeners();
    await _storage.writeCollageGridArrangement(arrangement);
    AppLog.d(_tag, 'setCollageGridArrangement=${arrangement.label}');
  }
}
