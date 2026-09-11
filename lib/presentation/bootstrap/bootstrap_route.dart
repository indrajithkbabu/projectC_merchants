import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/presentation/onboarding/onboarding_widgets/jewel_flow_logo.dart';

/// Cold-start gate shown while [AuthBloc] restores the session.
/// Never shows the marketing Continue CTA — that lives only on onboarding.
class BootstrapRoute extends StatelessWidget {
  const BootstrapRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenWrapper(
      backgroundColor: AppColors.background,
      statusBarIconBrightness: Brightness.dark,
      child: Center(child: JewelFlowLogo(size: 92)),
    );
  }
}
