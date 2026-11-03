import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:project_c/helper/app_log.dart';

/// Short UI sound effects (Telegram-style bubble tick on pending photo checks).
class UiSounds {
  UiSounds._();

  static const _tag = 'UiSounds';
  static const bubbleTickAsset = 'sounds/ui_pop.mp3';

  static AudioPool? _bubblePool;
  static Future<AudioPool?>? _bubbleWarm;
  static var _bubbleUnavailable = false;

  /// Preload the bubble pool (safe to call multiple times).
  static Future<void> warmBubbleTick() async {
    await _ensureBubblePool();
  }

  /// Play one bubble tick (overlapping OK — pool of short low-latency players).
  static void playBubbleTick() {
    unawaited(_playBubbleTick());
  }

  static Future<void> _playBubbleTick() async {
    final pool = await _ensureBubblePool();
    if (pool == null) return;
    try {
      await pool.start(volume: 0.7);
    } catch (e) {
      AppLog.e(_tag, 'bubble tick play failed', e);
    }
  }

  static Future<AudioPool?> _ensureBubblePool() {
    if (_bubbleUnavailable) return Future<AudioPool?>.value(null);
    final existing = _bubblePool;
    if (existing != null) return Future<AudioPool?>.value(existing);
    return _bubbleWarm ??= () async {
      try {
        final pool = await AudioPool.createFromAsset(
          path: bubbleTickAsset,
          maxPlayers: 6,
          minPlayers: 1,
          playerMode: PlayerMode.lowLatency,
        );
        _bubblePool = pool;
        return pool;
      } catch (e) {
        _bubbleUnavailable = true;
        _bubbleWarm = null;
        AppLog.e(_tag, 'bubble pool warm failed', e);
        return null;
      }
    }();
  }
}
