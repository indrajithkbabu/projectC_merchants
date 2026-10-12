import 'package:flutter/foundation.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/storage/app_settings_storage.dart';

/// Reactive Day / Night appearance preference.
///
/// Survives logout (same as screenshot preference). [App] listens and rebinds
/// [AppColors]; Settings writes through [setAppearance].
class ThemePreferences extends ChangeNotifier {
  ThemePreferences({required AppSettingsStorage storage}) : _storage = storage;

  static const _tag = 'ThemePreferences';

  final AppSettingsStorage _storage;

  AppAppearance _appearance = AppAppearance.day;
  bool _loaded = false;

  AppAppearance get appearance => _appearance;
  bool get isNight => _appearance.isNight;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _appearance = await _storage.readAppearance();
    _loaded = true;
    AppColors.bind(_appearance);
    AppLog.d(_tag, 'loaded appearance=${_appearance.storageValue}');
    notifyListeners();
  }

  Future<void> setAppearance(AppAppearance appearance) async {
    if (_appearance == appearance && _loaded) return;
    _appearance = appearance;
    _loaded = true;
    AppColors.bind(appearance);
    notifyListeners();
    await _storage.writeAppearance(appearance);
    AppLog.d(_tag, 'setAppearance=${appearance.storageValue}');
  }
}
