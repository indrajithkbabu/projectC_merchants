import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/onboarding/onboarding_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/onboarding/onboarding_widgets/welcome_step.dart';

class OnboardingRoute extends StatelessWidget {
  const OnboardingRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<OnboardingBloc, OnboardingState>(
          listenWhen:
              (prev, curr) => curr.navigateToAuth && !prev.navigateToAuth,
          listener: (context, state) {
            context.read<OnboardingBloc>().add(
              const OnboardingClearNavigateToAuth(),
            );
            Navigator.of(context).pushNamed(Routes.authPhoneRoute);
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: Padding(
          padding: EdgeInsets.only(top: ScreenWrapper.statusBarTop(context)),
          child: WelcomeStep(
            onContinue:
                () => context.read<OnboardingBloc>().add(
                  const OnboardingContinuePressed(),
                ),
          ),
        ),
      ),
    );
  }
}
