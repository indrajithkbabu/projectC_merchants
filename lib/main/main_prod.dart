import 'package:flutter/material.dart';
import 'package:flutter_flavor/flutter_flavor.dart';
import 'package:project_c/flavor/flavor_variables.dart';
import 'package:project_c/main/main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlavorConfig(name: FlavorNames.prod, variables: Prod.flavorVariables);

  defaultMain(Flavor.prod);
}
