import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:project_c/bloc/auth/auth_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/app_theme.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/navigation/route_initializer.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/services/screenshot_protection_service.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScreenshotProtection();
    });
  }

  Future<void> _startScreenshotProtection() async {
    final protection = ServiceLocator.get<ScreenshotProtectionService>();
    protection.attachMessenger(scaffoldMessengerKey);
    await protection.initialize(messengerKey: scaffoldMessengerKey);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ServiceLocator.get<ScreenshotProtectionService>().reapply();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc()..add(const AuthSessionRestoreRequested()),
      child: BlocListener<AuthBloc, AuthState>(
        // After cold-start restore only: replace bootstrap with the real root.
        // OTP / in-flow postAuthRoute is handled by OtpRoute (unchanged).
        listenWhen:
            (prev, curr) =>
                prev.isRestoringSession == true &&
                curr.isRestoringSession == false,
        listener: (context, state) {
          final route = state.postAuthRoute ?? Routes.onboardingRoute;
          AppLog.d(
            'TEST_COLD_START',
            'NAVIGATE after restore\n'
            '  authenticated=${state.isAuthenticated}\n'
            '  targetRoute=$route\n'
            '  paste this block with RESULT= above to judge A1–A4',
          );
          if (state.postAuthRoute != null) {
            context.read<AuthBloc>().add(const AuthClearPostAuthNavigation());
          }
          void go() {
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              route,
              (r) => false,
            );
          }

          // Unsigned restore can finish before the navigator is attached.
          if (navigatorKey.currentState != null) {
            go();
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) => go());
          }
        },
        child: MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          title: 'Project C',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          initialRoute: Routes.bootstrapRoute,
          onGenerateRoute: onGenerateRoutes,
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            CountryLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

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
