import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:project_c/bloc/auth/auth_bloc.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/app_theme.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/navigation/route_initializer.dart';
import 'package:project_c/navigation/routes.dart';

class App extends StatelessWidget {
  const App({super.key});

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
