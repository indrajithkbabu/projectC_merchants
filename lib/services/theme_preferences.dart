import 'package:flutter/material.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/storage/app_settings_storage.dart';

/// Reactive appearance preference (System / Day / Night).
///
/// Survives logout (same as screenshot preference). [App] listens and rebinds
/// [AppColors]; Settings writes through [setAppearance].
///
/// When preference is [AppAppearance.system], [resolvedAppearance] tracks the
/// device light/dark setting via [syncPlatformBrightness].
class ThemePreferences extends ChangeNotifier {
  ThemePreferences({required AppSettingsStorage storage}) : _storage = storage;

  static const _tag = 'ThemePreferences';

  final AppSettingsStorage _storage;

  AppAppearance _appearance = AppAppearance.system;
  AppAppearance _resolved = AppAppearance.day;
  bool _loaded = false;

  /// Persisted preference (may be System).
  AppAppearance get appearance => _appearance;

  /// Concrete Day/Night used for palettes and [AppearanceScope].
  AppAppearance get resolvedAppearance => _resolved;

  bool get isNight => _resolved == AppAppearance.night;
  bool get isLoaded => _loaded;

  ThemeMode get themeMode => _appearance.themeMode;

  Future<void> load() async {
    _appearance = await _storage.readAppearance();
    _resolved = _appearance.resolve(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    _loaded = true;
    AppColors.bind(_resolved);
    AppLog.d(
      _tag,
      'loaded appearance=${_appearance.storageValue} '
      'resolved=${_resolved.storageValue}',
    );
    notifyListeners();
  }

  Future<void> setAppearance(AppAppearance appearance) async {
    final resolved = appearance.resolve(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    if (_appearance == appearance &&
        _resolved == resolved &&
        _loaded) {
      return;
    }
    _appearance = appearance;
    _resolved = resolved;
    _loaded = true;
    AppColors.bind(_resolved);
    notifyListeners();
    await _storage.writeAppearance(appearance);
    AppLog.d(
      _tag,
      'setAppearance=${appearance.storageValue} '
      'resolved=${_resolved.storageValue}',
    );
  }

  /// Re-resolve when the OS light/dark setting changes (no-op if forced Day/Night).
  void syncPlatformBrightness(Brightness brightness) {
    if (!_appearance.isSystem) return;
    final resolved = _appearance.resolve(brightness);
    if (_resolved == resolved) return;
    _resolved = resolved;
    AppColors.bind(_resolved);
    AppLog.d(_tag, 'platformBrightness → resolved=${_resolved.storageValue}');
    notifyListeners();
  }
}
