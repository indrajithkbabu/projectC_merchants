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
import 'package:project_c/models/country_model.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/auth/auth_widgets/phone_country_field.dart';
import 'package:project_c/presentation/auth/auth_widgets/phone_number_field.dart';

class PhoneRoute extends StatelessWidget {
  const PhoneRoute({super.key});

  Future<void> _openCountryPicker(
    BuildContext context,
    AuthState state,
  ) async {
    final selected = await Navigator.of(context).pushNamed(
      Routes.countryPickerRoute,
      arguments: state.country.isoCode,
    );
    if (selected is! CountryModel || !context.mounted) return;
    context.read<AuthBloc>().add(AuthCountryChanged(selected));
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
          listenWhen: (prev, curr) =>
              curr.phoneSubmitted && !prev.phoneSubmitted,
          listener: (context, state) {
            context.read<AuthBloc>().add(const AuthClearPhoneSubmitted());
            Navigator.of(context).pushNamed(Routes.authOtpRoute);
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppBackButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(height: 12),
                        Text('Your phone number', style: AppTextStyles.title()),
                        const SizedBox(height: 10),
                        Text(
                          'Confirm your country code and enter your phone number.',
                          style: AppTextStyles.bodySecondary(),
                        ),
                        const SizedBox(height: 28),
                        PhoneCountryField(
                          country: state.country,
                          onTap: () => _openCountryPicker(context, state),
                        ),
                        const SizedBox(height: 12),
                        PhoneNumberField(
                          dialCode: state.country.dialCode,
                          displayNumber: state.displayPhone,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "We'll send a one-time code by SMS to verify it's you.",
                          style: AppTextStyles.caption(),
                        ),
                      ],
                    ),
                  ),
                ),
                KeypadCtaBar(
                  label: 'Continue',
                  enabled: state.canContinuePhone,
                  isLoading: state.isSubmitting,
                  onPressed: () => context
                      .read<AuthBloc>()
                      .add(const AuthPhoneContinuePressed()),
                ),
                CustomNumericKeypad(
                  onDigit: (digit) => context.read<AuthBloc>().add(
                        AuthDigitPressed(
                          digit,
                          target: AuthInputTarget.phone,
                        ),
                      ),
                  onBackspace: () => context.read<AuthBloc>().add(
                        const AuthBackspacePressed(
                          target: AuthInputTarget.phone,
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
