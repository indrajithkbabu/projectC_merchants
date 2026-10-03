import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/auth/auth_bloc.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/otp_sms_autofill.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/custom_numeric_keypad.dart';
import 'package:project_c/helper/widgets/keypad_cta_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/presentation/auth/auth_widgets/otp_code_display.dart';

class OtpRoute extends StatefulWidget {
  const OtpRoute({super.key});

  @override
  State<OtpRoute> createState() => _OtpRouteState();
}

class _OtpRouteState extends State<OtpRoute> {
  static const _tag = 'OtpRoute';

  final TextEditingController _autofillController = TextEditingController();
  final FocusNode _autofillFocus = FocusNode();

  /// Prevents overlapping User Consent listeners.
  bool _smsListenInFlight = false;
  int _listenGeneration = 0;
  int _consecutiveListenFailures = 0;

  @override
  void initState() {
    super.initState();
    _autofillController.addListener(_onAutofillControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_startSmsAutofill());
    });
  }

  @override
  void dispose() {
    _listenGeneration++;
    _autofillController.removeListener(_onAutofillControllerChanged);
    _autofillController.dispose();
    _autofillFocus.dispose();
    unawaited(OtpSmsAutofill.stopListening());
    super.dispose();
  }

  void _onAutofillControllerChanged() {
    final code = OtpSmsAutofill.normalizeCode(_autofillController.text);
    if (code == null) return;
    final bloc = context.read<AuthBloc>();
    final state = bloc.state;
    if (state.isSubmitting || state.isVerified) return;
    if (state.otpDigits == code) return;
    AppLog.d(_tag, 'iOS/autofill field produced OTP');
    bloc.add(AuthOtpAutoFilled(code));
  }

  Future<void> _startSmsAutofill() async {
    if (!Platform.isAndroid) return;
    if (!mounted) return;

    final auth = context.read<AuthBloc>().state;
    if (auth.isSubmitting || auth.isVerified) return;
    if (_smsListenInFlight) return;

    _smsListenInFlight = true;
    final generation = ++_listenGeneration;
    AppLog.d(_tag, 'SMS auto-read listen gen=$generation');

    final result = await OtpSmsAutofill.listenForCode();
    if (!mounted || generation != _listenGeneration) {
      if (generation == _listenGeneration) {
        _smsListenInFlight = false;
      }
      return;
    }

    if (result.status == OtpSmsListenStatus.code && result.code != null) {
      _consecutiveListenFailures = 0;
      _smsListenInFlight = false;
      final bloc = context.read<AuthBloc>();
      final state = bloc.state;
      if (state.isSubmitting || state.isVerified) return;
      AppLog.d(_tag, 'Android SMS auto-read → verify');
      bloc.add(AuthOtpAutoFilled(result.code!));
      return;
    }

    _smsListenInFlight = false;

    // Re-listen after cancel / timeout. Cap hard failures so missing Play
    // Services cannot spin forever.
    if (result.status == OtpSmsListenStatus.canceled) {
      _consecutiveListenFailures = 0;
    } else if (result.status == OtpSmsListenStatus.failed) {
      _consecutiveListenFailures++;
      if (_consecutiveListenFailures > 3) {
        AppLog.d(_tag, 'SMS auto-read stopped after repeated failures');
        return;
      }
    } else {
      return;
    }

    final afterListen = context.read<AuthBloc>().state;
    if (afterListen.isSubmitting || afterListen.isVerified) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || generation != _listenGeneration) return;
    unawaited(_startSmsAutofill());
  }

  Future<void> _restartSmsAutofill() async {
    await OtpSmsAutofill.stopListening();
    _smsListenInFlight = false;
    _consecutiveListenFailures = 0;
    if (!mounted) return;
    await _startSmsAutofill();
  }

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
          listenWhen:
              (prev, curr) =>
                  curr.errorMessage != null &&
                  curr.errorMessage != prev.errorMessage,
          listener: (context, state) {
            final message = state.errorMessage?.trim();
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            context.read<AuthBloc>().add(const AuthClearMessage());
            // After a failed verify, listen again for a new SMS (or resend).
            unawaited(_restartSmsAutofill());
          },
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen:
              (prev, curr) =>
                  curr.postAuthRoute != null &&
                  curr.postAuthRoute != prev.postAuthRoute,
          listener: (context, state) {
            final route = state.postAuthRoute;
            if (route == null) return;
            context.read<AuthBloc>().add(const AuthClearPostAuthNavigation());
            Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => r.isFirst);
          },
        ),
        // Fresh challenge (initial request already set before push; resend updates id).
        BlocListener<AuthBloc, AuthState>(
          listenWhen:
              (prev, curr) =>
                  curr.challengeId != null &&
                  curr.challengeId!.isNotEmpty &&
                  curr.challengeId != prev.challengeId,
          listener: (context, state) {
            _autofillController.clear();
            unawaited(_restartSmsAutofill());
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        resizeToAvoidBottomInset: false,
        child: Stack(
          children: [
            // Invisible autofill target (iOS SMS OTP suggestion / Android Autofill).
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0,
                child: AutofillGroup(
                  child: TextField(
                    controller: _autofillController,
                    focusNode: _autofillFocus,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    enableSuggestions: false,
                    autocorrect: false,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    style: const TextStyle(color: Colors.transparent),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(OtpSmsAutofill.codeLength),
                    ],
                  ),
                ),
              ),
            ),
            BlocBuilder<AuthBloc, AuthState>(
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
                                context.read<AuthBloc>().add(
                                  const AuthResetPhoneFlow(),
                                );
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
                            Text(
                              'We sent an SMS with a code to',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySecondary(),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.maskedPhoneDisplay,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
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
                                onPressed:
                                    state.canResend
                                        ? () => context.read<AuthBloc>().add(
                                          const AuthResendPressed(),
                                        )
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
                      onPressed:
                          () => context.read<AuthBloc>().add(
                            const AuthOtpContinuePressed(),
                          ),
                    ),
                    CustomNumericKeypad(
                      onDigit:
                          (digit) => context.read<AuthBloc>().add(
                            AuthDigitPressed(
                              digit,
                              target: AuthInputTarget.otp,
                            ),
                          ),
                      onBackspace:
                          () => context.read<AuthBloc>().add(
                            const AuthBackspacePressed(
                              target: AuthInputTarget.otp,
                            ),
                          ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
