import 'dart:async';

import 'package:flutter/material.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:no_screenshot/screenshot_snapshot.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/storage/app_settings_storage.dart';

/// App-wide screenshot / screen-recording gate.
///
/// Default: blocked. Settings can allow capture. While blocked, capture
/// attempts show a friendly snackbar when the platform reports them.
///
/// Must be initialized **after** the first frame so the Android Activity is
/// attached — calling [screenshotOff] earlier is a no-op for FLAG_SECURE.
class ScreenshotProtectionService extends ChangeNotifier {
  ScreenshotProtectionService({
    required AppSettingsStorage storage,
    NoScreenshot? plugin,
  }) : _storage = storage,
       _plugin = plugin ?? NoScreenshot.instance;

  static const _tag = 'ScreenshotProtection';
  static const blockedMessage =
      'Screenshots and screen recording are turned off for privacy. '
      'Enable them in Settings when you need to capture this screen.';

  final AppSettingsStorage _storage;
  final NoScreenshot _plugin;

  StreamSubscription<ScreenshotSnapshot>? _subscription;
  bool _allowScreenshots = false;
  bool _initialized = false;
  bool _listening = false;
  bool _wasRecording = false;
  bool _applying = false;
  DateTime? _lastSnackAt;

  /// `true` when the user may take screenshots / record the screen.
  bool get allowScreenshots => _allowScreenshots;

  bool get isInitialized => _initialized;

  GlobalKey<ScaffoldMessengerState>? _messengerKey;

  void attachMessenger(GlobalKey<ScaffoldMessengerState> key) {
    _messengerKey = key;
  }

  /// Load preference and apply platform protection.
  /// Call after the first frame (Activity must be attached).
  Future<void> initialize({
    GlobalKey<ScaffoldMessengerState>? messengerKey,
  }) async {
    if (messengerKey != null) {
      _messengerKey = messengerKey;
    }
    if (!_initialized) {
      _allowScreenshots = await _storage.readAllowScreenshots();
      _initialized = true;
      notifyListeners();
    }
    await _applyProtection();
    await _syncListening();
    AppLog.d(_tag, 'initialized allowScreenshots=$_allowScreenshots');
  }

  /// Re-apply the current preference (e.g. after resume / Activity recreate).
  Future<void> reapply() async {
    if (!_initialized) return;
    await _applyProtection();
  }

  Future<void> setAllowScreenshots(bool allow) async {
    _allowScreenshots = allow;
    await _storage.writeAllowScreenshots(allow);
    await _applyProtection();
    await _syncListening();
    notifyListeners();
  }

  Future<void> _applyProtection() async {
    if (_applying) return;
    _applying = true;
    try {
      // Plugin returns true even when Activity is null (FLAG_SECURE no-op),
      // so always apply, wait briefly, and apply again once Activity is up.
      await _setSecure(!_allowScreenshots);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _setSecure(!_allowScreenshots);
    } catch (e) {
      AppLog.e(_tag, 'Failed to apply screenshot protection', e);
    } finally {
      _applying = false;
    }
  }

  Future<void> _setSecure(bool secure) async {
    final ok =
        secure ? await _plugin.screenshotOff() : await _plugin.screenshotOn();
    AppLog.d(_tag, '${secure ? 'screenshotOff' : 'screenshotOn'} ok=$ok');
  }

  Future<void> _syncListening() async {
    if (_allowScreenshots) {
      await _stopListening();
      return;
    }
    await _startListening();
  }

  Future<void> _startListening() async {
    if (_listening) return;
    _subscription ??= _plugin.screenshotStream.listen(_onSnapshot);
    try {
      await _plugin.startScreenshotListening();
      await _plugin.startScreenRecordingListening();
      _listening = true;
      AppLog.d(_tag, 'capture listening started');
    } catch (e) {
      AppLog.e(_tag, 'Failed to start capture listening', e);
    }
  }

  Future<void> _stopListening() async {
    if (!_listening && _subscription == null) return;
    try {
      await _plugin.stopScreenshotListening();
      await _plugin.stopScreenRecordingListening();
    } catch (e) {
      AppLog.e(_tag, 'Failed to stop capture listening', e);
    }
    await _subscription?.cancel();
    _subscription = null;
    _listening = false;
  }

  void _onSnapshot(ScreenshotSnapshot snapshot) {
    if (_allowScreenshots) {
      _wasRecording = snapshot.isScreenRecording;
      return;
    }
    final recordingStarted =
        snapshot.isScreenRecording && !_wasRecording;
    _wasRecording = snapshot.isScreenRecording;
    if (snapshot.wasScreenshotTaken || recordingStarted) {
      _showBlockedSnack();
    }
  }

  void _showBlockedSnack() {
    final now = DateTime.now();
    if (_lastSnackAt != null &&
        now.difference(_lastSnackAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastSnackAt = now;
    final messenger = _messengerKey?.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(blockedMessage),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
  }

  @override
  void dispose() {
    unawaited(_stopListening());
    super.dispose();
  }
}
