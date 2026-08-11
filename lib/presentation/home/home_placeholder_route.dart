import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/auth/auth_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/presentation/onboarding/onboarding_widgets/jewel_flow_logo.dart';

class HomePlaceholderRoute extends StatelessWidget {
  const HomePlaceholderRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (prev, curr) =>
              curr.errorMessage != null &&
              curr.errorMessage != prev.errorMessage,
          listener: (context, state) {
            final message = state.errorMessage?.trim();
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
            context.read<AuthBloc>().add(const AuthClearMessage());
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: Padding(
          padding: AppPadding.screen(
            top: ScreenWrapper.statusBarTop(context) + 24,
            bottom: 24,
          ),
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              return Column(
                children: [
                  const Spacer(),
                  const JewelFlowLogo(size: 72),
                  const SizedBox(height: 24),
                  Text(
                    "You're verified",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.phoneE164 == null
                        ? "You're in — store setup next."
                        : '${state.phoneE164}\nYou\'re in — store setup next.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySecondary(height: 1.45),
                  ),
                  const Spacer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
