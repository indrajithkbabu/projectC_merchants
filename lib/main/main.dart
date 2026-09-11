import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/main/app.dart';

enum Flavor { dev, prod }

void defaultMain(Flavor flavor) {
  ServiceLocator.configureDependencies();
  configureSystemUi();
  runApp(const App());
}
