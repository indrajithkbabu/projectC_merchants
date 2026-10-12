import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:project_c/bloc/auth/auth_bloc.dart';
import 'package:project_c/bloc/network_status/network_status_cubit.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/app_theme.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/widgets/appearance_scope.dart';
import 'package:project_c/helper/widgets/network_status_gate.dart';
import 'package:project_c/navigation/route_initializer.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/services/product_details_preferences.dart';
import 'package:project_c/services/product_view_preferences.dart';
import 'package:project_c/services/push_notification_service.dart';
import 'package:project_c/services/screenshot_protection_service.dart';
import 'package:project_c/services/store_privacy_preferences.dart';
import 'package:project_c/services/theme_preferences.dart';
import 'package:project_c/services/view_beacon.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late final ThemePreferences _themePrefs;

  @override
  void initState() {
    super.initState();
    _themePrefs = ServiceLocator.get<ThemePreferences>();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScreenshotProtection();
      // Activity is attached now — Android 13+ can show the system
      // notification permission dialog (must not run from main() before runApp).
      // ignore: unawaited_futures
      ServiceLocator.get<PushNotificationService>().requestRuntimePermissions();
      ServiceLocator.get<ProductViewPreferences>().load();
      ServiceLocator.get<ProductDetailsPreferences>().load();
      ServiceLocator.get<StorePrivacyPreferences>().load();
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
      // Recover FCM after transient GMS SERVICE_NOT_AVAILABLE (OEM/network).
      // ignore: unawaited_futures
      ServiceLocator.get<PushNotificationService>().onAppResumed();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // ignore: unawaited_futures
      ViewBeacon.instance.flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthBloc()..add(const AuthSessionRestoreRequested()),
        ),
        BlocProvider(create: (_) => NetworkStatusCubit()..start()),
      ],
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
            // After shell/root is set, apply any deferred notification deep link.
            if (state.isAuthenticated) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ServiceLocator.get<PushNotificationService>().flushPendingOpen();
              });
            }
          }

          // Unsigned restore can finish before the navigator is attached.
          if (navigatorKey.currentState != null) {
            go();
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) => go());
          }
        },
        child: ListenableBuilder(
          listenable: _themePrefs,
          builder: (context, _) {
            AppColors.bind(_themePrefs.appearance);
            configureSystemUi();
            return MaterialApp(
              navigatorKey: navigatorKey,
              scaffoldMessengerKey: scaffoldMessengerKey,
              title: 'Project C',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: _themePrefs.appearance.themeMode,
              initialRoute: Routes.bootstrapRoute,
              onGenerateRoute: onGenerateRoutes,
              builder: (context, child) {
                final appearance = _themePrefs.appearance;
                return AppearanceScope(
                  appearance: appearance,
                  child: NetworkStatusGate(
                    child: AppearanceRebuildGate(
                      appearance: appearance,
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                );
              },
              supportedLocales: const [Locale('en')],
              localizationsDelegates: const [
                CountryLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            );
          },
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void configureSystemUi() {
  SystemChrome.setSystemUIOverlayStyle(AppColors.systemOverlayStyle);
}
