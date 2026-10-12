import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/firebase_options.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/main/app.dart';
import 'package:project_c/services/push_notification_service.dart';
import 'package:project_c/services/theme_preferences.dart';

enum Flavor { dev, prod }

Future<void> defaultMain(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Decoded half-screen tiles are still multi‑MB; keep a large LRU so pinch
  // zoom / back-navigation hit memory instead of re-decoding from disk.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 384 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 4000;

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  ServiceLocator.configureDependencies();
  await ServiceLocator.get<ThemePreferences>().load();
  AppColors.bind(ServiceLocator.get<ThemePreferences>().appearance);
  configureSystemUi();

  try {
    await ServiceLocator.get<PushNotificationService>().initialize();
  } catch (e) {
    // Notifications must not block app launch (permissions / Play Services).
    // ignore: avoid_print
    print('[FCM_DEBUG] INIT FATAL $e');
    AppLog.e('PushNotification', 'initialize failed', e);
  }

  // Do NOT apply FLAG_SECURE here — Android Activity is not attached yet.
  // App starts protection after the first frame.
  runApp(const App());
}
