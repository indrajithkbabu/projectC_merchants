import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/models/country_model.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(const AuthState()) {
    on<AuthCountryChanged>(_onCountryChanged);
    on<AuthDigitPressed>(_onDigitPressed);
    on<AuthBackspacePressed>(_onBackspacePressed);
    on<AuthPhoneContinuePressed>(_onPhoneContinue);
    on<AuthOtpContinuePressed>(_onOtpContinue);
    on<AuthResendPressed>(_onResendPressed);
    on<AuthTimerTicked>(_onTimerTicked);
    on<AuthClearMessage>(_onClearMessage);
    on<AuthClearVerified>(_onClearVerified);
    on<AuthClearPhoneSubmitted>(_onClearPhoneSubmitted);
    on<AuthResetPhoneFlow>(_onResetPhoneFlow);
    on<AuthLoggedOut>(_onLoggedOut);
  }

  Timer? _resendTimer;
  static const String mockOtp = '123456';
  static const int resendDurationSeconds = 30;

  void _onCountryChanged(
    AuthCountryChanged event,
    Emitter<AuthState> emit,
  ) {
    final maxLen = event.country.maxNationalLength;
    var phone = state.phoneDigits;
    if (phone.length > maxLen) {
      phone = phone.substring(0, maxLen);
    }
    emit(
      state.copyWith(
        country: event.country,
        phoneDigits: phone,
        clearError: true,
      ),
    );
  }

  void _onDigitPressed(
    AuthDigitPressed event,
    Emitter<AuthState> emit,
  ) {
    if (event.target == AuthInputTarget.phone) {
      final max = state.country.maxNationalLength;
      if (state.phoneDigits.length >= max) return;
      emit(
        state.copyWith(
          phoneDigits: '${state.phoneDigits}${event.digit}',
          clearError: true,
        ),
      );
      return;
    }

    if (state.otpDigits.length >= 6) return;
    emit(
      state.copyWith(
        otpDigits: '${state.otpDigits}${event.digit}',
        clearError: true,
      ),
    );
  }

  void _onBackspacePressed(
    AuthBackspacePressed event,
    Emitter<AuthState> emit,
  ) {
    if (event.target == AuthInputTarget.phone) {
      if (state.phoneDigits.isEmpty) return;
      emit(
        state.copyWith(
          phoneDigits:
              state.phoneDigits.substring(0, state.phoneDigits.length - 1),
          clearError: true,
        ),
      );
      return;
    }

    if (state.otpDigits.isEmpty) return;
    emit(
      state.copyWith(
        otpDigits: state.otpDigits.substring(0, state.otpDigits.length - 1),
        clearError: true,
      ),
    );
  }

  Future<void> _onPhoneContinue(
    AuthPhoneContinuePressed event,
    Emitter<AuthState> emit,
  ) async {
    if (!state.isPhoneValid) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _startResendTimer();
    emit(
      state.copyWith(
        otpDigits: '',
        isSubmitting: false,
        resendSeconds: resendDurationSeconds,
        phoneSubmitted: true,
        clearError: true,
      ),
    );
  }

  Future<void> _onOtpContinue(
    AuthOtpContinuePressed event,
    Emitter<AuthState> emit,
  ) async {
    if (state.otpDigits.length != 6) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (state.otpDigits != mockOtp) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Invalid code. Use 123456 for this demo.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isSubmitting: false,
        isVerified: true,
        status: AuthStatus.authenticated,
        phoneE164: state.e164Phone,
        clearError: true,
      ),
    );
  }

  void _onResendPressed(
    AuthResendPressed event,
    Emitter<AuthState> emit,
  ) {
    if (state.resendSeconds > 0) return;
    _startResendTimer();
    emit(
      state.copyWith(
        otpDigits: '',
        resendSeconds: resendDurationSeconds,
        clearError: true,
      ),
    );
  }

  void _onTimerTicked(AuthTimerTicked event, Emitter<AuthState> emit) {
    emit(state.copyWith(resendSeconds: event.secondsRemaining));
  }

  void _onClearMessage(AuthClearMessage event, Emitter<AuthState> emit) {
    emit(state.copyWith(clearError: true));
  }

  void _onClearVerified(AuthClearVerified event, Emitter<AuthState> emit) {
    emit(state.copyWith(clearVerified: true));
  }

  void _onClearPhoneSubmitted(
    AuthClearPhoneSubmitted event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(clearPhoneSubmitted: true));
  }

  void _onResetPhoneFlow(AuthResetPhoneFlow event, Emitter<AuthState> emit) {
    _cancelResendTimer();
    emit(
      state.copyWith(
        otpDigits: '',
        resendSeconds: 0,
        clearError: true,
        clearVerified: true,
        clearPhoneSubmitted: true,
      ),
    );
  }

  void _onLoggedOut(AuthLoggedOut event, Emitter<AuthState> emit) {
    _cancelResendTimer();
    emit(const AuthState());
  }

  void _startResendTimer() {
    _cancelResendTimer();
    var remaining = resendDurationSeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining -= 1;
      if (remaining <= 0) {
        timer.cancel();
        add(const AuthTimerTicked(0));
      } else {
        add(AuthTimerTicked(remaining));
      }
    });
  }

  void _cancelResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = null;
  }

  @override
  Future<void> close() {
    _cancelResendTimer();
    return super.close();
  }
}
