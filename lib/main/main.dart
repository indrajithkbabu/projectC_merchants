import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/main/app.dart';

enum Flavor { dev, prod }

Future<void> defaultMain(Flavor flavor) async {
  ServiceLocator.configureDependencies();
  configureSystemUi();
  // Do NOT apply FLAG_SECURE here — Android Activity is not attached yet.
  // App starts protection after the first frame.
  runApp(const App());
}
