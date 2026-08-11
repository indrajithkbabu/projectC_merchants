import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/onboarding/onboarding_bloc.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/auth/country_picker_route.dart';
import 'package:project_c/presentation/auth/otp_route.dart';
import 'package:project_c/presentation/auth/phone_route.dart';
import 'package:project_c/presentation/home/home_placeholder_route.dart';
import 'package:project_c/presentation/onboarding/onboarding_route.dart';

PageRoute? onGenerateRoutes(RouteSettings settings) {
  debugPrint('onGenerateRoutes called with route: ${settings.name}');
  switch (settings.name) {
    case Routes.onboardingRoute:
      return _onboardingRoute(settings);
    case Routes.authPhoneRoute:
      return _authPhoneRoute(settings);
    case Routes.authOtpRoute:
      return _authOtpRoute(settings);
    case Routes.countryPickerRoute:
      return _countryPickerRoute(settings);
    case Routes.homePlaceholderRoute:
      return _homePlaceholderRoute(settings);

    default:
      debugPrint('Route not found: ${settings.name}');
      return null;
  }
}

PageRoute? _onboardingRoute(RouteSettings settings) {
  return MaterialPageRoute(
    settings: settings,
    builder: (context) {
      return BlocProvider(
        create: (_) => OnboardingBloc(),
        child: const OnboardingRoute(),
      );
    },
  );
}

PageRoute? _authPhoneRoute(RouteSettings settings) {
  return MaterialPageRoute(
    settings: settings,
    builder: (context) => const PhoneRoute(),
  );
}

PageRoute? _authOtpRoute(RouteSettings settings) {
  return MaterialPageRoute(
    settings: settings,
    builder: (context) => const OtpRoute(),
  );
}

PageRoute? _countryPickerRoute(RouteSettings settings) {
  final initialIso =
      settings.arguments is String ? settings.arguments as String : null;

  return MaterialPageRoute(
    settings: settings,
    builder: (context) => CountryPickerRoute(initialIsoCode: initialIso),
  );
}

PageRoute? _homePlaceholderRoute(RouteSettings settings) {
  return MaterialPageRoute(
    settings: settings,
    builder: (context) => const HomePlaceholderRoute(),
  );
}
