import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:project_c/bloc/auth/auth_bloc.dart';
import 'package:project_c/helper/app_theme.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/navigation/route_initializer.dart';
import 'package:project_c/navigation/routes.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(),
      child: MaterialApp(
        title: 'Project C',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: Routes.onboardingRoute,
        onGenerateRoute: onGenerateRoutes,
        supportedLocales: const [
          Locale('en'),
        ],
        localizationsDelegates: const [
          CountryLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}

void configureSystemUi() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.scaffold,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}
