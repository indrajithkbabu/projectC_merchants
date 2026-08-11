import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/auth/auth_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/custom_numeric_keypad.dart';
import 'package:project_c/helper/widgets/keypad_cta_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/auth/auth_widgets/otp_code_display.dart';

class OtpRoute extends StatelessWidget {
  const OtpRoute({super.key});

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

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
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (prev, curr) => curr.isVerified && !prev.isVerified,
          listener: (context, state) {
            context.read<AuthBloc>().add(const AuthClearVerified());
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.homePlaceholderRoute,
              (route) => false,
            );
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        resizeToAvoidBottomInset: false,
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppPadding.screen(
                      top: ScreenWrapper.statusBarTop(context),
                      bottom: 16,
                    ),
                    child: Column(
                      children: [
                        AppBackButton(
                          onPressed: () {
                            context
                                .read<AuthBloc>()
                                .add(const AuthResetPhoneFlow());
                            Navigator.of(context).maybePop();
                          },
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            size: 34,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Enter the code',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.title(),
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            style: AppTextStyles.bodySecondary(),
                            children: [
                              const TextSpan(
                                text: 'We sent an SMS with a code to ',
                              ),
                              TextSpan(
                                text: state.maskedPhoneDisplay,
                                style: AppTextStyles.body(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),
                        OtpCodeDisplay(code: state.otpDigits),
                        const SizedBox(height: 20),
                        if (state.resendSeconds > 0)
                          Text(
                            'Resend code in ${_formatTimer(state.resendSeconds)}',
                            style: AppTextStyles.caption(fontSize: 14),
                          )
                        else
                          TextButton(
                            onPressed: state.canResend
                                ? () => context
                                    .read<AuthBloc>()
                                    .add(const AuthResendPressed())
                                : null,
                            child: Text(
                              'Resend code',
                              style: AppTextStyles.label(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                KeypadCtaBar(
                  label: 'Continue',
                  enabled: state.canContinueOtp,
                  isLoading: state.isSubmitting,
                  onPressed: () => context
                      .read<AuthBloc>()
                      .add(const AuthOtpContinuePressed()),
                ),
                CustomNumericKeypad(
                  onDigit: (digit) => context.read<AuthBloc>().add(
                        AuthDigitPressed(
                          digit,
                          target: AuthInputTarget.otp,
                        ),
                      ),
                  onBackspace: () => context.read<AuthBloc>().add(
                        const AuthBackspacePressed(
                          target: AuthInputTarget.otp,
                        ),
                      ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
