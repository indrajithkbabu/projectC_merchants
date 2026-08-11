import 'package:flutter/material.dart';
import 'package:project_c/main/app.dart';

enum Flavor { dev, prod }

void defaultMain(Flavor flavor) {
  configureSystemUi();
  runApp(const App());
}
